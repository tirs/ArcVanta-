#!/usr/bin/env python3
"""Checks exported graphs against vision/contract/model_contract.json.

This is the gate. A graph that fails here is not published, because the ways
an ONNX export goes wrong are mostly silent: a pose model at the wrong input
size still returns seventeen plausible landmarks, in the wrong places, and the
first sign of it is a coach disputing a release angle.

    python tool/vision/verify_contract.py --dir build/vision

Structural checks need only `onnx`. Passing `--run` additionally executes both
graphs on a fixed synthetic input under onnxruntime, which is the only way to
catch an export that is shaped right and computes nothing — an all-zero or
all-NaN output tensor.

Exit code is 0 when every check passes and 1 otherwise, so this can sit in CI
in front of a model release.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import pins


class Report:
    """Collects every failure rather than stopping at the first.

    An export that is wrong is usually wrong in several ways at once, and one
    round trip through a two-hour training job per discovered problem is not a
    workflow.
    """

    def __init__(self) -> None:
        self.failures: list[str] = []
        self.notes: list[str] = []

    def check(self, condition: bool, message: str) -> bool:
        if not condition:
            self.failures.append(message)
        return condition

    def note(self, message: str) -> None:
        self.notes.append(message)

    @property
    def ok(self) -> bool:
        return not self.failures


def load_contract() -> dict:
    return json.loads(pins.CONTRACT.read_text())


def shape_of(value) -> list:
    """ONNX shapes carry either a number or a symbolic name per dimension."""
    dimensions = []
    for dimension in value.type.tensor_type.shape.dim:
        if dimension.HasField("dim_value"):
            dimensions.append(dimension.dim_value)
        else:
            dimensions.append(dimension.dim_param or "?")
    return dimensions


ELEMENT_TYPES = {1: "float32", 6: "int32", 7: "int64", 9: "bool", 10: "float16"}


def dtype_of(value) -> str:
    return ELEMENT_TYPES.get(
        value.type.tensor_type.elem_type,
        f"type{value.type.tensor_type.elem_type}",
    )


def verify_graph(path: Path, spec: dict, report: Report) -> None:
    import onnx

    label = spec["file"]

    if not path.exists():
        report.check(False, f"{label}: not found at {path}")
        return

    try:
        model = onnx.load(str(path))
        onnx.checker.check_model(model)
    except Exception as error:  # noqa: BLE001 - any failure here is a failure
        report.check(False, f"{label}: will not load: {error}")
        return

    opsets = {imported.domain: imported.version for imported in model.opset_import}
    actual_opset = opsets.get("", opsets.get("ai.onnx"))
    report.check(
        actual_opset == spec["opset"],
        f"{label}: opset is {actual_opset}, contract says {spec['opset']}",
    )

    # Initialisers appear in graph.input on some exporters, so they are
    # excluded before the input is checked or the count is meaningless.
    initialisers = {tensor.name for tensor in model.graph.initializer}
    inputs = [value for value in model.graph.input if value.name not in initialisers]

    report.check(
        len(inputs) == 1,
        f"{label}: expected exactly one input, found {[v.name for v in inputs]}",
    )

    if inputs:
        actual = inputs[0]
        expected = spec["input"]
        report.check(
            actual.name == expected["name"],
            f"{label}: input is '{actual.name}', contract says '{expected['name']}'",
        )
        report.check(
            shape_of(actual) == expected["shape"],
            f"{label}: input shape is {shape_of(actual)}, "
            f"contract says {expected['shape']}",
        )
        report.check(
            dtype_of(actual) == expected["dtype"],
            f"{label}: input dtype is {dtype_of(actual)}, "
            f"contract says {expected['dtype']}",
        )

    outputs = {value.name: value for value in model.graph.output}
    for expected in spec["outputs"]:
        name = expected["name"]
        if not report.check(
            name in outputs,
            f"{label}: no output '{name}'; found {sorted(outputs)}",
        ):
            continue

        actual = outputs[name]
        report.check(
            shape_of(actual) == expected["shape"],
            f"{label}: output '{name}' is {shape_of(actual)}, "
            f"contract says {expected['shape']}",
        )
        report.check(
            dtype_of(actual) == expected["dtype"],
            f"{label}: output '{name}' is {dtype_of(actual)}, "
            f"contract says {expected['dtype']}",
        )

    extra = set(outputs) - {output["name"] for output in spec["outputs"]}
    if extra:
        report.note(f"{label}: graph also emits {sorted(extra)}, which the app ignores")

    # A dynamic dimension anywhere is worth saying out loud: NNAPI and Core ML
    # will decline the subgraph and the run silently lands on the CPU.
    for value in list(inputs) + list(outputs.values()):
        symbolic = [d for d in shape_of(value) if isinstance(d, str)]
        if symbolic:
            report.check(
                False,
                f"{label}: '{value.name}' has a dynamic dimension {symbolic}; "
                "the accelerators need static shapes",
            )

    if spec.get("nms", {}).get("appliedInGraph"):
        operators = {node.op_type for node in model.graph.node}
        report.check(
            "NonMaxSuppression" in operators,
            f"{label}: the contract says NMS is in the graph, but there is no "
            "NonMaxSuppression node",
        )

    # Reported, never asserted. This verifier answers "does this graph match
    # the contract", which is a question about shapes and behaviour; whether a
    # file is the exact artefact that was published is a different question,
    # and fetch_models.sh is where it gets asked. Conflating the two would make
    # every re-export fail against the digest of the export before it.
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    report.note(f"{label}: sha256 {digest[:16]}...")


def run_graph(path: Path, spec: dict, report: Report) -> None:
    """Executes the graph once to catch an export that computes nothing."""
    import numpy as np
    import onnxruntime as ort

    label = spec["file"]
    if not path.exists():
        return

    try:
        session = ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])
    except Exception as error:  # noqa: BLE001
        report.check(False, f"{label}: onnxruntime will not load it: {error}")
        return

    # A fixed pattern rather than noise: a repeatable input means a repeatable
    # failure, and structure gives the network something to respond to where
    # flat grey might legitimately produce nothing.
    shape = spec["input"]["shape"]
    rows, columns = shape[2], shape[3]
    y, x = np.mgrid[0:rows, 0:columns].astype(np.float32)
    pattern = np.sin(x / 17.0) * np.cos(y / 23.0)
    dummy = np.broadcast_to(pattern, (1, 3, rows, columns)).astype(np.float32).copy()

    try:
        results = session.run(None, {spec["input"]["name"]: dummy})
    except Exception as error:  # noqa: BLE001
        report.check(False, f"{label}: inference failed: {error}")
        return

    names = [output.name for output in session.get_outputs()]
    for name, value in zip(names, results):
        report.check(
            not np.isnan(value).any(),
            f"{label}: output '{name}' contains NaN",
        )
        report.check(
            not np.isinf(value).any(),
            f"{label}: output '{name}' contains infinities",
        )

        if name in ("simcc_x", "simcc_y"):
            # A dead SimCC head returns a flat distribution, which argmaxes to
            # index zero for every landmark and looks like a person standing in
            # the top-left corner.
            spread = float(value.max() - value.min())
            report.check(
                spread > 1e-4,
                f"{label}: output '{name}' is flat, so every landmark would "
                "decode to the same place",
            )

    report.note(f"{label}: ran on synthetic input, outputs are finite")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dir",
        type=Path,
        default=pins.ROOT / "build" / "vision",
        help="Where the exported graphs are.",
    )
    parser.add_argument(
        "--run",
        action="store_true",
        help="Also execute each graph once under onnxruntime.",
    )
    args = parser.parse_args()

    try:
        import onnx  # noqa: F401
    except ImportError:
        print("onnx is not installed. Run tool/vision/setup.sh first.", file=sys.stderr)
        return 2

    contract = load_contract()
    report = Report()

    for role in ("detector", "pose"):
        spec = contract[role]
        path = args.dir / spec["file"]
        # A role can be re-exported on its own, so a file that is simply not
        # there is skipped rather than failed.
        if not path.exists():
            report.note(f"{spec['file']}: not present, skipped")
            continue

        verify_graph(path, spec, report)
        if args.run:
            run_graph(path, spec, report)

    checked = [
        contract[role]["file"]
        for role in ("detector", "pose")
        if (args.dir / contract[role]["file"]).exists()
    ]
    if not checked:
        print(f"No graphs found in {args.dir}.", file=sys.stderr)
        return 1

    for note in report.notes:
        print(f"  {note}")

    if report.ok:
        print(f"\nContract v{contract['contractVersion']}: {len(checked)} graph(s) OK")
        return 0

    print(f"\n{len(report.failures)} contract violation(s):", file=sys.stderr)
    for failure in report.failures:
        print(f"  - {failure}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
