#!/usr/bin/env python3
"""Tests the contract verifier against graphs built to pass and to fail.

The verifier is the only thing standing between a bad export and a shipped
model, so it gets tested the same way the app does. The graphs here are
synthetic — they compute nothing meaningful — but they have exactly the shapes,
names, dtypes and operators the contract asks for, which is all the verifier
looks at.

    tool/vision/.venv/bin/python tool/vision/test_verify_contract.py

Needs only onnx, numpy and onnxruntime, not the full training environment.
"""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
import onnx
from onnx import TensorProto, helper, numpy_helper

import pins

HERE = Path(__file__).resolve().parent
CONTRACT = json.loads(pins.CONTRACT.read_text())


def constant(name: str, array: np.ndarray):
    return numpy_helper.from_array(array, name=name)


def detector_graph(
    *,
    input_name: str | None = None,
    input_shape: list[int] | None = None,
    dets_shape: list[int] | None = None,
    include_nms: bool = True,
    opset: int | None = None,
) -> onnx.ModelProto:
    """A graph shaped like the exported detector.

    Every property the verifier inspects is a parameter, so a test can bend
    exactly one of them and confirm that is the one that gets reported.
    """
    spec = CONTRACT["detector"]
    input_name = input_name or spec["input"]["name"]
    input_shape = input_shape or spec["input"]["shape"]
    dets_shape = dets_shape or spec["outputs"][0]["shape"]
    labels_shape = spec["outputs"][1]["shape"]
    opset = opset or spec["opset"]

    images = helper.make_tensor_value_info(input_name, TensorProto.FLOAT, input_shape)
    dets_out = helper.make_tensor_value_info("dets", TensorProto.FLOAT, dets_shape)
    labels_out = helper.make_tensor_value_info("labels", TensorProto.INT64, labels_shape)

    rng = np.random.default_rng(7)
    initialisers = [
        constant("dets_base", rng.random(dets_shape).astype(np.float32)),
        constant(
            "labels_value",
            rng.integers(0, 4, size=labels_shape).astype(np.int64),
        ),
    ]

    nodes = [
        # Tie the output to the input so the graph is not constant-folded away
        # and so the run check exercises something.
        helper.make_node("ReduceMean", ["images_in"], ["scale"], keepdims=0),
        helper.make_node("Add", ["dets_base", "scale"], ["dets"]),
        helper.make_node("Identity", ["labels_value"], ["labels"]),
    ]
    nodes.insert(0, helper.make_node("Identity", [input_name], ["images_in"]))

    if include_nms:
        # The contract says suppression happens in the graph. The verifier only
        # looks for the operator, so a self-contained one is enough to satisfy
        # it; a real export wires it into the decode.
        initialisers += [
            constant("nms_boxes", rng.random((1, 8, 4)).astype(np.float32)),
            constant("nms_scores", rng.random((1, 4, 8)).astype(np.float32)),
            constant("nms_max", np.array([100], dtype=np.int64)),
            constant("nms_iou", np.array([0.6], dtype=np.float32)),
            constant("nms_score", np.array([0.05], dtype=np.float32)),
        ]
        nodes.append(
            helper.make_node(
                "NonMaxSuppression",
                ["nms_boxes", "nms_scores", "nms_max", "nms_iou", "nms_score"],
                ["nms_selected"],
            )
        )
        # The selection is not a graph output, so its dynamic shape does not
        # reach the static-shape check. It is reduced to keep the graph valid.
        nodes.append(
            helper.make_node("Shape", ["nms_selected"], ["nms_shape"]),
        )

    graph = helper.make_graph(
        nodes,
        "detector",
        [images],
        [dets_out, labels_out],
        initializer=initialisers,
    )
    model = helper.make_model(
        graph, opset_imports=[helper.make_opsetid("", opset)]
    )
    model.ir_version = 9
    return model


def pose_graph(
    *,
    input_shape: list[int] | None = None,
    simcc_x_shape: list[int] | None = None,
    flat: bool = False,
) -> onnx.ModelProto:
    """A graph shaped like the exported pose model."""
    spec = CONTRACT["pose"]
    input_shape = input_shape or spec["input"]["shape"]
    simcc_x_shape = simcc_x_shape or spec["outputs"][0]["shape"]
    simcc_y_shape = spec["outputs"][1]["shape"]

    image = helper.make_tensor_value_info(
        spec["input"]["name"], TensorProto.FLOAT, input_shape
    )
    x_out = helper.make_tensor_value_info("simcc_x", TensorProto.FLOAT, simcc_x_shape)
    y_out = helper.make_tensor_value_info("simcc_y", TensorProto.FLOAT, simcc_y_shape)

    rng = np.random.default_rng(11)
    # A flat head is the failure the run check exists to catch: every landmark
    # would argmax to index zero.
    x_base = (
        np.zeros(simcc_x_shape, dtype=np.float32)
        if flat
        else rng.random(simcc_x_shape).astype(np.float32)
    )
    y_base = (
        np.zeros(simcc_y_shape, dtype=np.float32)
        if flat
        else rng.random(simcc_y_shape).astype(np.float32)
    )

    initialisers = [constant("x_base", x_base), constant("y_base", y_base)]
    nodes = [
        helper.make_node("ReduceMean", [spec["input"]["name"]], ["scale"], keepdims=0),
        helper.make_node("Mul", ["scale", "zero"], ["tied"]),
        helper.make_node("Add", ["x_base", "tied"], ["simcc_x"]),
        helper.make_node("Add", ["y_base", "tied"], ["simcc_y"]),
    ]
    # Zero-weighted so a flat head stays flat regardless of the input, which is
    # what makes the flatness test deterministic.
    initialisers.append(constant("zero", np.array(0.0, dtype=np.float32)))

    graph = helper.make_graph(
        nodes, "pose", [image], [x_out, y_out], initializer=initialisers
    )
    model = helper.make_model(
        graph, opset_imports=[helper.make_opsetid("", spec["opset"])]
    )
    model.ir_version = 9
    return model


