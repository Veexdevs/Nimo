import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'backend.dart';
import 'theme.dart';

// ============================================================
// MODELOS
// ============================================================
class StatusPost {
  final String id;
  final String userId;
  final String kind; // image | text
  final String? mediaUrl;
  final String? textContent;
  final String? bgColor;
  final String? caption;
  final int durationHours;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  int likeCount;
  bool likedByMe;
  int viewCount;
  bool viewedByMe;

  StatusPost({
    required this.id,
    required this.userId,
    required this.kind,
    this.mediaUrl,
    this.textContent,
    this.bgColor,
    this.caption,
    required this.durationHours,
    required this.createdAt,
    required this.expiresAt,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.likeCount = 0,
    this.likedByMe = false,
    this.viewCount = 0,
    this.viewedByMe = false,
  });

  String get shownName =>
      (displayName != null && displayName!.trim().isNotEmpty)
          ? displayName!
          : username;

  bool get isMine => supa.auth.currentUser?.id == userId;

  Color get background {
    if (bgColor == null) return const Color(0xFF123B9E);
    final v = int.tryParse(bgColor!.replaceFirst('#', ''), radix: 16);
    if (v == null) return const Color(0xFF123B9E);
    return Color(0xFF000000 | v);
  }
}

class StatusGroup {
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final List<StatusPost> items;

  StatusGroup({
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.items,
  });

  bool get isMine => supa.auth.currentUser?.id == userId;
  bool get allSeen => items.every((s) => s.viewedByMe || s.isMine);
  String get shownName =>
      (displayName != null && displayName!.trim().isNotEmpty)
          ? displayName!
          : username;
}

// ============================================================
// REPOSITÓRIO
// ============================================================
Future<List<StatusGroup>> fetchStatusGroups() async {
  final me = supa.auth.currentUser;
  if (me == null) return [];

  final rows = await supa
      .from('statuses')
      .select('*, profiles(username, display_name, avatar_url)')
      .gt('expires_at', DateTime.now().toUtc().toIso8601String())
      .order('created_at', ascending: true);

  final posts = <StatusPost>[];
  for (final r in rows as List) {
    final m = r as Map<String, dynamic>;
    final prof = (m['profiles'] ?? {}) as Map<String, dynamic>;
    posts.add(StatusPost(
      id: m['id'] as String,
      userId: m['user_id'] as String,
      kind: m['kind'] as String,
      mediaUrl: m['media_url'] as String?,
      textContent: m['text_content'] as String?,
      bgColor: m['bg_color'] as String?,
      caption: m['caption'] as String?,
      durationHours: (m['duration_hours'] ?? 24) as int,
      createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      expiresAt: DateTime.parse(m['expires_at'] as String).toLocal(),
      username: (prof['username'] ?? '') as String,
      displayName: prof['display_name'] as String?,
      avatarUrl: prof['avatar_url'] as String?,
    ));
  }
  if (posts.isEmpty) return [];

  final ids = posts.map((p) => p.id).toList();

  // curtidas (contagem pública + minhas)
  try {
    final likes = await supa
        .from('status_likes')
        .select('status_id, user_id')
        .inFilter('status_id', ids);
    for (final l in likes as List) {
      final sid = l['status_id'] as String;
      final uid = l['user_id'] as String;
      for (final p in posts.where((p) => p.id == sid)) {
        p.likeCount++;
        if (uid == me.id) p.likedByMe = true;
      }
    }
  } catch (_) {}

  // visualizações (dono vê contagem; eu sei o que já vi)
  try {
    final views = await supa
        .from('status_views')
        .select('status_id, user_id')
        .inFilter('status_id', ids);
    for (final v in views as List) {
      final sid = v['status_id'] as String;
      final uid = v['user_id'] as String;
      for (final p in posts.where((p) => p.id == sid)) {
        if (p.isMine) p.viewCount++;
        if (uid == me.id) p.viewedByMe = true;
      }
    }
  } catch (_) {}

  // agrupa por usuário — o meu primeiro, depois os mais recentes
  final byUser = <String, List<StatusPost>>{};
  for (final p in posts) {
    byUser.putIfAbsent(p.userId, () => []).add(p);
  }
  final groups = byUser.entries.map((e) {
    final first = e.value.first;
    return StatusGroup(
      userId: e.key,
      username: first.username,
      displayName: first.displayName,
      avatarUrl: first.avatarUrl,
      items: e.value,
    );
  }).toList();

  groups.sort((a, b) {
    if (a.isMine != b.isMine) return a.isMine ? -1 : 1;
    return b.items.last.createdAt.compareTo(a.items.last.createdAt);
  });
  return groups;
}

