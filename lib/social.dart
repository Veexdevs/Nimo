// ============================================================
// NIMO — camada social: amigos, conversas, grupos e servidores
// ============================================================
import 'backend.dart';

// ------------------------------------------------------------
// MODELOS
// ------------------------------------------------------------
class LiteUser {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  const LiteUser({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
  });

  String get shownName =>
      (displayName?.trim().isNotEmpty ?? false) ? displayName! : '@$username';

  factory LiteUser.fromMap(Map<String, dynamic> m) => LiteUser(
        id: m['id'] as String,
        username: (m['username'] ?? '') as String,
        displayName: m['display_name'] as String?,
        avatarUrl: m['avatar_url'] as String?,
      );
}

class FriendRequest {
  final String id;
  final LiteUser user; // a outra pessoa
  final bool incoming; // true = recebido, false = enviado
  const FriendRequest({
    required this.id,
    required this.user,
    required this.incoming,
  });
}

class Friend {
  final String friendshipId;
  final LiteUser user;
  const Friend({required this.friendshipId, required this.user});
}

class NimoConversation {
  final String id;
  final String kind; // dm | group
  final String? name;
  final String? iconUrl;
  final String? ownerId;
  final LiteUser? other; // para DMs
  String? lastMessage;
  DateTime? lastAt;
  int memberCount;

  NimoConversation({
    required this.id,
    required this.kind,
    this.name,
    this.iconUrl,
    this.ownerId,
    this.other,
    this.lastMessage,
    this.lastAt,
    this.memberCount = 0,
  });

  bool get isGroup => kind == 'group';
  String get title =>
      isGroup ? (name ?? 'Grupo') : (other?.shownName ?? 'Conversa');
  String? get avatarUrl => isGroup ? iconUrl : other?.avatarUrl;
}

class NimoServer {
  final String id;
  final String name;
  final String? iconUrl;
  final String ownerId;
  final String inviteCode;
  const NimoServer({
    required this.id,
    required this.name,
    this.iconUrl,
    required this.ownerId,
    required this.inviteCode,
  });

  bool get isMine => supa.auth.currentUser?.id == ownerId;

  factory NimoServer.fromMap(Map<String, dynamic> m) => NimoServer(
        id: m['id'] as String,
        name: (m['name'] ?? '') as String,
        iconUrl: m['icon_url'] as String?,
        ownerId: m['owner_id'] as String,
        inviteCode: (m['invite_code'] ?? '') as String,
      );
}

class NimoChannel {
  final String id;
  final String serverId;
  final String name;
  const NimoChannel({
    required this.id,
    required this.serverId,
    required this.name,
  });

  factory NimoChannel.fromMap(Map<String, dynamic> m) => NimoChannel(
        id: m['id'] as String,
        serverId: m['server_id'] as String,
        name: (m['name'] ?? '') as String,
      );
}

// ------------------------------------------------------------
// PERFIS (cache leve)
// ------------------------------------------------------------
final Map<String, LiteUser> _userCache = {};

Future<Map<String, LiteUser>> fetchUsersByIds(List<String> ids) async {
  final missing =
      ids.toSet().where((id) => !_userCache.containsKey(id)).toList();
  if (missing.isNotEmpty) {
    final rows = await supa
        .from('profiles')
        .select('id, username, display_name, avatar_url')
        .inFilter('id', missing);
    for (final r in rows as List) {
      final u = LiteUser.fromMap(r as Map<String, dynamic>);
      _userCache[u.id] = u;
    }
  }
  return {for (final id in ids.toSet()) if (_userCache[id] != null) id: _userCache[id]!};
}

Future<List<LiteUser>> searchUsers(String query) async {
  final q = query.trim().replaceAll('@', '');
  if (q.isEmpty) return [];
  final me = supa.auth.currentUser?.id;
  final rows = await supa
      .from('profiles')
      .select('id, username, display_name, avatar_url')
      .or('username.ilike.%$q%,display_name.ilike.%$q%')
      .limit(15);
  return (rows as List)
      .map((r) => LiteUser.fromMap(r as Map<String, dynamic>))
      .where((u) => u.id != me)
      .toList();
}

// ------------------------------------------------------------
// AMIGOS
// ------------------------------------------------------------
/// 'none' | 'friends' | 'sent' | 'received'
Future<String> friendStateWith(String otherId) async {
  final me = supa.auth.currentUser!.id;
  final rows = await supa
      .from('friendships')
      .select('requester, addressee, status')
      .or('and(requester.eq.$me,addressee.eq.$otherId),and(requester.eq.$otherId,addressee.eq.$me)');
  if ((rows as List).isEmpty) return 'none';
  final r = rows.first as Map<String, dynamic>;
  if (r['status'] == 'accepted') return 'friends';
  return r['requester'] == me ? 'sent' : 'received';
}

