import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, AuthState;

import 'auth.dart';
import 'backend.dart';
import 'chat.dart';
import 'data.dart';
import 'friends.dart';
import 'profile.dart';
import 'server.dart';
import 'social.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<NimoServer> _servers = [];
  NimoServer? _selected;
  late final _sub = supa.auth.onAuthStateChange.listen((_) => _loadServers());

  @override
  void initState() {
    super.initState();
    _sub;
    _loadServers();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Future<void> _loadServers() async {
    if (!isLoggedIn) {
      if (mounted) {
        setState(() {
          _servers = [];
          _selected = null;
        });
      }
      return;
    }
    try {
      final s = await fetchMyServers();
      if (mounted) {
        setState(() {
          _servers = s;
          if (_selected != null) {
            final still =
                s.where((x) => x.id == _selected!.id).toList();
            _selected = still.isEmpty ? null : still.first;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _addServer() async {
    if (!isLoggedIn) {
      goToAuth(context);
      return;
    }
    final s = await showServerSheet(context);
    if (s != null) {
      await _loadServers();
      if (mounted) setState(() => _selected = s);
    }
  }

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
                children: [
                  ServerRail(
                    servers: _servers,
                    selectedId: _selected?.id,
                    onHome: () => setState(() => _selected = null),
                    onServer: (s) => setState(() => _selected = s),
                    onAdd: _addServer,
                    onSearch: () {
                      if (!isLoggedIn) {
                        goToAuth(context);
                        return;
                      }
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const FriendsScreen(startTab: 2),
                      ));
                    },
                  ),
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: NimoColors.hairline,
                  ),
                  Expanded(
                    child: _selected == null
                        ? const MessagesPanel()
                        : ServerPanel(
                            server: _selected!,
                            onExit: () {
                              setState(() => _selected = null);
                              _loadServers();
                            },
                          ),
                  ),
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
  final List<NimoServer> servers;
  final String? selectedId;
  final VoidCallback onHome;
  final ValueChanged<NimoServer> onServer;
  final VoidCallback onAdd;
  final VoidCallback onSearch;
  const ServerRail({
    super.key,
    required this.servers,
    required this.selectedId,
    required this.onHome,
    required this.onServer,
    required this.onAdd,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      // Início — Mensagens
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Pressable(
          onTap: onHome,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: selectedId == null
                  ? NimoColors.blue
                  : const Color(0xFF131317),
              borderRadius: BorderRadius.circular(16),
              border: selectedId == null
                  ? null
                  : Border.all(color: const Color(0xFF222227)),
            ),
            child: Icon(
              Icons.chat_bubble,
              color:
                  selectedId == null ? Colors.white : NimoColors.textMuted,
              size: 26,
            ),
          ),
        ),
      ),
      if (servers.isNotEmpty) ...[
        Container(
          width: 34,
          height: 2,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF222227),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        for (final s in servers)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Pressable(
              onTap: () => onServer(s),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: selectedId == s.id
                        ? NimoColors.blueBright
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: NimoAvatar(
                  name: s.name,
                  url: s.iconUrl,
                  size: 50,
                  square: true,
                ),
              ),
            ),
          ),
        const SizedBox(height: 4),
      ],
      _RailCircle(icon: Icons.search, onTap: onSearch),
      const SizedBox(height: 14),
      _RailCircle(icon: Icons.add, onTap: onAdd),
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
class MessagesPanel extends StatefulWidget {
  const MessagesPanel({super.key});

  @override
  State<MessagesPanel> createState() => _MessagesPanelState();
}

class _MessagesPanelState extends State<MessagesPanel> {
  final _listKey = GlobalKey<ConversationsListState>();

  Future<void> _openFriends() async {
    if (!isLoggedIn) {
      goToAuth(context);
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const FriendsScreen(),
    ));
    _listKey.currentState?.refresh();
  }

  Future<void> _newGroup() async {
    final created = await showCreateGroupSheet(context);
    if (created) _listKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(onAddFriend: _openFriends, onNewGroup: _newGroup),
        const StatusStrip(),
        Expanded(child: ConversationsList(key: _listKey)),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onAddFriend;
  final VoidCallback onNewGroup;
  const _Header({required this.onAddFriend, required this.onNewGroup});

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
              _CircleBtn(icon: Icons.person_add_alt_1, onTap: onAddFriend),
              const SizedBox(width: 12),
              _CircleBtn(icon: Icons.add, onTap: onNewGroup),
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
