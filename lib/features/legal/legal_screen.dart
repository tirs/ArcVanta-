import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_surface.dart';
import 'legal_documents.dart';

/// Renders a bundled legal document.
///
/// Long prose in a product that is otherwise all numbers needs a comfortable
/// measure and generous leading, so headings sit on the section they open and
/// paragraphs stay readable at large text sizes.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return AvScaffold(
      title: document.title,
      subtitle: 'Effective ${document.effective}',
      leading: const AvBackButton(),
      slivers: [
        SliverGutter(
          child: AvTintCard(
            tint: AvColors.canvasSunken,
            child: Text(document.summary, style: AvType.body.secondary),
          ),
        ),
        for (final section in document.sections)
          SliverGutter(
            top: AvSpace.md,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(section.heading, style: AvType.titleSmall.primary),
                const SizedBox(height: AvSpace.xs),
                Text(
                  section.body,
                  style: AvType.bodySmall.secondary.copyWith(height: 1.55),
                ),
              ],
            ),
          ),
        const SliverGutter(top: AvSpace.xl, child: SizedBox(height: AvSpace.xl)),
      ],
    );
  }
}
