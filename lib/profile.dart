import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth.dart';
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
/// Meu perfil (modo visitante — sem conta ainda)
/// ============================================================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _snack(BuildContext context, String msg) {
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

  @override
  Widget build(BuildContext context) {
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
                        _header(context),
                        const SizedBox(height: 64),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _identity(),
                              const SizedBox(height: 22),
                              _card(
                                title: 'MINHA CONTA',
                                rows: const [
                                  _InfoRow(
                                    icon: Icons.person_outline,
                                    label: 'Nome de exibição',
                                    value: 'Não definido',
                                  ),
                                  _InfoRow(
                                    icon: Icons.alternate_email,
                                    label: 'Nome único',
                                    value: 'Não definido',
                                    note:
                                        'Pode ser alterado a cada 7 dias',
                                  ),
                                  _InfoRow(
                                    icon: Icons.mail_outline,
                                    label: 'E-mail',
                                    value: '—',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _card(
                                title: 'SOBRE',
                                rows: const [
                                  _InfoRow(
                                    icon: Icons.public,
                                    label: 'País',
                                    value: '—',
                                  ),
                                  _InfoRow(
                                    icon: Icons.event_outlined,
                                    label: 'Membro desde',
                                    value: '—',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _primaryButton(
                                context,
                                'Criar conta',
                                () => Navigator.of(context)
                                    .push(authRoute(signup: true)),
                              ),
                              const SizedBox(height: 12),
                              _outlineButton(
                                context,
                                'Entrar',
                                () => Navigator.of(context)
                                    .push(authRoute()),
                              ),
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
  Widget _header(BuildContext context) {
    return SizedBox(
      height: 208,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Banner
          GestureDetector(
            onTap: () => _snack(
                context, 'Crie uma conta para personalizar seu perfil.'),
            child: Container(
              height: 150,
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
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _editBadge(),
                ),
              ),
            ),
          ),
          // Avatar quadrado arredondado
          Positioned(
            left: 20,
            top: 92,
            child: GestureDetector(
              onTap: () => _snack(
                  context, 'Crie uma conta para personalizar seu perfil.'),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 116,
                    height: 116,
                    decoration: BoxDecoration(
                      color: const Color(0xFF17171B),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: NimoColors.black,
                        width: 6,
                      ),
                    ),
                    child: const Icon(
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
  Widget _identity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Visitante',
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
              'nome único não definido',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: NimoColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: NimoColors.blue.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: NimoColors.blue.withOpacity(0.35)),
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
    ).animate().fadeIn(duration: 320.ms, delay: 60.ms);
  }

  // ----------------------------------------------------------
  // Cartões de informação
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

  Widget _primaryButton(
      BuildContext context, String label, VoidCallback onTap) {
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

  Widget _outlineButton(
      BuildContext context, String label, VoidCallback onTap) {
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
