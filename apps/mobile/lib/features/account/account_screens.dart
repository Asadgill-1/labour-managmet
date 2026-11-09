import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/settings.dart';
import '../../app/theme.dart';
import '../../data/account.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';

/// Opens a company on this device. [companyName] comes with a company just made, so its first screen need not ask again.
typedef OpenCompany = Future<void> Function(String tenantId, {String? companyName});

String accountProblemText(AppLocalizations l10n, AccountProblem problem) => switch (problem) {
  AccountProblem.offline => l10n.accountOffline,
  AccountProblem.wrongLogin => l10n.accountWrongLogin,
  AccountProblem.notConfirmed => l10n.accountNotConfirmed,
  AccountProblem.exists => l10n.accountExists,
  AccountProblem.weakPassword => l10n.accountPasswordWeak,
  AccountProblem.badCode => l10n.accountBadCode,
  AccountProblem.tooMany => l10n.accountTooMany,
  AccountProblem.deviceRevoked => l10n.accountDeviceRevoked,
  AccountProblem.failed => l10n.accountFailed,
};

/// One step at a time: the main action waits while the server answers, and a refusal is said plainly (UX-04).
mixin _Step<T extends StatefulWidget> on State<T> {
  bool busy = false;

  Future<void> attempt(Future<void> Function() work) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await work();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      showFormError(context, e is AccountRefused ? accountProblemText(l10n, e.problem) : l10n.accountFailed);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void push(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
}

/// After any sign-in: the user's company opens, or, with none yet, they name it (UX-02).
Future<void> _afterSignIn(BuildContext context, Account account, OpenCompany onOpen) async {
  final tenantId = await account.openCompany();
  if (tenantId != null) return onOpen(tenantId);
  if (context.mounted) await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CompanyNameScreen(account: account, onOpen: onOpen)));
}

Future<void> _say(BuildContext context, String text) => showDialog<void>(
  context: context,
  builder: (dialog) => AlertDialog(
    content: Text(text),
    actions: [TextButton(onPressed: () => Navigator.of(dialog).pop(), child: Text(AppLocalizations.of(dialog).accountOk))],
  ),
);

String? _emailError(AppLocalizations l10n, String? v) => isEmail(v ?? '') ? null : l10n.accountEmailInvalid;

String? _newPasswordError(AppLocalizations l10n, String? v) => isStrongPassword(v ?? '') ? null : l10n.accountPasswordWeak;

