import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, AuthState;

import 'auth.dart';
import 'backend.dart';
import 'data.dart';
import 'profile.dart';
import 'status.dart';
import 'theme.dart';
import 'weblinks.dart';
import 'zoom.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  // Sessão vinda do subdomínio de login (#nimo_rt=...)
  if (kIsWeb) {
    final frag = Uri.base.fragment;
    if (frag.startsWith('nimo_rt=')) {
      final rt = Uri.decodeComponent(frag.substring('nimo_rt='.length));
      try {
        await supa.auth.setSession(rt);
      } catch (_) {}
      cleanUrlFragment();
    }
  }

  runApp(const NimoApp());
}

/// Permite arrastar listas com mouse/trackpad (web e desktop)
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class NimoApp extends StatelessWidget {
  const NimoApp({super.key});

  /// true quando o app foi aberto pelo subdomínio de autenticação
  /// (ex.: nimo-login.vercel.app ou login.nimo.com)
  static bool get _isLoginHost {
    if (!kIsWeb) return false;
    final host = Uri.base.host.toLowerCase();
    return host.startsWith('login.') ||
        host.startsWith('nimo-login') ||
        host.startsWith('login-nimo');
  }

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: NimoColors.black,
      colorScheme: ColorScheme.fromSeed(
        seedColor: NimoColors.blue,
        brightness: Brightness.dark,
        surface: NimoColors.black,
      ),
      splashFactory: InkRipple.splashFactory,
    );

    return MaterialApp(
      title: 'Nimo',
      debugShowCheckedModeBanner: false,
      scrollBehavior: AppScrollBehavior(),
      theme: base.copyWith(
        textTheme: GoogleFonts.interTextTheme(base.textTheme),
      ),
      home: StreamBuilder<AuthState>(
        stream: supa.auth.onAuthStateChange,
        builder: (context, _) {
          if (_isLoginHost) {
            if (isLoggedIn) {
              // já logado no subdomínio: manda para o app principal
              return const _RedirectToApp();
            }
            final wantsSignup =
                kIsWeb && Uri.base.fragment.contains('signup');
            return AuthScreen(standalone: true, startSignup: wantsSignup);
          }
          return const HomeScreen();
        },
      ),
    );
  }
}

/// Mostra um carregando e leva a sessão do subdomínio para o app
class _RedirectToApp extends StatefulWidget {
  const _RedirectToApp();

  @override
  State<_RedirectToApp> createState() => _RedirectToAppState();
}

class _RedirectToAppState extends State<_RedirectToApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rt = supa.auth.currentSession?.refreshToken;
      if (rt != null) {
        gotoUrl('$nimoAppUrl/#nimo_rt=${Uri.encodeComponent(rt)}');
      } else {
        gotoUrl(nimoAppUrl);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: NimoColors.black,
      body: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: NimoColors.blue,
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NimoColors.black,
      body: SafeArea(
        child: ZoomFit(
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  ServerRail(),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: NimoColors.hairline,
                  ),
                  Expanded(child: MessagesPanel()),
                ],
              ),
              // Barra de perfil flutuante (arredondada, sem encostar nas bordas)
              const Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: GuestBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Escala suave ao pressionar
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const Pressable({super.key, required this.child, this.onTap});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// ============================================================
/// BARRA DE SERVIDORES (sem servidores ainda)
/// ============================================================
class ServerRail extends StatelessWidget {
  const ServerRail({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      // Início — Mensagens
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Pressable(
          onTap: () {},
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: NimoColors.blue,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.chat_bubble,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
      _RailCircle(icon: Icons.search, onTap: () {}),
      const SizedBox(height: 14),
      _RailCircle(icon: Icons.add, onTap: () {}),
      const SizedBox(height: 10),
    ];

    return SizedBox(
      width: 86,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: items
              .animate(interval: 45.ms)
              .fadeIn(duration: 260.ms, curve: Curves.easeOut)
              .slideX(begin: -0.5, duration: 320.ms, curve: Curves.easeOutCubic),
        ),
      ),
    );
  }
}

