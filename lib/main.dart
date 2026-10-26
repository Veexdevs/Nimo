import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

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
/// BARRA DE SERVIDORES
/// ============================================================
class ServerRail extends StatefulWidget {
  const ServerRail({super.key});

  @override
  State<ServerRail> createState() => _ServerRailState();
}

class _ServerRailState extends State<ServerRail> {
  int _selected = -1;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      // Início — Mensagens
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Pressable(
          onTap: () => setState(() => _selected = -1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _selected == -1
                  ? NimoColors.blue
                  : const Color(0xFF15151A),
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
      for (int i = 0; i < servers.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _ServerTileView(
            tile: servers[i],
            selected: _selected == i,
            onTap: () => setState(() => _selected = i),
          ),
        ),
      const SizedBox(height: 6),
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
              .animate(interval: 35.ms)
              .fadeIn(duration: 260.ms, curve: Curves.easeOut)
              .slideX(begin: -0.5, duration: 320.ms, curve: Curves.easeOutCubic),
        ),
      ),
    );
  }
}

class _ServerTileView extends StatelessWidget {
  final ServerTile tile;
  final bool selected;
  final VoidCallback onTap;
  const _ServerTileView({
    required this.tile,
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
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: tile.bg,
              borderRadius:
                  BorderRadius.circular(selected ? 16 : tile.radius),
              border: Border.all(
                color: selected
                    ? NimoColors.blueBright
                    : (tile.bordered
                        ? const Color(0xFF26262B)
                        : Colors.transparent),
                width: selected ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: tile.icon != null
                ? Icon(tile.icon, color: tile.fg, size: 26)
                : Text(
                    tile.text ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: tile.fg,
                      fontSize: tile.fontSize,
                      fontWeight: FontWeight.w900,
                      fontStyle:
                          tile.italic ? FontStyle.italic : FontStyle.normal,
                      letterSpacing: 0.2,
                      height: 1,
                    ),
                  ),
          ),
          if (tile.badge > 0)
            Positioned(
              bottom: -4,
              right: -4,
              child: Container(
                height: 22,
                constraints: const BoxConstraints(minWidth: 22),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: NimoColors.redBadge,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: NimoColors.black, width: 3),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${tile.badge}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
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
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _Header(),
            StatusRow(),
            Expanded(child: DmList()),
          ],
        ),
        const Positioned(left: 10, right: 10, bottom: 10, child: MeBar()),
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
/// FILEIRA DE STATUS
/// ============================================================
class StatusRow extends StatelessWidget {
  const StatusRow({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final u in statusUsers)
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: _StatusAvatar(user: u),
        ),
    ];

    return SizedBox(
      height: 112,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(22, 12, 8, 8),
        children: items
            .animate(interval: 60.ms, delay: 100.ms)
            .fadeIn(duration: 280.ms)
            .scale(
              begin: const Offset(0.7, 0.7),
              duration: 380.ms,
              curve: Curves.easeOutBack,
            ),
      ),
    );
  }
}

class _StatusAvatar extends StatelessWidget {
  final StatusUser user;
  const _StatusAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final ringColor =
        user.isNew ? NimoColors.greenLight : NimoColors.ringSeen;

    return Pressable(
      onTap: () {},
      child: SizedBox(
        width: 88,
        height: 88,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: 2.5),
              ),
              padding: const EdgeInsets.all(4),
              child: ClipOval(
                child: Image.asset(user.avatar, fit: BoxFit.cover),
              ),
            ),
            Positioned(
              bottom: 1,
              right: 1,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: NimoColors.black,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: user.isNew
                    ? Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: NimoColors.greenLight,
                          shape: BoxShape.circle,
                        ),
                      )
                    : Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: NimoColors.ringSeen,
                            width: 2.5,
                          ),
                        ),
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
/// LISTA DE CONVERSAS
/// ============================================================
class DmList extends StatelessWidget {
  const DmList({super.key});

