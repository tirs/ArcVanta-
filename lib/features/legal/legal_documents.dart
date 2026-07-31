/// The terms and privacy notice, held in the binary rather than behind a URL.
///
/// A build that measures everything on the device should not need a network
/// round trip to show the user what they agreed to, and a hosted policy would
/// let the text drift away from the build it describes. Each document carries
/// the date it was last changed so a support conversation can pin down which
/// wording someone accepted.
library;

class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.summary,
    required this.effective,
    required this.sections,
  });

  final String title;
  final String summary;
  final String effective;
  final List<LegalSection> sections;
}

class LegalSection {
  const LegalSection({required this.heading, required this.body});

  final String heading;
  final String body;
}

const String _effective = '30 July 2026';

const LegalDocument termsOfService = LegalDocument(
  title: 'Terms of service',
  summary:
      'What ArcVanta promises to do, what it does not promise, and what is '
      'expected of you while using it.',
  effective: _effective,
  sections: [
    LegalSection(
      heading: 'What this software is',
      body:
          'ArcVanta AI is a measurement tool. It uses the camera on your '
          'device to estimate shooting outcomes and body mechanics, and it '
          'stores those estimates locally so you can compare sessions over '
          'time. It is a training aid, not a referee, a scout or a clinician.',
    ),
    LegalSection(
      heading: 'Accuracy and its limits',
      body:
          'Every number in the app is an estimate produced from camera frames '
          'under the conditions you provided: placement, lighting, framing and '
          'how still the phone was. The app grades each session and tells you '
          'when a measurement is weak. Do not use these numbers for medical, '
          'diagnostic, contractual or selection decisions. Where a result '
          'looks wrong, correct it; corrections are kept separate from what '
          'the models produced.',
    ),
    LegalSection(
      heading: 'Your account and your data',
      body:
          'This build has no accounts and no servers. Everything you record '
          'is written to this device only. Removing the app removes the data '
          'with it, and no copy exists anywhere else. Export your data before '
          'uninstalling if you want to keep it.',
    ),
    LegalSection(
      heading: 'Acceptable use',
      body:
          'Record only in places where you are allowed to use a camera, and '
          'only people who know they are being recorded. If you point the '
          'camera at anyone else, getting their agreement is your '
          'responsibility, and a guardian must agree for anyone under 18. Do '
          'not use the app to monitor people covertly.',
    ),
    LegalSection(
      heading: 'Safety while training',
      body:
          'The app does not know your physical condition. Warm up, rest, and '
          'stop when something hurts. Coaching cues are general prompts drawn '
          'from your own measurements, not individual medical advice.',
    ),
    LegalSection(
      heading: 'Payment',
      body:
          'This build has no purchasing. Every feature that works runs on the '
          'device and nothing is behind a paywall. Any future paid tier will '
          'be presented before it charges, never applied retroactively.',
    ),
    LegalSection(
      heading: 'Liability',
      body:
          'The software is provided as it is, without warranty of any kind. '
          'To the extent the law allows, ArcVanta is not liable for injury, '
          'lost data, missed opportunities or decisions taken on the basis of '
          'a measurement. Nothing here removes rights that cannot be removed '
          'by agreement where you live.',
    ),
    LegalSection(
      heading: 'Changes',
      body:
          'These terms travel with the build. A new version of the app can '
          'carry new terms, and the effective date above tells you which '
          'wording you are reading. Continuing to use a build means the terms '
          'inside it apply.',
    ),
    LegalSection(
      heading: 'Contact',
      body: 'Questions about these terms go to support@arcvanta.ai.',
    ),
  ],
);

const LegalDocument privacyPolicy = LegalDocument(
  title: 'Privacy policy',
  summary:
      'What ArcVanta collects, where it goes, and how to get rid of it. In '
      'this build the short answer is: everything stays on your phone.',
  effective: _effective,
  sections: [
    LegalSection(
      heading: 'What is collected',
      body:
          'Camera frames are read, measured and discarded while a session '
          'runs. No video or still image is written to disk. What is saved is '
          'the result: shot outcomes, positions on the court, joint angles, '
          'timings, session summaries, and the calibration used to produce '
          'them. Alongside that sits what you typed yourself, such as your '
          'display name, age band and goals.',
    ),
    LegalSection(
      heading: 'Where it goes',
      body:
          'Nowhere. This build has no servers, no analytics, no crash '
          'reporting and no advertising identifiers. There is no network path '
          'for your sessions to travel on, so there is no upload to turn off.',
    ),
    LegalSection(
      heading: 'What leaves only when you ask',
      body:
          'Two actions send data off the device, both started by you and both '
          'showing what is being sent first. Export writes a JSON file and '
          'hands it to the share sheet you choose. Emailing support attaches '
          'a short diagnostic report of app version, device model, which '
          'capture pipeline ran and how many sessions exist, with no names '
          'and no measurements.',
    ),
    LegalSection(
      heading: 'How long it is kept',
      body:
          'Until you delete it. Sessions do not expire and nothing is pruned '
          'behind your back. Delete everything under Privacy and data clears '
          'the database, and uninstalling the app removes the rest.',
    ),
    LegalSection(
      heading: 'Children',
      body:
          'If the age band you choose is under 18, the app asks for a '
          'guardian name and email and records that consent on the device. '
          'The email is stored locally and is not contacted by the app, '
          'because there is no service to contact it from.',
    ),
    LegalSection(
      heading: 'Permissions',
      body:
          'Camera access is required, because nothing can be measured without '
          'it. The microphone, photo library and system notifications are not '
          'used at all. Alerts appear inside the app only.',
    ),
    LegalSection(
      heading: 'Your rights',
      body:
          'Because your data lives on hardware you hold, access, portability '
          'and erasure are all immediate: export produces a complete machine '
          'readable copy, and delete removes it. No request to us is needed, '
          'and we could not action one, because we do not hold anything.',
    ),
    LegalSection(
      heading: 'Contact',
      body: 'Privacy questions go to support@arcvanta.ai.',
    ),
  ],
);