/// The first screen on a device with no company open: log in, or start an account. The language comes first (UX-02).
class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.account, required this.onOpen, super.key});

  final Account account;
  final OpenCompany onOpen;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with _Step {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _phoneData = false;

  @override
  void initState() {
    super.initState();
    widget.account.hasPhoneData().then((v) {
      if (mounted) setState(() => _phoneData = v);
    });
  }

  Future<void> _login() async {
    if (!validateAndReveal(_form)) return;
    final email = _email.text.trim();
    await attempt(() async {
      try {
        await widget.account.signIn(email, _password.text);
      } on AccountRefused catch (e) {
        if (e.problem != AccountProblem.notConfirmed) rethrow;
        // Signed up but never confirmed the email: send it again and ask for the confirmation.
        await widget.account.resendSignup(email);
        push(CodeScreen(account: widget.account, onOpen: widget.onOpen, email: email, password: _password.text));
        return;
      }
      if (mounted) await _afterSignIn(context, widget.account, widget.onOpen);
    });
  }

  Future<void> _forgot() async {
    final l10n = AppLocalizations.of(context);
    if (!widget.account.emailCodes) return _say(context, l10n.accountResetUnavailable);
    final email = _email.text.trim();
    if (!isEmail(email)) return showFormError(context, l10n.accountEmailInvalid);
    await attempt(() async {
      await widget.account.sendReset(email);
      push(CodeScreen(account: widget.account, onOpen: widget.onOpen, email: email));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _StepScaffold(
      title: l10n.accountLoginTitle,
      busy: busy,
      action: MainActionBar(label: l10n.accountLogin, onPressed: busy ? null : _login),
      language: true,
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: FormBody(
            children: [
              Text(l10n.accountIntro),
              fieldGap,
              Field(
                l10n.accountEmail,
                _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: (v) => _emailError(l10n, v),
              ),
              fieldGap,
              _PasswordField(
                l10n.accountPassword,
                _password,
                autofillHints: const [AutofillHints.password],
                validator: (v) => (v ?? '').isEmpty ? l10n.fieldRequired : null,
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(onPressed: busy ? null : _forgot, child: Text(l10n.accountForgot)),
              ),
              if (_phoneData) ...[_Note(l10n.accountPhoneData), fieldGap],
              fieldGap,
              OutlinedButton(
                onPressed: busy ? null : () => push(SignupScreen(account: widget.account, onOpen: widget.onOpen)),
                child: Text(l10n.accountCreate),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({required this.account, required this.onOpen, super.key});

  final Account account;
  final OpenCompany onOpen;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with _Step {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  Future<void> _signUp() async {
    if (!validateAndReveal(_form)) return;
    final email = _email.text.trim();
    await attempt(() async {
      await widget.account.signUp(email, _password.text);
      push(CodeScreen(account: widget.account, onOpen: widget.onOpen, email: email, password: _password.text));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _StepScaffold(
      title: l10n.accountSignupTitle,
      busy: busy,
      action: MainActionBar(label: l10n.accountSignup, onPressed: busy ? null : _signUp),
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: FormBody(
            children: [
              Text(l10n.accountSignupIntro),
              fieldGap,
              Field(
                l10n.accountEmail,
                _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: (v) => _emailError(l10n, v),
              ),
              fieldGap,
              _PasswordField(
                l10n.accountPassword,
                _password,
                helper: l10n.accountPasswordHelp,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) => _newPasswordError(l10n, v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirms a new account's email, by the code in it or, from Supabase's own sender, its link. Without a [password]
/// it replaces a forgotten one with the code (AUTH-01).
class CodeScreen extends StatefulWidget {
  const CodeScreen({required this.account, required this.onOpen, required this.email, this.password, super.key});

  final Account account;
  final OpenCompany onOpen;
  final String email;

  /// The password just typed, to sign in once the email's link was tapped. Null when resetting a password.
  final String? password;

  bool get recovery => password == null;

  /// The email carries a code to type; otherwise only a link.
  bool get code => account.emailCodes;

  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<CodeScreen> with _Step {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();

  Future<void> _continue() async {
    if (!validateAndReveal(_form)) return;
    final code = _code.text.trim();
    await attempt(() async {
      if (widget.recovery) {
        await widget.account.resetPassword(widget.email, code, _password.text);
      } else if (widget.code) {
        await widget.account.confirmSignup(widget.email, code);
      } else {
        // The link confirmed the email in the browser; signing in shows whether it was tapped.
        await widget.account.signIn(widget.email, widget.password!);
      }
      if (mounted) await _afterSignIn(context, widget.account, widget.onOpen);
    });
  }

  Future<void> _resend() => attempt(() async {
    widget.recovery ? await widget.account.sendReset(widget.email) : await widget.account.resendSignup(widget.email);
    if (mounted) showSavedOnPhone(context, AppLocalizations.of(context).accountResent);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _StepScaffold(
      title: widget.code ? l10n.accountCodeTitle : l10n.accountSignupTitle,
      busy: busy,
      action: MainActionBar(label: widget.recovery ? l10n.accountSetPassword : l10n.accountContinue, onPressed: busy ? null : _continue),
      child: Form(
        key: _form,
        child: FormBody(
          children: [
            Text(widget.code ? l10n.accountCodeSent(widget.email) : l10n.accountLinkSent(widget.email)),
            if (widget.code) ...[
              fieldGap,
              Field(
                l10n.accountCode,
                _code,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                validator: (v) => isEmailCode(v ?? '') ? null : l10n.accountCodeInvalid,
              ),
            ],
            if (widget.recovery) ...[
              fieldGap,
              _PasswordField(
                l10n.accountNewPassword,
                _password,
                helper: l10n.accountPasswordHelp,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) => _newPasswordError(l10n, v),
              ),
            ],
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(onPressed: busy ? null : _resend, child: Text(l10n.accountResend)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The company's name, the last online step before its books open (UX-02).
class CompanyNameScreen extends StatefulWidget {
  const CompanyNameScreen({required this.account, required this.onOpen, super.key});

  final Account account;
  final OpenCompany onOpen;

  @override
  State<CompanyNameScreen> createState() => _CompanyNameScreenState();
}

class _CompanyNameScreenState extends State<CompanyNameScreen> with _Step {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _operationId = newUuid();

  Future<void> _start() async {
    if (!validateAndReveal(_form)) return;
    final name = _name.text.trim();
    await attempt(() async => widget.onOpen(await widget.account.createCompany(name, _operationId), companyName: name));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _StepScaffold(
      title: l10n.welcomeTitle,
      busy: busy,
      action: MainActionBar(label: l10n.accountStart, onPressed: busy ? null : _start),
      child: Form(
        key: _form,
        child: FormBody(
          children: [
            Text(l10n.welcomeBody),
            fieldGap,
            Field(l10n.legalName, _name, validator: (v) => (v ?? '').trim().isEmpty ? l10n.fieldRequired : null),
          ],
        ),
      ),
    );
  }
}

/// The frame every account step shares: the cover's header, a page, and the one action at thumb height.
class _StepScaffold extends StatelessWidget {
  const _StepScaffold({required this.title, required this.busy, required this.action, required this.child, this.language = false});

  final String title;
  final bool busy;
  final Widget action;
  final Widget child;

  /// Offers the other language on the header, so it can be chosen before anything else.
  final bool language;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [if (language) const _LanguageButton()],
        bottom: busy ? const PreferredSize(preferredSize: Size.fromHeight(3), child: LinearProgressIndicator(minHeight: 3)) : null,
      ),
      bottomNavigationBar: action,
      body: child,
    );
  }
}

class _LanguageButton extends ConsumerWidget {
  const _LanguageButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final urdu = ref.watch(settingsProvider).locale == romanUrdu;
    return BarButton(
      urdu ? l10n.languageEnglish : l10n.languageRomanUrdu,
      onPressed: () => ref.read(settingsProvider.notifier).setLocale(urdu ? english : romanUrdu),
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField(this.label, this.controller, {required this.validator, required this.autofillHints, this.helper});

  final String label;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final Iterable<String> autofillHints;
  final String? helper;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  var _hidden = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      obscureText: _hidden,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      autofillHints: widget.autofillHints,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper,
        helperMaxLines: 3,
        errorMaxLines: 3,
        suffixIcon: IconButton(
          tooltip: _hidden ? l10n.accountShowPassword : l10n.accountHidePassword,
          icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      ),
    );
  }
}

/// A plain remark on the page, set off by a rule at its start like a margin note in a book.
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 12, top: 2, bottom: 2),
      decoration: const BoxDecoration(border: BorderDirectional(start: BorderSide(color: fieldEdge, width: 3))),
      child: Text(text, style: const TextStyle(fontSize: 14.5, height: 1.4, color: muted)),
    );
  }
}