/// Envia pedido; se já existir pedido da outra pessoa, aceita direto.
/// Retorna: 'sent' | 'accepted' | 'already'
Future<String> sendFriendRequest(String otherId) async {
  final me = supa.auth.currentUser!.id;
  final rows = await supa
      .from('friendships')
      .select('id, requester, status')
      .or('and(requester.eq.$me,addressee.eq.$otherId),and(requester.eq.$otherId,addressee.eq.$me)');
  if ((rows as List).isNotEmpty) {
    final r = rows.first as Map<String, dynamic>;
    if (r['status'] == 'accepted') return 'already';
    if (r['requester'] == otherId) {
      await supa
          .from('friendships')
          .update({'status': 'accepted'}).eq('id', r['id'] as String);
      return 'accepted';
    }
    return 'already';
  }
  await supa
      .from('friendships')
      .insert({'requester': me, 'addressee': otherId});
  return 'sent';
}

Future<void> acceptFriendRequest(String friendshipId) async {
  await supa
      .from('friendships')
      .update({'status': 'accepted'}).eq('id', friendshipId);
}

Future<void> deleteFriendship(String friendshipId) async {
  await supa.from('friendships').delete().eq('id', friendshipId);
}

class FriendsData {
  final List<Friend> friends;
  final List<FriendRequest> incoming;
  final List<FriendRequest> outgoing;
  const FriendsData(this.friends, this.incoming, this.outgoing);
}

Future<FriendsData> fetchFriendsData() async {
  final me = supa.auth.currentUser!.id;
  final rows = await supa
      .from('friendships')
      .select('id, requester, addressee, status')
      .or('requester.eq.$me,addressee.eq.$me');
  final list = (rows as List).cast<Map<String, dynamic>>();

  final otherIds = <String>[];
  for (final r in list) {
    otherIds.add(r['requester'] == me
        ? r['addressee'] as String
        : r['requester'] as String);
  }
  final users = await fetchUsersByIds(otherIds);

  final friends = <Friend>[];
  final incoming = <FriendRequest>[];
  final outgoing = <FriendRequest>[];
  for (final r in list) {
    final otherId = r['requester'] == me
        ? r['addressee'] as String
        : r['requester'] as String;
    final u = users[otherId];
    if (u == null) continue;
    final fid = r['id'] as String;
    if (r['status'] == 'accepted') {
      friends.add(Friend(friendshipId: fid, user: u));
    } else if (r['requester'] == me) {
      outgoing.add(FriendRequest(id: fid, user: u, incoming: false));
    } else {
      incoming.add(FriendRequest(id: fid, user: u, incoming: true));
    }
  }
  friends.sort((a, b) => a.user.shownName
      .toLowerCase()
      .compareTo(b.user.shownName.toLowerCase()));
  return FriendsData(friends, incoming, outgoing);
}

// ------------------------------------------------------------
// CONVERSAS (DM e GRUPO)
// ------------------------------------------------------------
Future<List<NimoConversation>> fetchConversations() async {
  final me = supa.auth.currentUser!.id;
  final rows = await supa
      .from('conversation_members')
      .select(
          'conversation:conversations(id, kind, name, icon_url, owner_id, created_at)')
      .eq('user_id', me);

  final convs = <NimoConversation>[];
  final ids = <String>[];
  final raw = <String, Map<String, dynamic>>{};
  for (final r in rows as List) {
    final c = (r as Map<String, dynamic>)['conversation'];
    if (c == null) continue;
    final m = c as Map<String, dynamic>;
    ids.add(m['id'] as String);
    raw[m['id'] as String] = m;
  }
  if (ids.isEmpty) return [];

  // membros (para achar o "outro" nas DMs e contar nos grupos)
  final memRows = await supa
      .from('conversation_members')
      .select('conversation_id, user_id')
      .inFilter('conversation_id', ids);
  final membersByConv = <String, List<String>>{};
  for (final r in memRows as List) {
    final m = r as Map<String, dynamic>;
    membersByConv
        .putIfAbsent(m['conversation_id'] as String, () => [])
        .add(m['user_id'] as String);
  }
  final otherIds = <String>[];
  for (final e in membersByConv.entries) {
    for (final uid in e.value) {
      if (uid != me) otherIds.add(uid);
    }
  }
  final users = await fetchUsersByIds(otherIds);

  // últimas mensagens
  final msgRows = await supa
      .from('messages')
      .select('conversation_id, content, created_at')
      .inFilter('conversation_id', ids)
      .order('created_at', ascending: false)
      .limit(400);
  final lastByConv = <String, Map<String, dynamic>>{};
  for (final r in msgRows as List) {
    final m = r as Map<String, dynamic>;
    lastByConv.putIfAbsent(m['conversation_id'] as String, () => m);
  }

  for (final id in ids) {
    final m = raw[id]!;
    final members = membersByConv[id] ?? [];
    LiteUser? other;
    if (m['kind'] == 'dm') {
      final otherId =
          members.where((u) => u != me).cast<String?>().firstWhere(
                (e) => true,
                orElse: () => null,
              );
      if (otherId != null) other = users[otherId];
    }
    final last = lastByConv[id];
    convs.add(NimoConversation(
      id: id,
      kind: m['kind'] as String,
      name: m['name'] as String?,
      iconUrl: m['icon_url'] as String?,
      ownerId: m['owner_id'] as String?,
      other: other,
      memberCount: members.length,
      lastMessage: last?['content'] as String?,
      lastAt: last == null
          ? DateTime.parse(m['created_at'] as String).toLocal()
          : DateTime.parse(last['created_at'] as String).toLocal(),
    ));
  }
  convs.sort((a, b) => (b.lastAt ?? DateTime(2000))
      .compareTo(a.lastAt ?? DateTime(2000)));
  return convs;
}