  @override
  Widget build(BuildContext context) {
    final tiles = [for (final c in dms) DmTile(chat: c)];

    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 112),
      children: tiles
          .animate(interval: 40.ms, delay: 180.ms)
          .fadeIn(duration: 300.ms)
          .slideY(begin: 0.25, duration: 360.ms, curve: Curves.easeOutCubic),
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
        borderRadius: BorderRadius.circular(14),
        hoverColor: Colors.white.withOpacity(0.035),
        splashColor: NimoColors.blue.withOpacity(0.12),
        highlightColor: Colors.white.withOpacity(0.02),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(chat: chat),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _nameRow(),
                    const SizedBox(height: 4),
                    Text(
                      chat.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: NimoColors.textMuted,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  chat.time,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
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

  Widget _nameRow() {
    final nameStyle = chat.serif
        ? GoogleFonts.lora(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            color: Colors.white,
          )
        : GoogleFonts.inter(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.1,
          );

    final children = <Widget>[];

    if (chat.medals) {
      children.add(const Padding(
        padding: EdgeInsets.only(right: 5),
        child: Icon(Icons.military_tech, size: 18, color: NimoColors.amber),
      ));
    }

    if (chat.devSup) {
      children.add(Flexible(
        child: Text.rich(
          TextSpan(
            text: chat.name,
            style: nameStyle,
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.top,
                child: Transform.translate(
                  offset: const Offset(1, -2),
                  child: Text(
                    'dev',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: NimoColors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ));
    } else {
      children.add(Flexible(
        child: Text(
          chat.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: nameStyle,
        ),
      ));
    }

    if (chat.medals) {
      children.add(const Padding(
        padding: EdgeInsets.only(left: 5),
        child: Icon(Icons.military_tech, size: 18, color: NimoColors.amber),
      ));
    }

    if (chat.botTag) {
      children.add(const SizedBox(width: 8));
      children.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: NimoColors.blue,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, size: 12, color: Colors.white),
            const SizedBox(width: 3),
            Text(
              'APP',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
          ],
        ),
      ));
    }

    if (chat.tag != null) {
      children.add(const SizedBox(width: 8));
      children.add(TagChip(tag: chat.tag!));
    }

    return Row(children: children);
  }
}

class _Avatar extends StatelessWidget {
  final DmChat chat;
  const _Avatar({required this.chat});

  @override
  Widget build(BuildContext context) {
    Widget core;
    if (chat.botAvatar) {
      core = Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFFE8373B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.smart_toy, color: Colors.white, size: 28),
      );
    } else {
      core = ClipOval(
        child: Image.asset(
          chat.avatar!,
          width: 54,
          height: 54,
          fit: BoxFit.cover,
        ),
      );
    }

    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          core,
          Positioned(
            bottom: -3,
            right: -3,
            child: _presenceBadge(),
          ),
        ],
      ),
    );
  }

  Widget _presenceBadge() {
    Widget inner;
    switch (chat.presence) {
      case Presence.online:
        inner = Container(
          width: 13,
          height: 13,
          decoration: const BoxDecoration(
            color: NimoColors.greenLight,
            shape: BoxShape.circle,
          ),
        );
        break;
      case Presence.idle:
        inner = Container(
          width: 13,
          height: 13,
          decoration: const BoxDecoration(
            color: NimoColors.yellow,
            shape: BoxShape.circle,
          ),
        );
        break;
      case Presence.dnd:
        inner = Container(
          width: 13,
          height: 13,
          decoration: const BoxDecoration(
            color: NimoColors.red,
            shape: BoxShape.circle,
          ),
        );
        break;
      case Presence.none:
        inner = Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: NimoColors.ringSeen, width: 2.5),
          ),
        );
        break;
    }

    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: NimoColors.black,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: inner,
    );
  }
}

/// Insígnia com ícone (sem emoji)
class TagChip extends StatelessWidget {
  final Tag tag;
  const TagChip({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: NimoColors.chipBg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: NimoColors.chipBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tag.icon, size: 13, color: tag.iconColor),
          const SizedBox(width: 4),
          Text(
            tag.label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: NimoColors.textNormal,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// BARRA DO SEU PERFIL
/// ============================================================
class MeBar extends StatelessWidget {
  const MeBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: NimoColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: NimoColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/avatars/av_denolk.jpg',
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: NimoColors.surface,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: NimoColors.ringSeen,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '『✝ Denolk ✝』',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.unifrakturMaguntia(
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    const TagChip(tag: tagSnek),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.expand_more,
                      size: 20,
                      color: NimoColors.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Invisível',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: NimoColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none,
              size: 26,
              color: Colors.white,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: 350.ms)
        .slideY(begin: 1.4, duration: 480.ms, curve: Curves.easeOutCubic);
  }
}
