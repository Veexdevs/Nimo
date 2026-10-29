// ============================================================
// NIMO — Servidores: criar/entrar, canais e membros
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'backend.dart';
import 'chat.dart';
import 'social.dart';
import 'status.dart';
import 'theme.dart';

// ------------------------------------------------------------
// Criar servidor ou entrar com convite
// ------------------------------------------------------------
Future<NimoServer?> showServerSheet(BuildContext context) async {
  final nameCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  final result = await showModalBottomSheet<NimoServer>(
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
        top: 16,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A30),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Servidores',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'CRIAR UM NOVO',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: NimoColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _sheetField(nameCtrl, 'Nome do servidor', maxLen: 60),
              ),
              const SizedBox(width: 10),
              _sheetBtn('Criar', NimoColors.blue, () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  nimoSnack(ctx, 'Dê um nome ao servidor.');
                  return;
                }
                try {
                  final s = await createServer(name);
                  if (ctx.mounted) Navigator.of(ctx).pop(s);
                } catch (_) {
                  if (ctx.mounted) {
                    nimoSnack(ctx, 'Não foi possível criar o servidor.');
                  }
                }
              }),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'ENTRAR COM CONVITE',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: NimoColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _sheetField(codeCtrl, 'Código do convite', maxLen: 16),
              ),
              const SizedBox(width: 10),
              _sheetBtn('Entrar', const Color(0xFF22C55E), () async {
                final code = codeCtrl.text.trim();
                if (code.isEmpty) {
                  nimoSnack(ctx, 'Digite o código do convite.');
                  return;
                }
                try {
                  final sid = await joinServerByCode(code);
                  final servers = await fetchMyServers();
                  final s = servers.where((x) => x.id == sid).toList();
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop(s.isEmpty ? null : s.first);
                  }
                } catch (_) {
                  if (ctx.mounted) nimoSnack(ctx, 'Convite inválido.');
                }
              }),
            ],
          ),
        ],
      ),
    ),
  );
  nameCtrl.dispose();
  codeCtrl.dispose();
  return result;
}

