import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import 'schedule_confirm_screen.dart';

// ---------------------------------------------------------------------------
// A Beautiful Orbiting Icons Widget (Luma Inspired)
// ---------------------------------------------------------------------------
class OrbitingIconsWidget extends StatefulWidget {
  final Widget centerWidget;
  final double radius;

  const OrbitingIconsWidget({
    super.key,
    required this.centerWidget,
    this.radius = 110,
  });

  @override
  State<OrbitingIconsWidget> createState() => _OrbitingIconsWidgetState();
}

class _OrbitingIconsWidgetState extends State<OrbitingIconsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final icons = [
      (Icons.fitness_center_rounded, CxColors.ember),
      (Icons.calendar_today_rounded, CxColors.ultraviolet),
      (Icons.bolt_rounded, CxColors.warning),
      (Icons.favorite_rounded, CxColors.ember),
      (Icons.emoji_events_rounded, CxColors.warning),
      (Icons.insights_rounded, CxColors.ultraviolet),
    ];

    return SizedBox(
      width: widget.radius * 2 + 80,
      height: widget.radius * 2 + 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Central Widget (Yorhart)
          widget.centerWidget,

          // Orbiting Icons
          AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: List.generate(icons.length, (index) {
                  final angle = (index * 2 * 3.141592653589793 / icons.length) +
                      (_rotationController.value * 2 * 3.141592653589793);
                  final x = widget.radius * math.cos(angle);
                  final y = widget.radius * math.sin(angle);

                  final iconData = icons[index].$1;
                  final iconColor = icons[index].$2;

                  return Transform.translate(
                    offset: Offset(x, y),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark
                            ? CxColors.darkSurfaceHigh.withOpacity(0.85)
                            : Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05),
                          width: 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        iconData,
                        color: iconColor,
                        size: 22,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onboarding Screen
// ---------------------------------------------------------------------------
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Form Inputs
  String _name = '';
  String _sex = 'Male';
  int _age = 24;
  double _height = 170.0;
  double _weight = 70.0;
  String _goal = 'Build Muscle';
  String _experience = 'Never trained';
  final List<String> _daysPerWeek = ['Mon', 'Wed', 'Fri'];
  String _equipment = 'Full gym';
  final List<String> _injuries = [];
  bool _notificationPermission = false;
  String _selectedAvatar = 'happy';

  // Generation Loading State
  bool _isGenerating = false;
  int _generationPhase = 0;
  final List<String> _generationSteps = [
    'Analyzing your goals...',
    'Coach is designing your plan...',
    'Working around your equipment and injuries...',
    'Mapping your training week...',
    'Ready to review...',
  ];

  void _nextStep() {
    FocusScope.of(context).unfocus();
    if (_currentStep < 11) {
      CxHaptics.fire(CxHaptic.selection);
      setState(() {
        _currentStep++;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: CxDuration.slow,
        curve: CxCurves.standard,
      );
    } else {
      // Trigger Program Generation Loader
      _startProgramGeneration();
    }
  }

  void _prevStep() {
    FocusScope.of(context).unfocus();
    if (_currentStep > 0) {
      CxHaptics.fire(CxHaptic.selection);
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: CxDuration.slow,
        curve: CxCurves.standard,
      );
    }
  }

  /// Builds the user's first program, then hands off to the review screen.
  ///
  /// Two plans are produced, deliberately:
  ///   1. A curated template, instantly and offline. This guarantees the user
  ///      always leaves onboarding with a working, safe program.
  ///   2. A plan Coach writes from their actual answers — equipment, injuries,
  ///      experience, goal — which replaces the template when it arrives.
  ///
  /// The AI call runs alongside the staging animation the user is already
  /// watching, so personalisation costs no extra waiting. If Coach is slow,
  /// unreachable, or the user is offline, step 1 is what they get and nothing
  /// tells them anything went wrong — because nothing did.
  Future<void> _startProgramGeneration() async {
    CxHaptics.fire(CxHaptic.selection);
    setState(() {
      _isGenerating = true;
      _generationPhase = 0;
    });

    final profile = UserProfile(
      name: _name.isEmpty ? "Adventurer" : _name,
      sex: _sex,
      age: _age,
      height: _height,
      weight: _weight,
      goal: _goal,
      experience: _experience,
      daysPerWeek: _daysPerWeek,
      equipment: _equipment,
      injuries: _injuries,
      notificationPermission: _notificationPermission,
      avatar: _selectedAvatar,
    );
    ref.read(userProfileProvider.notifier).updateProfile(profile);

    final notifier = ref.read(programProvider.notifier);
    notifier.generateProgram(profile);
    final personalised = notifier.generateProgramWithAI(profile);

    for (var i = 1; i < _generationSteps.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      if (!mounted) return;
      setState(() => _generationPhase = i);
    }

    // Wait a little longer if Coach is still writing, but never hang on it.
    await personalised.timeout(
      const Duration(seconds: 20),
      onTimeout: () => null,
    );
    if (!mounted) return;

    setState(() => _isGenerating = false);
    // Push a dedicated screen so we don't tear down the wizard tree
    // mid-frame (that caused `_dependents.isEmpty` crashes).
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ScheduleConfirmScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;

    if (_isGenerating) {
      return _buildGenerationScreen(c);
    }

    // Calculates progress bar percentage starting at 15% (endowed progress) up to 100%
    final double progressPercent = 0.15 + (0.85 * (_currentStep / 11.0));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              CxColors.darkCanvas,
              CxColors.darkSurface,
            ],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF3EDF8), // Soft lilac tinted Canvas
              Color(0xFFFFFDF9), // Cream canvas
              Color(0xFFEEF7F2), // Soft mint canvas
            ],
          );

    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Top Progress Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CxSpace.screen,
                  vertical: CxSpace.md,
                ),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      IconButton(
                        icon: Icon(Icons.arrow_back_rounded, color: c.textPrimary),
                        onPressed: _prevStep,
                      )
                    else
                      const SizedBox(width: 48),
                    Expanded(
                      child: CxProgressBar(
                        value: progressPercent,
                        accent: CxProgressAccent.ultraviolet,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Page View
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _stepWelcome(c),
                    _stepName(c),
                    _stepSex(c),
                    _stepAge(c),
                    _stepHeight(c),
                    _stepWeight(c),
                    _stepGoal(c),
                    _stepExperience(c),
                    _stepDays(c),
                    _stepEquipment(c),
                    _stepInjuries(c),
                    _stepNotification(c),
                  ],
                ),
              ),

              // Bottom CTA
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: CxSpace.screen, vertical: CxSpace.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CxButton(
                      label: _currentStep == 0 ? "Let's Go!" : (_currentStep == 11 ? "Generate My Plan" : "Continue"),
                      expand: true,
                      onPressed: (_currentStep == 1 && _name.trim().isEmpty) ? null : _nextStep,
                    ),
                    if (_currentStep == 0) ...[
                      const SizedBox(height: CxSpace.sm),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            CxHaptics.fire(CxHaptic.selection);
                            ref.read(authProvider.notifier).logout();
                          },
                          child: Text(
                            "Already have an account? Log In",
                            style: CxType.titleSmall.copyWith(
                              color: c.ember,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Welcome Step
  Widget _stepWelcome(CxColorsExt c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(CxSpace.screen),
      child: Column(
        children: [
          const SizedBox(height: CxSpace.xl),
          // Clean orbiting visual with Yorhart center
          const OrbitingIconsWidget(
            centerWidget: YorhartWidget(expression: 'happy', size: 130),
            radius: 100,
          ),
          const SizedBox(height: CxSpace.x2l),
          Text(
            "Walk in knowing\nexactly what to do",
            textAlign: TextAlign.center,
            style: CxType.displayL.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: CxSpace.lg),
          Text(
            "Welcome to Crux. A beautiful, progressive overload tracking system designed to build consistent strength.",
            textAlign: TextAlign.center,
            style: CxType.body.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }

  // 2. Name Step
  Widget _stepName(CxColorsExt c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(CxSpace.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: CxSpace.xl),
          Center(child: const YorhartWidget(expression: 'happy', size: 110)),
          const SizedBox(height: CxSpace.x2l),
          Text("What should we call you?", style: CxType.headline.copyWith(color: c.textPrimary)),
          const SizedBox(height: CxSpace.md),
          Text("This helps Yorhart customize your coaching dialogue.", style: CxType.bodySmall.copyWith(color: c.textTertiary)),
          const SizedBox(height: CxSpace.xl),
          CxTextField(
            label: "Your Name",
            hint: "E.g. David",
            controller: TextEditingController(text: _name)..selection = TextSelection.fromPosition(TextPosition(offset: _name.length)),
            onChanged: (val) {
              setState(() {
                _name = val;
              });
            },
          ),
        ],
      ),
    );
  }

  // 3. Sex Step
  Widget _stepSex(CxColorsExt c) {
    final options = [
      ('Male', 'determined', 'Tailored presets for strength & muscle'),
      ('Female', 'happy', 'Focus on toning, glute presets & lifting'),
      ('Prefer not to say', 'resting', 'General health, balance & mobility'),
    ];
    return Padding(
      padding: const EdgeInsets.all(CxSpace.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: CxSpace.xl),
          Text("What is your sex?", style: CxType.headline.copyWith(color: c.textPrimary)),
          const SizedBox(height: CxSpace.md),
          Text("This helps us calibrate starting strength standards and templates.", style: CxType.bodySmall.copyWith(color: c.textSecondary)),
          const SizedBox(height: CxSpace.x2l),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 180,
                          child: _buildGridCard(
                            title: options[0].$1,
                            subtitle: options[0].$3,
                            isSelected: _sex == options[0].$1,
                            activeBorderColor: c.ember,
                            illustration: YorhartWidget(
                              expression: options[0].$2,
                              size: 72,
                              animate: _sex == options[0].$1,
                            ),
                            onTap: () {
                              CxHaptics.fire(CxHaptic.selection);
                              setState(() => _sex = options[0].$1);
                            },
                            c: c,
                          ),
                        ),
                      ),
                      const SizedBox(width: CxSpace.md),
                      Expanded(
                        child: SizedBox(
                          height: 180,
                          child: _buildGridCard(
                            title: options[1].$1,
                            subtitle: options[1].$3,
                            isSelected: _sex == options[1].$1,
                            activeBorderColor: c.ember,
                            illustration: YorhartWidget(
                              expression: options[1].$2,
                              size: 72,
                              animate: _sex == options[1].$1,
                            ),
                            onTap: () {
                              CxHaptics.fire(CxHaptic.selection);
                              setState(() => _sex = options[1].$1);
                            },
                            c: c,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CxSpace.md),
                  SizedBox(
                    height: 100,
                    child: _buildWideGridCard(
                      title: options[2].$1,
                      subtitle: options[2].$3,
                      isSelected: _sex == options[2].$1,
                      activeBorderColor: c.ember,
                      illustration: YorhartWidget(
                        expression: options[2].$2,
                        size: 64,
                        animate: _sex == options[2].$1,
                      ),
                      onTap: () {
                        CxHaptics.fire(CxHaptic.selection);
                        setState(() => _sex = options[2].$1);
                      },
                      c: c,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. Age Step
  Widget _stepAge(CxColorsExt c) {
    return Padding(
      padding: const EdgeInsets.all(CxSpace.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: CxSpace.xl),
          Text("How old are you?", style: CxType.headline.copyWith(color: c.textPrimary)),
          const SizedBox(height: CxSpace.md),
          Text("Age helps us tune starting recovery curves.", style: CxType.bodySmall.copyWith(color: c.textSecondary)),
          const SizedBox(height: CxSpace.x2l),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const YorhartWidget(expression: 'happy', size: 120),
                const SizedBox(height: CxSpace.x2l),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      "$_age",
                      style: CxType.numHero.copyWith(color: c.textPrimary),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "years",
                      style: CxType.title.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: CxSpace.lg),
                CxRulerSlider(
                  value: _age.toDouble(),
                  min: 14,
                  max: 100,
                  step: 1.0,
                  majorInterval: 10,
                  minorInterval: 1,
                  onChanged: (val) {
                    setState(() {
                      _age = val.toInt();
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 5. Height Step
  Widget _stepHeight(CxColorsExt c) {
    return Padding(
      padding: const EdgeInsets.all(CxSpace.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: CxSpace.xl),
          Text("How tall are you?", style: CxType.headline.copyWith(color: c.textPrimary)),
          const SizedBox(height: CxSpace.md),
          Text("Used for calculating basic body metrics.", style: CxType.bodySmall.copyWith(color: c.textSecondary)),
          const SizedBox(height: CxSpace.x2l),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Visual height scaling container (Tactile height feedback)
                Container(
                  height: 180,
                  alignment: Alignment.bottomCenter,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Backdrop grid lines / measurements
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 0,
                        top: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 1,
                              color: c.border.withOpacity(0.4),
                            ),
                            Container(
                              width: 1,
                              color: c.border.withOpacity(0.4),
                            ),
                          ],
                        ),
                      ),
                      // Height marks
                      Positioned(
                        right: 32,
                        bottom: 0,
                        top: 0,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("220 cm", style: CxType.caption.copyWith(color: c.textTertiary)),
                            Text("180 cm", style: CxType.caption.copyWith(color: c.textTertiary)),
                            Text("140 cm", style: CxType.caption.copyWith(color: c.textTertiary)),
                            Text("100 cm", style: CxType.caption.copyWith(color: c.textTertiary)),
                          ],
                        ),
                      ),
                      // Character scaling up and down
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: YorhartWidget(
                          expression: 'determined',
                          // size scales from 90 to 160 proportional to height (100 to 250)
                          size: 90 + (_height - 100) * 0.46,
                          animate: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CxSpace.x2l),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      "${_height.round()}",
                      style: CxType.numHero.copyWith(color: c.textPrimary),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "cm",
                      style: CxType.title.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: CxSpace.lg),
                CxRulerSlider(
                  value: _height,
                  min: 100,
                  max: 250,
                  step: 1.0,
                  majorInterval: 10,
                  minorInterval: 1,
                  onChanged: (val) {
                    setState(() {
                      _height = val;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 6. Current Weight Step
  Widget _stepWeight(CxColorsExt c) {
    return Padding(
      padding: const EdgeInsets.all(CxSpace.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: CxSpace.xl),
          Text("What's your current weight?", style: CxType.headline.copyWith(color: c.textPrimary)),
          const SizedBox(height: CxSpace.md),
          Text("We use this to set starting lift calibration standards.", style: CxType.bodySmall.copyWith(color: c.textSecondary)),
          const SizedBox(height: CxSpace.x2l),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                YorhartWidget(
                  expression: 'weightlifting',
                  // size scales slightly according to weight to look active!
                  size: 130 + (_weight - 30) * 0.15,
                  animate: true,
                ),
                const SizedBox(height: CxSpace.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _weight.toStringAsFixed(1),
                      style: CxType.numHero.copyWith(color: c.textPrimary),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "kg",
                      style: CxType.title.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: CxSpace.lg),
                CxRulerSlider(
                  value: _weight,
                  min: 30,
                  max: 200,
                  step: 0.5,
                  majorInterval: 10,
                  minorInterval: 2,
                  onChanged: (val) {
                    setState(() {
                      _weight = val;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 7. Goal Step
  Widget _stepGoal(CxColorsExt c) {
    final options = [
      ('Build Muscle', 'weightlifting', "Focus on size & aesthetic proportions"),
      ('Get Stronger', 'determined', "Boost pure mechanical force & compound 1RMs"),
      ('Lose Fat & Tone', 'happy', "Calorie deficits paired with high work density"),
      ('General Fitness', 'coaching', "Heart health, mobility & clean movement"),
    ];

    return Padding(
      padding: const EdgeInsets.all(CxSpace.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: CxSpace.xl),
          Text("What is your fitness goal?", style: CxType.headline.copyWith(color: c.textPrimary)),
          const SizedBox(height: CxSpace.md),
          Text("Your plan structure and rep ranges will automatically calibrate to this.", style: CxType.bodySmall.copyWith(color: c.textSecondary)),
          const SizedBox(height: CxSpace.x2l),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    children: [
                       Expanded(
                        child: SizedBox(
                          height: 205,
                          child: _buildGridCard(
                            title: options[0].$1,
                            subtitle: options[0].$3,
                            isSelected: _goal == options[0].$1,
                            activeBorderColor: c.ember,
                            illustration: YorhartWidget(
                              expression: options[0].$2,
                              size: 72,
                              animate: _goal == options[0].$1,
                            ),
                            onTap: () {
                              CxHaptics.fire(CxHaptic.selection);
                              setState(() => _goal = options[0].$1);
                            },
                            c: c,
                          ),
                        ),
                      ),
                      const SizedBox(width: CxSpace.md),
                      Expanded(
                        child: SizedBox(
                          height: 205,
                          child: _buildGridCard(
                            title: options[1].$1,
                            subtitle: options[1].$3,
                            isSelected: _goal == options[1].$1,
                            activeBorderColor: c.ember,
                            illustration: YorhartWidget(
                              expression: options[1].$2,
                              size: 72,
                              animate: _goal == options[1].$1,
                            ),
                            onTap: () {
                              CxHaptics.fire(CxHaptic.selection);
                              setState(() => _goal = options[1].$1);
                            },
                            c: c,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CxSpace.md),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 205,
                          child: _buildGridCard(
                            title: options[2].$1,
                            subtitle: options[2].$3,
                            isSelected: _goal == options[2].$1,
                            activeBorderColor: c.ember,
                            illustration: YorhartWidget(
                              expression: options[2].$2,
                              size: 72,
                              animate: _goal == options[2].$1,
                            ),
                            onTap: () {
                              CxHaptics.fire(CxHaptic.selection);
                              setState(() => _goal = options[2].$1);
                            },
                            c: c,
                          ),
                        ),
                      ),
                      const SizedBox(width: CxSpace.md),
                      Expanded(
                        child: SizedBox(
                          height: 205,
                          child: _buildGridCard(
                            title: options[3].$1,
                            subtitle: options[3].$3,
                            isSelected: _goal == options[3].$1,
                            activeBorderColor: c.ember,
                            illustration: YorhartWidget(
                              expression: options[3].$2,
                              size: 72,
                              animate: _goal == options[3].$1,
                            ),
                            onTap: () {
                              CxHaptics.fire(CxHaptic.selection);
                              setState(() => _goal = options[3].$1);
                            },
                            c: c,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 8. Experience Step
  Widget _stepExperience(CxColorsExt c) {
    final options = [
      ('Never trained', 'coaching', "I don't know my way around the gym yet"),
      ('<6 months', 'happy', "I have some basic exposure to lifting"),
      ('6–24 months', 'determined', "Consistent lifting, familiar with key compounds"),
      ('2+ years', 'weightlifting', "Deep knowledge, striving for micro-overloads"),
    ];
    return Padding(
      padding: const EdgeInsets.all(CxSpace.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: CxSpace.xl),
          Text("What's your lifting experience?", style: CxType.headline.copyWith(color: c.textPrimary)),
          const SizedBox(height: CxSpace.md),
          Text("Novices get more guidance; experts get raw control.", style: CxType.bodySmall.copyWith(color: c.textSecondary)),
          const SizedBox(height: CxSpace.x2l),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 205,
                          child: _buildGridCard(
                            title: options[0].$1,
                            subtitle: options[0].$3,
                            isSelected: _experience == options[0].$1,
                            activeBorderColor: c.ember,
                            illustration: YorhartWidget(
                              expression: options[0].$2,
                              size: 72,
                              animate: _experience == options[0].$1,
                            ),
                            onTap: () {
                              CxHaptics.fire(CxHaptic.selection);
                              setState(() => _experience = options[0].$1);
                            },
                            c: c,
                          ),
                        ),
                      ),
                      const SizedBox(width: CxSpace.md),
                      Expanded(
                        child: SizedBox(
                          height: 205,
                          child: _buildGridCard(
                            title: options[1].$1,
                            subtitle: options[1].$3,
                            isSelected: _experience == options[1].$1,
                            activeBorderColor: c.ember,
                            illustration: YorhartWidget(
                              expression: options[1].$2,
                              size: 72,
                              animate: _experience == options[1].$1,
                            ),
                            onTap: () {
                              CxHaptics.fire(CxHaptic.selection);
                              setState(() => _experience = options[1].$1);
                            },
                            c: c,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CxSpace.md),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 205,
                          child: _buildGridCard(
                            title: options[2].$1,
                            subtitle: options[2].$3,
                            isSelected: _experience == options[2].$1,
                            activeBorderColor: c.ember,
                            illustration: YorhartWidget(
                              expression: options[2].$2,
                              size: 72,
                              animate: _experience == options[2].$1,
                            ),
                            onTap: () {
                              CxHaptics.fire(CxHaptic.selection);
                              setState(() => _experience = options[2].$1);
                            },
                            c: c,
                          ),
                        ),
                      ),
                      const SizedBox(width: CxSpace.md),
                      Expanded(
                        child: SizedBox(
                          height: 205,
                          child: _buildGridCard(
                            title: options[3].$1,
                            subtitle: options[3].$3,
                            isSelected: _experience == options[3].$1,
                            activeBorderColor: c.ember,
                            illustration: YorhartWidget(
                              expression: options[3].$2,
                              size: 72,
                              animate: _experience == options[3].$1,
                            ),
                            onTap: () {
                              CxHaptics.fire(CxHaptic.selection);
                              setState(() => _experience = options[3].$1);
                            },
                            c: c,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 9. Days per week Step
  Widget _stepDays(CxColorsExt c) {
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Padding(
      padding: const EdgeInsets.all(CxSpace.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: CxSpace.xl),
          Text("Which days will you train?", style: CxType.headline.copyWith(color: c.textPrimary)),
          const SizedBox(height: CxSpace.md),
          Text("Tap 2 to 6 days per week. We will customize your split accordingly.", style: CxType.bodySmall.copyWith(color: c.textSecondary)),
          const SizedBox(height: CxSpace.x3l),
          Center(
            child: Wrap(
              spacing: CxSpace.md,
              runSpacing: CxSpace.md,
              alignment: WrapAlignment.center,
              children: [
                for (final day in weekDays) ...[
                  GestureDetector(
                    onTap: () {
                      CxHaptics.fire(CxHaptic.selection);
                      setState(() {
                        if (_daysPerWeek.contains(day)) {
                          if (_daysPerWeek.length > 2) {
                            _daysPerWeek.remove(day);
                          }
                        } else {
                          if (_daysPerWeek.length < 6) {
                            _daysPerWeek.add(day);
                          }
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: CxDuration.fast,
                      padding: const EdgeInsets.symmetric(horizontal: CxSpace.lg, vertical: CxSpace.md),
                      decoration: BoxDecoration(
                        color: _daysPerWeek.contains(day) ? c.ember : c.surfaceHigh,
                        borderRadius: CxRadii.brMd,
                        border: Border.all(
                          color: _daysPerWeek.contains(day) ? c.ember : c.border,
                          width: 1.5,
                        ),
                        boxShadow: _daysPerWeek.contains(day)
                            ? [
                                BoxShadow(
                                  color: c.ember.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        day,
                        style: CxType.titleSmall.copyWith(
                          color: _daysPerWeek.contains(day) ? c.onEmber : c.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: CxSpace.x3l),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: CxSpace.xl, vertical: CxSpace.sm),
              decoration: BoxDecoration(
                color: c.surfaceHigh,
                borderRadius: CxRadii.brPill,
                border: Border.all(color: c.border),
              ),
              child: Text(
                "${_daysPerWeek.length} days selected per week",
                style: CxType.titleSmall.copyWith(color: c.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 10. Equipment Step
  Widget _stepEquipment(CxColorsExt c) {
    final options = [
      ('Full gym', Icons.home_repair_service_rounded, "Access to barbells, racks, and machines"),
      ('Dumbbells only', Icons.fitness_center_rounded, "Only have a set of adjustable DBs"),
      ('Minimal home', Icons.chair_rounded, "Just bodyweight, bands or light items"),
    ];
    return Padding(
      padding: const EdgeInsets.all(CxSpace.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: CxSpace.xl),
          Text("What equipment do you have?", style: CxType.headline.copyWith(color: c.textPrimary)),
          const SizedBox(height: CxSpace.md),
          Text("We'll filter out routines you can't perform.", style: CxType.bodySmall.copyWith(color: c.textSecondary)),
          const SizedBox(height: CxSpace.x2l),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 205,
                          child: _buildGridCard(
                            title: options[0].$1,
                            subtitle: options[0].$3,
                            isSelected: _equipment == options[0].$1,
                            activeBorderColor: c.ember,
                            illustration: Icon(
                              options[0].$2,
                              color: _equipment == options[0].$1 ? c.ember : c.textTertiary,
                              size: 40,
                            ),
                            onTap: () {
                              CxHaptics.fire(CxHaptic.selection);
                              setState(() => _equipment = options[0].$1);
                            },
                            c: c,
                          ),
                        ),
                      ),
                      const SizedBox(width: CxSpace.md),
                      Expanded(
                        child: SizedBox(
                          height: 205,
                          child: _buildGridCard(
                            title: options[1].$1,
                            subtitle: options[1].$3,
                            isSelected: _equipment == options[1].$1,
                            activeBorderColor: c.ember,
                            illustration: Icon(
                              options[1].$2,
                              color: _equipment == options[1].$1 ? c.ember : c.textTertiary,
                              size: 40,
                            ),
                            onTap: () {
                              CxHaptics.fire(CxHaptic.selection);
                              setState(() => _equipment = options[1].$1);
                            },
                            c: c,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CxSpace.md),
                  SizedBox(
                    height: 100,
                    child: _buildWideGridCard(
                      title: options[2].$1,
                      subtitle: options[2].$3,
                      isSelected: _equipment == options[2].$1,
                      activeBorderColor: c.ember,
                      illustration: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: CxSpace.sm),
                        child: Icon(
                          options[2].$2,
                          color: _equipment == options[2].$1 ? c.ember : c.textTertiary,
                          size: 36,
                        ),
                      ),
                      onTap: () {
                        CxHaptics.fire(CxHaptic.selection);
                        setState(() => _equipment = options[2].$1);
                      },
                      c: c,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 11. Injuries Step
  Widget _stepInjuries(CxColorsExt c) {
    final options = [
      ('Shoulder', Icons.accessibility_new_rounded, 'Shoulder pain, overhead press issues'),
      ('Knee', Icons.directions_walk_rounded, 'Knee pain, squatting sensitivity'),
      ('Lower back', Icons.airline_seat_recline_normal_rounded, 'Stiffness, deadlift loading sensitivity'),
      ('None', Icons.check_circle_outline_rounded, 'No active joint pains or limitations'),
    ];
    return Padding(
      padding: const EdgeInsets.all(CxSpace.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: CxSpace.xl),
          Text("Any joint pains or injuries?", style: CxType.headline.copyWith(color: c.textPrimary)),
          const SizedBox(height: CxSpace.md),
          Text("We will automatically substitute exercises that over-stress these regions.", style: CxType.bodySmall.copyWith(color: c.textSecondary)),
          const SizedBox(height: CxSpace.x2l),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 160,
                          child: _buildGridCard(
                            title: options[0].$1,
                            subtitle: options[0].$3,
                            isSelected: _injuries.contains(options[0].$1),
                            activeBorderColor: c.ember,
                            illustration: Icon(
                              options[0].$2,
                              color: _injuries.contains(options[0].$1) ? c.ember : c.textTertiary,
                              size: 36,
                            ),
                            onTap: () {
                              CxHaptics.fire(CxHaptic.selection);
                              setState(() {
                                if (_injuries.contains(options[0].$1)) {
                                  _injuries.remove(options[0].$1);
                                } else {
                                  _injuries.add(options[0].$1);
                                }
                              });
                            },
                            c: c,
                          ),
                        ),
                      ),
                      const SizedBox(width: CxSpace.md),
                      Expanded(
                        child: SizedBox(
                          height: 160,
                          child: _buildGridCard(
                            title: options[1].$1,
                            subtitle: options[1].$3,
                            isSelected: _injuries.contains(options[1].$1),
                            activeBorderColor: c.ember,
                            illustration: Icon(
                              options[1].$2,
                              color: _injuries.contains(options[1].$1) ? c.ember : c.textTertiary,
                              size: 36,
                            ),
                            onTap: () {
                              CxHaptics.fire(CxHaptic.selection);
                              setState(() {
                                if (_injuries.contains(options[1].$1)) {
                                  _injuries.remove(options[1].$1);
                                } else {
                                  _injuries.add(options[1].$1);
                                }
                              });
                            },
                            c: c,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CxSpace.md),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 160,
                          child: _buildGridCard(
                            title: options[2].$1,
                            subtitle: options[2].$3,
                            isSelected: _injuries.contains(options[2].$1),
                            activeBorderColor: c.ember,
                            illustration: Icon(
                              options[2].$2,
                              color: _injuries.contains(options[2].$1) ? c.ember : c.textTertiary,
                              size: 36,
                            ),
                            onTap: () {
                              CxHaptics.fire(CxHaptic.selection);
                              setState(() {
                                if (_injuries.contains(options[2].$1)) {
                                  _injuries.remove(options[2].$1);
                                } else {
                                  _injuries.add(options[2].$1);
                                }
                              });
                            },
                            c: c,
                          ),
                        ),
                      ),
                      const SizedBox(width: CxSpace.md),
                      Expanded(
                        child: SizedBox(
                          height: 160,
                          child: _buildGridCard(
                            title: options[3].$1,
                            subtitle: options[3].$3,
                            isSelected: _injuries.isEmpty,
                            activeBorderColor: c.ember,
                            illustration: Icon(
                              options[3].$2,
                              color: _injuries.isEmpty ? c.ember : c.textTertiary,
                              size: 36,
                            ),
                            onTap: () {
                              CxHaptics.fire(CxHaptic.selection);
                              setState(() {
                                _injuries.clear();
                              });
                            },
                            c: c,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CxSpace.x2l),
                  CxTextField(
                    label: "Specific exercise to avoid (Optional)",
                    hint: "E.g. Barbell Deadlift",
                    onChanged: (val) {
                      // Custom text input can be processed if needed
                    },
                  ),
                  const SizedBox(height: CxSpace.lg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 12. Notification Step
  Widget _stepNotification(CxColorsExt c) {
    return Padding(
      padding: const EdgeInsets.all(CxSpace.screen),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: CxSpace.xl),
            Text(
              "HONEST VALUE FRAMING",
              textAlign: TextAlign.center,
              style: CxType.overline.copyWith(color: c.ember),
            ),
            const SizedBox(height: CxSpace.sm),
            Text(
              "Keep your streak alive",
              textAlign: TextAlign.center,
              style: CxType.headline.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: CxSpace.x2l),
            const YorhartWidget(expression: 'coaching', size: 120),
            const SizedBox(height: CxSpace.x2l),
            Text(
              "We don't spam. We only send notifications to remind you of your training days, celebrate your PRs, and keep your daily streak alive.",
              textAlign: TextAlign.center,
              style: CxType.body.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: CxSpace.x2l),
            SwitchListTile(
              value: _notificationPermission,
              activeColor: c.ember,
              title: Text("Enable smart reminders", style: CxType.titleSmall.copyWith(color: c.textPrimary)),
              subtitle: Text("Highly recommended for consistency", style: CxType.caption.copyWith(color: c.textTertiary)),
              onChanged: (val) {
                CxHaptics.fire(CxHaptic.selection);
                setState(() {
                  _notificationPermission = val;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // 13. Generation Screen
  Widget _buildGenerationScreen(CxColorsExt c) {
    // Cycle expression based on phase
    final expressions = ['happy', 'determined', 'weightlifting', 'celebrating'];
    final currentExpr = expressions[_generationPhase % expressions.length];

    return Scaffold(
      backgroundColor: c.ember, // Solid vibrant orange canvas (Mozi Style)
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(CxSpace.x2l),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // White circular mascot backdrop
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.12),
                ),
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: CxDuration.slow,
                  child: YorhartWidget(
                    key: ValueKey(currentExpr),
                    expression: currentExpr,
                    size: 140,
                    animate: true,
                  ),
                ),
              ),
              const SizedBox(height: CxSpace.x4l),
              
              // White loader indicator
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  backgroundColor: Colors.white.withOpacity(0.2),
                ),
              ),
              const SizedBox(height: CxSpace.x2l),
              
              Text(
                "BUILDING YOUR ROUTINE",
                style: CxType.overline.copyWith(
                  color: Colors.white.withOpacity(0.7),
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: CxSpace.sm),
              
              AnimatedSwitcher(
                duration: CxDuration.slow,
                child: Text(
                  _generationSteps[_generationPhase],
                  key: ValueKey(_generationPhase),
                  textAlign: TextAlign.center,
                  style: CxType.headline.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? illustration,
    required CxColorsExt c,
    Color? activeBorderColor,
  }) {
    final activeColor = activeBorderColor ?? c.ultraviolet;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: CxDuration.fast,
        padding: const EdgeInsets.all(CxSpace.md),
        decoration: BoxDecoration(
          color: isSelected ? c.surfaceHighest : c.surfaceHigh,
          borderRadius: CxRadii.brLg,
          border: Border.all(
            color: isSelected ? activeColor : c.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (illustration != null) ...[
              illustration,
              const SizedBox(height: CxSpace.sm),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: CxType.titleSmall.copyWith(
                color: c.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Center(
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: CxType.caption.copyWith(color: c.textSecondary),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideGridCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? illustration,
    required CxColorsExt c,
    Color? activeBorderColor,
  }) {
    final activeColor = activeBorderColor ?? c.ultraviolet;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: CxDuration.fast,
        padding: const EdgeInsets.symmetric(horizontal: CxSpace.md, vertical: CxSpace.sm),
        decoration: BoxDecoration(
          color: isSelected ? c.surfaceHighest : c.surfaceHigh,
          borderRadius: CxRadii.brLg,
          border: Border.all(
            color: isSelected ? activeColor : c.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            if (illustration != null) ...[
              illustration,
              const SizedBox(width: CxSpace.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: CxType.titleSmall.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: CxType.caption.copyWith(color: c.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