Future<void> createTextStatus({
  required String text,
  required String bgHex,
  String? caption,
  required int hours,
}) async {
  final me = supa.auth.currentUser!;
  await supa.from('statuses').insert({
    'user_id': me.id,
    'kind': 'text',
    'text_content': text,
    'bg_color': bgHex,
    'caption': (caption?.trim().isEmpty ?? true) ? null : caption!.trim(),
    'duration_hours': hours,
    'expires_at':
        DateTime.now().toUtc().add(Duration(hours: hours)).toIso8601String(),
  });
}

Future<void> createImageStatus({
  required Uint8List bytes,
  String? caption,
  required int hours,
}) async {
  final me = supa.auth.currentUser!;
  final path =
      '${me.id}/${DateTime.now().millisecondsSinceEpoch}.png';
  await supa.storage.from('status').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(
          contentType: 'image/png',
          cacheControl: '3600',
        ),
      );
  final url = supa.storage.from('status').getPublicUrl(path);
  await supa.from('statuses').insert({
    'user_id': me.id,
    'kind': 'image',
    'media_url': url,
    'caption': (caption?.trim().isEmpty ?? true) ? null : caption!.trim(),
    'duration_hours': hours,
    'expires_at':
        DateTime.now().toUtc().add(Duration(hours: hours)).toIso8601String(),
  });
}

Future<void> deleteStatus(String id) async {
  await supa.from('statuses').delete().eq('id', id);
}

Future<bool> toggleLike(StatusPost p) async {
  final me = supa.auth.currentUser!;
  if (p.likedByMe) {
    await supa
        .from('status_likes')
        .delete()
        .eq('status_id', p.id)
        .eq('user_id', me.id);
    p.likedByMe = false;
    p.likeCount = (p.likeCount - 1).clamp(0, 1 << 30);
  } else {
    await supa.from('status_likes').upsert(
      {'status_id': p.id, 'user_id': me.id},
      onConflict: 'status_id,user_id',
      ignoreDuplicates: true,
    );
    p.likedByMe = true;
    p.likeCount++;
  }
  return p.likedByMe;
}

Future<void> markViewed(StatusPost p) async {
  if (p.isMine || p.viewedByMe) return;
  final me = supa.auth.currentUser!;
  try {
    await supa.from('status_views').upsert(
      {'status_id': p.id, 'user_id': me.id},
      onConflict: 'status_id,user_id',
      ignoreDuplicates: true,
    );
    p.viewedByMe = true;
  } catch (_) {}
}

Future<List<Map<String, dynamic>>> fetchPeople(
    String table, String statusId) async {
  final rows = await supa
      .from(table)
      .select('created_at, profiles(username, display_name, avatar_url)')
      .eq('status_id', statusId)
      .order('created_at', ascending: false);
  return (rows as List).cast<Map<String, dynamic>>();
}

Future<List<Map<String, dynamic>>> fetchComments(String statusId) async {
  final rows = await supa
      .from('status_comments')
      .select(
          'text, created_at, profiles(username, display_name, avatar_url)')
      .eq('status_id', statusId)
      .order('created_at', ascending: false);
  return (rows as List).cast<Map<String, dynamic>>();
}

Future<void> addComment(String statusId, String text) async {
  final me = supa.auth.currentUser!;
  await supa.from('status_comments').insert({
    'status_id': statusId,
    'user_id': me.id,
    'text': text.trim(),
  });
}

// ============================================================
// HELPERS DE TEMPO
// ============================================================
String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'há ${diff.inHours} h';
  return 'há ${diff.inDays} d';
}

String expiresIn(DateTime d) {
  final diff = d.difference(DateTime.now());
  if (diff.isNegative) return 'expirado';
  if (diff.inMinutes < 60) return 'expira em ${diff.inMinutes} min';
  if (diff.inHours < 48) return 'expira em ${diff.inHours} h';
  return 'expira em ${diff.inDays} d';
}

String durationLabel(int hours) =>
    hours < 24 ? '$hours h' : '${hours ~/ 24} ${hours == 24 ? 'dia' : 'dias'}';

