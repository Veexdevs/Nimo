import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'data.dart';
import 'theme.dart';

void main() => runApp(const NimoApp());

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nimo',
      debugShowCheckedModeBanner: false,
      scrollBehavior: AppScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: NimoColors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: NimoColors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
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
        child: Row(
          children: const [
            ServerRail(),
            Expanded(child: MessagesPanel()),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// Escala suave ao pressionar (Motion)
/// ============================================================
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
        scale: _down ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Bolinha de presença (online, ausente, dnd, offline)
class PresenceDot extends StatelessWidget {
  final Presence presence;
  final double size;
  final Color ringColor;
  const PresenceDot({
    super.key,
    required this.presence,
    this.size = 13,
    this.ringColor = NimoColors.bgDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: presenceColor(presence),
        border: Border.all(color: ringColor, width: 2.5),
      ),
    );
  }
}

/// Tag/insígnia ao lado do nome (ex.: 🎮 SynC)
class ChipTag extends StatelessWidget {
  final String label;
  final bool bot;
  const ChipTag({super.key, required this.label, this.bot = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bot ? NimoColors.blue : NimoColors.bgElevated,
        borderRadius: BorderRadius.circular(6),
        border: bot ? null : Border.all(color: NimoColors.borderSoft),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// ============================================================
/// BARRA DE SERVIDORES (esquerda)
/// ============================================================
class ServerRail extends StatefulWidget {
  const ServerRail({super.key});

  @override
  State<ServerRail> createState() => _ServerRailState();
}

class _ServerRailState extends State<ServerRail> {
  int _selected = -1; // -1 = Início (Mensagens)

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      // Início (logo Nimo)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Pressable(
          onTap: () => setState(() => _selected = -1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _selected == -1 ? NimoColors.blue : NimoColors.bgElevated,
              borderRadius: BorderRadius.circular(_selected == -1 ? 16 : 24),
            ),
            child: const Icon(Icons.chat_bubble, color: Colors.white, size: 22),
          ),
        ),
      ),
      Container(
        width: 32,
        height: 2,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A24),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
      // Servidores
      for (int i = 0; i < servers.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _RailServer(
            item: servers[i],
            selected: _selected == i,
            onTap: () => setState(() => _selected = i),
          ),
        ),
      const SizedBox(height: 4),
      _RailAction(icon: Icons.search, onTap: () {}),
      const SizedBox(height: 8),
      _RailAction(icon: Icons.add, onTap: () {}),
      const SizedBox(height: 12),
    ];

    return Container(
      width: 72,
      color: NimoColors.black,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: items
              .animate(interval: 40.ms)
              .fadeIn(duration: 300.ms, curve: Curves.easeOut)
              .slideX(begin: -0.6, duration: 350.ms, curve: Curves.easeOutCubic),
        ),
      ),
    );
  }
}

class _RailServer extends StatelessWidget {
  final ServerItem item;
  final bool selected;
  final VoidCallback onTap;
  const _RailServer({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: item.gradient,
              ),
              borderRadius: BorderRadius.circular(selected ? 16 : 24),
              border: selected
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              item.label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          if (item.badge > 0)
            Positioned(
              bottom: -3,
              right: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                height: 19,
                constraints: const BoxConstraints(minWidth: 19),
                decoration: BoxDecoration(
                  color: NimoColors.red,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: NimoColors.black, width: 3),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${item.badge}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RailAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RailAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: NimoColors.bgElevated,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: NimoColors.textNormal, size: 22),
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
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: NimoColors.bgDark,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(14)),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _Header(),
              StatusRow(),
              Expanded(child: DmList()),
            ],
          ),
          const Positioned(left: 12, right: 12, bottom: 12, child: MeBar()),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mensagens',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: NimoColors.textNormal,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _searchPill()),
              const SizedBox(width: 10),
              _CircleBtn(icon: Icons.person_add_alt_1, onTap: () {}),
              const SizedBox(width: 10),
              _CircleBtn(icon: Icons.add, onTap: () {}),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms)
        .slideY(begin: -0.2, duration: 400.ms, curve: Curves.easeOutCubic);
  }

  Widget _searchPill() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NimoColors.border),
      ),
      child: Row(
        children: const [
          Icon(Icons.search, size: 20, color: NimoColors.textFaint),
          SizedBox(width: 10),
          Expanded(
            child: TextField(
              cursorColor: NimoColors.blueBright,
              style: TextStyle(fontSize: 15.5, color: NimoColors.textNormal),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Pesquisar...',
                hintStyle: TextStyle(color: NimoColors.textFaint),
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
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: NimoColors.bgElevated,
          shape: BoxShape.circle,
          border: Border.all(color: NimoColors.border),
        ),
        child: Icon(icon, size: 20, color: NimoColors.textNormal),
      ),
    );
  }
}

