import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

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

/// Converte texto para minúsculas enquanto digita (nome único)
class _LowerCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toLowerCase());
}

class AuthScreen extends StatefulWidget {
  final bool startSignup;

  /// true quando a tela abre direto pelo subdomínio de login
  final bool standalone;

  const AuthScreen({
    super.key,
    this.startSignup = false,
    this.standalone = false,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _signup = widget.startSignup;
  int _step = 0; // etapa do cadastro (0..3)
  bool _forward = true; // direção da animação entre etapas
  bool _loading = false;

  static const _totalSteps = 4;

  // Entrar
  final _loginKey = GlobalKey<FormState>();
  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();
  bool _hideLoginPass = true;

  // Etapa 1 — e-mail e senha
  final _stepKeys =
      List.generate(_totalSteps, (_) => GlobalKey<FormState>());
  final _suEmail = TextEditingController();
  final _suPass = TextEditingController();
  final _suPass2 = TextEditingController();
  bool _hideSuPass = true;
  bool _hideSuPass2 = true;
  int _passScore = 0;

  // Etapa 2 — nome e nome único
  final _suName = TextEditingController();
  final _suUser = TextEditingController();

  // Etapa 3 — foto e banner (opcionais)
  final _picker = ImagePicker();
  Uint8List? _avatarBytes;
  Uint8List? _bannerBytes;

  // Etapa 4 — nascimento e país
  final _suBirth = TextEditingController();
  DateTime? _birth;
  String? _country;
  bool _terms = false;

  @override
  void dispose() {
    _loginEmail.dispose();
    _loginPass.dispose();
    _suEmail.dispose();
    _suPass.dispose();
    _suPass2.dispose();
    _suName.dispose();
    _suUser.dispose();
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
    if (t.isEmpty) return 'Escolha seu nome único.';
    if (t.length < 3) return 'Mínimo de 3 caracteres.';
    if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(t)) {
      return 'Use apenas letras minúsculas, números, ponto e _';
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

  Future<void> _pickImage(bool banner) async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: banner ? 1600 : 800,
        imageQuality: 88,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        if (banner) {
          _bannerBytes = bytes;
        } else {
          _avatarBytes = bytes;
        }
      });
    } catch (_) {
      _snack('Não foi possível abrir a galeria neste dispositivo.');
    }
  }

  void _goStep(int next) {
    setState(() {
      _forward = next > _step;
      _step = next;
    });
  }

  void _continue() {
    FocusScope.of(context).unfocus();

    // valida apenas a etapa atual
    final ok = _stepKeys[_step].currentState?.validate() ?? true;
    if (!ok) return;

    if (_step == 3) {
      _submitSignup();
      return;
    }
    _goStep(_step + 1);
  }

  Future<void> _submitSignup() async {
    if (_birth == null) {
      _snack('Informe sua data de nascimento.');
      return;
    }
    final age = DateTime.now().difference(_birth!).inDays ~/ 365;
    if (age < 13) {
      _snack('É preciso ter pelo menos 13 anos para usar o Nimo.');
      return;
    }
    if (_country == null) {
      _snack('Selecione o seu país.');
      return;
    }
    if (!_terms) {
      _snack('Aceite os Termos de Serviço para continuar.');
      return;
    }

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _loading = false);
    _snack(
        'Tudo certo por aqui! Os servidores do Nimo serão ligados em breve.');
  }

  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();
    final ok = _loginKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _loading = false);
    _snack('Os servidores do Nimo serão ligados em breve. Fique de olho!');
  }

  void _handleBack() {
    if (_signup && _step > 0) {
      _goStep(_step - 1);
      return;
    }
    if (!widget.standalone) {
      Navigator.of(context).maybePop();
    }
  }

  bool get _showBackButton =>
      !widget.standalone || (_signup && _step > 0);

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final inWizard = _signup && _step > 0;

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
                      const SizedBox(height: 26),
                      if (!inWizard) ...[
                        _modeToggle(),
                        const SizedBox(height: 26),
                      ],
                      if (_signup) ...[
                        _progressHeader(),
                        const SizedBox(height: 22),
                      ],
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween(
                              begin: Offset(_forward ? 0.06 : -0.06, 0),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: _signup
                            ? KeyedSubtree(
                                key: ValueKey('step$_step'),
                                child: _stepBody(),
                              )
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
            if (_showBackButton)
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  onPressed: _handleBack,
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

  // ----------------------------------------------------------
  // Cabeçalho (logo maior + título por etapa)
  // ----------------------------------------------------------
  String get _title {
    if (!_signup) return 'Bem-vindo(a) de volta!';
    switch (_step) {
      case 0:
        return 'Crie sua conta';
      case 1:
        return 'Como podemos te chamar?';
      case 2:
        return 'Deixe o perfil com a sua cara';
      default:
        return 'Quase lá!';
    }
  }

  String get _subtitle {
    if (!_signup) return 'Que bom te ver por aqui de novo!';
    switch (_step) {
      case 0:
        return 'Primeiro, seu e-mail e uma senha segura.';
      case 1:
        return 'Seu nome único é só seu — ninguém mais pode usar.';
      case 2:
        return 'Foto de perfil e banner são opcionais. Dá para pular.';
      default:
        return 'Só mais alguns detalhes e está feito.';
    }
  }

  Widget _logoHeader() {
    final inWizard = _signup && _step > 0;
    final size = inWizard ? 88.0 : 132.0;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(inWizard ? 22 : 30),
            boxShadow: [
              BoxShadow(
                color: NimoColors.blue.withOpacity(0.28),
                blurRadius: 42,
                spreadRadius: 2,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/logo-icon.png',
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            _title,
            key: ValueKey('$_signup-$_step-t'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            _subtitle,
            key: ValueKey('$_signup-$_step-s'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14.5,
              color: NimoColors.textMuted,
            ),
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
                setState(() {
                  _signup = false;
                  _step = 0;
                });
              }),
              _toggleItem('Criar conta', _signup, () {
                setState(() {
                  _signup = true;
                  _step = 0;
                });
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
  // Progresso do cadastro
  // ----------------------------------------------------------
  Widget _progressHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ETAPA ${_step + 1} DE $_totalSteps',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: NimoColors.textMuted,
              ),
            ),
            Text(
              const [
                'Acesso',
                'Identidade',
                'Aparência',
                'Finalizar'
              ][_step],
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: NimoColors.blueBright,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(_totalSteps, (i) {
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                height: 5,
                margin: EdgeInsets.only(
                    right: i == _totalSteps - 1 ? 0 : 6),
                decoration: BoxDecoration(
                  color: i <= _step
                      ? NimoColors.blue
                      : const Color(0xFF1B1B20),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
      ],
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
          _primaryButton('Entrar', _submitLogin),
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
                onTap: () => setState(() {
                  _signup = true;
                  _step = 0;
                }),
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
  // Etapas do cadastro
  // ----------------------------------------------------------
  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _stepCredentials();
      case 1:
        return _stepIdentity();
      case 2:
        return _stepAppearance();
      default:
        return _stepFinish();
    }
  }

  /// Etapa 1 — e-mail e senha
  Widget _stepCredentials() {
    return Form(
      key: _stepKeys[0],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 24),
          _primaryButton('Continuar', _continue),
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

  /// Etapa 2 — nome de exibição e nome único
  Widget _stepIdentity() {
    return Form(
      key: _stepKeys[1],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('Nome de exibição  •  opcional'),
          _input(
            controller: _suName,
            hint: 'Como você quer aparecer para os outros',
          ),
          const SizedBox(height: 18),
          _label('Nome único'),
          _input(
            controller: _suUser,
            hint: 'seu_nome_unico',
            prefixText: '@',
            validator: _vUser,
            formatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.]')),
              _LowerCaseFormatter(),
            ],
          ),
          const SizedBox(height: 14),
          _infoCard(
            icon: Icons.badge_outlined,
            text:
                'O nome único identifica você no Nimo e só pode ser alterado a cada 7 dias. O nome de exibição você muda quando quiser, direto no seu perfil.',
          ),
          const SizedBox(height: 24),
          _primaryButton('Continuar', _continue),
        ],
      ),
    );
  }

  /// Etapa 3 — foto de perfil e banner (opcionais)
  Widget _stepAppearance() {
    return Form(
      key: _stepKeys[2],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('Banner do perfil  •  opcional'),
          _bannerPicker(),
          const SizedBox(height: 20),
          _label('Foto de perfil  •  opcional'),
          _avatarPicker(),
          const SizedBox(height: 24),
          _primaryButton('Continuar', _continue),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _avatarBytes = null;
                  _bannerBytes = null;
                });
                _goStep(3);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                child: Text(
                  'Pular por enquanto',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: NimoColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerPicker() {
    return GestureDetector(
      onTap: () => _pickImage(true),
      child: Container(
        height: 110,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: NimoColors.field,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1D1D22)),
        ),
        child: _bannerBytes != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(_bannerBytes!, fit: BoxFit.cover),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _removeBadge(
                        () => setState(() => _bannerBytes = null)),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.panorama_outlined,
                    size: 28,
                    color: NimoColors.textMuted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Adicionar banner',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: NimoColors.textMuted,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _avatarPicker() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => _pickImage(false),
          child: Container(
            width: 92,
            height: 92,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: NimoColors.field,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1D1D22)),
            ),
            child: _avatarBytes != null
                ? Image.memory(_avatarBytes!, fit: BoxFit.cover)
                : const Icon(
                    Icons.add_a_photo_outlined,
                    size: 26,
                    color: NimoColors.textMuted,
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _avatarBytes != null
                    ? 'Boa escolha!'
                    : 'Escolha uma foto sua',
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Você pode trocar a foto e o banner a qualquer momento no seu perfil.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: NimoColors.textMuted,
                  height: 1.4,
                ),
              ),
              if (_avatarBytes != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _avatarBytes = null),
                  child: Text(
                    'Remover foto',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: NimoColors.red,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _removeBadge(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, size: 17, color: Colors.white),
      ),
    );
  }

  /// Etapa 4 — data de nascimento e país
  Widget _stepFinish() {
    return Form(
      key: _stepKeys[3],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('Data de nascimento'),
          GestureDetector(
            onTap: _pickBirth,
            child: AbsorbPointer(
              child: _input(
                controller: _suBirth,
                hint: 'dd/mm/aaaa',
                validator: (_) =>
                    _birth == null ? 'Informe sua data de nascimento.' : null,
                suffix: const Icon(
                  Icons.calendar_today_outlined,
                  size: 19,
                  color: NimoColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _label('País'),
          GestureDetector(
            onTap: _pickCountry,
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: NimoColors.field,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1D1D22)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.public,
                    size: 20,
                    color: NimoColors.textMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _country ?? 'Selecione o seu país',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: _country != null
                            ? NimoColors.textNormal
                            : NimoColors.textFaint,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: NimoColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _termsRow(),
          const SizedBox(height: 22),
          _primaryButton('Criar conta', _continue),
        ],
      ),
    );
  }

  static const _countries = [
    'Brasil',
    'Portugal',
    'Alemanha',
    'Angola',
    'Argentina',
    'Austrália',
    'Áustria',
    'Bélgica',
    'Bolívia',
    'Cabo Verde',
    'Canadá',
    'Chile',
    'China',
    'Colômbia',
    'Coreia do Sul',
    'Costa Rica',
    'Cuba',
    'Dinamarca',
    'Egito',
    'Emirados Árabes Unidos',
    'Equador',
    'Espanha',
    'Estados Unidos',
    'Filipinas',
    'Finlândia',
    'França',
    'Grécia',
    'Guiné-Bissau',
    'Holanda (Países Baixos)',
    'Índia',
    'Indonésia',
    'Irlanda',
    'Israel',
    'Itália',
    'Japão',
    'México',
    'Moçambique',
    'Noruega',
    'Nova Zelândia',
    'Panamá',
    'Paraguai',
    'Peru',
    'Polônia',
    'Reino Unido',
    'República Dominicana',
    'Romênia',
    'Rússia',
    'São Tomé e Príncipe',
    'Suécia',
    'Suíça',
    'Tailândia',
    'Timor-Leste',
    'Turquia',
    'Ucrânia',
    'Uruguai',
    'Venezuela',
    'Vietnã',
    'Outro país',
  ];

  Future<void> _pickCountry() async {
    FocusScope.of(context).unfocus();
    final searchCtrl = TextEditingController();

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF101014),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final q = searchCtrl.text.trim().toLowerCase();
            final list = q.isEmpty
                ? _countries
                : _countries
                    .where((c) => c.toLowerCase().contains(q))
                    .toList();
            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.72,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A30),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: TextField(
                      controller: searchCtrl,
                      autofocus: false,
                      onChanged: (_) => setSheet(() {}),
                      cursorColor: NimoColors.blueBright,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: NimoColors.textNormal,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Buscar país',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 15,
                          color: NimoColors.textFaint,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 20,
                          color: NimoColors.textMuted,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF17171B),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final c = list[i];
                        final active = c == _country;
                        return ListTile(
                          onTap: () => Navigator.of(ctx).pop(c),
                          leading: Icon(
                            active
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 20,
                            color: active
                                ? NimoColors.blueBright
                                : NimoColors.textFaint,
                          ),
                          title: Text(
                            c,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: active
                                  ? Colors.white
                                  : NimoColors.textNormal,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    searchCtrl.dispose();
    if (selected != null) {
      setState(() => _country = selected);
    }
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

  Widget _infoCard({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NimoColors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NimoColors.blue.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: NimoColors.blueBright),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: NimoColors.textNormal,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    String? hint,
    String? prefixText,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboard,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    List<TextInputFormatter>? formatters,
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
      inputFormatters: formatters,
      cursorColor: NimoColors.blueBright,
      style: GoogleFonts.inter(fontSize: 15.5, color: NimoColors.textNormal),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.inter(fontSize: 15, color: NimoColors.textFaint),
        prefixText: prefixText,
        prefixStyle: GoogleFonts.inter(
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
          color: NimoColors.blueBright,
        ),
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

  Widget _primaryButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: _loading ? null : onTap,
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