void nimoSnack(BuildContext context, String msg) {
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

// ============================================================
// FAIXA DE STATUS (fila horizontal na tela Mensagens)
// ============================================================
class StatusStrip extends StatefulWidget {
  const StatusStrip({super.key});

  @override
  State<StatusStrip> createState() => StatusStripState();
}

class StatusStripState extends State<StatusStrip> {
  List<StatusGroup> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (!isLoggedIn) {
      if (mounted) setState(() => _groups = []);
      return;
    }
    try {
      final g = await fetchStatusGroups();
      if (mounted) {
        setState(() {
          _groups = g;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) return const SizedBox.shrink();

    final mine =
        _groups.where((g) => g.isMine).toList();
    final others = _groups.where((g) => !g.isMine).toList();

    return SizedBox(
      height: 112,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: [
          _myTile(mine.isEmpty ? null : mine.first),
          const SizedBox(width: 14),
          for (final g in others) ...[
            _groupTile(g),
            const SizedBox(width: 14),
          ],
          if (_loading && _groups.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 6, top: 30),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: NimoColors.textFaint,
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _avatarCircle(String? url, {double size = 64}) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF17171B),
      ),
      child: url != null
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.person_outline,
                size: 28,
                color: NimoColors.textMuted,
              ),
            )
          : const Icon(
              Icons.person_outline,
              size: 28,
              color: NimoColors.textMuted,
            ),
    );
  }

  Widget _myTile(StatusGroup? mine) {
    return GestureDetector(
      onTap: () async {
        if (mine == null) {
          await showStatusComposer(context);
        } else {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => StatusViewerScreen(group: mine),
          ));
        }
        refresh();
      },
      onLongPress: () async {
        await showStatusComposer(context);
        refresh();
      },
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: mine != null
                        ? NimoColors.blueBright
                        : const Color(0xFF26262B),
                    width: 2.4,
                  ),
                ),
                child: _avatarCircle(
                  mine?.avatarUrl,
                  size: 62,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: NimoColors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: NimoColors.black, width: 2),
                  ),
                  child:
                      const Icon(Icons.add, size: 15, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Meu status',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: NimoColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupTile(StatusGroup g) {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => StatusViewerScreen(group: g),
        ));
        refresh();
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: g.allSeen
                    ? const Color(0xFF34343C)
                    : NimoColors.blueBright,
                width: 2.4,
              ),
            ),
            child: _avatarCircle(g.avatarUrl, size: 62),
          ),
          const SizedBox(height: 7),
          SizedBox(
            width: 74,
            child: Text(
              g.shownName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: NimoColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CRIAR STATUS
// ============================================================
Future<void> showStatusComposer(BuildContext context) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: const Color(0xFF101014),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 14),
          Text(
            'Postar status',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          _composerOption(ctx, Icons.image_outlined, 'Foto',
              'Escolha uma imagem da galeria', 'image'),
          _composerOption(ctx, Icons.text_fields, 'Texto',
              'Escreva com emojis e cor de fundo', 'text'),
          _composerOption(ctx, Icons.videocam_outlined, 'Vídeo e música',
              'Em breve', null),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  if (choice == 'text') {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const TextStatusComposer(),
    ));
  } else if (choice == 'image') {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1600, imageQuality: 88);
    if (file == null || !context.mounted) return;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ImageStatusComposer(bytes: bytes),
    ));
  }
}

Widget _composerOption(BuildContext ctx, IconData icon, String title,
    String subtitle, String? value) {
  final enabled = value != null;
  return ListTile(
    enabled: enabled,
    onTap: enabled ? () => Navigator.of(ctx).pop(value) : null,
    leading: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: enabled
            ? NimoColors.blue.withOpacity(0.14)
            : const Color(0xFF17171B),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon,
          size: 22,
          color: enabled ? NimoColors.blueBright : NimoColors.textFaint),
    ),
    title: Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        color: enabled ? Colors.white : NimoColors.textFaint,
      ),
    ),
    subtitle: Text(
      subtitle,
      style: GoogleFonts.inter(
        fontSize: 12.5,
        color: NimoColors.textFaint,
      ),
    ),
    trailing: enabled
        ? const Icon(Icons.chevron_right,
            color: NimoColors.textMuted, size: 22)
        : Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF17171B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF26262B)),
            ),
            child: Text(
              'EM BREVE',
              style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: NimoColors.textFaint,
              ),
            ),
          ),
  );
}

