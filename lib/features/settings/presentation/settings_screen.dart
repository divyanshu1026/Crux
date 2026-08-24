import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme_mode_provider.dart';
import '../../../core/data/backup_schedule.dart';
import '../../../core/data/local_store.dart';
import '../../../core/data/supabase/account_repository.dart';
import '../../../core/data/supabase/supabase_config.dart';
import '../../../core/data/supabase/sync_service.dart';
import '../../../core/providers/backup_providers.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

// The privacy policy and terms are shipped in-app (see
// `lib/features/legal/domain/legal_docs.dart` and [Routes.privacy]) rather than
// hosted, so they need no domain and work offline. The Play Console still
// requires a public policy URL in App content — see RELEASE.md.

/// Settings (Phase 8.2): units, theme, rest-timer default, reminders, Zen mode,
/// language, automatic backup, and delete-data. One decision per row, honest
/// copy.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.cx;
    final profile = ref.watch(userProfileProvider);
    final settings = ref.watch(appSettingsProvider);
    // Watched so the row rebuilds the moment the mode changes; the switch
    // itself reads the *rendered* brightness, which is what the user sees.
    ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            CxSpace.screen, CxSpace.md, CxSpace.screen, 48),
        children: [
          // --- Units --------------------------------------------------------
          _Section(title: 'Units'),
          _SettingCard(
            child: _SegmentedRow(
              icon: Icons.straighten_rounded,
              label: 'Weight units',
              options: const ['kg', 'lbs'],
              selected: profile.units,
              onSelected: (v) {
                CxHaptics.fire(CxHaptic.selection);
                ref.read(userProfileProvider.notifier).setUnits(v);
              },
            ),
          ),

          // --- Appearance ---------------------------------------------------
          _Section(title: 'Appearance'),
          _SettingCard(
            child: _SwitchRow(
              icon: Icons.dark_mode_rounded,
              label: 'Dark theme',
              subtitle: 'Warm near-black, easy on the eyes',
              // Reflect what is actually on screen, not the stored mode:
              // under `system` the app can be dark while the mode isn't
              // `ThemeMode.dark`, and a switch that disagrees with the screen
              // is why the first tap used to look like it did nothing.
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: (v) {
                CxHaptics.fire(CxHaptic.selection);
                ref.read(themeModeProvider.notifier).setDark(v);
              },
            ),
          ),
          const SizedBox(height: CxSpace.md),
          _SettingCard(
            child: _SwitchRow(
              icon: Icons.self_improvement_rounded,
              label: 'Zen mode',
              subtitle: 'Hide XP, streaks and quests — just track',
              value: profile.zenMode,
              onChanged: (_) {
                CxHaptics.fire(CxHaptic.selection);
                ref.read(userProfileProvider.notifier).toggleZenMode();
              },
            ),
          ),

          // --- Training -----------------------------------------------------
          _Section(title: 'Training'),
          _SettingCard(
            child: _StepperRow(
              icon: Icons.timer_rounded,
              label: 'Rest timer default',
              value: '${settings.restTimerSeconds}s',
              onDecrement: settings.restTimerSeconds > 30
                  ? () {
                      CxHaptics.fire(CxHaptic.selection);
                      ref
                          .read(appSettingsProvider.notifier)
                          .setRestTimerSeconds(settings.restTimerSeconds - 15);
                    }
                  : null,
              onIncrement: settings.restTimerSeconds < 300
                  ? () {
                      CxHaptics.fire(CxHaptic.selection);
                      ref
                          .read(appSettingsProvider.notifier)
                          .setRestTimerSeconds(settings.restTimerSeconds + 15);
                    }
                  : null,
            ),
          ),
          const SizedBox(height: CxSpace.md),
          _SettingCard(
            child: _SwitchRow(
              icon: Icons.volume_up_rounded,
              label: 'Rest complete tone',
              subtitle: 'Beep when rest ends so you know to lift again',
              value: settings.restCompleteSoundEnabled,
              onChanged: (v) {
                CxHaptics.fire(CxHaptic.selection);
                ref.read(appSettingsProvider.notifier).setRestCompleteSound(v);
              },
            ),
          ),
          const SizedBox(height: CxSpace.md),
          _SettingCard(
            child: _SwitchRow(
              icon: Icons.notifications_active_rounded,
              label: 'Training reminders',
              subtitle: 'Nudges on your planned days only. No spam.',
              value: settings.remindersEnabled,
              onChanged: (v) =>
                  _toggleTrainingReminders(context, ref, v),
            ),
          ),
          const SizedBox(height: CxSpace.md),
          _SettingCard(
            child: _SwitchRow(
              icon: Icons.water_drop_rounded,
              label: 'Hydration reminders',
              subtitle: 'Three gentle water nudges through the day',
              value: settings.hydrationRemindersEnabled,
              onChanged: (v) =>
                  _toggleHydrationReminders(context, ref, v),
            ),
          ),

          // --- Language -----------------------------------------------------
          _Section(title: 'Language'),
          _SettingCard(
            child: Row(
              children: [
                Icon(Icons.language_rounded, color: c.textSecondary),
                const SizedBox(width: CxSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('English',
                          style:
                              CxType.titleSmall.copyWith(color: c.textPrimary)),
                      Text('More languages coming soon',
                          style:
                              CxType.caption.copyWith(color: c.textTertiary)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- Cloud (only when a Supabase project is wired) ----------------
          if (SupabaseConfig.isConfigured) ...[
            _Section(title: 'Cloud backup'),
            const _AutoBackupCard(),
            const SizedBox(height: CxSpace.md),
            _ActionRow(
              icon: Icons.cloud_upload_rounded,
              label: 'Back up now',
              subtitle: 'Push your training log, profile & weight to the cloud',
              onTap: () => _sync(context, ref, backup: true),
            ),
            const SizedBox(height: CxSpace.md),
            _ActionRow(
              icon: Icons.cloud_download_rounded,
              label: 'Restore from cloud',
              subtitle: 'Pull your data onto this device',
              onTap: () => _sync(context, ref, backup: false),
            ),
          ],

          // --- Data ---------------------------------------------------------
          _Section(title: 'Your data'),
          _ActionRow(
            icon: Icons.phonelink_erase_rounded,
            label: 'Clear data on this device',
            subtitle: 'Wipes local data and signs you out. Cloud backup stays.',
            destructive: true,
            onTap: () => _confirmDelete(context, ref),
          ),
          const SizedBox(height: CxSpace.md),
          _ActionRow(
            icon: Icons.no_accounts_rounded,
            label: 'Delete my account',
            subtitle: 'Permanently deletes your account and all cloud data',
            destructive: true,
            onTap: () => _confirmDeleteAccount(context, ref),
          ),

          // --- About / legal --------------------------------------------------
          _Section(title: 'About'),
          _ActionRow(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy policy',
            subtitle: 'What we store, and what we never collect',
            onTap: () => context.push(Routes.privacy),
          ),
          const SizedBox(height: CxSpace.md),
          _ActionRow(
            icon: Icons.gavel_rounded,
            label: 'Terms of use',
            subtitle: 'The deal, in plain language',
            onTap: () => context.push(Routes.terms),
          ),

          const SizedBox(height: CxSpace.x2l),
          Center(
            child: Text('Crux v1.0.0',
                style: CxType.caption.copyWith(color: c.textTertiary)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTrainingReminders(
      BuildContext context, WidgetRef ref, bool enabled) async {
    CxHaptics.fire(CxHaptic.selection);
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(notificationServiceProvider);
    ref.read(appSettingsProvider.notifier).setReminders(enabled);
    if (enabled) {
      final granted = await service.requestPermission();
      await service.scheduleTrainingReminders(
          ref.read(userProfileProvider).daysPerWeek);
      if (!granted && !kIsWeb) {
        messenger.showSnackBar(const SnackBar(
            content: Text(
                'Allow notifications in system settings so reminders can reach you.')));
      }
    } else {
      await service.cancelTrainingReminders();
    }
  }

  Future<void> _toggleHydrationReminders(
      BuildContext context, WidgetRef ref, bool enabled) async {
    CxHaptics.fire(CxHaptic.selection);
    final service = ref.read(notificationServiceProvider);
    ref.read(appSettingsProvider.notifier).setHydrationReminders(enabled);
    if (enabled) {
      await service.requestPermission();
      await service.scheduleHydrationReminders();
    } else {
      await service.cancelHydrationReminders();
    }
  }

  Future<void> _sync(BuildContext context, WidgetRef ref,
      {required bool backup}) async {
    final messenger = ScaffoldMessenger.of(context);
    final sync = ref.read(syncServiceProvider);
    messenger.showSnackBar(SnackBar(
        content: Text(backup ? 'Backing up…' : 'Restoring…')));
    try {
      if (backup) {
        await sync.backup(ref.read);
      } else {
        await sync.restore(ref.read);
      }
      CxHaptics.fire(CxHaptic.success);
      messenger.showSnackBar(SnackBar(
          content: Text(backup ? 'Backed up to cloud' : 'Restored from cloud')));
    } on SyncException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Sync failed. Try again in a moment.')));
    }
  }

  /// Permanent account deletion (Play User Data policy): removes the cloud
  /// account + all server rows, then wipes the device. Gated behind an
  /// explicit typed confirmation because it is irreversible.
  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    final c = context.cx;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => _DeleteAccountSheet(colors: c),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final c = context.cx;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CxGlassBottomSheet(
        title: 'Delete all data?',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'This permanently erases your profile, program and history on this '
              'device, then signs you out. This cannot be undone.',
              style: CxType.bodySmall.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: CxSpace.xl),
            CxButton(
              label: 'Delete everything',
              variant: CxButtonVariant.danger,
              expand: true,
              onPressed: () async {
                Navigator.pop(context);
                final store = ref.read(localStoreProvider);
                await store.clearUserData();
                await store.remove(LocalStore.kLastAccountId);
                ref.invalidate(userProfileProvider);
                ref.invalidate(programProvider);
                ref.invalidate(workoutHistoryProvider);
                ref.invalidate(activeWorkoutProvider);
                ref.invalidate(questProvider);
                ref.invalidate(bodyweightProvider);
                ref.invalidate(measurementsProvider);
                ref.invalidate(progressPhotosProvider);
                ref.invalidate(hydrationProvider);
                ref.invalidate(proteinProvider);
                ref.invalidate(coachChatProvider);
                ref.read(notificationServiceProvider).cancelAll();
                await ref.read(authProvider.notifier).logout();
              },
            ),
            const SizedBox(height: CxSpace.sm),
            CxButton(
              label: 'Keep my data',
              variant: CxButtonVariant.ghost,
              expand: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Building blocks
// ---------------------------------------------------------------------------

/// Automatic backup: on/off, how often, and at what time.
///
/// The copy is deliberately precise about *when* this runs. Android will not
/// let an ordinary app guarantee it wakes at 02:00, so promising a nightly
/// upload would be a promise the OS breaks — see [BackupRunner].
class _AutoBackupCard extends ConsumerWidget {
  const _AutoBackupCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.cx;
    final schedule = ref.watch(backupScheduleProvider);
    final status = ref.watch(backupStatusProvider);
    final notifier = ref.read(backupScheduleProvider.notifier);

    return _SettingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SwitchRow(
            icon: Icons.backup_rounded,
            label: 'Automatic backup',
            subtitle: schedule.describeNext(DateTime.now()),
            value: schedule.enabled,
            onChanged: (v) {
              CxHaptics.fire(CxHaptic.selection);
              notifier.setEnabled(v);
            },
          ),
          if (schedule.enabled) ...[
            const SizedBox(height: CxSpace.lg),
            Text('How often',
                style: CxType.caption.copyWith(color: c.textTertiary)),
            const SizedBox(height: CxSpace.sm),
            Wrap(
              spacing: CxSpace.sm,
              runSpacing: CxSpace.sm,
              children: [
                for (final f in BackupFrequency.values)
                  CxChip(
                    label: f.label,
                    selected: schedule.frequency == f,
                    onTap: () {
                      CxHaptics.fire(CxHaptic.selection);
                      notifier.setFrequency(f);
                    },
                  ),
              ],
            ),
            const SizedBox(height: CxSpace.sm),
            Text(schedule.frequency.blurb,
                style: CxType.caption.copyWith(color: c.textTertiary)),
            const SizedBox(height: CxSpace.lg),
            InkWell(
              borderRadius: CxRadii.brMd,
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                      hour: schedule.hour, minute: schedule.minute),
                  helpText: 'Back up after this time',
                );
                if (picked != null) {
                  CxHaptics.fire(CxHaptic.selection);
                  notifier.setTime(picked.hour, picked.minute);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: CxSpace.sm),
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, color: c.textSecondary),
                    const SizedBox(width: CxSpace.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Backup time',
                              style: CxType.titleSmall
                                  .copyWith(color: c.textPrimary)),
                          Text(
                            'Due after ${schedule.timeLabel} — never mid-workout',
                            style: CxType.caption
                                .copyWith(color: c.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    Text(schedule.timeLabel,
                        style: CxType.titleSmall.copyWith(color: c.ember)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: CxSpace.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(CxSpace.md),
              decoration: BoxDecoration(
                color: status == BackupStatus.failed
                    ? c.warning.withValues(alpha: 0.12)
                    : c.surfaceHigh,
                borderRadius: CxRadii.brMd,
              ),
              child: Text(
                switch (status) {
                  BackupStatus.running => 'Backing up now…',
                  BackupStatus.ok => 'Last backup succeeded.',
                  BackupStatus.failed =>
                    "Last backup didn't go through. It'll retry next time you "
                        'open the app.',
                  BackupStatus.idle =>
                    'Runs when you open the app after a backup is due. Android '
                        "doesn't let apps guarantee an exact overnight wake-up, "
                        'so we catch up instead of promising a time we can\'t keep.',
                },
                style: CxType.caption.copyWith(color: c.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Padding(
      padding: const EdgeInsets.only(
          top: CxSpace.xl, bottom: CxSpace.md, left: CxSpace.xs),
      child: Text(title.toUpperCase(),
          style: CxType.overline.copyWith(color: c.textTertiary)),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CxCard(padding: const EdgeInsets.all(CxSpace.lg), child: child);
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Row(
      children: [
        Icon(icon, color: c.textSecondary),
        const SizedBox(width: CxSpace.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: CxType.titleSmall.copyWith(color: c.textPrimary)),
              Text(subtitle,
                  style: CxType.caption.copyWith(color: c.textTertiary)),
            ],
          ),
        ),
        Switch(value: value, activeThumbColor: c.ember, onChanged: onChanged),
      ],
    );
  }
}

class _SegmentedRow extends StatelessWidget {
  const _SegmentedRow({
    required this.icon,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });
  final IconData icon;
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Row(
      children: [
        Icon(icon, color: c.textSecondary),
        const SizedBox(width: CxSpace.lg),
        Expanded(
          child: Text(label,
              style: CxType.titleSmall.copyWith(color: c.textPrimary)),
        ),
        Container(
          padding: const EdgeInsets.all(CxSpace.xxs),
          decoration: BoxDecoration(
            color: c.surfaceHigh,
            borderRadius: CxRadii.brSm,
          ),
          child: Row(
            children: [
              for (final o in options)
                GestureDetector(
                  onTap: () => onSelected(o),
                  child: AnimatedContainer(
                    duration: CxDuration.fast,
                    padding: const EdgeInsets.symmetric(
                        horizontal: CxSpace.lg, vertical: CxSpace.sm),
                    decoration: BoxDecoration(
                      color: selected == o ? c.ember : Colors.transparent,
                      borderRadius: CxRadii.brSm,
                    ),
                    child: Text(o,
                        style: CxType.label.copyWith(
                          color: selected == o ? c.onEmber : c.textSecondary,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onIncrement,
    this.onDecrement,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Row(
      children: [
        Icon(icon, color: c.textSecondary),
        const SizedBox(width: CxSpace.lg),
        Expanded(
          child: Text(label,
              style: CxType.titleSmall.copyWith(color: c.textPrimary)),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline_rounded),
          color: onDecrement == null ? c.textTertiary : c.textPrimary,
          onPressed: onDecrement,
        ),
        SizedBox(
          width: 52,
          child: Text(value,
              textAlign: TextAlign.center,
              style: CxType.numS.copyWith(
                  color: c.textPrimary, fontWeight: FontWeight.bold)),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline_rounded),
          color: onIncrement == null ? c.textTertiary : c.textPrimary,
          onPressed: onIncrement,
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final color = destructive ? c.danger : c.textPrimary;
    return CxCard(
      onTap: onTap,
      padding: const EdgeInsets.all(CxSpace.lg),
      child: Row(
        children: [
          Icon(icon, color: destructive ? c.danger : c.textSecondary),
          const SizedBox(width: CxSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: CxType.titleSmall.copyWith(color: color)),
                Text(subtitle,
                    style: CxType.caption.copyWith(color: c.textTertiary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.textTertiary),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Account deletion (Google Play User Data policy)
// ---------------------------------------------------------------------------

/// Irreversible: deletes the cloud account + every server row, then wipes the
/// device. The user must type DELETE — a stray tap should never be able to
/// destroy someone's training history.
class _DeleteAccountSheet extends ConsumerStatefulWidget {
  const _DeleteAccountSheet({required this.colors});

  final CxColorsExt colors;

  @override
  ConsumerState<_DeleteAccountSheet> createState() =>
      _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<_DeleteAccountSheet> {
  final _confirmController = TextEditingController();
  bool _busy = false;
  String? _error;

  static const _phrase = 'DELETE';

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  bool get _canDelete =>
      _confirmController.text.trim().toUpperCase() == _phrase && !_busy;

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      // 1. Server first — if this fails the account still exists and the user
      //    can retry, rather than being locked out of data we failed to erase.
      await ref.read(accountRepositoryProvider).deleteCloudAccount();

      // 2. Then the device.
      final store = ref.read(localStoreProvider);
      await store.clearUserData();
      await store.remove(LocalStore.kLastAccountId);
      ref.invalidate(userProfileProvider);
      ref.invalidate(programProvider);
      ref.invalidate(workoutHistoryProvider);
      ref.invalidate(activeWorkoutProvider);
      ref.invalidate(questProvider);
      ref.invalidate(bodyweightProvider);
      ref.invalidate(measurementsProvider);
      ref.invalidate(progressPhotosProvider);
      ref.invalidate(hydrationProvider);
      ref.invalidate(proteinProvider);
      ref.invalidate(coachChatProvider);
      ref.read(notificationServiceProvider).cancelAll();
      await ref.read(authProvider.notifier).logout();

      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Your account and data were deleted.')),
      );
    } on AccountDeletionException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return CxGlassBottomSheet(
      title: 'Delete your account?',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'This permanently deletes your Crux account and everything in '
            'it — profile, program, workout history, PRs, body log and coach '
            'conversations — from this device and from our servers.',
            style: CxType.bodySmall.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: CxSpace.md),
          Container(
            padding: const EdgeInsets.all(CxSpace.md),
            decoration: BoxDecoration(
              color: c.danger.withValues(alpha: 0.12),
              borderRadius: CxRadii.brMd,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: c.danger),
                const SizedBox(width: CxSpace.sm),
                Expanded(
                  child: Text(
                    'This cannot be undone. Export your data first if you want '
                    'to keep a copy.',
                    style: CxType.caption.copyWith(color: c.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CxSpace.lg),
          CxTextField(
            label: 'Type $_phrase to confirm',
            hint: _phrase,
            controller: _confirmController,
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...[
            const SizedBox(height: CxSpace.sm),
            Text(_error!,
                style: CxType.caption.copyWith(color: c.danger)),
          ],
          const SizedBox(height: CxSpace.xl),
          CxButton(
            label: 'Delete my account',
            variant: CxButtonVariant.danger,
            expand: true,
            loading: _busy,
            onPressed: _canDelete ? _delete : null,
          ),
          const SizedBox(height: CxSpace.sm),
          CxButton(
            label: 'Keep my account',
            variant: CxButtonVariant.ghost,
            expand: true,
            onPressed: _busy ? null : () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
