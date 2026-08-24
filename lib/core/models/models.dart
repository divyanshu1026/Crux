import '../domain/gamification.dart';

class UserProfile {
  final String name;
  final String sex;
  final int age;
  final double height;
  final double weight;
  final String goal;
  final String experience;
  final List<String> daysPerWeek;
  final String equipment;
  final List<String> injuries;
  final bool notificationPermission;
  final String avatar;
  final int level;
  final int xp;
  final int streak;
  final bool hasCompletedOnboarding;

  /// Display units — 'kg' (metric) or 'lbs' (imperial). Data is always stored
  /// in kg; this only affects the display layer. See [WeightUnit] helpers.
  final String units;

  /// Zen mode hides all gamification UI (XP, streaks, quests, ranks) for a
  /// clean-tracker presentation. Events still record silently (Phase 5.6).
  final bool zenMode;

  /// Pro entitlement — unlocks unlimited AI coach, analytics, marketplace, etc.
  ///
  /// A cache of the server's `is_pro`, which only billing can write. Never set
  /// this from the client in response to a tap: that was the old paywall, and
  /// it gave Pro away for free.
  final bool isPro;

  /// End of the paid period, mirroring the server's `pro_expires_at`.
  ///
  /// Without an expiry the cached flag never lapses, so someone who cancels —
  /// or who goes offline forever — keeps Pro. Null with [isPro] true means a
  /// grant that doesn't expire (comp account). See [hasProAccess].
  final DateTime? proExpiresAt;

  /// Whether Pro features should be unlocked right now.
  ///
  /// Includes a few days past expiry so a renewal that hasn't synced yet — or
  /// a plane trip — doesn't lock a paying subscriber out of what they bought.
  /// The server is still the authority; this only decides what the app shows
  /// between checks.
  bool get hasProAccess {
    if (!isPro) return false;
    final expiry = proExpiresAt;
    if (expiry == null) return true;
    return DateTime.now().isBefore(expiry.add(const Duration(days: 3)));
  }

  /// Rest Passes protect the streak from one missed planned day; refilled to 1
  /// each calendar month (plan Phase 5.3 — loss aversion, humanely).
  final int restPassesRemaining;

  /// yyyyMM of the month the pass was last granted (0 = never).
  final int lastRestPassMonth;

  /// First token of [name] for greetings (avoids showing a full legal name).
  String get firstName {
    final t = name.trim();
    if (t.isEmpty) return '';
    return t.split(RegExp(r'\s+')).first;
  }

  const UserProfile({
    required this.name,
    required this.sex,
    required this.age,
    required this.height,
    required this.weight,
    required this.goal,
    required this.experience,
    required this.daysPerWeek,
    required this.equipment,
    required this.injuries,
    required this.notificationPermission,
    required this.avatar,
    this.level = 1,
    this.xp = 0,
    this.streak = 3, // Start with some endowed streak progress
    this.hasCompletedOnboarding = false,
    this.units = 'kg',
    this.zenMode = false,
    this.isPro = false,
    this.proExpiresAt,
    this.restPassesRemaining = 1,
    this.lastRestPassMonth = 0,
  });

