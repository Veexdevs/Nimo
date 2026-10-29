import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth.dart';
import 'backend.dart';
import 'theme.dart';
import 'zoom.dart';

/// Transição suave para a tela de perfil
Route profileRoute() => PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => const ProfileScreen(),
      transitionsBuilder: (_, anim, __, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

/// ============================================================
/// Meu perfil — visitante ou conta logada
/// ============================================================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  NimoProfile? _profile;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!isLoggedIn) return;
    try {
      final p = await fetchMyProfile();
      if (mounted) setState(() => _profile = p);
    } catch (_) {}
  }

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

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await supa.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Não foi possível sair agora. Tente de novo.');
    }
  }

  void _editTap() {
    _snack(isLoggedIn
        ? 'A edição de perfil chega em breve.'
        : 'Crie uma conta para personalizar seu perfil.');
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final logged = isLoggedIn;
    final p = _profile;

    return Scaffold(
      backgroundColor: NimoColors.black,
      body: SafeArea(
        child: ZoomFit(
          designWidth: 520,
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(p),
                        const SizedBox(height: 64),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _identity(logged, p),
                              const SizedBox(height: 22),
                              _bioCard(logged, p),
                              const SizedBox(height: 14),
                              _card(
                                title: 'SOBRE',
                                rows: [
                                  _InfoRow(
                                    icon: Icons.public,
                                    label: 'País',
                                    value: logged
                                        ? (p?.country ?? '—')
                                        : '—',
                                  ),
                                  _InfoRow(
                                    icon: Icons.event_outlined,
                                    label: 'Membro desde',
                                    value: logged
                                        ? _fmtDate(p?.createdAt)
                                        : '—',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              if (logged) ...[
                                _dangerButton(
                                  _busy ? 'Saindo...' : 'Sair da conta',
                                  _busy ? null : _signOut,
                                ),
                              ] else ...[
                                _primaryButton(
                                  'Criar conta',
                                  () => goToAuth(context, signup: true),
                                ),
                                const SizedBox(height: 12),
                                _outlineButton(
                                  'Entrar',
                                  () => goToAuth(context),
                                ),
                              ],
                              const SizedBox(height: 26),
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
                      ],
                    ),
                  ),
                ),
              ),
              // Voltar
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // Banner + avatar sobreposto
  // ----------------------------------------------------------
  Widget _header(NimoProfile? p) {
    return SizedBox(
      height: 208,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Banner
          GestureDetector(
            onTap: _editTap,
            child: Container(
              height: 150,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0B1D45),
                    Color(0xFF123B9E),
                    Color(0xFF0B0B0E),
                  ],
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (p?.bannerUrl != null)
                    Image.network(
                      p!.bannerUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const SizedBox.shrink(),
                    ),
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _editBadge(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Avatar quadrado arredondado
          Positioned(
            left: 20,
            top: 92,
            child: GestureDetector(
              onTap: _editTap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 116,
                    height: 116,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFF17171B),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: NimoColors.black,
                        width: 6,
                      ),
                    ),
                    child: p?.avatarUrl != null
                        ? Image.network(
                            p!.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person_outline,
                              size: 52,
                              color: NimoColors.textMuted,
                            ),
                          )
                        : const Icon(
                            Icons.person_outline,
                            size: 52,
                            color: NimoColors.textMuted,
                          ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: _editBadge(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 320.ms);
  }

  Widget _editBadge() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFF17171B),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF26262B)),
      ),
      child: const Icon(
        Icons.edit_outlined,
        size: 16,
        color: NimoColors.textMuted,
      ),
    );
  }

  // ----------------------------------------------------------
  // Nome + status
  // ----------------------------------------------------------
  Widget _identity(bool logged, NimoProfile? p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          logged ? (p?.shownName ?? '...') : 'Visitante',
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(
              Icons.alternate_email,
              size: 15,
              color: NimoColors.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              logged
                  ? (p?.username ?? '...')
                  : 'nome único não definido',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: NimoColors.textMuted,
              ),
            ),
          ],
        ),
        if (!logged) ...[
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: NimoColors.blue.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: NimoColors.blue.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 15,
                  color: NimoColors.blueBright,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'Você ainda não tem uma conta no Nimo',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: NimoColors.blueBright,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ).animate().fadeIn(duration: 320.ms, delay: 60.ms);
  }

  // ----------------------------------------------------------
  // Bio
  // ----------------------------------------------------------
  Future<void> _editBio() async {
    if (!isLoggedIn) {
      _snack('Crie uma conta para escrever sua bio.');
      return;
    }
    final ctrl = TextEditingController(text: _profile?.bio ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF101014),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sua bio',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              maxLines: 4,
              maxLength: 190,
              autofocus: true,
              cursorColor: NimoColors.blueBright,
              style: GoogleFonts.inter(
                  fontSize: 15, color: NimoColors.textNormal),
              decoration: InputDecoration(
                hintText: 'Conte algo sobre você...',
                hintStyle: GoogleFonts.inter(
                    fontSize: 15, color: NimoColors.textFaint),
                counterStyle: GoogleFonts.inter(
                    fontSize: 11.5, color: NimoColors.textFaint),
                filled: true,
                fillColor: NimoColors.field,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(true),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: NimoColors.blue,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Salvar bio',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      try {
        await updateBio(ctrl.text);
        await _load();
        if (mounted) _snack('Bio atualizada!');
      } catch (_) {
        if (mounted) _snack('Não foi possível salvar a bio.');
      }
    }
    ctrl.dispose();
  }

  Widget _bioCard(bool logged, NimoProfile? p) {
    final hasBio = (p?.bio?.trim().isNotEmpty ?? false);
    return GestureDetector(
      onTap: _editBio,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: NimoColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: NimoColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'BIO',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: NimoColors.textMuted,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.edit_outlined,
                    size: 16, color: NimoColors.textMuted),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasBio
                  ? p!.bio!
                  : (logged
                      ? 'Toque para escrever sua bio.'
                      : 'Crie uma conta para ter uma bio.'),
              style: GoogleFonts.inter(
                fontSize: 14.5,
                height: 1.45,
                color: hasBio
                    ? NimoColors.textNormal
                    : NimoColors.textFaint,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 320.ms, delay: 100.ms);
  }

  // ----------------------------------------------------------
  // Cartões e botões
  // ----------------------------------------------------------
  Widget _card({required String title, required List<_InfoRow> rows}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: NimoColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NimoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: NimoColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          ...rows,
        ],
      ),
    ).animate().fadeIn(duration: 320.ms, delay: 120.ms);
  }

  Widget _primaryButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: NimoColors.blue,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 320.ms, delay: 180.ms);
  }

  Widget _outlineButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF26262B), width: 1.4),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 320.ms, delay: 220.ms);
  }

  Widget _dangerButton(String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: NimoColors.red.withOpacity(0.55), width: 1.4),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.logout, size: 18, color: NimoColors.red),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: NimoColors.red,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 320.ms, delay: 180.ms);
  }
}

/// Linha de informação dentro de um cartão
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? note;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF141419),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: NimoColors.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: NimoColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: NimoColors.textNormal,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    note!,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: NimoColors.textFaint,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