Widget _sheetField(TextEditingController c, String hint, {int maxLen = 60}) {
  return TextField(
    controller: c,
    maxLength: maxLen,
    cursorColor: NimoColors.blueBright,
    style: GoogleFonts.inter(fontSize: 15, color: NimoColors.textNormal),
    decoration: InputDecoration(
      hintText: hint,
      counterText: '',
      hintStyle: GoogleFonts.inter(fontSize: 15, color: NimoColors.textFaint),
      filled: true,
      fillColor: NimoColors.field,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

Widget _sheetBtn(String label, Color color, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------
// PAINEL DO SERVIDOR (lado direito da Home)
// ------------------------------------------------------------
class ServerPanel extends StatefulWidget {
  final NimoServer server;
  final VoidCallback onExit; // saiu/apagou — volta para Mensagens
  const ServerPanel({super.key, required this.server, required this.onExit});

  @override
  State<ServerPanel> createState() => _ServerPanelState();
}

class _ServerPanelState extends State<ServerPanel> {
  List<NimoChannel> _channels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ServerPanel old) {
    super.didUpdateWidget(old);
    if (old.server.id != widget.server.id) {
      _loading = true;
      _channels = [];
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final c = await fetchChannels(widget.server.id);
      if (mounted) {
        setState(() {
          _channels = c;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.server;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 14, 6),
          child: Row(
            children: [
              NimoAvatar(name: s.name, url: s.iconUrl, size: 46, square: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      s.isMine ? 'Seu servidor' : 'Membro',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: NimoColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _menuBtn(context),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Text(
                'CANAIS',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: NimoColors.textMuted,
                ),
              ),
              const Spacer(),
              if (s.isMine)
                GestureDetector(
                  onTap: _newChannel,
                  child: const Icon(Icons.add,
                      size: 19, color: NimoColors.textMuted),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: NimoColors.textFaint,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: _channels.length,
                  itemBuilder: (_, i) {
                    final ch = _channels[i];
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            chatId: ch.id,
                            isChannel: true,
                            title: '#${ch.name}',
                            subtitle: s.name,
                          ),
                        ));
                      },
                      onLongPress:
                          s.isMine ? () => _confirmDeleteChannel(ch) : null,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 7),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: NimoColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: NimoColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.tag,
                                size: 19, color: NimoColors.blueBright),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                ch.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: NimoColors.textNormal,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                size: 19, color: NimoColors.textFaint),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    ).animate().fadeIn(duration: 260.ms);
  }

  Widget _menuBtn(BuildContext context) {
    final s = widget.server;
    return PopupMenuButton<String>(
      color: const Color(0xFF17171B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      icon: const Icon(Icons.more_vert, color: NimoColors.textMuted),
      onSelected: (v) async {
        switch (v) {
          case 'invite':
            await Clipboard.setData(ClipboardData(text: s.inviteCode));
            if (context.mounted) {
              nimoSnack(context,
                  'Convite copiado: ${s.inviteCode} — compartilhe para chamarem o servidor!');
            }
            break;
          case 'members':
            await _showMembers();
            break;
          case 'leave':
            try {
              await leaveServer(s.id);
              widget.onExit();
            } catch (_) {}
            break;
          case 'delete':
            final ok = await _confirm(
                'Apagar servidor?', 'Tudo dele será apagado para sempre.');
            if (ok) {
              try {
                await deleteServer(s.id);
                widget.onExit();
              } catch (_) {}
            }
            break;
        }
      },
      itemBuilder: (_) => [
        _item('invite', Icons.link, 'Copiar convite'),
        _item('members', Icons.group_outlined, 'Ver membros'),
        if (!s.isMine) _item('leave', Icons.logout, 'Sair do servidor'),
        if (s.isMine)
          _item('delete', Icons.delete_outline, 'Apagar servidor',
              danger: true),
      ],
    );
  }

  PopupMenuItem<String> _item(String v, IconData i, String label,
      {bool danger = false}) {
    final c = danger ? const Color(0xFFFF5555) : Colors.white;
    return PopupMenuItem(
      value: v,
      child: Row(
        children: [
          Icon(i, size: 18, color: c),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.inter(fontSize: 14, color: c)),
        ],
      ),
    );
  }

  Future<bool> _confirm(String title, String msg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131317),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title,
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w800)),
        content:
            Text(msg, style: GoogleFonts.inter(color: NimoColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar',
                style: GoogleFonts.inter(color: NimoColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Apagar',
                style: GoogleFonts.inter(color: const Color(0xFFFF5555))),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _confirmDeleteChannel(NimoChannel ch) async {
    if (_channels.length <= 1) {
      nimoSnack(context, 'O servidor precisa de pelo menos 1 canal.');
      return;
    }
    final ok = await _confirm('Apagar #${ch.name}?',
        'As mensagens desse canal serão apagadas para sempre.');
    if (ok) {
      try {
        await deleteChannel(ch.id);
        await _load();
      } catch (_) {}
    }
  }

  Future<void> _newChannel() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131317),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Novo canal',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 40,
          cursorColor: NimoColors.blueBright,
          style:
              GoogleFonts.inter(fontSize: 15, color: NimoColors.textNormal),
          decoration: InputDecoration(
            hintText: 'nome-do-canal',
            counterText: '',
            prefixText: '# ',
            prefixStyle: GoogleFonts.inter(
                fontSize: 15, color: NimoColors.blueBright),
            hintStyle: GoogleFonts.inter(
                fontSize: 15, color: NimoColors.textFaint),
            filled: true,
            fillColor: NimoColors.field,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar',
                style: GoogleFonts.inter(color: NimoColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Criar',
                style: GoogleFonts.inter(color: NimoColors.blueBright)),
          ),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      try {
        await createChannel(widget.server.id, ctrl.text);
        await _load();
      } catch (_) {
        if (mounted) nimoSnack(context, 'Não foi possível criar o canal.');
      }
    }
    ctrl.dispose();
  }

  Future<void> _showMembers() async {
    List<LiteUser> members = [];
    try {
      members = await fetchServerMembers(widget.server.id);
    } catch (_) {}
    if (!mounted || members.isEmpty) return;
    final meId = supa.auth.currentUser?.id;
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101014),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Membros (${members.length})',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: members.length,
                  itemBuilder: (_, i) {
                    final u = members[i];
                    final isOwner = u.id == widget.server.ownerId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          NimoAvatar(
                              name: u.shownName, url: u.avatarUrl, size: 38),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              '${u.shownName}  ·  @${u.username}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: NimoColors.textNormal,
                              ),
                            ),
                          ),
                          if (isOwner)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: NimoColors.blue.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'DONO',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: NimoColors.blueBright,
                                ),
                              ),
                            )
                          else if (u.id != meId && widget.server.isMine)
                            GestureDetector(
                              onTap: () async {
                                try {
                                  await supa
                                      .from('server_members')
                                      .delete()
                                      .eq('server_id', widget.server.id)
                                      .eq('user_id', u.id);
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                } catch (_) {}
                              },
                              child: const Icon(Icons.person_remove_outlined,
                                  size: 18, color: Color(0xFFFF5555)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
