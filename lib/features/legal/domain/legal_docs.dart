/// In-app legal documents.
///
/// These ship inside the binary rather than living behind a URL so the app has
/// no external hosting dependency: the policy is readable offline, it can never
/// 404, and it is always the version that matches the installed build.
///
/// Note for the Play Console: Google *also* requires a publicly reachable
/// privacy-policy URL in the App content section. That field cannot be
/// satisfied by an in-app screen — see RELEASE.md.
library;

/// One block of document content. Rendering lives in the presentation layer.
sealed class LegalBlock {
  const LegalBlock();
}

/// A `##` level heading.
class LegalHeading extends LegalBlock {
  const LegalHeading(this.text);
  final String text;
}

/// A body paragraph.
class LegalParagraph extends LegalBlock {
  const LegalParagraph(this.text);
  final String text;
}

/// A bulleted list.
class LegalBullets extends LegalBlock {
  const LegalBullets(this.items);
  final List<String> items;
}

/// A label → explanation pair, used where the source document had a table.
/// Rendered as a definition row, which reads far better on a phone than a
/// horizontally scrolling table.
class LegalDefinitions extends LegalBlock {
  const LegalDefinitions(this.entries);
  final List<(String, String)> entries;
}

/// A visually distinct callout for the parts people actually need to notice.
class LegalCallout extends LegalBlock {
  const LegalCallout(this.text);
  final String text;
}

class LegalDoc {
  const LegalDoc({
    required this.title,
    required this.lastUpdated,
    required this.blocks,
  });

  final String title;
  final String lastUpdated;
  final List<LegalBlock> blocks;
}

abstract final class LegalDocs {
  /// Contact address used across both documents. Change in one place.
  static const contactEmail = 'privacy@crux.app';

