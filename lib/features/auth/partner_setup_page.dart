import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/data/auth_repository.dart';
import '../../ui/advent_tree.dart';
import '../../ui/riso.dart';
import '../../ui/riso_theme.dart';
import '../surprise/surprise_media.dart';

/// Address of the app for invitation emails: the website itself on the web,
/// otherwise `APP_URL` from the build configuration (may be empty).
String get _appUrl => kIsWeb
    ? '${Uri.base.origin}${Uri.base.path}'
    : const String.fromEnvironment('APP_URL');

/// Shown after sign-in until the person is linked with a partner.
class PartnerSetupPage extends StatefulWidget {
  const PartnerSetupPage({
    super.key,
    required this.auth,
    required this.status,
    required this.onChanged,
  });

  final AuthRepository auth;
  final PartnerMissing status;

  /// Reloads the partner status (after inviting, accepting, declining).
  final VoidCallback onChanged;

  @override
  State<PartnerSetupPage> createState() => _PartnerSetupPageState();
}

class _PartnerSetupPageState extends State<PartnerSetupPage>
    with WidgetsBindingObserver {
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _email.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The partner may have accepted while the app was in the background.
    if (state == AppLifecycleState.resumed) {
      widget.onChanged();
    }
  }

  Future<void> _connect({required String email, String? name}) async {
    final who = name == null ? email : '$name ($email)';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Connect with $who?'),
        content: const Text(
          'You fill their tree and they fill yours. You can only be '
          'connected with one person, and this cannot be changed in the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _run(() async {
      await widget.auth.invitePartner(email);
      _email.clear();
    });
  }

  Future<void> _decline(Invitation invitation) =>
      _run(() => widget.auth.declineInvitation(invitation.email));

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      widget.onChanged();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = userMessage(error, 'That did not work'));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _sendEmail(String email) {
    final me = widget.status.me.displayName;
    final link = _appUrl;
    final body = [
      'Hi!',
      '',
      '$me invited you to our Adventskalender: each of us fills 24 pouches on '
          'the other\'s Christmas tree, and every day in December one opens.',
      '',
      if (link.isNotEmpty) 'Open it here: $link',
      'Create an account with this email address ($email), then accept my '
          'invitation and our trees are connected.',
    ].join('\n');
    final uri = Uri.parse(
      'mailto:$email'
      '?subject=${Uri.encodeComponent('$me invited you to an Adventskalender')}'
      '&body=${Uri.encodeComponent(body)}',
    );
    openExternal(context, uri);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = widget.status;
    final invited = status.invitedEmail;
    return Scaffold(
      appBar: AppBar(
        title: Text('Hi ${status.me.displayName}'),
        actions: [
          TextButton(
            onPressed: _busy ? null : widget.auth.signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => widget.onChanged(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Center(
              child: SizedBox(
                width: 80,
                height: 80 * treeAspect,
                child: CustomPaint(painter: TreePainter()),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Connect with your partner',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your tree is filled by one person, and you fill theirs. '
              'Enter your partner\'s email address. Your trees are connected '
              'as soon as they enter yours too.',
            ),
            for (final invitation in status.incoming) ...[
              const SizedBox(height: 16),
              _InvitationCard(
                invitation: invitation,
                busy: _busy,
                onAccept: () =>
                    _connect(email: invitation.email, name: invitation.name),
                onDecline: () => _decline(invitation),
              ),
            ],
            const SizedBox(height: 24),
            if (invited != null) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Riso.paper,
                  border: Border.all(color: Riso.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: risoShadow(color: Riso.yellow, offset: 4),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Waiting for $invited',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'They need an account with exactly this address, '
                        'and to enter your email address as their partner.',
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _sendEmail(invited),
                            icon: const Icon(Icons.mail_outline),
                            label: const Text('Send invitation email'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : widget.onChanged,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Check again'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            TextField(
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: invited == null
                    ? 'Partner\'s email'
                    : 'Invite someone else instead',
              ),
              onSubmitted: (value) => _connect(email: value),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : () => _connect(email: _email.text),
              child: Text(_busy ? 'Please wait…' : 'Connect'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final Invitation invitation;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Riso.paper,
        border: Border.all(color: Riso.ink, width: 1.5),
        borderRadius: BorderRadius.circular(10),
        boxShadow: risoShadow(offset: 4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${invitation.name} wants to connect',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(invitation.email),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton(
                  onPressed: busy ? null : onAccept,
                  child: const Text('Accept'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: busy ? null : onDecline,
                  child: const Text('Decline'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