/// ============================================================
/// FILEIRA DE STATUS (quem postou status)
/// ============================================================
class StatusRow extends StatelessWidget {
  const StatusRow({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final u in statusUsers)
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: StatusRing(user: u),
        ),
    ];

    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 6, 6, 8),
        children: items
            .animate(interval: 70.ms, delay: 120.ms)
            .fadeIn(duration: 300.ms)
            .scale(
              begin: const Offset(0.5, 0.5),
              duration: 450.ms,
              curve: Curves.easeOutBack,
            ),
      ),
    );
  }
}

class StatusRing extends StatelessWidget {
  final StatusUser user;
  const StatusRing({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    Widget ring = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: user.isNew
            ? const SweepGradient(
                colors: [
                  NimoColors.green,
                  NimoColors.greenLight,
                  NimoColors.green,
                ],
              )
            : null,
        color: user.isNew ? null : NimoColors.ringSeen,
      ),
    );

    // Anel girando para status novos (Motion)
    if (user.isNew) {
      ring = ring
          .animate(onPlay: (c) => c.repeat())
          .rotate(duration: 4.seconds);
    }

    return Pressable(
      onTap: () {},
      child: SizedBox(
        width: 76,
        height: 76,
        child: Stack(
          children: [
            Positioned.fill(child: ring),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: NimoColors.bgDark,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: user.gradient,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      user.emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 17,
                height: 17,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: user.isNew ? NimoColors.green : NimoColors.ringSeen,
                  border: Border.all(color: NimoColors.bgDark, width: 3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// LISTA DE CONVERSAS (DMs)
/// ============================================================
class DmList extends StatelessWidget {
  const DmList({super.key});

  @override
  Widget build(BuildContext context) {
    final tiles = [for (final c in dms) DmTile(chat: c)];

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 96),
      children: tiles
          .animate(interval: 45.ms, delay: 200.ms)
          .fadeIn(duration: 350.ms)
          .slideY(begin: 0.3, duration: 400.ms, curve: Curves.easeOutCubic),
    );
  }
}

class DmTile extends StatelessWidget {
  final DmChat chat;
  const DmTile({super.key, required this.chat});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        hoverColor: Colors.white.withOpacity(0.04),
        splashColor: NimoColors.blue.withOpacity(0.15),
        highlightColor: Colors.white.withOpacity(0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            chat.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              fontStyle: chat.italic
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              color: NimoColors.textNormal,
                            ),
                          ),
                        ),
                        if (chat.chip != null) ...[
                          const SizedBox(width: 8),
                          ChipTag(label: chat.chip!, bot: chat.botChip),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      chat.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: NimoColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  chat.time,
                  style: const TextStyle(
                    fontSize: 13,
                    color: NimoColors.textFaint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar() {
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (chat.logoAvatar)
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NimoColors.black,
                border: Border.all(color: NimoColors.blue),
              ),
              child: ClipOval(
                child: Image.asset('assets/logo-icon.png', fit: BoxFit.cover),
              ),
            )
          else
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: chat.gradient,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                chat.letter,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          Positioned(
            bottom: -1,
            right: -1,
            child: PresenceDot(presence: chat.presence),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// BARRA DO SEU PERFIL (flutuante, com blur)
/// ============================================================
class MeBar extends StatelessWidget {
  const MeBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          decoration: BoxDecoration(
            color: const Color(0xEB08080C),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: NimoColors.border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: NimoColors.black,
                        border: Border.all(color: NimoColors.blue),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/logo-icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const Positioned(
                      bottom: -1,
                      right: -1,
                      child: PresenceDot(
                        presence: Presence.offline,
                        ringColor: Color(0xFF08080C),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: const [
                        Flexible(
                          child: Text(
                            '『✝ Denolk ✝』',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: NimoColors.textNormal,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        ChipTag(label: '⚔️ snek'),
                        SizedBox(width: 4),
                        Icon(
                          Icons.expand_more,
                          size: 18,
                          color: NimoColors.textMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Invisível',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: NimoColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.notifications,
                  color: NimoColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms, delay: 400.ms)
        .slideY(begin: 1.6, duration: 550.ms, curve: Curves.easeOutCubic);
  }
}
