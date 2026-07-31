/// What this build can and cannot do off the device.
///
/// ArcVanta's measurement runs entirely on the phone, which is the point. But
/// several surfaces used to offer cloud backup, cloud analysis and "help
/// improve detection" as live switches, and a switch is a promise: flip it and
/// something happens. Nothing did, because there is no service on the other
/// end.
///
/// Rather than delete the ideas, the screens read this flag and present them
/// as not yet available. A user can then tell the difference between a feature
/// they have turned off and a feature that does not exist — a distinction that
/// matters a great deal when the subject is where their video goes.
abstract final class CloudFeatures {
  static const bool isAvailable = false;

  static const String unavailableHeadline = 'Off-device features are not live';

  static const String unavailableBody =
      'Backup, cloud analysis and detection feedback all need an ArcVanta '
      'service to send to, and this build does not include one. Every '
      'measurement you see was computed on this phone and stays here.';

  /// Short form for a single row that would otherwise carry a switch.
  static const String unavailableRowNote = 'Needs a service this build lacks.';
}
