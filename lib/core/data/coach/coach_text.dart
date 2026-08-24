/// Cleans the model's formatting into something the chat bubble can show.
///
/// The bubbles render plain text, so a reply written in markdown arrives as
/// literal noise: `**Why this works**`, `| **Wed** | Pull | Deadlift |`, a
/// stray `**` on its own line. The prompt asks for plain text, but a model
/// will reach for a table the moment it lists a week, and a user should never
/// see the pipes when it does.
///
/// Deliberately small: unwrap emphasis, turn table rows into readable lines,
/// normalise bullets. Anything cleverer belongs in a real markdown renderer.
String tidyCoachMarkdown(String input) {
  final out = <String>[];

  for (var line in input.split('\n')) {
    var t = line.trimRight();

    // Table separator rows (|---|:--:|) carry nothing readable.
    if (RegExp(r'^\s*\|?[\s:|-]+\|[\s:|-]*$').hasMatch(t) && t.contains('-')) {
      continue;
    }

    // Table rows → "Mon — Pull — Deadlift, barbell row".
    if (t.trimLeft().startsWith('|') && t.contains('|', 1)) {
      final cells = t
          .trim()
          .split('|')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList();
      if (cells.isNotEmpty) {
        t = '• ${cells.join(' — ')}';
      }
    }

    // Headings: "## Weekly volume" → "Weekly volume".
    t = t.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s*'), '');

    // Emphasis markers, including the unmatched ones models leave behind.
    t = t
        .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m[1]!)
        .replaceAllMapped(RegExp(r'(?<!\*)\*(?!\s)([^*\n]+?)(?<!\s)\*(?!\*)'),
            (m) => m[1]!)
        .replaceAll('**', '')
        .replaceAllMapped(RegExp(r'__(.+?)__'), (m) => m[1]!);

    // Hyphen/asterisk bullets → the bullet the rest of the app uses.
    // (Dart replacement strings don't expand $1 — that needs the mapped form.)
    t = t.replaceFirstMapped(
        RegExp(r'^(\s*)[-*]\s+'), (m) => '${m[1]}• ');

    out.add(t.trimRight());
  }

  // Collapse the blank lines that stripping markers can leave behind, and
  // drop leading/trailing ones entirely.
  final cleaned = <String>[];
  for (final line in out) {
    if (line.trim().isEmpty && (cleaned.isEmpty || cleaned.last.isEmpty)) {
      continue;
    }
    cleaned.add(line.trim().isEmpty ? '' : line);
  }
  while (cleaned.isNotEmpty && cleaned.last.isEmpty) {
    cleaned.removeLast();
  }
  return cleaned.join('\n');
}
