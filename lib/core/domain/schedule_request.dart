/// Recognising "please change my plan" in free text.
///
/// This is deliberately *not* the same thing as [parseScheduleCommand], which
/// has to understand a request well enough to execute it offline. This only
/// has to answer a much cheaper question: does this message sound like the
/// person wants their training changed?
///
/// It is used to decide whether to offer an apply-this-to-my-plan action after
/// Coach answers in the main chat. Getting it wrong is cheap in both
/// directions — a missed offer means the user opens the schedule screen the
/// old way, and a spurious one is an extra card they can ignore — so it errs
/// toward offering when a change verb and something plan-shaped appear
/// together, and stays quiet for pure questions ("explain my program").
library;

const _planNouns = {
  'schedule', 'program', 'programme', 'plan', 'split', 'routine', 'workout',
  'workouts', 'training', 'week', 'weeks', 'session', 'sessions', 'exercise',
  'exercises', 'day', 'days', 'lift', 'lifts',
};

const _weekdayWords = {
  'monday', 'mon', 'tuesday', 'tue', 'tues', 'wednesday', 'wed', 'thursday',
  'thu', 'thur', 'thurs', 'friday', 'fri', 'saturday', 'sat', 'sunday', 'sun',
  'weekend', 'weekday', 'weekdays',
};

/// Movement names common enough to be worth recognising. A change verb aimed
/// at one of these ("drop the deadlifts", "swap in machine rows") is a plan
/// edit even though no plan noun is spoken.
const _exerciseWords = {
  'deadlift', 'deadlifts', 'squat', 'squats', 'bench', 'press', 'presses',
  'pressing', 'curl', 'curls', 'row', 'rows', 'pulldown', 'pulldowns',
  'pullup', 'pullups', 'chinup', 'chinups', 'lunge', 'lunges', 'plank',
  'planks', 'thrust', 'thrusts', 'raise', 'raises', 'fly', 'flyes', 'flies',
  'extension', 'extensions', 'machine', 'machines', 'barbell', 'dumbbell',
  'dumbbells', 'cable', 'cables', 'kettlebell', 'kettlebells',
};

const _changeVerbs = {
  'change', 'swap', 'move', 'shift', 'replace', 'switch', 'rearrange',
  'rebuild', 'reschedule', 'redo', 'rewrite', 'restructure', 'reorder',
  'add', 'remove', 'drop', 'cut', 'skip', 'delete', 'reduce', 'increase',
  'balance', 'spread', 'split', 'make', 'set', 'put', 'give', 'update',
  'adjust', 'tweak', 'fix', 'focus', 'prioritise', 'prioritize',
};

const _bodyParts = {
  'shoulder', 'shoulders', 'knee', 'knees', 'back', 'elbow', 'elbows',
  'wrist', 'wrists', 'hip', 'hips', 'neck', 'ankle', 'ankles', 'chest',
  'hamstring', 'hamstrings', 'lower', 'groin', 'quad', 'quads',
};

const _muscles = {
  'glute', 'glutes', 'chest', 'back', 'arm', 'arms', 'bicep', 'biceps',
  'tricep', 'triceps', 'shoulder', 'shoulders', 'delt', 'delts', 'leg',
  'legs', 'quad', 'quads', 'hamstring', 'hamstrings', 'calf', 'calves',
  'core', 'abs', 'cardio', 'lat', 'lats', 'trap', 'traps', 'push', 'pull',
};

/// True when [input] reads like a request to change the training plan rather
/// than a question about it.
bool looksLikeScheduleRequest(String input) {
  final text = input.toLowerCase().trim();
  if (text.isEmpty) return false;

  final words = text
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final wordSet = words.toSet();
  bool any(Set<String> vocabulary) => wordSet.any(vocabulary.contains);

  // Phrases that are a plan change however they're worded.
  if (text.contains('rest day') ||
      text.contains('day off') ||
      text.contains('deload') ||
      text.contains('train less') ||
      text.contains('train more')) {
    return true;
  }

  // "I can only train 3 days", "I only have dumbbells now", "no gym this week".
  if (wordSet.contains('only') &&
      (any(_planNouns) ||
          wordSet.contains('dumbbells') ||
          wordSet.contains('bands') ||
          wordSet.contains('home') ||
          wordSet.contains('gym'))) {
    return true;
  }
  if (RegExp(r'\bno (gym|equipment|barbell|rack|machine)').hasMatch(text)) {
    return true;
  }

  // Pain and injury: the useful next step is almost always swapping movements,
  // so offer it rather than leaving the advice as prose.
  if (RegExp(r'\b(hurts?|hurting|sore|painful|pain|injured|injury|tweaked|'
                  r'strained)\b')
          .hasMatch(text) &&
      (any(_bodyParts) || any(_planNouns))) {
    return true;
  }

  // "more glute work", "less cardio", "too much chest".
  final hasQuantifier = wordSet.contains('more') ||
      wordSet.contains('less') ||
      wordSet.contains('fewer') ||
      wordSet.contains('extra') ||
      text.contains('too much') ||
      text.contains('too little');
  if (hasQuantifier && (any(_muscles) || any(_planNouns))) return true;

  // A change verb pointed at something plan-shaped.
  final hasChangeVerb = any(_changeVerbs);
  final hasPlanTarget =
      any(_planNouns) || any(_weekdayWords) || any(_exerciseWords);
  if (hasChangeVerb && hasPlanTarget) {
    // "explain what my program does" — a verb like 'focus' or 'make' can show
    // up inside a question. Questions asking for understanding aren't asking
    // for a rewrite.
    if (RegExp(r'^(what|why|when|how|explain|tell me|is |are |does |do i|'
                    r'should i know)')
        .hasMatch(text)) {
      // "how do I move leg day?" still wants the change.
      return RegExp(r'\b(move|swap|change|add|remove|drop|replace|switch)\b')
          .hasMatch(text);
    }
    return true;
  }

  return false;
}
