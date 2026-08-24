import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme_mode_provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Internal design gallery: every color, type style, and component in one
/// scrollable place. Used to approve the visual language and to catch drift.
class DesignGalleryScreen extends ConsumerStatefulWidget {
  const DesignGalleryScreen({super.key});

  @override
  ConsumerState<DesignGalleryScreen> createState() =>
      _DesignGalleryScreenState();
}

class _DesignGalleryScreenState extends ConsumerState<DesignGalleryScreen> {
  double _weight = 60;
  int _xp = 1240;
  int _selectedGoal = 0;
  final Set<String> _equipment = {'Dumbbells'};

  void _showDemoSheet(BuildContext context) {
    var selectedStatus = 'Active';
    showRqGlassBottomSheet(
      context: context,
      title: 'Set Status',
      headerIcon: Icons.favorite_rounded,
      headerIconColor: CxColors.ember,
      actionLabel: 'Done',
      onActionPressed: () => Navigator.pop(context),
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          final options = [
            ('Active', 'Being healthy and active.', Icons.directions_run_rounded),
            ('On a Break', 'Taking a few days off to recover.', Icons.beach_access_rounded),
            ('Sick', 'Needing rest to get well.', Icons.thermostat_rounded),
            ('Injured', 'Needing time to heal.', Icons.healing_rounded),
          ];

          final c = context.cx;
          return Column(
            children: options.map((opt) {
              final isSelected = selectedStatus == opt.$1;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: CxSpace.sm,
                  vertical: CxSpace.xs,
                ),
                leading: Icon(
                  opt.$3,
                  color: isSelected ? c.ember : c.textSecondary,
                  size: 24,
                ),
                title: Text(
                  opt.$1,
                  style: CxType.titleSmall.copyWith(
                    color: isSelected ? c.textPrimary : c.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  opt.$2,
                  style: CxType.bodySmall.copyWith(color: c.textTertiary),
                ),
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? c.ember : c.border,
                      width: isSelected ? 2 : 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: isSelected
                      ? Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.ember,
                          ),
                        )
                      : null,
                ),
                onTap: () {
                  setSheetState(() => selectedStatus = opt.$1);
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Design gallery'),
        actions: [
          IconButton(
            tooltip: isDark ? 'Switch to light' : 'Switch to dark',
            icon: Icon(isDark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded),
            onPressed: () =>
                ref.read(themeModeProvider.notifier).setDark(!isDark),
          ),
          const SizedBox(width: CxSpace.sm),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          CxSpace.screen,
          CxSpace.sm,
          CxSpace.screen,
          CxSpace.x5l,
        ),
        children: [
          Text(
            'Night Gym',
            style: CxType.displayXL.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: CxSpace.xs),
          Text(
            'Every token and component in one place.',
            style: CxType.body.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: CxSpace.x3l),

          _Section(
            title: 'Color',
            child: _ColorTokens(),
          ),

          _Section(
            title: 'Typography',
            child: _TypeScale(),
          ),

          _Section(
            title: 'Number roll',
            subtitle: 'Odometer numerals — tabular, never jitter.',
            child: _NumberRollDemo(
              weight: _weight,
              xp: _xp,
              onWeight: (v) => setState(() => _weight = v),
              onXpBump: () => setState(() => _xp += 175),
            ),
          ),

          _Section(
            title: 'Buttons',
            child: _Buttons(),
          ),

          _Section(
            title: 'Cards',
            child: _Cards(),
          ),

          _Section(
            title: 'Glass Popups',
            subtitle: 'Frosted glass bottom sheets with BackdropFilter.',
            child: CxButton(
              label: 'Trigger Set Status Sheet',
              icon: Icons.blur_on_rounded,
              variant: CxButtonVariant.secondary,
              expand: true,
              onPressed: () => _showDemoSheet(context),
            ),
          ),

          _Section(
            title: 'Chips & tags',
            child: _Chips(
              selectedGoal: _selectedGoal,
              onGoal: (i) => setState(() => _selectedGoal = i),
              equipment: _equipment,
              onEquipment: (label) => setState(() {
                if (!_equipment.remove(label)) _equipment.add(label);
              }),
            ),
          ),

          _Section(
            title: 'Inputs',
            child: _Inputs(),
          ),

          _Section(
            title: 'Progress',
            child: const _Progress(),
          ),

          _Section(
            title: 'Spacing & radii',
            child: const _SpacingRadii(),
          ),

          _Section(
            title: 'Motion & haptics',
            subtitle: 'Tap to feel each event.',
            child: const _Haptics(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section scaffold
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Padding(
      padding: const EdgeInsets.only(bottom: CxSpace.x3l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: CxType.overline.copyWith(color: c.ultraviolet),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: CxSpace.xs),
            Text(subtitle!,
                style: CxType.bodySmall.copyWith(color: c.textTertiary)),
          ],
          const SizedBox(height: CxSpace.lg),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Color tokens
// ---------------------------------------------------------------------------

class _ColorTokens extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Column(
      children: [
        Wrap(
          spacing: CxSpace.md,
          runSpacing: CxSpace.md,
          children: [
            _Swatch('Canvas', c.canvas, c.textPrimary, border: c.border),
            _Swatch('Surface', c.surface, c.textPrimary, border: c.border),
            _Swatch('Surface+', c.surfaceHigh, c.textPrimary),
            _Swatch('Surface++', c.surfaceHighest, c.textPrimary),
          ],
        ),
        const SizedBox(height: CxSpace.md),
        Wrap(
          spacing: CxSpace.md,
          runSpacing: CxSpace.md,
          children: [
            _Swatch('Ember', c.ember, c.onEmber),
            _Swatch('Ultraviolet', c.ultraviolet, c.onUltraviolet),
            _Swatch('Success', c.success, c.onStatus),
            _Swatch('Warning', c.warning, c.onStatus),
            _Swatch('Danger', c.danger, c.onStatus),
          ],
        ),
        const SizedBox(height: CxSpace.md),
        Wrap(
          spacing: CxSpace.md,
          runSpacing: CxSpace.md,
          children: [
            _Swatch('Lilac', c.lilac, c.onPastel),
            _Swatch('Cream', c.cream, c.onPastel),
            _Swatch('Mint', c.mint, c.onPastel),
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.label, this.color, this.onColor, {this.border});
  final String label;
  final Color color;
  final Color onColor;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 76,
      padding: const EdgeInsets.all(CxSpace.md),
      alignment: Alignment.bottomLeft,
      decoration: BoxDecoration(
        color: color,
        borderRadius: CxRadii.brMd,
        border: border != null ? Border.all(color: border!) : null,
      ),
      child: Text(label, style: CxType.caption.copyWith(color: onColor)),
    );
  }
}

// ---------------------------------------------------------------------------
// Type scale
// ---------------------------------------------------------------------------

class _TypeScale extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final samples = <(String, TextStyle)>[
      ('Display XL — Clash', CxType.displayXL),
      ('Display L — Clash', CxType.displayL),
      ('Headline — Clash', CxType.headline),
      ('Title — General Sans', CxType.title),
      ('Title small', CxType.titleSmall),
      ('Body — General Sans', CxType.body),
      ('Body small', CxType.bodySmall),
      ('Label', CxType.label),
      ('Caption', CxType.caption),
      ('OVERLINE', CxType.overline),
    ];
    return CxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (name, style) in samples)
            Padding(
              padding: const EdgeInsets.only(bottom: CxSpace.md),
              child: Text(name, style: style.copyWith(color: c.textPrimary)),
            ),
          const Divider(),
          const SizedBox(height: CxSpace.md),
          Text('Numerals — JetBrains Mono',
              style: CxType.label.copyWith(color: c.textTertiary)),
          const SizedBox(height: CxSpace.sm),
          Text('62.5', style: CxType.numHero.copyWith(color: c.textPrimary)),
          Text('01:30', style: CxType.timer.copyWith(color: c.ultraviolet)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Number roll
// ---------------------------------------------------------------------------

class _NumberRollDemo extends StatelessWidget {
  const _NumberRollDemo({
    required this.weight,
    required this.xp,
    required this.onWeight,
    required this.onXpBump,
  });

  final double weight;
  final int xp;
  final ValueChanged<double> onWeight;
  final VoidCallback onXpBump;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Column(
      children: [
        CxCard(
          child: Column(
            children: [
              Text('WORKING WEIGHT',
                  style: CxType.overline.copyWith(color: c.textTertiary)),
              const SizedBox(height: CxSpace.lg),
              CxStepper(
                value: weight,
                onChanged: onWeight,
                unitLabel: 'kg',
                step: 2.5,
              ),
            ],
          ),
        ),
        const SizedBox(height: CxSpace.lg),
        CxCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL XP',
                        style:
                            CxType.overline.copyWith(color: c.textTertiary)),
                    const SizedBox(height: CxSpace.sm),
                    CxNumberRoll(
                      value: xp,
                      style: CxType.numXL,
                      color: c.ultraviolet,
                    ),
                  ],
                ),
              ),
              CxButton(
                label: '+175 XP',
                variant: CxButtonVariant.secondary,
                onPressed: onXpBump,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------------

class _Buttons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CxButton(
          label: 'Start workout',
          size: CxButtonSize.large,
          icon: Icons.play_arrow_rounded,
          expand: true,
          onPressed: () {},
        ),
        const SizedBox(height: CxSpace.md),
        Row(
          children: [
            Expanded(
              child: CxButton(
                label: 'Log set',
                onPressed: () {},
              ),
            ),
            const SizedBox(width: CxSpace.md),
            Expanded(
              child: CxButton(
                label: 'Skip',
                variant: CxButtonVariant.secondary,
                onPressed: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: CxSpace.md),
        Row(
          children: [
            Expanded(
              child: CxButton(
                label: 'Ghost',
                variant: CxButtonVariant.ghost,
                onPressed: () {},
              ),
            ),
            const SizedBox(width: CxSpace.md),
            Expanded(
              child: CxButton(
                label: 'Delete',
                icon: Icons.delete_outline_rounded,
                variant: CxButtonVariant.danger,
                onPressed: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: CxSpace.md),
        Row(
          children: [
            Expanded(
              child: CxButton(
                label: 'Loading',
                loading: true,
                onPressed: () {},
              ),
            ),
            const SizedBox(width: CxSpace.md),
            Expanded(
              child: CxButton(
                label: 'Disabled',
                onPressed: null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------

class _Cards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Column(
      children: [
        CxCard(
          elevated: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Surface card',
                  style: CxType.titleSmall.copyWith(color: c.textPrimary)),
              const SizedBox(height: CxSpace.xs),
              Text(
                'Neutral container for content that lives in the dark.',
                style: CxType.bodySmall.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: CxSpace.lg),
        _PastelCardSample(
          tint: CxPastelTint.lilac,
          title: 'Push day',
          subtitle: 'Chest · Shoulders · Triceps',
        ),
        const SizedBox(height: CxSpace.md),
        _PastelCardSample(
          tint: CxPastelTint.mint,
          title: 'Lower body',
          subtitle: 'Hip thrust · RDL · Split squat',
        ),
        const SizedBox(height: CxSpace.md),
        _PastelCardSample(
          tint: CxPastelTint.cream,
          title: 'Full body',
          subtitle: 'Squat · Bench · Row',
        ),
      ],
    );
  }
}

class _PastelCardSample extends StatelessWidget {
  const _PastelCardSample({
    required this.tint,
    required this.title,
    required this.subtitle,
  });
  final CxPastelTint tint;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return CxPastelCard(
      tint: tint,
      onTap: () {},
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: CxType.title.copyWith(color: CxColors.pastelInk)),
                const SizedBox(height: CxSpace.xs),
                Text(subtitle,
                    style: CxType.bodySmall
                        .copyWith(color: CxColors.pastelInkSoft)),
                const SizedBox(height: CxSpace.md),
                const CxTag(label: '4 exercises', icon: Icons.fitness_center),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: CxColors.pastelInk.withValues(alpha: 0.6)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chips
// ---------------------------------------------------------------------------

class _Chips extends StatelessWidget {
  const _Chips({
    required this.selectedGoal,
    required this.onGoal,
    required this.equipment,
    required this.onEquipment,
  });

  final int selectedGoal;
  final ValueChanged<int> onGoal;
  final Set<String> equipment;
  final ValueChanged<String> onEquipment;

  @override
  Widget build(BuildContext context) {
    const goals = ['Build muscle', 'Get stronger', 'Lose fat', 'Stay fit'];
    const gear = ['Full gym', 'Dumbbells', 'Minimal home'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: CxSpace.sm,
          runSpacing: CxSpace.sm,
          children: [
            for (var i = 0; i < goals.length; i++)
              CxChip(
                label: goals[i],
                selected: selectedGoal == i,
                accent: CxChipAccent.ember,
                onTap: () => onGoal(i),
              ),
          ],
        ),
        const SizedBox(height: CxSpace.lg),
        Wrap(
          spacing: CxSpace.sm,
          runSpacing: CxSpace.sm,
          children: [
            for (final g in gear)
              CxChip(
                label: g,
                selected: equipment.contains(g),
                onTap: () => onEquipment(g),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Inputs
// ---------------------------------------------------------------------------

class _Inputs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        CxTextField(
          label: 'Display name',
          hint: 'What should we call you?',
        ),
        SizedBox(height: CxSpace.lg),
        CxTextField(
          label: 'Body weight',
          hint: '0',
          errorText: 'Enter a weight between 30 and 300 kg.',
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Progress
// ---------------------------------------------------------------------------

class _Progress extends StatelessWidget {
  const _Progress();

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return CxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('XP to next level',
              style: CxType.label.copyWith(color: c.textSecondary)),
          const SizedBox(height: CxSpace.sm),
          const CxProgressBar(value: 0.62),
          const SizedBox(height: CxSpace.xl),
          Text('Weekly quest',
              style: CxType.label.copyWith(color: c.textSecondary)),
          const SizedBox(height: CxSpace.sm),
          const CxProgressBar(value: 0.4, accent: CxProgressAccent.ember),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Spacing & radii
// ---------------------------------------------------------------------------

class _SpacingRadii extends StatelessWidget {
  const _SpacingRadii();

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final spaces = <(String, double)>[
      ('xs', CxSpace.xs),
      ('sm', CxSpace.sm),
      ('md', CxSpace.md),
      ('lg', CxSpace.lg),
      ('xl', CxSpace.xl),
      ('2xl', CxSpace.x2l),
      ('3xl', CxSpace.x3l),
    ];
    final radii = <(String, double)>[
      ('sm', CxRadii.sm),
      ('md', CxRadii.md),
      ('lg', CxRadii.lg),
      ('xl', CxRadii.xl),
    ];
    return CxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (name, value) in spaces)
            Padding(
              padding: const EdgeInsets.only(bottom: CxSpace.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(name,
                        style: CxType.numS.copyWith(color: c.textTertiary)),
                  ),
                  Container(
                    height: 12,
                    width: value,
                    decoration: BoxDecoration(
                      color: c.ultraviolet,
                      borderRadius: CxRadii.brSm,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
          const SizedBox(height: CxSpace.sm),
          Wrap(
            spacing: CxSpace.md,
            runSpacing: CxSpace.md,
            children: [
              for (final (name, value) in radii)
                Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: c.surfaceHighest,
                        borderRadius: BorderRadius.circular(value),
                        border: Border.all(color: c.border),
                      ),
                    ),
                    const SizedBox(height: CxSpace.xs),
                    Text(name,
                        style: CxType.caption.copyWith(color: c.textTertiary)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Haptics
// ---------------------------------------------------------------------------

class _Haptics extends StatelessWidget {
  const _Haptics();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: CxSpace.sm,
      runSpacing: CxSpace.sm,
      children: [
        for (final h in CxHaptic.values)
          CxChip(
            label: h.name,
            icon: Icons.vibration_rounded,
            onTap: () => CxHaptics.fire(h),
          ),
      ],
    );
  }
}