Future<String> openDm(String otherUserId) async {
  final res = await supa.rpc('get_or_create_dm', params: {'other': otherUserId});
  return res as String;
}

Future<String> createGroup(String name, List<String> memberIds) async {
  final res = await supa.rpc('create_group', params: {
    'gname': name,
    'member_ids': memberIds,
  });
  return res as String;
}

Future<List<LiteUser>> fetchConversationMembers(String conversationId) async {
  final rows = await supa
      .from('conversation_members')
      .select('user_id')
      .eq('conversation_id', conversationId);
  final ids =
      (rows as List).map((r) => (r as Map)['user_id'] as String).toList();
  final users = await fetchUsersByIds(ids);
  final list = users.values.toList()
    ..sort((a, b) =>
        a.shownName.toLowerCase().compareTo(b.shownName.toLowerCase()));
  return list;
}

Future<void> leaveConversation(String conversationId) async {
  final me = supa.auth.currentUser!.id;
  await supa
      .from('conversation_members')
      .delete()
      .eq('conversation_id', conversationId)
      .eq('user_id', me);
}

Future<void> deleteConversation(String conversationId) async {
  await supa.from('conversations').delete().eq('id', conversationId);
}

Future<void> sendMessage(String conversationId, String text) async {
  final me = supa.auth.currentUser!.id;
  await supa.from('messages').insert({
    'conversation_id': conversationId,
    'sender_id': me,
    'content': text.trim(),
  });
}

// ------------------------------------------------------------
// SERVIDORES
// ------------------------------------------------------------
Future<List<NimoServer>> fetchMyServers() async {
  final me = supa.auth.currentUser!.id;
  final rows = await supa
      .from('server_members')
      .select('joined_at, server:servers(id, name, icon_url, owner_id, invite_code)')
      .eq('user_id', me)
      .order('joined_at', ascending: true);
  final out = <NimoServer>[];
  for (final r in rows as List) {
    final s = (r as Map<String, dynamic>)['server'];
    if (s != null) out.add(NimoServer.fromMap(s as Map<String, dynamic>));
  }
  return out;
}

Future<NimoServer> createServer(String name) async {
  final me = supa.auth.currentUser!.id;
  final row = await supa
      .from('servers')
      .insert({'name': name.trim(), 'owner_id': me})
      .select()
      .single();
  return NimoServer.fromMap(row);
}

Future<String> joinServerByCode(String code) async {
  final res = await supa.rpc('join_server_by_code', params: {'code': code});
  return res as String;
}

Future<void> leaveServer(String serverId) async {
  final me = supa.auth.currentUser!.id;
  await supa
      .from('server_members')
      .delete()
      .eq('server_id', serverId)
      .eq('user_id', me);
}

Future<void> deleteServer(String serverId) async {
  await supa.from('servers').delete().eq('id', serverId);
}

Future<List<NimoChannel>> fetchChannels(String serverId) async {
  final rows = await supa
      .from('channels')
      .select('id, server_id, name')
      .eq('server_id', serverId)
      .order('position', ascending: true)
      .order('created_at', ascending: true);
  return (rows as List)
      .map((r) => NimoChannel.fromMap(r as Map<String, dynamic>))
      .toList();
}

Future<void> createChannel(String serverId, String name) async {
  await supa.from('channels').insert({
    'server_id': serverId,
    'name': name.trim().toLowerCase().replaceAll(' ', '-'),
  });
}

Future<void> deleteChannel(String channelId) async {
  await supa.from('channels').delete().eq('id', channelId);
}

Future<List<LiteUser>> fetchServerMembers(String serverId) async {
  final rows = await supa
      .from('server_members')
      .select('user_id')
      .eq('server_id', serverId);
  final ids =
      (rows as List).map((r) => (r as Map)['user_id'] as String).toList();
  final users = await fetchUsersByIds(ids);
  final list = users.values.toList()
    ..sort((a, b) =>
        a.shownName.toLowerCase().compareTo(b.shownName.toLowerCase()));
  return list;
}

Future<void> sendChannelMessage(String channelId, String text) async {
  final me = supa.auth.currentUser!.id;
  await supa.from('channel_messages').insert({
    'channel_id': channelId,
    'sender_id': me,
    'content': text.trim(),
  });
}
