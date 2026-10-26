import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme.dart';

/// Transição suave para a tela de autenticação
Route authRoute({bool signup = false}) => PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => AuthScreen(startSignup: signup),
      transitionsBuilder: (_, anim, __, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

class AuthScreen extends StatefulWidget {
  final bool startSignup;
  const AuthScreen({super.key, this.startSignup = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _signup = widget.startSignup;
  bool _loading = false;

  // Entrar
  final _loginKey = GlobalKey<FormState>();
  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();
  bool _hideLoginPass = true;

  // Criar conta
  final _signupKey = GlobalKey<FormState>();
  final _suUser = TextEditingController();
  final _suEmail = TextEditingController();
  final _suPass = TextEditingController();
  final _suPass2 = TextEditingController();
  final _suBirth = TextEditingController();
  bool _hideSuPass = true;
  bool _hideSuPass2 = true;
  bool _terms = false;
  DateTime? _birth;
  int _passScore = 0;

  @override
  void dispose() {
    _loginEmail.dispose();
    _loginPass.dispose();
    _suUser.dispose();
    _suEmail.dispose();
    _suPass.dispose();
    _suPass2.dispose();
    _suBirth.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // Validações
  // ----------------------------------------------------------
  static final _emailRx = RegExp(r'^[\w\.\-+]+@[\w\-]+(\.[\w\-]+)+$');

  String? _vEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe seu e-mail.';
    if (!_emailRx.hasMatch(v.trim())) return 'E-mail inválido.';
    return null;
  }

  String? _vUser(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Escolha um nome de usuário.';
    if (t.length < 3) return 'Mínimo de 3 caracteres.';
    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(t)) {
      return 'Use apenas letras, números, ponto e _';
    }
    return null;
  }

  String? _vPass(String? v) {
    if (v == null || v.isEmpty) return 'Crie uma senha.';
    if (v.length < 8) return 'A senha precisa de pelo menos 8 caracteres.';
    return null;
  }

  int _score(String s) {
    var sc = 0;
    if (s.length >= 8) sc++;
    if (s.length >= 12) sc++;
    if (RegExp(r'[A-Z]').hasMatch(s) && RegExp(r'[a-z]').hasMatch(s)) sc++;
    if (RegExp(r'[0-9]').hasMatch(s) && RegExp(r'[^A-Za-z0-9]').hasMatch(s)) {
      sc++;
    }
    return sc;
  }

  // ----------------------------------------------------------
  // Ações
  // ----------------------------------------------------------
  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF17171B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF26262B)),
        ),
        content: Text(
          msg,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14.5),
        ),
      ),
    );
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Data de nascimento',
      cancelText: 'Cancelar',
      confirmText: 'OK',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: NimoColors.blue,
            surface: Color(0xFF131317),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _birth = picked;
        _suBirth.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_signup) {
      final ok = _signupKey.currentState?.validate() ?? false;
      if (!ok) return;
      if (_birth == null) {
        _snack('Informe sua data de nascimento.');
        return;
      }
      final age = DateTime.now().difference(_birth!).inDays ~/ 365;
      if (age < 13) {
        _snack('É preciso ter pelo menos 13 anos para usar o Nimo.');
        return;
      }
      if (!_terms) {
        _snack('Aceite os Termos de Serviço para continuar.');
        return;
      }
    } else {
      final ok = _loginKey.currentState?.validate() ?? false;
      if (!ok) return;
    }

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _loading = false);
    _snack(_signup
        ? 'Tudo certo por aqui! Os servidores do Nimo serão ligados em breve.'
        : 'Os servidores do Nimo serão ligados em breve. Fique de olho!');
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NimoColors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _logoHeader(),
                      const SizedBox(height: 28),
                      _modeToggle(),
                      const SizedBox(height: 26),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, 0.04),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: _signup
                            ? _signupForm(key: const ValueKey('signup'))
                            : _loginForm(key: const ValueKey('login')),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Nimo • v0.1.0',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: NimoColors.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Voltar
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoHeader() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.asset(
            'assets/logo-icon.png',
            width: 84,
            height: 84,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            _signup ? 'Crie sua conta' : 'Bem-vindo(a) de volta!',
            key: ValueKey(_signup),
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _signup
              ? 'Rápido e grátis. Entre para a comunidade Nimo.'
              : 'Que bom te ver por aqui de novo!',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14.5,
            color: NimoColors.textMuted,
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 350.ms)
        .slideY(begin: -0.1, duration: 400.ms, curve: Curves.easeOutCubic);
  }

  Widget _modeToggle() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: NimoColors.field,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1D1D22)),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment:
                _signup ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: NimoColors.blue,
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ),
          Row(
            children: [
              _toggleItem('Entrar', !_signup, () {
                setState(() => _signup = false);
              }),
              _toggleItem('Criar conta', _signup, () {
                setState(() => _signup = true);
              }),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms, delay: 80.ms);
  }

  Widget _toggleItem(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : NimoColors.textMuted,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // Formulário: Entrar
  // ----------------------------------------------------------
  Widget _loginForm({Key? key}) {
    return Form(
      key: _loginKey,
      child: Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('E-mail'),
          _input(
            controller: _loginEmail,
            hint: 'voce@exemplo.com',
            keyboard: TextInputType.emailAddress,
            validator: _vEmail,
          ),
          const SizedBox(height: 18),
          _label('Senha'),
          _input(
            controller: _loginPass,
            hint: 'Sua senha',
            obscure: _hideLoginPass,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Informe sua senha.' : null,
            suffix: _eye(
              _hideLoginPass,
              () => setState(() => _hideLoginPass = !_hideLoginPass),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => _snack(
                  'A recuperação de senha chega junto com o lançamento.'),
              child: Text(
                'Esqueceu sua senha?',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: NimoColors.blueBright,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          _primaryButton('Entrar'),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Novo por aqui?  ',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: NimoColors.textMuted,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _signup = true),
                child: Text(
                  'Crie uma conta',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: NimoColors.blueBright,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // Formulário: Criar conta
  // ----------------------------------------------------------
  Widget _signupForm({Key? key}) {
    return Form(
      key: _signupKey,
      child: Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('Nome de usuário'),
          _input(
            controller: _suUser,
            hint: 'ex.: joao.silva',
            validator: _vUser,
          ),
          const SizedBox(height: 18),
          _label('E-mail'),
          _input(
            controller: _suEmail,
            hint: 'voce@exemplo.com',
            keyboard: TextInputType.emailAddress,
            validator: _vEmail,
          ),
          const SizedBox(height: 18),
          _label('Senha'),
          _input(
            controller: _suPass,
            hint: 'Mínimo de 8 caracteres',
            obscure: _hideSuPass,
            validator: _vPass,
            onChanged: (v) => setState(() => _passScore = _score(v)),
            suffix: _eye(
              _hideSuPass,
              () => setState(() => _hideSuPass = !_hideSuPass),
            ),
          ),
          if (_suPass.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            _strengthBar(),
          ],
          const SizedBox(height: 18),
          _label('Confirmar senha'),
          _input(
            controller: _suPass2,
            hint: 'Repita a senha',
            obscure: _hideSuPass2,
            validator: (v) =>
                v != _suPass.text ? 'As senhas não coincidem.' : null,
            suffix: _eye(
              _hideSuPass2,
              () => setState(() => _hideSuPass2 = !_hideSuPass2),
            ),
          ),
          const SizedBox(height: 18),
          _label('Data de nascimento'),
          GestureDetector(
            onTap: _pickBirth,
            child: AbsorbPointer(
              child: _input(
                controller: _suBirth,
                hint: 'dd/mm/aaaa',
                suffix: const Icon(
                  Icons.calendar_today_outlined,
                  size: 19,
                  color: NimoColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _termsRow(),
          const SizedBox(height: 22),
          _primaryButton('Criar conta'),
          const SizedBox(height: 14),
          Text(
            'Enviaremos um e-mail para confirmar sua conta.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: NimoColors.textFaint,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // Peças reutilizáveis
  // ----------------------------------------------------------
  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: NimoColors.textMuted,
        ),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    String? hint,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboard,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      validator: validator,
      onChanged: onChanged,
      cursorColor: NimoColors.blueBright,
      style: GoogleFonts.inter(fontSize: 15.5, color: NimoColors.textNormal),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.inter(fontSize: 15, color: NimoColors.textFaint),
        filled: true,
        fillColor: NimoColors.field,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        enabledBorder: border(const Color(0xFF1D1D22)),
        focusedBorder: border(NimoColors.blue, 1.4),
        errorBorder: border(NimoColors.red),
        focusedErrorBorder: border(NimoColors.red, 1.4),
        errorStyle: GoogleFonts.inter(
          fontSize: 12.5,
          color: NimoColors.red,
        ),
        suffixIcon: suffix,
      ),
    );
  }

  Widget _eye(bool hidden, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
        color: NimoColors.textMuted,
      ),
    );
  }

  Widget _strengthBar() {
    final labels = ['Muito fraca', 'Fraca', 'Boa', 'Forte', 'Excelente'];
    final colors = [
      NimoColors.red,
      const Color(0xFFF0883E),
      NimoColors.yellow,
      NimoColors.green,
      NimoColors.greenLight,
    ];
    final idx = _passScore.clamp(0, 4);

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 6,
              color: const Color(0xFF1B1B20),
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                widthFactor: (idx + 1) / 5,
                child: Container(color: colors[idx]),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          labels[idx],
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors[idx],
          ),
        ),
      ],
    );
  }

  Widget _termsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _terms,
            onChanged: (v) => setState(() => _terms = v ?? false),
            activeColor: NimoColors.blue,
            side: const BorderSide(color: Color(0xFF3A3A42), width: 1.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _terms = !_terms),
            child: Text.rich(
              TextSpan(
                text: 'Li e aceito os ',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: NimoColors.textMuted,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: 'Termos de Serviço',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: NimoColors.blueBright,
                    ),
                  ),
                  const TextSpan(text: ' e a '),
                  TextSpan(
                    text: 'Política de Privacidade',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: NimoColors.blueBright,
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _primaryButton(String label) {
    return GestureDetector(
      onTap: _loading ? null : _submit,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 54,
        decoration: BoxDecoration(
          color: _loading
              ? NimoColors.blue.withOpacity(0.6)
              : NimoColors.blue,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
