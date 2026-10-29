// ============================================================
// NIMO — Amigos: lista, pedidos e adicionar
// ============================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'chat.dart';
import 'social.dart';
import 'status.dart';
import 'theme.dart';

class FriendsScreen extends StatefulWidget {
  final int startTab;
  const FriendsScreen({super.key, this.startTab = 0});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late int _tab = widget.startTab;
  FriendsData _data = const FriendsData([], [], []);
  bool _loading = true;

  // busca
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<LiteUser> _results = [];
  final Map<String, String> _state = {}; // userId -> estado
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await fetchFriendsData();
      if (mounted) {
        setState(() {
          _data = d;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (q.trim().isEmpty) {
        if (mounted) setState(() => _results = []);
        return;
      }
      setState(() => _searching = true);
      try {
        final r = await searchUsers(q);
        final states = <String, String>{};
        for (final u in r) {
          states[u.id] = await friendStateWith(u.id);
        }
        if (mounted) {
          setState(() {
            _results = r;
            _state.addAll(states);
            _searching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NimoColors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Amigos',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  _tabBtn('Amigos', 0, _data.friends.length),
                  const SizedBox(width: 8),
                  _tabBtn('Pedidos', 1, _data.incoming.length),
                  const SizedBox(width: 8),
                  _tabBtn('Adicionar', 2, 0),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _loading
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: NimoColors.textFaint,
                        ),
                      ),
                    )
                  : IndexedStack(
                      index: _tab,
                      children: [
                        _friendsTab(),
                        _requestsTab(),
                        _addTab(),
                      ],
                    ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 280.ms),
    );
  }

  Widget _tabBtn(String label, int idx, int badge) {
    final sel = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: sel ? NimoColors.blue : const Color(0xFF131317),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: sel ? NimoColors.blue : const Color(0xFF222227),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : NimoColors.textMuted,
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: sel ? Colors.white : NimoColors.blue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badge',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: sel ? NimoColors.blue : Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // ABA AMIGOS
  // ----------------------------------------------------------
  Widget _friendsTab() {
    if (_data.friends.isEmpty) {
      return _emptyMsg(Icons.group_outlined,
          'Nenhum amigo ainda.\nUse a aba Adicionar para encontrar pessoas.');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      itemCount: _data.friends.length,
      itemBuilder: (_, i) {
        final f = _data.friends[i];
        return _personTile(
          f.user,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iconBtn(Icons.chat_bubble_outline, NimoColors.blueBright,
                  () => openDmWith(context, f.user)),
              const SizedBox(width: 8),
              _iconBtn(Icons.person_remove_outlined, const Color(0xFFFF5555),
                  () => _confirmRemove(f)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmRemove(Friend f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131317),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Remover amigo?',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(
          '${f.user.shownName} será removido dos seus amigos.',
          style: GoogleFonts.inter(color: NimoColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar',
                style: GoogleFonts.inter(color: NimoColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Remover',
                style: GoogleFonts.inter(color: const Color(0xFFFF5555))),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await deleteFriendship(f.friendshipId);
        _state.remove(f.user.id);
        await _load();
      } catch (_) {}
    }
  }

  // ----------------------------------------------------------
  // ABA PEDIDOS
  // ----------------------------------------------------------
  Widget _requestsTab() {
    if (_data.incoming.isEmpty && _data.outgoing.isEmpty) {
      return _emptyMsg(
          Icons.mark_email_unread_outlined, 'Nenhum pedido pendente.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      children: [
        if (_data.incoming.isNotEmpty) ...[
          _sectionLabel('RECEBIDOS'),
          for (final r in _data.incoming)
            _personTile(
              r.user,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _iconBtn(Icons.check, const Color(0xFF22C55E), () async {
                    try {
                      await acceptFriendRequest(r.id);
                      _state[r.user.id] = 'friends';
                      await _load();
                    } catch (_) {}
                  }),
                  const SizedBox(width: 8),
                  _iconBtn(Icons.close, const Color(0xFFFF5555), () async {
                    try {
                      await deleteFriendship(r.id);
                      _state.remove(r.user.id);
                      await _load();
                    } catch (_) {}
                  }),
                ],
              ),
            ),
          const SizedBox(height: 10),
        ],
        if (_data.outgoing.isNotEmpty) ...[
          _sectionLabel('ENVIADOS'),
          for (final r in _data.outgoing)
            _personTile(
              r.user,
              trailing: _iconBtn(Icons.close, NimoColors.textMuted, () async {
                try {
                  await deleteFriendship(r.id);
                  _state.remove(r.user.id);
                  await _load();
                } catch (_) {}
              }),
            ),
        ],
      ],
    );
  }

  // ----------------------------------------------------------
  // ABA ADICIONAR
  // ----------------------------------------------------------
  Widget _addTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: NimoColors.field,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1D1D22)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 22, color: NimoColors.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onQuery,
                    cursorColor: NimoColors.blueBright,
                    style: GoogleFonts.inter(
                        fontSize: 15, color: NimoColors.textNormal),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Nome ou @nomeunico...',
                      hintStyle: GoogleFonts.inter(
                          fontSize: 15, color: NimoColors.textFaint),
                    ),
                  ),
                ),
                if (_searching)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: NimoColors.textFaint,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _results.isEmpty
              ? _emptyMsg(
                  Icons.person_search_outlined,
                  _searchCtrl.text.trim().isEmpty
                      ? 'Procure pessoas pelo nome\nou pelo @nomeunico.'
                      : 'Ninguém encontrado.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final u = _results[i];
                    return _personTile(u, trailing: _addButton(u));
                  },
                ),
        ),
      ],
    );
  }

  Widget _addButton(LiteUser u) {
    final st = _state[u.id] ?? 'none';
    String label;
    Color bg;
    Color fg;
    VoidCallback? onTap;
    switch (st) {
      case 'friends':
        label = 'Amigos';
        bg = const Color(0xFF17171B);
        fg = const Color(0xFF22C55E);
        onTap = null;
        break;
      case 'sent':
        label = 'Enviado';
        bg = const Color(0xFF17171B);
        fg = NimoColors.textMuted;
        onTap = null;
        break;
      case 'received':
        label = 'Aceitar';
        bg = const Color(0xFF22C55E);
        fg = Colors.white;
        onTap = () async {
          try {
            final res = await sendFriendRequest(u.id);
            if (res == 'accepted') _state[u.id] = 'friends';
            setState(() {});
            await _load();
          } catch (_) {}
        };
        break;
      default:
        label = 'Adicionar';
        bg = NimoColors.blue;
        fg = Colors.white;
        onTap = () async {
          try {
            final res = await sendFriendRequest(u.id);
            _state[u.id] = res == 'accepted' ? 'friends' : 'sent';
            setState(() {});
            await _load();
            if (mounted && res == 'sent') {
              nimoSnack(context, 'Pedido enviado!');
            }
          } catch (_) {
            if (mounted) {
              nimoSnack(context, 'Não foi possível enviar o pedido.');
            }
          }
        };
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // Peças compartilhadas
  // ----------------------------------------------------------
  Widget _personTile(LiteUser u, {required Widget trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: NimoColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: NimoColors.border),
      ),
      child: Row(
        children: [
          NimoAvatar(name: u.shownName, url: u.avatarUrl, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.shownName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '@${u.username}',
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
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF17171B),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF232328)),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(
          t,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: NimoColors.textMuted,
          ),
        ),
      );

  Widget _emptyMsg(IconData icon, String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: NimoColors.textFaint),
          const SizedBox(height: 14),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: NimoColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
