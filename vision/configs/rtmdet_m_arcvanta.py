"""RTMDet-m fine-tuned to the four things a shot measurement depends on.

COCO has `person` and `sports ball` but no rim and no backboard, and those two
are exactly what the court solve reads: the ring gives the ellipse the pose
solve needs, and the backboard disambiguates which way the camera is facing.
So this is a fine-tune from the COCO checkpoint with a four-class head rather
than a stock model with a class filter.

Run it against the vendored mmdet at the commit in vision/pins.lock. Nothing
here is imported by the app: the output of training this is a .pth, and the
output of exporting that is the .onnx the app actually loads.

Point it at a dataset with:

    tools/train.py vision/configs/rtmdet_m_arcvanta.py \\
        --cfg-options data_root=work/datasets/arcvanta-det/
"""

# A path into the vendored checkout rather than mmdet's own `mmdet::` scheme.
# That scheme resolves through the installed distribution's location, which for
# an editable install is site-packages, where mmdet's config tree is not. The
# base config is only a file to read, and the vendored tree is at a known
# commit, so reading it directly is both simpler and the same in every
# environment — including the training one, which builds mmcv against a
# different torch but shares this pure-Python config tree.
_base_ = ["../.vendor/mmdet/configs/rtmdet/rtmdet_m_8xb32-300e_coco.py"]

classes = ("person", "ball", "rim", "backboard")
num_classes = len(classes)

# 640 is the contract's input size. Changing it here without changing
# vision/contract/model_contract.json produces a graph the verifier rejects,
# which is the intended relationship between the two files.
image_size = (640, 640)

model = dict(bbox_head=dict(num_classes=num_classes))

data_root = "work/datasets/arcvanta-det/"
metainfo = dict(
    classes=classes,
    # Overlay colours, so a labelling review looks like the app does.
    palette=[(232, 138, 62), (214, 92, 51), (44, 122, 123), (58, 63, 74)],
)

# 16 fits a 16 GB card at 640 with RTMDet-m and leaves room for the EMA copy.
train_dataloader = dict(
    batch_size=16,
    num_workers=8,
    dataset=dict(
        data_root=data_root,
        metainfo=metainfo,
        ann_file="annotations/train.json",
        data_prefix=dict(img="images_train/"),
    ),
)

val_dataloader = dict(
    batch_size=8,
    num_workers=4,
    dataset=dict(
        data_root=data_root,
        metainfo=metainfo,
        ann_file="annotations/val.json",
        data_prefix=dict(img="images_val/"),
    ),
)

test_dataloader = dict(
    batch_size=8,
    num_workers=4,
    dataset=dict(
        data_root=data_root,
        metainfo=metainfo,
        ann_file="annotations/test.json",
        data_prefix=dict(img="images_test/"),
    ),
)

val_evaluator = dict(ann_file=data_root + "annotations/val.json", classwise=True)
test_evaluator = dict(ann_file=data_root + "annotations/test.json", classwise=True)

# A fine-tune, not a training run. The COCO weights already know what a person
# and a ball look like; what they are learning is two new classes and a gym.
load_from = (
    "https://download.openmmlab.com/mmdetection/v3.0/rtmdet/"
    "rtmdet_m_8xb32-300e_coco/"
    "rtmdet_m_8xb32-300e_coco_20220719_112220-229f527c.pth"
)

max_epochs = 60
# The last stage drops the heavy augmentation so the model settles on the real
# distribution rather than on mosaics of it.
stage2_num_epochs = 10
# A twentieth of the from-scratch rate. The backbone already knows what it is
# looking at, and the full 0.004 unlearns that faster than 1,400 images can
# teach it anything back.
base_lr = 0.0002

train_cfg = dict(
    max_epochs=max_epochs,
    val_interval=5,
    dynamic_intervals=[(max_epochs - stage2_num_epochs, 1)],
)

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
    checkpoint=dict(interval=5, max_keep_ckpts=3, save_best="coco/bbox_mAP"),
    logger=dict(interval=20),
)

# Restated in full because the base builds its switch epoch from the base's own
# 300-epoch schedule. Inheriting it would switch off the heavy augmentation at
# epoch 280 of a 60-epoch run, which is to say never.
custom_hooks = [
    dict(
        type="EMAHook",
        ema_type="ExpMomentumEMA",
        momentum=0.0002,
        update_buffers=True,
        priority=49,
    ),
    dict(
        type="PipelineSwitchHook",
        switch_epoch=max_epochs - stage2_num_epochs,
        switch_pipeline={{_base_.train_pipeline_stage2}},
    ),
]
