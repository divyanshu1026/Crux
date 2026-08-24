// Throwaway preview harness — renders the exercise-guide movement diagrams
// with no auth, no Supabase, no router. Not part of the shipped app; delete
// once the diagrams have been reviewed.
//
// Run with: flutter run -d web-server --web-port 8080 -t lib/dev/movement_diagram_preview.dart
import 'package:flutter/material.dart';

import '../core/theme/theme.dart';
import '../features/exercise_guide/domain/movement_pose.dart';
import '../features/exercise_guide/presentation/movement_diagram.dart';

void main() => runApp(const _PreviewApp());

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CxTheme.dark,
      home: Builder(
        builder: (context) {
          final c = context.cx;
          return Scaffold(
            backgroundColor: c.canvas,
            appBar: AppBar(
              backgroundColor: c.canvas,
              title: const Text('Movement diagram preview'),
            ),
            body: ListView(
              padding: const EdgeInsets.all(CxSpace.lg),
              children: [
                for (final pattern in MovementPatterns.all) ...[
                  Text(pattern.name,
                      style: CxType.titleSmall.copyWith(color: c.textPrimary)),
                  const SizedBox(height: CxSpace.sm),
                  MovementDiagram(pattern: pattern, height: 240),
                  const SizedBox(height: CxSpace.xl),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
