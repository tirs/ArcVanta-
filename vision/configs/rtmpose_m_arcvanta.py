"""RTMPose-m at 256x192, COCO-17, unchanged in every way that matters.

Unlike the detector this is not a class change: the seventeen COCO landmarks
already cover every joint the product measures. What it is instead is a
domain fine-tune, because a shooter at the top of a jump shot — arms
overhead, one foot off the ground, body rotated away from the camera — is the
tail of the COCO distribution and the stock checkpoint is weakest exactly
where the measurement is taken.

Inherits from the vendored mmpose at the commit in vision/pins.lock. RTMPose
lives under projects/, which upstream holds to a weaker API-stability bar than
the main package; that is the reason the commit is pinned rather than the
version, and the reason the .onnx rather than this file is what the app
depends on.
"""

_base_ = [
    "../../vision/.vendor/mmpose/configs/body_2d_keypoint/rtmpose/coco/"
    "rtmpose-m_8xb256-420e_coco-256x192.py",
]

# Both are the contract's. codec.input_size is (width, height); the ONNX input
# is NCHW, so the contract writes the same thing as [1, 3, 256, 192].
input_size = (192, 256)
simcc_split_ratio = 2.0

codec = dict(
    type="SimCCLabel",
    input_size=input_size,
    sigma=(6.0, 6.93),
    simcc_split_ratio=simcc_split_ratio,
    normalize=False,
    use_dark=False,
)

model = dict(
    head=dict(
        input_size=input_size,
        simcc_split_ratio=simcc_split_ratio,
        decoder=codec,
    ),
    test_cfg=dict(flip_test=False),
)
# Flip-test averages a run with its mirror. It buys accuracy at exactly double
# the cost, and it cannot be exported as a single graph, so it is off here to
# keep training and inference measuring the same thing.

data_root = "data/arcvanta/"
metainfo = dict(from_file="configs/_base_/datasets/coco.py")

train_dataloader = dict(
    batch_size=64,
    dataset=dict(
        data_root=data_root,
        metainfo=metainfo,
        ann_file="annotations/pose_train.json",
        data_prefix=dict(img="train/"),
    ),
)

val_dataloader = dict(
    dataset=dict(
        data_root=data_root,
        metainfo=metainfo,
        ann_file="annotations/pose_val.json",
        data_prefix=dict(img="val/"),
        # Ground-truth boxes at validation. The detector is measured
        # separately, and mixing the two makes a pose regression look like a
        # detection regression.
        bbox_file=None,
    )
)
test_dataloader = val_dataloader

val_evaluator = dict(ann_file=data_root + "annotations/pose_val.json")
test_evaluator = val_evaluator

load_from = (
    "https://download.openmmlab.com/mmpose/v1/projects/rtmposev1/"
    "rtmpose-m_simcc-aic-coco_pt-aic-coco_420e-256x192-63eb25f7_20230126.pth"
)

max_epochs = 80
base_lr = 0.0005

train_cfg = dict(max_epochs=max_epochs, val_interval=5)
optim_wrapper = dict(optimizer=dict(lr=base_lr))

param_scheduler = [
    dict(type="LinearLR", start_factor=1.0e-5, by_epoch=False, begin=0, end=500),
    dict(
        type="CosineAnnealingLR",
        eta_min=base_lr * 0.05,
        begin=max_epochs // 2,
        end=max_epochs,
        T_max=max_epochs // 2,
        by_epoch=True,
        convert_to_iter_based=True,
    ),
]

default_hooks = dict(
    checkpoint=dict(interval=5, max_keep_ckpts=3, save_best="coco/AP")
)