class _RailCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RailCircle({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFF131317),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF222227)),
        ),
        child: Icon(icon, color: Colors.white, size: 25),
      ),
    );
  }
}

/// ============================================================
/// PAINEL DE MENSAGENS
/// ============================================================
class MessagesPanel extends StatelessWidget {
  const MessagesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _Header(),
        StatusStrip(),
        Expanded(child: EmptyConversations()),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mensagens',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _searchField()),
              const SizedBox(width: 12),
              _CircleBtn(icon: Icons.person_add_alt_1, onTap: () {}),
              const SizedBox(width: 12),
              _CircleBtn(icon: Icons.add, onTap: () {}),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: -0.15, duration: 350.ms, curve: Curves.easeOutCubic);
  }

  Widget _searchField() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: NimoColors.field,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF1D1D22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 24, color: NimoColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              cursorColor: NimoColors.blueBright,
              style: GoogleFonts.inter(
                fontSize: 17,
                color: NimoColors.textNormal,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Pesquisar...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 17,
                  color: NimoColors.textFaint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF17171B),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF232328)),
        ),
        child: Icon(icon, size: 23, color: Colors.white),
      ),
    );
  }
}

/// ============================================================
/// ESTADO VAZIO — nenhuma conta/conversa ainda
/// ============================================================
class EmptyConversations extends StatelessWidget {
  const EmptyConversations({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0E0E12),
                border: Border.all(color: const Color(0xFF1D1D22)),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 40,
                color: NimoColors.blueBright,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Nenhuma conversa ainda',
              style: GoogleFonts.inter(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione amigos para começar a conversar.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14.5,
                color: NimoColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            Pressable(
              onTap: () {
                if (isLoggedIn) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: const Color(0xFF17171B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Color(0xFF26262B)),
                      ),
                      content: Text(
                        'A busca de amigos chega em breve!',
                        style: GoogleFonts.inter(
                            color: Colors.white, fontSize: 14.5),
                      ),
                    ),
                  );
                } else {
                  goToAuth(context, signup: true);
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                decoration: BoxDecoration(
                  color: NimoColors.blue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_add_alt_1,
                      size: 19,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      'Adicionar amigo',
                      style: GoogleFonts.inter(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 150.ms)
        .scale(
          begin: const Offset(0.92, 0.92),
          duration: 450.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

/// ============================================================
/// BARRA DE PERFIL — visitante ou conta logada
/// ============================================================
class GuestBar extends StatefulWidget {
  const GuestBar({super.key});

  @override
  State<GuestBar> createState() => _GuestBarState();
}

class _GuestBarState extends State<GuestBar> {
  NimoProfile? _profile;
  late final _sub = supa.auth.onAuthStateChange.listen((_) => _load());

  @override
  void initState() {
    super.initState();
    _sub; // inicia a escuta
    _load();
  }

  Future<void> _load() async {
    if (!isLoggedIn) {
      if (mounted) setState(() => _profile = null);
      return;
    }
    try {
      final p = await fetchMyProfile();
      if (mounted) setState(() => _profile = p);
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logged = isLoggedIn;
    final p = _profile;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      decoration: BoxDecoration(
        color: NimoColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: NimoColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Pressable(
              onTap: () => Navigator.of(context).push(profileRoute()),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFF17171B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF232328)),
                    ),
                    child: (logged && p?.avatarUrl != null)
                        ? Image.network(
                            p!.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person_outline,
                              size: 30,
                              color: NimoColors.textMuted,
                            ),
                          )
                        : const Icon(
                            Icons.person_outline,
                            size: 30,
                            color: NimoColors.textMuted,
                          ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          logged ? (p?.shownName ?? '...') : 'Visitante',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          logged
                              ? '@${p?.username ?? ''}'
                              : 'Toque para ver seu perfil',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: NimoColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!logged) ...[
            Pressable(
              onTap: () => goToAuth(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                decoration: BoxDecoration(
                  color: NimoColors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Entrar',
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none,
              size: 25,
              color: Colors.white,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: 300.ms)
        .slideY(begin: 1.0, duration: 450.ms, curve: Curves.easeOutCubic);
  }
}