  static const privacy = LegalDoc(
    title: 'Privacy Policy',
    lastUpdated: '3 August 2026',
    blocks: [
      LegalCallout(
        'Short version: your training data lives on your phone. If you sign '
        'in, it is also backed up to our server so you can restore it on a '
        'new device. We do not sell your data, we do not run ads, and we do '
        'not track you across other apps.',
      ),
      LegalParagraph(
        'Crux ("we", "the app") is a gym training app. This policy explains '
        'exactly what we store, why, and what we never collect. It is written '
        'to be read, not to be survived.',
      ),

      LegalHeading('1. Who we are'),
      LegalParagraph(
        'Crux is operated by the developer of the Crux app. For privacy '
        'questions and data requests, contact $contactEmail.',
      ),

      LegalHeading('2. What we collect'),
      LegalParagraph('Data you enter — the app\'s whole purpose:'),
      LegalDefinitions([
        ('Name or nickname', 'To address you in the app.'),
        (
          'Sex, age, height, bodyweight',
          'To calibrate starting weights, strength standards and '
              'calorie/protein targets.'
        ),
        (
          'Goal, experience, equipment, injuries',
          'To generate and adjust your program safely.'
        ),
        (
          'Workouts, sets, reps, weights, notes, PRs',
          'The core training log.'
        ),
        (
          'Bodyweight log and body measurements',
          'Progress tracking and nutrition targets.'
        ),
        ('Water and protein entries', 'Daily habit tracking.'),
        (
          'Messages you send to the AI Coach',
          'To answer them, and to review the safety of AI responses.'
        ),
      ]),
      LegalParagraph(
        'Account data: if you create an account we store your email address '
        '(or, for Google/Apple sign-in, the identifier that provider returns) '
        'and an authentication token. You can also use the app without an '
        'account, fully offline — in that case nothing leaves your phone.',
      ),
      LegalParagraph(
        'Progress photos you add stay on your device only. They are never '
        'uploaded to our servers.',
      ),
      LegalParagraph('What we do NOT collect:'),
      LegalBullets([
        'We do not collect your precise location.',
        'We do not collect your contacts, calendar, call logs or SMS.',
        'We do not use advertising identifiers, and we show no ads.',
        'We do not track you across other apps or websites.',
        'We do not sell or rent your personal data to anyone. Ever.',
      ]),

      LegalHeading('3. Permissions we ask for'),
      LegalDefinitions([
        (
          'Notifications',
          'Rest-timer alerts, training-day and hydration reminders. Optional '
              '— the app works without it.'
        ),
        (
          'Alarms & reminders',
          'So the rest-timer alert fires on time when your screen is off '
              'mid-workout. Optional — falls back to approximate timing.'
        ),
        (
          'Photos / media',
          'Only when you choose to add a progress photo. Optional.'
        ),
        (
          'Vibration',
          'Haptic feedback when logging sets and when rest ends.'
        ),
      ]),
      LegalParagraph(
        'We only request a permission at the moment the related feature is '
        'used.',
      ),

      LegalHeading('4. How your data is used'),
      LegalParagraph('We use your data solely to run the app for you:'),
      LegalBullets([
        'To generate and adapt your training program (progression, volume, '
            'rest).',
        'To show your progress (charts, records, streaks, weekly summaries).',
        'To answer your AI Coach questions. When you send a coach message, we '
            'send that message together with a summary of your own training '
            'data to our AI provider so the answer is personalised.',
        'To back up and restore your data across your devices, if you sign in.',
      ]),
      LegalParagraph(
        'Automatic backup: when you are signed in, Crux backs your training '
        'log, profile and bodyweight history up to your account on a schedule '
        'you control in Settings — weekly by default, due after 02:00 so it '
        'never runs mid-workout. You can change how often it runs, change the '
        'time, or switch it off entirely. It only ever uploads to your own '
        'account, and nothing is uploaded at all if you are not signed in.',
      ),
      LegalParagraph(
        'We do not use your data to build advertising profiles, and we do not '
        'use your personal training data to train third-party AI models.',
      ),

      LegalHeading('5. Third parties we share data with'),
      LegalDefinitions([
        (
          'Supabase',
          'Database and auth hosting. Receives your account and the training '
              'data listed above, to store your account and backup.'
        ),
        (
          'OpenRouter',
          'Routes AI requests to a model provider on our behalf. Receives your '
              'coach message plus a summary of your training data.'
        ),
        (
          'The model provider behind that request',
          'Currently DeepSeek. Generates the actual reply or training plan '
              'from what OpenRouter passes on.'
        ),
        (
          'Anthropic (Claude) and Google (Gemini)',
          'Used as backups when the primary provider is unavailable, so the '
              'coach still answers. They receive the same information.'
        ),
      ]),
      LegalParagraph(
        'We send only what is needed to answer well, and we never send your '
        'email address, progress photos, or precise identity to AI providers. '
        'We ask these providers not to train on your inputs, but AI routing '
        'means the model answering you may change over time — this section is '
        'updated when it does. If you never use the AI Coach or ask Coach to '
        'build a plan, nothing is ever sent to an AI provider.',
      ),

      LegalHeading('6. How long we keep data'),
      LegalBullets([
        'While your account exists: we keep your data so you can use and '
            'restore it.',
        'When you delete your account: we delete your account and its data '
            'from our servers. Deletion is immediate and permanent.',
        'Local data stays on your device until you clear it, delete your '
            'account, or uninstall the app.',
        'Payment records: if you ever purchase a subscription, we keep '
            'transaction records (without linking them to your deleted '
            'account) for as long as tax and accounting law requires.',
      ]),

      LegalHeading('7. Deleting your data'),
      LegalParagraph('You are in control, from inside the app:'),
      LegalBullets([
        'Settings → Clear data on this device wipes everything locally and '
            'signs you out. Any cloud backup is untouched.',
        'Settings → Delete my account permanently deletes your account and '
            'all associated data from our servers, then wipes this device.',
        'Settings → Automatic backup controls what gets uploaded and how '
            'often, and can be switched off.',
      ]),
      LegalParagraph(
        'You can also email $contactEmail from your account\'s email address '
        'to request deletion, or to request a copy of your data in a portable '
        'format, and we will action it within 30 days.',
      ),

      LegalHeading('8. Your rights'),
      LegalParagraph(
        'Depending on where you live (for example the EEA/UK under GDPR, or '
        'California under CCPA/CPRA), you have the right to access, correct, '
        'export, or delete your personal data, to object to or restrict '
        'certain processing, and to complain to your data protection '
        'authority. The in-app delete tools cover erasure instantly; for a '
        'copy of your data, or anything else, email $contactEmail and we will '
        'respond within 30 days. We do not "sell" or "share" personal '
        'information as those terms are defined under California law.',
      ),

      LegalHeading('9. Security'),
      LegalParagraph(
        'Data in transit is encrypted with TLS. Data on our servers is stored '
        'with per-user access rules, so one account cannot read another\'s '
        'rows. AI provider keys are held only on our server and are never '
        'shipped inside the app. No system is perfectly secure, but we keep '
        'the amount of data we hold deliberately small.',
      ),

      LegalHeading('10. Children'),
      LegalParagraph(
        'Crux is not intended for children under 13 (or the minimum age of '
        'digital consent in your country). We do not knowingly collect data '
        'from children. If you believe a child has provided us data, email '
        '$contactEmail and we will delete it.',
      ),

      LegalHeading('11. Health disclaimer'),
      LegalCallout(
        'Crux provides general fitness information and AI-generated training '
        'guidance. It is not medical, dietetic, or physiotherapy advice, and '
        'it is not a substitute for a qualified professional. Consult a '
        'professional before starting a new exercise or nutrition programme, '
        'and stop exercising if you experience pain.',
      ),

      LegalHeading('12. Changes to this policy'),
      LegalParagraph(
        'If we make a material change, we will update the date at the top of '
        'this page and notify you in the app before the change takes effect.',
      ),

      LegalHeading('13. Contact'),
      LegalParagraph(contactEmail),
    ],
  );

