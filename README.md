# ArcVanta AI

Advanced basketball intelligence for iOS and Android. The app turns a single
phone on a tripod into a shooting measurement system: it counts makes and
attempts, locates every shot on the floor, measures release and arc mechanics
from pose, and explains what changed between sessions.

The product rule that shapes every screen: **never show a number the camera
could not actually measure.** Metrics that a given camera placement cannot
support are marked unavailable with the placement that would measure them, and
every value carries a confidence level derived from calibration, detection and
tracking quality.

## Design language

The interface is called *Hardwood and Ink*. It is deliberately not a dark glass
theme.

| Token | Value | Used for |
| --- | --- | --- |
| Canvas | warm parchment | app background, keeps long reading sessions calm |
| Ink | deep indigo with a court-line texture | hero panels, scoreboards, capture surfaces |
| Flare | orange | the shooting action, primary calls to action, live state |
| Court | teal | capture, calibration and camera concepts |
| Insight | violet | analysis, comparison and coaching intelligence |
| Made / Miss | green / red | shot outcomes only, never decoration |

Type is Archivo for headings and metrics, Inter for body, with tabular figures
wherever numbers change in place. All spacing, radii, shadow and motion values
come from `lib/core/theme/av_tokens.dart`; nothing in the feature layer defines
its own.

## Running it

```bash
flutter pub get
flutter run
```

Built and verified against Flutter 3.44.2 with Dart 3.12.

The app ships with a deterministic seeded dataset (`lib/data/seed`) covering
nineteen sessions, a six-athlete roster, a training plan, goals, highlights and
notifications, so every screen is populated without a backend. The live session
screen simulates the capture pipeline, including pose animation, shot phases and
event timing.

## Layout of the code

```
lib/
  core/        theme tokens, colours, typography, router, formatters
  data/        models, metric catalog, repositories, seeded data
  design/      the component library: surfaces, buttons, charts, painters
  features/    one folder per area of the product
  state/       Riverpod stores and app settings
```

`lib/data/metrics/metric_catalog.dart` is the single definition of every
measurable value: its unit, precision, target band, the camera angles that can
support it and how it is presented. Screens read from it rather than formatting
metrics themselves, so a shot detail, a session summary and a coach review all
describe the same measurement identically.

## Decisions

Architecture decisions live in `docs/adr`. The capture pipeline is simulated in
this repository, but the models behind it are already chosen:
[the vision model stack](docs/adr/0001-vision-model-stack.md) is RTMDet for
detection with MediaPipe Pose first and basketball-trained RTMPose second, all
Apache 2.0, so nothing in the analysis path constrains how the app is licensed.

## Testing

```bash
flutter test
```

Three suites run:

- `widget_test.dart` boots the app and checks it reaches onboarding.
- `screen_smoke_test.dart` mounts every screen at five viewport
  configurations (three phone widths, 1.3x text scale and landscape). Layout
  overflow and paint errors fail the test, which is how the interface is kept
  correct on small screens and at accessibility text sizes without a device.
- `ui_preview_test.dart` renders the key surfaces to PNG in `test/previews`
  using the real bundled fonts. Refresh them with:

```bash
flutter test test/ui_preview_test.dart --update-goldens
```

## Building

```bash
flutter build apk --release
flutter build ipa --release
```

## What the product does not claim

Measurements are estimates from video. They are not clinical or medical data,
they do not assess injury risk, and they are never used to make a decision about
a player without a human reading them. On accounts under sixteen a guardian
approves coach access before any shot-level data or video is shared, and public
sharing is not available at all.