const _durations = [1, 3, 6, 12, 24, 48];
const _bgColors = [
  Color(0xFF123B9E),
  Color(0xFF0B0B0E),
  Color(0xFF7C1D1D),
  Color(0xFF14532D),
  Color(0xFF6D28D9),
  Color(0xFF9A3412),
  Color(0xFF155E75),
  Color(0xFF831843),
];

String _hex(Color c) =>
    '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Composer de status de TEXTO
class TextStatusComposer extends StatefulWidget {
  const TextStatusComposer({super.key});

  @override
  State<TextStatusComposer> createState() => _TextStatusComposerState();
}

class _TextStatusComposerState extends State<TextStatusComposer> {
  final _text = TextEditingController();
  final _caption = TextEditingController();
  Color _bg = _bgColors.first;
  int _hours = 24;
  bool _posting = false;

  @override
  void dispose() {
    _text.dispose();
    _caption.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    if (_text.text.trim().isEmpty) {
      nimoSnack(context, 'Escreva alguma coisa primeiro.');
      return;
    }
    setState(() => _posting = true);
    try {
      await createTextStatus(
        text: _text.text.trim(),
        bgHex: _hex(_bg),
        caption: _caption.text,
        hours: _hours,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      nimoSnack(context, 'Status publicado!');
    } catch (_) {
      if (!mounted) return;
      setState(() => _posting = false);
      nimoSnack(context, 'Não foi possível publicar. Tente de novo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NimoColors.black,
      body: SafeArea(
        child: Column(
          children: [
            _composerTopBar(context, 'Status de texto'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: TextField(
                      controller: _text,
                      maxLines: null,
                      maxLength: 300,
                      textAlign: TextAlign.center,
                      cursorColor: Colors.white,
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.35,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(24),
                        hintText: 'Escreva aqui...\nemojis valem!',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.45),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // cores de fundo
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                children: [
                  for (final c in _bgColors)
                    GestureDetector(
                      onTap: () => setState(() => _bg = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _bg == c
                                ? Colors.white
                                : const Color(0xFF26262B),
                            width: _bg == c ? 2.4 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _captionAndDuration(
              caption: _caption,
              hours: _hours,
              onHours: (h) => setState(() => _hours = h),
              posting: _posting,
              onPost: _post,
            ),
          ],
        ),
      ),
    );
  }
}

/// Composer de status de FOTO
class ImageStatusComposer extends StatefulWidget {
  final Uint8List bytes;
  const ImageStatusComposer({super.key, required this.bytes});

  @override
  State<ImageStatusComposer> createState() => _ImageStatusComposerState();
}

class _ImageStatusComposerState extends State<ImageStatusComposer> {
  final _caption = TextEditingController();
  int _hours = 24;
  bool _posting = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    setState(() => _posting = true);
    try {
      await createImageStatus(
        bytes: widget.bytes,
        caption: _caption.text,
        hours: _hours,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      nimoSnack(context, 'Status publicado!');
    } catch (_) {
      if (!mounted) return;
      setState(() => _posting = false);
      nimoSnack(context, 'Não foi possível publicar. Tente de novo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NimoColors.black,
      body: SafeArea(
        child: Column(
          children: [
            _composerTopBar(context, 'Status de foto'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFF101014),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Image.memory(widget.bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            _captionAndDuration(
              caption: _caption,
              hours: _hours,
              onHours: (h) => setState(() => _hours = h),
              posting: _posting,
              onPost: _post,
            ),
          ],
        ),
      ),
    );
  }
}

Widget _composerTopBar(BuildContext context, String title) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
    child: Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 2),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
}

class _captionAndDuration extends StatelessWidget {
  final TextEditingController caption;
  final int hours;
  final void Function(int) onHours;
  final bool posting;
  final VoidCallback onPost;

  const _captionAndDuration({
    required this.caption,
    required this.hours,
    required this.onHours,
    required this.posting,
    required this.onPost,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: caption,
            maxLength: 200,
            cursorColor: NimoColors.blueBright,
            style: GoogleFonts.inter(
                fontSize: 14.5, color: NimoColors.textNormal),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Adicionar descrição (opcional)',
              hintStyle: GoogleFonts.inter(
                  fontSize: 14.5, color: NimoColors.textFaint),
              filled: true,
              fillColor: NimoColors.field,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule,
                  size: 17, color: NimoColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'Duração:',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: NimoColors.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final h in _durations)
                        GestureDetector(
                          onTap: () => onHours(h),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: hours == h
                                  ? NimoColors.blue
                                  : NimoColors.field,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: hours == h
                                    ? NimoColors.blue
                                    : const Color(0xFF26262B),
                              ),
                            ),
                            child: Text(
                              durationLabel(h),
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: hours == h
                                    ? Colors.white
                                    : NimoColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: posting ? null : onPost,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: posting
                    ? NimoColors.blue.withOpacity(0.6)
                    : NimoColors.blue,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: posting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(
                      'Postar status',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
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

// ============================================================
// VISUALIZADOR DE STATUS
// ============================================================
class StatusViewerScreen extends StatefulWidget {
  final StatusGroup group;
  const StatusViewerScreen({super.key, required this.group});

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen> {
  late final PageController _page = PageController();
  final _comment = TextEditingController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    markViewed(widget.group.items.first);
  }

  @override
  void dispose() {
    _page.dispose();
    _comment.dispose();
    super.dispose();
  }

  StatusPost get _current => widget.group.items[_index];

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131317),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: Text('Apagar status?',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text('Essa ação não pode ser desfeita.',
            style: GoogleFonts.inter(color: NimoColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar',
                style: GoogleFonts.inter(color: NimoColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Apagar',
                style: GoogleFonts.inter(
                    color: NimoColors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await deleteStatus(_current.id);
      if (!mounted) return;
      widget.group.items.removeAt(_index);
      if (widget.group.items.isEmpty) {
        Navigator.of(context).pop();
      } else {
        setState(() => _index = _index.clamp(0, widget.group.items.length - 1));
      }
    } catch (_) {
      if (mounted) nimoSnack(context, 'Não foi possível apagar.');
    }
  }

  Future<void> _sendComment() async {
    final t = _comment.text.trim();
    if (t.isEmpty) return;
    try {
      await addComment(_current.id, t);
      _comment.clear();
      FocusScope.of(context).unfocus();
      if (mounted) {
        nimoSnack(context,
            'Comentário enviado para @${_current.username}.');
      }
    } catch (_) {
      if (mounted) nimoSnack(context, 'Não foi possível comentar.');
    }
  }

  void _showPeople() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101014),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _StatusStatsSheet(post: _current),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _current;
    final total = widget.group.items.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // barras de progresso
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: List.generate(total, (i) {
                  return Expanded(
                    child: Container(
                      height: 3.5,
                      margin: EdgeInsets.only(
                          right: i == total - 1 ? 0 : 5),
                      decoration: BoxDecoration(
                        color: i <= _index
                            ? Colors.white
                            : Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // cabeçalho
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF17171B),
                    ),
                    child: p.avatarUrl != null
                        ? Image.network(p.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.person_outline,
                                size: 20,
                                color: NimoColors.textMuted))
                        : const Icon(Icons.person_outline,
                            size: 20, color: NimoColors.textMuted),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.shownName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${timeAgo(p.createdAt)}  •  ${expiresIn(p.expiresAt)}  •  ${durationLabel(p.durationHours)}',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (p.isMine) ...[
                    IconButton(
                      onPressed: _showPeople,
                      icon: const Icon(Icons.visibility_outlined,
                          color: Colors.white, size: 22),
                    ),
                    IconButton(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.white, size: 22),
                    ),
                  ],
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close,
                        color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),
            // conteúdo
            Expanded(
              child: GestureDetector(
                onTapUp: (d) {
                  final w = MediaQuery.of(context).size.width;
                  if (d.globalPosition.dx > w / 2) {
                    if (_index < total - 1) {
                      setState(() => _index++);
                      markViewed(_current);
                    }
                  } else {
                    if (_index > 0) setState(() => _index--);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: p.kind == 'text'
                          ? p.background
                          : const Color(0xFF0B0B0E),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    width: double.infinity,
                    child: p.kind == 'text'
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(26),
                              child: Text(
                                p.textContent ?? '',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          )
                        : (p.mediaUrl != null
                            ? Image.network(
                                p.mediaUrl!,
                                fit: BoxFit.contain,
                                loadingBuilder: (c, child, prog) =>
                                    prog == null
                                        ? child
                                        : const Center(
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white38,
                                            ),
                                          ),
                                errorBuilder: (_, __, ___) =>
                                    const Center(
                                  child: Icon(Icons.broken_image_outlined,
                                      size: 40,
                                      color: NimoColors.textFaint),
                                ),
                              )
                            : const SizedBox.shrink()),
                  ),
                ),
              ),
            ),
            // legenda
            if (p.caption != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(
                  p.caption!,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ),
            // rodapé: curtir + comentar
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      try {
                        await toggleLike(p);
                        if (mounted) setState(() {});
                      } catch (_) {}
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF17171B),
                        borderRadius: BorderRadius.circular(13),
                        border:
                            Border.all(color: const Color(0xFF26262B)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            p.likedByMe
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 20,
                            color: p.likedByMe
                                ? NimoColors.red
                                : Colors.white,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            '${p.likeCount}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (p.isMine) ...[
                    GestureDetector(
                      onTap: _showPeople,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF17171B),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                              color: const Color(0xFF26262B)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.visibility_outlined,
                                size: 20, color: Colors.white),
                            const SizedBox(width: 7),
                            Text(
                              '${p.viewCount}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                  ] else
                    Expanded(
                      child: TextField(
                        controller: _comment,
                        maxLength: 500,
                        cursorColor: NimoColors.blueBright,
                        style: GoogleFonts.inter(
                            fontSize: 14, color: Colors.white),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'Comentar...',
                          hintStyle: GoogleFonts.inter(
                              fontSize: 14, color: NimoColors.textFaint),
                          filled: true,
                          fillColor: const Color(0xFF17171B),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 11),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(13),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            onPressed: _sendComment,
                            icon: const Icon(Icons.send,
                                size: 19, color: NimoColors.blueBright),
                          ),
                        ),
                        onSubmitted: (_) => _sendComment(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quem viu / quem curtiu / comentários (só o dono)
class _StatusStatsSheet extends StatefulWidget {
  final StatusPost post;
  const _StatusStatsSheet({required this.post});

  @override
  State<_StatusStatsSheet> createState() => _StatusStatsSheetState();
}

class _StatusStatsSheetState extends State<_StatusStatsSheet> {
  int _tab = 0;
  List<Map<String, dynamic>>? _views;
  List<Map<String, dynamic>>? _likes;
  List<Map<String, dynamic>>? _comments;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await fetchPeople('status_views', widget.post.id);
      final l = await fetchPeople('status_likes', widget.post.id);
      final c = await fetchComments(widget.post.id);
      if (mounted) {
        setState(() {
          _views = v;
          _likes = l;
          _comments = c;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _views = [];
          _likes = [];
          _comments = [];
        });
      }
    }
  }

  Widget _tabButton(int i, String label, int? count) {
    final active = _tab == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? NimoColors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Text(
            count == null ? label : '$label ($count)',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : NimoColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = [_views, _likes, _comments][_tab];

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: NimoColors.field,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _tabButton(0, 'Viram', _views?.length),
                  _tabButton(1, 'Curtiram', _likes?.length),
                  _tabButton(2, 'Comentários', _comments?.length),
                ],
              ),
            ),
          ),
          Expanded(
            child: list == null
                ? const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: NimoColors.textFaint),
                  )
                : list.isEmpty
                    ? Center(
                        child: Text(
                          'Ninguém por aqui ainda.',
                          style: GoogleFonts.inter(
                              fontSize: 14, color: NimoColors.textFaint),
                        ),
                      )
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final m = list[i];
                          final prof = (m['profiles'] ?? {})
                              as Map<String, dynamic>;
                          final name = (prof['display_name'] as String?)
                                      ?.trim()
                                      .isNotEmpty ==
                                  true
                              ? prof['display_name'] as String
                              : (prof['username'] ?? '') as String;
                          return ListTile(
                            leading: Container(
                              width: 42,
                              height: 42,
                              clipBehavior: Clip.antiAlias,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF17171B),
                              ),
                              child: prof['avatar_url'] != null
                                  ? Image.network(
                                      prof['avatar_url'] as String,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.person_outline,
                                              size: 20,
                                              color:
                                                  NimoColors.textMuted))
                                  : const Icon(Icons.person_outline,
                                      size: 20,
                                      color: NimoColors.textMuted),
                            ),
                            title: Text(
                              name,
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Text(
                              _tab == 2
                                  ? (m['text'] ?? '') as String
                                  : '@${prof['username'] ?? ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: NimoColors.textMuted,
                              ),
                            ),
                            trailing: Text(
                              timeAgo(DateTime.parse(
                                      m['created_at'] as String)
                                  .toLocal()),
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: NimoColors.textFaint,
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