  static const terms = LegalDoc(
    title: 'Terms of Use',
    lastUpdated: '3 August 2026',
    blocks: [
      LegalCallout(
        'Crux is a training log and coaching aid, not a medical service. Train '
        'within your own limits, and stop if something hurts.',
      ),

      LegalHeading('1. Agreement'),
      LegalParagraph(
        'By using Crux you agree to these terms. If you do not agree, please '
        'stop using the app and delete it.',
      ),

      LegalHeading('2. Who can use Crux'),
      LegalParagraph(
        'You must be at least 13 years old, or the minimum age of digital '
        'consent in your country, whichever is higher. If you are under 18, '
        'use Crux with the involvement of a parent or guardian.',
      ),

      LegalHeading('3. Your account'),
      LegalBullets([
        'You are responsible for keeping your sign-in credentials secure.',
        'You are responsible for the content you enter, including any notes '
            'and messages you send to the AI Coach.',
        'You may delete your account at any time from Settings.',
      ]),

      LegalHeading('4. Health and safety'),
      LegalParagraph(
        'Crux generates training programs and AI guidance from the '
        'information you provide. It cannot see you train, cannot assess your '
        'form, and does not know your medical history. Nothing in the app is '
        'medical, dietetic, or physiotherapy advice.',
      ),
      LegalBullets([
        'Consult a qualified professional before starting a new exercise or '
            'nutrition programme, especially if you have an injury, are '
            'pregnant, or have a medical condition.',
        'Warm up, use appropriate loads, and stop immediately if you feel '
            'pain, dizziness or shortness of breath.',
        'You train at your own risk. We are not liable for injury arising '
            'from your use of the app.',
      ]),

      LegalHeading('5. The AI Coach'),
      LegalParagraph(
        'Coach replies are generated by an AI model. They can be wrong, '
        'incomplete, or out of date, and they are not a substitute for a '
        'human coach or clinician. Use your judgement, and treat the coach as '
        'a well-read training partner rather than an authority. Usage limits '
        'apply to keep the service available to everyone.',
      ),

      LegalHeading('6. Acceptable use'),
      LegalParagraph('Please do not:'),
      LegalBullets([
        'Attempt to break, overload, or reverse-engineer the app or its '
            'backend.',
        'Use automated tools to send bulk requests to the AI Coach.',
        'Use Crux to store or transmit unlawful content.',
        'Resell or redistribute the app or its content.',
      ]),
      LegalParagraph(
        'We may suspend access that damages the service or other users.',
      ),

      LegalHeading('7. Subscriptions'),
      LegalParagraph(
        'Crux may offer an optional paid tier. Where it does, purchases are '
        'processed by the app store on your device and are governed by that '
        'store\'s terms. Manage or cancel a subscription through your store '
        'account; refunds follow the store\'s policy. Cancelling stops future '
        'renewals and leaves your training data intact.',
      ),

      LegalHeading('8. Your content'),
      LegalParagraph(
        'Your training data is yours. You grant us only the permission needed '
        'to run the app for you — storing it, backing it up on the schedule '
        'you set, and processing it to produce your program and coach '
        'replies. We claim no ownership of it, you can delete it at any time, '
        'and you can request a copy by emailing $contactEmail.',
      ),

      LegalHeading('9. Availability and backups'),
      LegalParagraph(
        'We aim to keep Crux running, but we do not guarantee uninterrupted '
        'service. Features may change, and cloud backup or AI features may be '
        'temporarily unavailable. Your locally stored training data remains '
        'usable offline.',
      ),
      LegalCallout(
        'Automatic backup is a convenience, not a guarantee. It runs when you '
        'open the app after a backup is due, because mobile operating systems '
        'do not let apps reliably wake themselves at a fixed time. If you have '
        'not opened Crux since your last backup, your most recent sessions may '
        'not be in the cloud yet. Keep your phone backed up as well, and use '
        '"Back up now" in Settings before wiping or changing device.',
      ),

      LegalHeading('10. Liability'),
      LegalParagraph(
        'To the extent permitted by law, Crux is provided "as is" and we are '
        'not liable for indirect or consequential loss. Nothing in these '
        'terms limits liability that cannot legally be limited, including for '
        'death or personal injury caused by negligence.',
      ),

      LegalHeading('11. Changes'),
      LegalParagraph(
        'We may update these terms. Material changes will be notified in the '
        'app before they take effect, and the date at the top of this page '
        'will change.',
      ),

      LegalHeading('12. Contact'),
      LegalParagraph(contactEmail),
    ],
  );
}
