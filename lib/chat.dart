// ============================================================
// NIMO — conversas: lista, chat de DM/grupo e chat de canal
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth.dart';
import 'backend.dart';
import 'social.dart';
import 'status.dart';
import 'theme.dart';

// ------------------------------------------------------------
// Avatar genérico (foto ou inicial)
// ------------------------------------------------------------
class NimoAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  final bool square;
  const NimoAvatar({
    super.key,
    required this.name,
    this.url,
    this.size = 48,
    this.square = false,
  });

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty
        ? '?'
        : name.trim().replaceAll('@', '').substring(0, 1).toUpperCase();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF17171B),
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(size * 0.3) : null,
      ),
      child: url != null
          ? Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _letter(letter),
            )
          : _letter(letter),
    );
  }

  Widget _letter(String l) => Center(
        child: Text(
          l,
          style: GoogleFonts.inter(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w800,
            color: NimoColors.blueBright,
          ),
        ),
      );
}

// ------------------------------------------------------------
// Abre (ou cria) uma DM com alguém
// ------------------------------------------------------------
Future<void> openDmWith(BuildContext context, LiteUser user) async {
  try {
    final cid = await openDm(user.id);
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        chatId: cid,
        isChannel: false,
        title: user.shownName,
        subtitle: '@${user.username}',
        avatarUrl: user.avatarUrl,
      ),
    ));
  } catch (_) {
    if (context.mounted) {
      nimoSnack(context, 'Não foi possível abrir a conversa.');
    }
  }
}

// ------------------------------------------------------------
// LISTA DE CONVERSAS (painel Mensagens)
// ------------------------------------------------------------
class ConversationsList extends StatefulWidget {
  const ConversationsList({super.key});

  @override
  State<ConversationsList> createState() => ConversationsListState();
}

class ConversationsListState extends State<ConversationsList> {
  List<NimoConversation> _convs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (!isLoggedIn) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final c = await fetchConversations();
      if (mounted) {
        setState(() {
          _convs = c;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: NimoColors.textFaint,
          ),
        ),
      );
    }
    if (_convs.isEmpty) return _empty(context);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 120),
      itemCount: _convs.length,
      itemBuilder: (context, i) {
        final c = _convs[i];
        return _ConvTile(
          conv: c,
          onOpen: () async {
            await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatId: c.id,
                isChannel: false,
                title: c.title,
                subtitle: c.isGroup
                    ? '${c.memberCount} membros'
                    : '@${c.other?.username ?? ''}',
                avatarUrl: c.avatarUrl,
                conversation: c,
              ),
            ));
            refresh();
          },
          onChanged: refresh,
        );
      },
    );
  }

  Widget _empty(BuildContext context) {
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
            GestureDetector(
              onTap: () {
                if (!isLoggedIn) {
                  goToAuth(context, signup: true);
                }
              },
              child: isLoggedIn
                  ? const SizedBox.shrink()
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 26, vertical: 14),
                      decoration: BoxDecoration(
                        color: NimoColors.blue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Criar conta',
                        style: GoogleFonts.inter(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 150.ms);
  }
}

