import 'package:flutter_test/flutter_test.dart';
import 'package:crux/core/data/coach/coach_text.dart';

/// Chat bubbles render plain text. Anything markdown-shaped that survives to
/// the bubble is shown to the user as literal `**` and `|`, which is what a
/// real reply looked like before this existed.
void main() {
  test('unwraps bold and strips stray markers', () {
    expect(tidyCoachMarkdown('**Why this works**'), 'Why this works');
    expect(tidyCoachMarkdown('Nice work\n**'), 'Nice work');
  });

  test('turns a markdown table into readable lines', () {
    const table = '| Day | Focus | Main lifts |\n'
        '|---|---|---|\n'
        '| **Wed** | Pull | Deadlift, barbell row |';
    expect(
      tidyCoachMarkdown(table),
      '• Day — Focus — Main lifts\n• Wed — Pull — Deadlift, barbell row',
    );
  });

  test('normalises headings and bullets', () {
    expect(tidyCoachMarkdown('## Weekly volume'), 'Weekly volume');
    expect(tidyCoachMarkdown('- squat\n* bench'), '• squat\n• bench');
  });

  test('collapses the gaps stripping leaves behind', () {
    expect(tidyCoachMarkdown('a\n\n\n\nb\n\n'), 'a\n\nb');
  });

  test('leaves ordinary prose alone', () {
    const plain = 'Today is Saturday — a rest day on your plan.\n\n'
        'Ask me anything about your training.';
    expect(tidyCoachMarkdown(plain), plain);
  });

  test('does not eat arithmetic or units', () {
    expect(tidyCoachMarkdown('3 sets x 8 reps at 62.5 kg'),
        '3 sets x 8 reps at 62.5 kg');
  });
}