  UserProfile copyWith({
    String? name,
    String? sex,
    int? age,
    double? height,
    double? weight,
    String? goal,
    String? experience,
    List<String>? daysPerWeek,
    String? equipment,
    List<String>? injuries,
    bool? notificationPermission,
    String? avatar,
    int? level,
    int? xp,
    int? streak,
    bool? hasCompletedOnboarding,
    String? units,
    bool? zenMode,
    bool? isPro,
    DateTime? proExpiresAt,
    int? restPassesRemaining,
    int? lastRestPassMonth,
  }) {
    return UserProfile(
      name: name ?? this.name,
      sex: sex ?? this.sex,
      age: age ?? this.age,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      goal: goal ?? this.goal,
      experience: experience ?? this.experience,
      daysPerWeek: daysPerWeek ?? this.daysPerWeek,
      equipment: equipment ?? this.equipment,
      injuries: injuries ?? this.injuries,
      notificationPermission:
          notificationPermission ?? this.notificationPermission,
      avatar: avatar ?? this.avatar,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      units: units ?? this.units,
      zenMode: zenMode ?? this.zenMode,
      isPro: isPro ?? this.isPro,
      proExpiresAt: proExpiresAt ?? this.proExpiresAt,
      restPassesRemaining: restPassesRemaining ?? this.restPassesRemaining,
      lastRestPassMonth: lastRestPassMonth ?? this.lastRestPassMonth,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'sex': sex,
        'age': age,
        'height': height,
        'weight': weight,
        'goal': goal,
        'experience': experience,
        'daysPerWeek': daysPerWeek,
        'equipment': equipment,
        'injuries': injuries,
        'notificationPermission': notificationPermission,
        'avatar': avatar,
        'level': level,
        'xp': xp,
        'streak': streak,
        'hasCompletedOnboarding': hasCompletedOnboarding,
        'units': units,
        'zenMode': zenMode,
        'isPro': isPro,
        'proExpiresAt': proExpiresAt?.toIso8601String(),
        'restPassesRemaining': restPassesRemaining,
        'lastRestPassMonth': lastRestPassMonth,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String? ?? '',
        sex: json['sex'] as String? ?? 'Prefer not to say',
        age: (json['age'] as num?)?.toInt() ?? 25,
        height: (json['height'] as num?)?.toDouble() ?? 175,
        weight: (json['weight'] as num?)?.toDouble() ?? 75,
        goal: json['goal'] as String? ?? 'Build Muscle',
        experience: json['experience'] as String? ?? 'Never trained',
        daysPerWeek:
            (json['daysPerWeek'] as List?)?.cast<String>() ?? const [],
        equipment: json['equipment'] as String? ?? 'Full gym',
        injuries: (json['injuries'] as List?)?.cast<String>() ?? const [],
        notificationPermission: json['notificationPermission'] as bool? ?? false,
        avatar: json['avatar'] as String? ?? 'assets/images/yorhart_neutral.png',
        level: (json['level'] as num?)?.toInt() ?? 1,
        xp: (json['xp'] as num?)?.toInt() ?? 0,
        streak: (json['streak'] as num?)?.toInt() ?? 3,
        hasCompletedOnboarding: json['hasCompletedOnboarding'] as bool? ?? false,
        units: json['units'] as String? ?? 'kg',
        zenMode: json['zenMode'] as bool? ?? false,
        isPro: json['isPro'] as bool? ?? false,
        proExpiresAt: DateTime.tryParse(json['proExpiresAt'] as String? ?? ''),
        restPassesRemaining:
            (json['restPassesRemaining'] as num?)?.toInt() ?? 1,
        lastRestPassMonth: (json['lastRestPassMonth'] as num?)?.toInt() ?? 0,
      );

  String get rankBadge {
    if (level <= 2) {
      return "Novice — everyone starts here.";
    } else if (level <= 4) {
      return "Challenger — building momentum.";
    } else {
      return "Iron Warrior — unstoppable force.";
    }
  }

  double get xpProgress {
    // XP threshold grows with level, say level * 100
    final threshold = nextLevelXpThreshold;
    return (xp / threshold).clamp(0.0, 1.0);
  }

  /// XP required to advance from the current level (plan: 100 × level^1.5).
  int get nextLevelXpThreshold => levelXpThreshold(level);
}

class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final String equipment;
  final int targetSets;
  final String targetReps; // E.g., "8-12", "4-6"
  final double suggestedWeight;
  final bool isWarmup;
  final int restTimeSeconds;

  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    required this.targetSets,
    required this.targetReps,
    required this.suggestedWeight,
    this.isWarmup = false,
    this.restTimeSeconds = 90,
  });

  Exercise copyWith({
    String? id,
    String? name,
    String? muscleGroup,
    String? equipment,
    int? targetSets,
    String? targetReps,
    double? suggestedWeight,
    bool? isWarmup,
    int? restTimeSeconds,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      equipment: equipment ?? this.equipment,
      targetSets: targetSets ?? this.targetSets,
      targetReps: targetReps ?? this.targetReps,
      suggestedWeight: suggestedWeight ?? this.suggestedWeight,
      isWarmup: isWarmup ?? this.isWarmup,
      restTimeSeconds: restTimeSeconds ?? this.restTimeSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'muscleGroup': muscleGroup,
        'equipment': equipment,
        'targetSets': targetSets,
        'targetReps': targetReps,
        'suggestedWeight': suggestedWeight,
        'isWarmup': isWarmup,
        'restTimeSeconds': restTimeSeconds,
      };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: json['id'] as String,
        name: json['name'] as String,
        muscleGroup: json['muscleGroup'] as String? ?? '',
        equipment: json['equipment'] as String? ?? '',
        targetSets: (json['targetSets'] as num?)?.toInt() ?? 3,
        targetReps: json['targetReps'] as String? ?? '8-12',
        suggestedWeight: (json['suggestedWeight'] as num?)?.toDouble() ?? 0,
        isWarmup: json['isWarmup'] as bool? ?? false,
        restTimeSeconds: (json['restTimeSeconds'] as num?)?.toInt() ?? 90,
      );
}