class _ConvTile extends StatelessWidget {
  final NimoConversation conv;
  final VoidCallback onOpen;
  final VoidCallback onChanged;
  const _ConvTile({
    required this.conv,
    required this.onOpen,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      onLongPress: () => _options(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: NimoColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NimoColors.border),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                NimoAvatar(
                  name: conv.title,
                  url: conv.avatarUrl,
                  size: 52,
                ),
                if (conv.isGroup)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: NimoColors.blue,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: NimoColors.black, width: 2),
                      ),
                      child: const Icon(Icons.group,
                          size: 11, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conv.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    conv.lastMessage ?? 'Conversa criada',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: NimoColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              conv.lastAt == null ? '' : timeAgo(conv.lastAt!),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: NimoColors.textFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _options(BuildContext context) async {
    final me = supa.auth.currentUser?.id;
    final isOwner = conv.isGroup && conv.ownerId == me;
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101014),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            if (conv.isGroup)
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.white),
                title: Text('Sair do grupo',
                    style: GoogleFonts.inter(color: Colors.white)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  try {
                    await leaveConversation(conv.id);
                    onChanged();
                  } catch (_) {}
                },
              ),
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: Color(0xFFFF5555)),
                title: Text('Apagar grupo',
                    style: GoogleFonts.inter(color: const Color(0xFFFF5555))),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  try {
                    await deleteConversation(conv.id);
                    onChanged();
                  } catch (_) {}
                },
              ),
            if (!conv.isGroup)
              ListTile(
                leading: const Icon(Icons.close, color: Colors.white),
                title: Text('Fechar',
                    style: GoogleFonts.inter(color: Colors.white)),
                onTap: () => Navigator.of(ctx).pop(),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// CRIAR GRUPO
// ------------------------------------------------------------
Future<bool> showCreateGroupSheet(BuildContext context) async {
  if (!isLoggedIn) {
    goToAuth(context);
    return false;
  }
  List<Friend> friends;
  try {
    friends = (await fetchFriendsData()).friends;
  } catch (_) {
    friends = [];
  }
  if (!context.mounted) return false;
  if (friends.isEmpty) {
    nimoSnack(context, 'Adicione amigos primeiro para criar um grupo.');
    return false;
  }

  final nameCtrl = TextEditingController();
  final selected = <String>{};
  final created = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: const Color(0xFF101014),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 18,
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
              'Novo grupo',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              maxLength: 50,
              cursorColor: NimoColors.blueBright,
              style: GoogleFonts.inter(
                  fontSize: 15, color: NimoColors.textNormal),
              decoration: InputDecoration(
                hintText: 'Nome do grupo',
                counterText: '',
                hintStyle: GoogleFonts.inter(
                    fontSize: 15, color: NimoColors.textFaint),
                filled: true,
                fillColor: NimoColors.field,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'AMIGOS',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: NimoColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: friends.length,
                itemBuilder: (_, i) {
                  final f = friends[i];
                  final sel = selected.contains(f.user.id);
                  return GestureDetector(
                    onTap: () => setSheet(() {
                      sel
                          ? selected.remove(f.user.id)
                          : selected.add(f.user.id);
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: sel
                            ? NimoColors.blue.withOpacity(0.14)
                            : NimoColors.field,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: sel ? NimoColors.blue : NimoColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          NimoAvatar(
                            name: f.user.shownName,
                            url: f.user.avatarUrl,
                            size: 38,
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              f.user.shownName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Icon(
                            sel
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 21,
                            color: sel
                                ? NimoColors.blueBright
                                : NimoColors.textFaint,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  nimoSnack(ctx, 'Dê um nome ao grupo.');
                  return;
                }
                if (selected.isEmpty) {
                  nimoSnack(ctx, 'Escolha pelo menos 1 amigo.');
                  return;
                }
                try {
                  await createGroup(name, selected.toList());
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                } catch (_) {
                  if (ctx.mounted) {
                    nimoSnack(ctx, 'Não foi possível criar o grupo.');
                  }
                }
              },
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: NimoColors.blue,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Criar grupo',
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
    ),
  );
  nameCtrl.dispose();
  return created == true;
}

// ------------------------------------------------------------
// TELA DE CHAT (DM, grupo ou canal de servidor)
// ------------------------------------------------------------
class ChatScreen extends StatefulWidget {
  final String chatId;
  final bool isChannel;
  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final NimoConversation? conversation;
  const ChatScreen({
    super.key,
    required this.chatId,
    required this.isChannel,
    required this.title,
    this.subtitle,
    this.avatarUrl,
    this.conversation,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final Map<String, LiteUser> _users = {};
  bool _sending = false;

  late final Stream<List<Map<String, dynamic>>> _stream = widget.isChannel
      ? supa
          .from('channel_messages')
          .stream(primaryKey: ['id'])
          .eq('channel_id', widget.chatId)
          .order('created_at', ascending: true)
          .limit(300)
      : supa
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('conversation_id', widget.chatId)
          .order('created_at', ascending: true)
          .limit(300);

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureUsers(List<String> ids) async {
    final missing =
        ids.toSet().where((id) => !_users.containsKey(id)).toList();
    if (missing.isEmpty) return;
    try {
      final got = await fetchUsersByIds(missing);
      if (mounted && got.isNotEmpty) {
        setState(() => _users.addAll(got));
      }
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      if (widget.isChannel) {
        await sendChannelMessage(widget.chatId, text);
      } else {
        await sendMessage(widget.chatId, text);
      }
      _msgCtrl.clear();
    } catch (_) {
      if (mounted) nimoSnack(context, 'Não foi possível enviar.');
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _showMembers() async {
    List<LiteUser> members = [];
    try {
      if (!widget.isChannel && widget.conversation != null) {
        members = await fetchConversationMembers(widget.conversation!.id);
      }
    } catch (_) {}
    if (!mounted || members.isEmpty) return;
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

  @override
  Widget build(BuildContext context) {
    final me = supa.auth.currentUser?.id;
    return Scaffold(
      backgroundColor: NimoColors.black,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            const Divider(height: 1, thickness: 1, color: NimoColors.hairline),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _stream,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: NimoColors.textFaint,
                        ),
                      ),
                    );
                  }
                  final msgs = snap.data!;
                  final senders = msgs
                      .map((m) => m['sender_id'] as String)
                      .toList();
                  _ensureUsers(senders);
                  if (msgs.isEmpty) {
                    return Center(
                      child: Text(
                        widget.isChannel
                            ? 'Seja o primeiro a falar neste canal!'
                            : 'Diga um oi para começar!',
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          color: NimoColors.textFaint,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    itemCount: msgs.length,
                    itemBuilder: (context, i) {
                      final m = msgs[msgs.length - 1 - i];
                      final senderId = m['sender_id'] as String;
                      final mine = senderId == me;
                      final user = _users[senderId];
                      final prev = (msgs.length - 1 - i) > 0
                          ? msgs[msgs.length - 2 - i]
                          : null;
                      final showName = !mine &&
                          (prev == null || prev['sender_id'] != senderId);
                      return _bubble(m, mine, user, showName);
                    },
                  );
                },
              ),
            ),
            _inputBar(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          widget.isChannel
              ? Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF17171B),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.tag,
                      size: 21, color: NimoColors.blueBright),
                )
              : NimoAvatar(
                  name: widget.title, url: widget.avatarUrl, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                if (widget.subtitle != null)
                  Text(
                    widget.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: NimoColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (!widget.isChannel && (widget.conversation?.isGroup ?? false))
            IconButton(
              onPressed: _showMembers,
              icon: const Icon(Icons.group_outlined,
                  color: NimoColors.textMuted),
            ),
        ],
      ),
    );
  }

  Widget _bubble(
      Map<String, dynamic> m, bool mine, LiteUser? user, bool showName) {
    final content = (m['content'] ?? '') as String;
    final at = DateTime.parse(m['created_at'] as String).toLocal();
    return Padding(
      padding: EdgeInsets.only(top: showName ? 12 : 3),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showName)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                user?.shownName ?? '...',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: NimoColors.blueBright,
                ),
              ),
            ),
          Row(
            mainAxisAlignment:
                mine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (mine)
                Padding(
                  padding: const EdgeInsets.only(right: 7, bottom: 2),
                  child: Text(
                    timeAgo(at),
                    style: GoogleFonts.inter(
                        fontSize: 10.5, color: NimoColors.textFaint),
                  ),
                ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  constraints: const BoxConstraints(maxWidth: 420),
                  decoration: BoxDecoration(
                    color: mine ? NimoColors.blue : const Color(0xFF17171B),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(mine ? 16 : 5),
                      bottomRight: Radius.circular(mine ? 5 : 16),
                    ),
                  ),
                  child: Text(
                    content,
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      height: 1.35,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (!mine)
                Padding(
                  padding: const EdgeInsets.only(left: 7, bottom: 2),
                  child: Text(
                    timeAgo(at),
                    style: GoogleFonts.inter(
                        fontSize: 10.5, color: NimoColors.textFaint),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: NimoColors.field,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF1D1D22)),
              ),
              child: TextField(
                controller: _msgCtrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                cursorColor: NimoColors.blueBright,
                style: GoogleFonts.inter(
                    fontSize: 15, color: NimoColors.textNormal),
                decoration: InputDecoration(
                  isCollapsed: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                  border: InputBorder.none,
                  hintText: 'Mensagem...',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 15, color: NimoColors.textFaint),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: NimoColors.blue,
                shape: BoxShape.circle,
              ),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      size: 21, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
