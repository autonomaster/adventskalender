import 'package:flutter/material.dart';

import '../../core/data/auth_repository.dart';
import '../../ui/advent_tree.dart';

enum _Mode {
  signIn,
  signUp,

  /// Enter the code from the confirmation email.
  confirm,

  /// Ask for a password reset code.
  forgot,

  /// Enter the reset code and a new password.
  reset,
}

const _minPasswordLength = 8;

class SignInPage extends StatefulWidget {
  const SignInPage({super.key, required this.auth, this.hint});

  final AuthRepository auth;
  final String? hint;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  void _go(_Mode mode, {String? info}) {
    setState(() {
      _mode = mode;
      _error = null;
      _info = info;
      _code.clear();
      if (mode == _Mode.reset) {
        _password.clear();
      }
    });
  }

  String get _emailText => _email.text.trim();

  /// Runs [action] with the busy state and error display.
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on EmailNotConfirmed {
      await widget.auth.resendSignUpCode(_emailText);
      if (mounted) {
        _go(_Mode.confirm, info: _codeSentText());
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = userMessage(error, 'That did not work');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _codeSentText() =>
      'We emailed a code to $_emailText. It can take a minute; check your '
      'spam folder too.';

  String? _validate() {
    if (!_emailText.contains('@')) {
      return 'Enter your email address.';
    }
    final needsPassword = _mode == _Mode.signUp || _mode == _Mode.reset;
    if (_mode == _Mode.signUp && _name.text.trim().isEmpty) {
      return 'Enter your name.';
    }
    if (needsPassword && _password.text.length < _minPasswordLength) {
      return 'Use at least $_minPasswordLength characters for the password.';
    }
    if ((_mode == _Mode.confirm || _mode == _Mode.reset) &&
        _code.text.trim().isEmpty) {
      return 'Enter the code from the email.';
    }
    return null;
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final auth = widget.auth;
    switch (_mode) {
      case _Mode.signIn:
        await _run(
          () => auth.signIn(email: _emailText, password: _password.text),
        );
      case _Mode.signUp:
        await _run(() async {
          final signedIn = await auth.signUp(
            email: _emailText,
            password: _password.text,
            displayName: _name.text,
          );
          if (!signedIn && mounted) {
            _go(_Mode.confirm, info: _codeSentText());
          }
        });
      case _Mode.confirm:
        await _run(
          () => auth.confirmSignUp(email: _emailText, code: _code.text),
        );
      case _Mode.forgot:
        await _run(() async {
          await auth.sendPasswordResetCode(_emailText);
          if (mounted) {
            _go(_Mode.reset, info: _codeSentText());
          }
        });
      case _Mode.reset:
        await _run(
          () => auth.resetPassword(
            email: _emailText,
            code: _code.text,
            newPassword: _password.text,
          ),
        );
    }
  }

  Future<void> _resendCode() => _run(() async {
    if (_mode == _Mode.reset) {
      await widget.auth.sendPasswordResetCode(_emailText);
    } else {
      await widget.auth.resendSignUpCode(_emailText);
    }
    if (mounted) {
      setState(() => _info = 'New code sent to $_emailText.');
    }
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = _mode;
    final showName = mode == _Mode.signUp;
    final showPassword = mode != _Mode.confirm && mode != _Mode.forgot;
    final showCode = mode == _Mode.confirm || mode == _Mode.reset;
    final (heading, button) = switch (mode) {
      _Mode.signIn => (null, 'Sign in'),
      _Mode.signUp => ('Create an account', 'Create account'),
      _Mode.confirm => ('Confirm your email', 'Confirm'),
      _Mode.forgot => ('Forgot your password?', 'Send code'),
      _Mode.reset => ('Choose a new password', 'Save new password'),
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: SizedBox(
                        width: 110,
                        height: 110 * treeAspect,
                        child: CustomPaint(painter: TreePainter()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Adventskalender',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    if (heading != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        heading,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    if (showName) ...[
                      TextField(
                        controller: _name,
                        enabled: !_busy,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.givenName],
                        decoration: const InputDecoration(
                          labelText: 'Your name',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _email,
                      enabled: !_busy && !showCode,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    if (showCode) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _code,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        decoration: const InputDecoration(
                          labelText: 'Code from the email',
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                    ],
                    if (showPassword) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        enabled: !_busy,
                        obscureText: true,
                        autofillHints: [
                          mode == _Mode.signIn
                              ? AutofillHints.password
                              : AutofillHints.newPassword,
                        ],
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: mode == _Mode.reset
                              ? 'New password'
                              : 'Password',
                          helperText: mode == _Mode.signIn
                              ? null
                              : 'At least $_minPasswordLength characters',
                        ),
                      ),
                    ],
                    if (_info != null) ...[
                      const SizedBox(height: 12),
                      Text(_info!),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(_busy ? 'Please wait…' : button),
                    ),
                    const SizedBox(height: 8),
                    ..._links(mode),
                    if (widget.hint != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        widget.hint!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _links(_Mode mode) {
    Widget link(String label, VoidCallback onPressed) =>
        TextButton(onPressed: _busy ? null : onPressed, child: Text(label));
    return switch (mode) {
      _Mode.signIn => [
        link('New here? Create an account', () => _go(_Mode.signUp)),
        link('Forgot password?', () => _go(_Mode.forgot)),
      ],
      _Mode.signUp => [
        link('I already have an account', () => _go(_Mode.signIn)),
      ],
      _Mode.confirm || _Mode.reset => [
        link('Send a new code', _resendCode),
        link('Back to sign-in', () => _go(_Mode.signIn)),
      ],
      _Mode.forgot => [link('Back to sign-in', () => _go(_Mode.signIn))],
    };
  }
}