class WorkoutDay {
  final String id;
  final String name; // E.g., "Day 1: Full Body"
  final List<Exercise> exercises;

  const WorkoutDay({
    required this.id,
    required this.name,
    required this.exercises,
  });

  WorkoutDay copyWith({
    String? id,
    String? name,
    List<Exercise>? exercises,
  }) {
    return WorkoutDay(
      id: id ?? this.id,
      name: name ?? this.name,
      exercises: exercises ?? this.exercises,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory WorkoutDay.fromJson(Map<String, dynamic> json) => WorkoutDay(
        id: json['id'] as String,
        name: json['name'] as String,
        exercises: (json['exercises'] as List? ?? [])
            .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Program {
  final String id;
  final String name;
  final String description;
  final List<WorkoutDay> days;
  final String whyFitsParagraph;

  /// The weekly schedule: weekday abbreviation ('Mon'…'Sun') → [WorkoutDay.id].
  /// Weekdays absent from the map are rest days. The generator auto-fills this
  /// from the user's chosen training days; the user can reassign freely.
  final Map<String, String> dayAssignments;

  const Program({
    required this.id,
    required this.name,
    required this.description,
    required this.days,
    required this.whyFitsParagraph,
    this.dayAssignments = const {},
  });

  static const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// The workout assigned to a weekday, or null for a rest day. Falls back to
  /// cycling through days in order for programs saved before scheduling
  /// existed (keyed off [trainingDays] order).
  WorkoutDay? dayForWeekday(String weekday, {List<String> fallbackDays = const []}) {
    if (dayAssignments.isNotEmpty) {
      final id = dayAssignments[weekday];
      if (id == null) return null;
      for (final d in days) {
        if (d.id == id) return d;
      }
      return null;
    }
    // Legacy fallback: nth selected training day → nth program day (cycled).
    final ordered = weekdays.where(fallbackDays.contains).toList();
    final idx = ordered.indexOf(weekday);
    if (idx < 0 || days.isEmpty) return null;
    return days[idx % days.length];
  }

  Program copyWith({
    String? id,
    String? name,
    String? description,
    List<WorkoutDay>? days,
    String? whyFitsParagraph,
    Map<String, String>? dayAssignments,
  }) {
    return Program(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      days: days ?? this.days,
      whyFitsParagraph: whyFitsParagraph ?? this.whyFitsParagraph,
      dayAssignments: dayAssignments ?? this.dayAssignments,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'days': days.map((d) => d.toJson()).toList(),
        'whyFitsParagraph': whyFitsParagraph,
        'dayAssignments': dayAssignments,
      };

  factory Program.fromJson(Map<String, dynamic> json) => Program(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        days: (json['days'] as List? ?? [])
            .map((d) => WorkoutDay.fromJson(d as Map<String, dynamic>))
            .toList(),
        whyFitsParagraph: json['whyFitsParagraph'] as String? ?? '',
        dayAssignments:
            (json['dayAssignments'] as Map?)?.cast<String, String>() ??
                const {},
      );
}

class SetLog {
  final String id;
  final double weight;
  final int reps;
  final bool completed;
  final bool isWarmup;
  final bool isPR;
  final bool isEpleyPR;

  /// Optional per-set note ("felt heavy", "left shoulder tweak") — context the
  /// coach can reason over later.
  final String? note;

  const SetLog({
    required this.id,
    required this.weight,
    required this.reps,
    this.completed = false,
    this.isWarmup = false,
    this.isPR = false,
    this.isEpleyPR = false,
    this.note,
  });

  SetLog copyWith({
    String? id,
    double? weight,
    int? reps,
    bool? completed,
    bool? isWarmup,
    bool? isPR,
    bool? isEpleyPR,
    String? note,
  }) {
    return SetLog(
      id: id ?? this.id,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      completed: completed ?? this.completed,
      isWarmup: isWarmup ?? this.isWarmup,
      isPR: isPR ?? this.isPR,
      isEpleyPR: isEpleyPR ?? this.isEpleyPR,
      note: note ?? this.note,
    );
  }

  /// [copyWith] can't null a field; use this to clear a note.
  SetLog withoutNote() => SetLog(
        id: id,
        weight: weight,
        reps: reps,
        completed: completed,
        isWarmup: isWarmup,
        isPR: isPR,
        isEpleyPR: isEpleyPR,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'weight': weight,
        'reps': reps,
        'completed': completed,
        'isWarmup': isWarmup,
        'isPR': isPR,
        'isEpleyPR': isEpleyPR,
        'note': note,
      };

  factory SetLog.fromJson(Map<String, dynamic> json) => SetLog(
        id: json['id'] as String,
        weight: (json['weight'] as num?)?.toDouble() ?? 0,
        reps: (json['reps'] as num?)?.toInt() ?? 0,
        completed: json['completed'] as bool? ?? false,
        isWarmup: json['isWarmup'] as bool? ?? false,
        isPR: json['isPR'] as bool? ?? false,
        isEpleyPR: json['isEpleyPR'] as bool? ?? false,
        note: json['note'] as String?,
      );
}

class ExerciseLog {
  final String exerciseId;
  final String exerciseName;
  final List<SetLog> sets;
  final String muscleGroup;

  /// The prescribed rep range for this exercise (e.g. "8-12"), shown as the
  /// target during logging.
  final String targetReps;

  /// The double-progression reason for this session's suggested numbers
  /// (null for added/swapped exercises without history).
  final String? progressionReason;

  const ExerciseLog({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    required this.muscleGroup,
    this.targetReps = '',
    this.progressionReason,
  });

  ExerciseLog copyWith({
    String? exerciseId,
    String? exerciseName,
    List<SetLog>? sets,
    String? muscleGroup,
    String? targetReps,
    String? progressionReason,
  }) {
    return ExerciseLog(
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      sets: sets ?? this.sets,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      targetReps: targetReps ?? this.targetReps,
      progressionReason: progressionReason ?? this.progressionReason,
    );
  }

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'muscleGroup': muscleGroup,
        'targetReps': targetReps,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory ExerciseLog.fromJson(Map<String, dynamic> json) => ExerciseLog(
        exerciseId: json['exerciseId'] as String? ?? '',
        exerciseName: json['exerciseName'] as String? ?? '',
        muscleGroup: json['muscleGroup'] as String? ?? '',
        targetReps: json['targetReps'] as String? ?? '',
        sets: (json['sets'] as List? ?? [])
            .map((s) => SetLog.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class WorkoutSession {
  final String id;
  final String programId;
  final String workoutDayName;
  final DateTime date;

  /// When this session actually began on the device — the anchor for the
  /// running clock. Kept separate from [date], which is the calendar day the
  /// workout belongs to and can be backdated when logging a past session.
  /// Null on sessions saved before this field existed; callers fall back to
  /// [date].
  final DateTime? startedAt;
  final int durationSeconds;
  final bool completed;
  final List<ExerciseLog> exercises;
  final double totalVolume;
  final int xpEarned;
  final List<String> prsHit;
  final Map<String, String> overloadSuggestions;

  /// Variable-reward XP included in [xpEarned] (0 = no bonus this session).
  final int coachBonusXp;
  final String? coachBonusReason;

  const WorkoutSession({
    required this.id,
    required this.programId,
    required this.workoutDayName,
    required this.date,
    this.startedAt,
    this.durationSeconds = 0,
    this.completed = false,
    required this.exercises,
    this.totalVolume = 0.0,
    this.xpEarned = 0,
    this.prsHit = const [],
    this.overloadSuggestions = const {},
    this.coachBonusXp = 0,
    this.coachBonusReason,
  });

  WorkoutSession copyWith({
    String? id,
    String? programId,
    String? workoutDayName,
    DateTime? date,
    DateTime? startedAt,
    int? durationSeconds,
    bool? completed,
    List<ExerciseLog>? exercises,
    double? totalVolume,
    int? xpEarned,
    List<String>? prsHit,
    Map<String, String>? overloadSuggestions,
    int? coachBonusXp,
    String? coachBonusReason,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      programId: programId ?? this.programId,
      workoutDayName: workoutDayName ?? this.workoutDayName,
      date: date ?? this.date,
      startedAt: startedAt ?? this.startedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      completed: completed ?? this.completed,
      exercises: exercises ?? this.exercises,
      totalVolume: totalVolume ?? this.totalVolume,
      xpEarned: xpEarned ?? this.xpEarned,
      prsHit: prsHit ?? this.prsHit,
      overloadSuggestions: overloadSuggestions ?? this.overloadSuggestions,
      coachBonusXp: coachBonusXp ?? this.coachBonusXp,
      coachBonusReason: coachBonusReason ?? this.coachBonusReason,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'programId': programId,
        'workoutDayName': workoutDayName,
        'date': date.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'durationSeconds': durationSeconds,
        'completed': completed,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'totalVolume': totalVolume,
        'xpEarned': xpEarned,
        'prsHit': prsHit,
        'overloadSuggestions': overloadSuggestions,
        'coachBonusXp': coachBonusXp,
        'coachBonusReason': coachBonusReason,
      };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
        id: json['id'] as String,
        programId: json['programId'] as String? ?? '',
        workoutDayName: json['workoutDayName'] as String? ?? '',
        date: DateTime.parse(json['date'] as String),
        startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
        durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
        completed: json['completed'] as bool? ?? false,
        exercises: (json['exercises'] as List? ?? [])
            .map((e) => ExerciseLog.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalVolume: (json['totalVolume'] as num?)?.toDouble() ?? 0,
        xpEarned: (json['xpEarned'] as num?)?.toInt() ?? 0,
        prsHit: (json['prsHit'] as List?)?.cast<String>() ?? const [],
        overloadSuggestions:
            (json['overloadSuggestions'] as Map?)?.cast<String, String>() ??
                const {},
        coachBonusXp: (json['coachBonusXp'] as num?)?.toInt() ?? 0,
        coachBonusReason: json['coachBonusReason'] as String?,
      );
}

class WeighIn {
  final DateTime date;
  final double weight;

  const WeighIn({
    required this.date,
    required this.weight,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'weight': weight,
      };

  factory WeighIn.fromJson(Map<String, dynamic> json) => WeighIn(
        date: DateTime.parse(json['date'] as String),
        weight: (json['weight'] as num).toDouble(),
      );
}

class Quest {
  final String id;
  final String title;
  final String description;
  final int targetValue;
  final int currentValue;
  final int xpReward;
  final bool isMilestone;
  final bool isClaimed;

  const Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.targetValue,
    required this.currentValue,
    required this.xpReward,
    this.isMilestone = false,
    this.isClaimed = false,
  });

  bool get isCompleted => currentValue >= targetValue;

  Quest copyWith({
    String? id,
    String? title,
    String? description,
    int? targetValue,
    int? currentValue,
    int? xpReward,
    bool? isMilestone,
    bool? isClaimed,
  }) {
    return Quest(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      xpReward: xpReward ?? this.xpReward,
      isMilestone: isMilestone ?? this.isMilestone,
      isClaimed: isClaimed ?? this.isClaimed,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'targetValue': targetValue,
        'currentValue': currentValue,
        'xpReward': xpReward,
        'isMilestone': isMilestone,
        'isClaimed': isClaimed,
      };

  factory Quest.fromJson(Map<String, dynamic> json) => Quest(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        targetValue: (json['targetValue'] as num?)?.toInt() ?? 1,
        currentValue: (json['currentValue'] as num?)?.toInt() ?? 0,
        xpReward: (json['xpReward'] as num?)?.toInt() ?? 0,
        isMilestone: json['isMilestone'] as bool? ?? false,
        isClaimed: json['isClaimed'] as bool? ?? false,
      );
}

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        text: json['text'] as String? ?? '',
        isUser: json['isUser'] as bool? ?? false,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
