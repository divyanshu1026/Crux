import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../domain/legal_docs.dart';

/// Renders a [LegalDoc] in-app.
///
/// Legal text ships in the binary instead of behind a link so it works
/// offline, survives having no domain, and always matches the installed
/// build.
class LegalDocScreen extends StatelessWidget {
  const LegalDocScreen({super.key, required this.doc});

  final LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(title: Text(doc.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          CxSpace.screen,
          CxSpace.md,
          CxSpace.screen,
          48,
        ),
        children: [
          Text(
            'Last updated ${doc.lastUpdated}',
            style: CxType.caption.copyWith(color: c.textTertiary),
          ),
          const SizedBox(height: CxSpace.lg),
          for (final block in doc.blocks) _Block(block: block),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.block});

  final LegalBlock block;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;

    switch (block) {
      case LegalHeading(:final text):
        return Padding(
          padding: const EdgeInsets.only(top: CxSpace.xl, bottom: CxSpace.sm),
          child: Text(
            text,
            style: CxType.title.copyWith(color: c.textPrimary),
          ),
        );

      case LegalParagraph(:final text):
        return Padding(
          padding: const EdgeInsets.only(bottom: CxSpace.md),
          child: Text(
            text,
            style: CxType.bodySmall.copyWith(color: c.textSecondary, height: 1.6),
          ),
        );

      case LegalBullets(:final items):
        return Padding(
          padding: const EdgeInsets.only(bottom: CxSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: CxSpace.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7, right: CxSpace.sm),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: c.ember,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item,
                          style: CxType.bodySmall
                              .copyWith(color: c.textSecondary, height: 1.6),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );

      // Source documents used tables here. On a phone a definition list reads
      // far better than a table that scrolls sideways.
      case LegalDefinitions(:final entries):
        return Padding(
          padding: const EdgeInsets.only(bottom: CxSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (label, detail) in entries)
                Container(
                  margin: const EdgeInsets.only(bottom: CxSpace.sm),
                  padding: const EdgeInsets.all(CxSpace.md),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: CxRadii.brMd,
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: CxType.bodySmall.copyWith(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: CxType.caption
                            .copyWith(color: c.textSecondary, height: 1.5),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );

      case LegalCallout(:final text):
        return Container(
          margin: const EdgeInsets.only(bottom: CxSpace.lg),
          padding: const EdgeInsets.all(CxSpace.md),
          decoration: BoxDecoration(
            color: c.ember.withValues(alpha: 0.10),
            borderRadius: CxRadii.brMd,
            border: Border.all(color: c.ember.withValues(alpha: 0.25)),
          ),
          child: Text(
            text,
            style: CxType.bodySmall.copyWith(color: c.textPrimary, height: 1.6),
          ),
        );
    }
  }
}