def verify(directory: Path, run: bool = False) -> tuple[int, str]:
    command = [sys.executable, str(HERE / "verify_contract.py"), "--dir", str(directory)]
    if run:
        command.append("--run")
    result = subprocess.run(command, capture_output=True, text=True)
    return result.returncode, result.stdout + result.stderr


class Failed(AssertionError):
    pass


CASES = []


def case(name):
    def register(function):
        CASES.append((name, function))
        return function

    return register


@case("a conforming pair passes")
def _(directory: Path):
    onnx.save(detector_graph(), directory / CONTRACT["detector"]["file"])
    onnx.save(pose_graph(), directory / CONTRACT["pose"]["file"])

    code, output = verify(directory)
    if code != 0:
        raise Failed(f"expected a pass, got:\n{output}")
    if "2 graph(s) OK" not in output:
        raise Failed(f"expected both graphs to be counted:\n{output}")


@case("a conforming pair also passes when actually run")
def _(directory: Path):
    onnx.save(detector_graph(), directory / CONTRACT["detector"]["file"])
    onnx.save(pose_graph(), directory / CONTRACT["pose"]["file"])

    code, output = verify(directory, run=True)
    if code != 0:
        raise Failed(f"expected a pass, got:\n{output}")
    if "ran on synthetic input" not in output:
        raise Failed(f"expected the run check to report:\n{output}")


@case("a renamed input is rejected")
def _(directory: Path):
    onnx.save(
        detector_graph(input_name="input_0"),
        directory / CONTRACT["detector"]["file"],
    )

    code, output = verify(directory)
    if code == 0:
        raise Failed("a renamed input should not pass")
    if "input is 'input_0'" not in output:
        raise Failed(f"the failure should name the input:\n{output}")


@case("a wrong input size is rejected")
def _(directory: Path):
    # The failure this exists for: a 512 detector produces boxes in the wrong
    # place, and every one of them still looks like a plausible detection.
    onnx.save(
        detector_graph(input_shape=[1, 3, 512, 512]),
        directory / CONTRACT["detector"]["file"],
    )

    code, output = verify(directory)
    if code == 0:
        raise Failed("a 512 input should not pass a 640 contract")
    if "input shape is [1, 3, 512, 512]" not in output:
        raise Failed(f"the failure should name the shape:\n{output}")


@case("a dynamic batch dimension is rejected")
def _(directory: Path):
    model = detector_graph()
    model.graph.input[0].type.tensor_type.shape.dim[0].dim_param = "batch"
    model.graph.input[0].type.tensor_type.shape.dim[0].ClearField("dim_value")
    onnx.save(model, directory / CONTRACT["detector"]["file"])

    code, output = verify(directory)
    if code == 0:
        raise Failed("a dynamic dimension should not pass")
    if "dynamic dimension" not in output:
        raise Failed(f"the failure should say why it matters:\n{output}")


@case("a graph without NMS is rejected")
def _(directory: Path):
    onnx.save(
        detector_graph(include_nms=False),
        directory / CONTRACT["detector"]["file"],
    )

    code, output = verify(directory)
    if code == 0:
        raise Failed("the contract says NMS is in the graph")
    if "NonMaxSuppression" not in output:
        raise Failed(f"the failure should name the operator:\n{output}")


@case("a wrong opset is rejected")
def _(directory: Path):
    onnx.save(detector_graph(opset=13), directory / CONTRACT["detector"]["file"])

    code, output = verify(directory)
    if code == 0:
        raise Failed("opset 13 should not pass an opset 17 contract")
    if "opset is 13" not in output:
        raise Failed(f"the failure should name the opset:\n{output}")


@case("a wrong SimCC width is rejected")
def _(directory: Path):
    # 384 is 192 columns times the split ratio. A model exported at a different
    # ratio decodes every landmark to the wrong x.
    onnx.save(
        pose_graph(simcc_x_shape=[1, 17, 192]),
        directory / CONTRACT["pose"]["file"],
    )

    code, output = verify(directory)
    if code == 0:
        raise Failed("a 192-bin simcc_x should not pass")
    if "simcc_x" not in output:
        raise Failed(f"the failure should name the output:\n{output}")


@case("a flat SimCC head is caught only by the run check")
def _(directory: Path):
    onnx.save(pose_graph(flat=True), directory / CONTRACT["pose"]["file"])

    code, _ = verify(directory)
    if code != 0:
        raise Failed("a flat head is structurally valid, so the shape check passes")

    code, output = verify(directory, run=True)
    if code == 0:
        raise Failed("a flat head should not pass the run check")
    if "is flat" not in output:
        raise Failed(f"the failure should say the head is flat:\n{output}")


@case("an empty directory is a failure, not a pass")
def _(directory: Path):
    code, output = verify(directory)
    if code == 0:
        raise Failed("verifying nothing should not report success")
    if "No graphs found" not in output:
        raise Failed(f"the failure should say the directory is empty:\n{output}")


def main() -> int:
    passed = 0
    failures = []

    for name, function in CASES:
        with tempfile.TemporaryDirectory() as raw:
            directory = Path(raw)
            try:
                function(directory)
                print(f"  ok   {name}")
                passed += 1
            except Exception as error:  # noqa: BLE001
                print(f"  FAIL {name}")
                failures.append((name, error))

    print()
    if not failures:
        print(f"{passed} passed")
        return 0

    for name, error in failures:
        print(f"{name}:\n  {error}\n")
    print(f"{passed} passed, {len(failures)} failed")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
