import 'package:flutter/material.dart';
import 'theme.dart';

enum Presence { online, idle, dnd, none }

/// Quem postou status (fileira do topo)
class StatusUser {
  final String avatar;
  final bool isNew; // não visto = anel verde
  const StatusUser(this.avatar, this.isNew);
}

const statusUsers = [
  StatusUser('assets/avatars/av_robot.jpg', true),
  StatusUser('assets/avatars/av_silver.jpg', true),
  StatusUser('assets/avatars/av_sea.jpg', true),
  StatusUser('assets/avatars/av_mono.jpg', false),
  StatusUser('assets/avatars/av_purple.jpg', false),
  StatusUser('assets/avatars/av_shadow.jpg', false),
];

/// Insígnia/tag ao lado do nome
class Tag {
  final IconData icon;
  final Color iconColor;
  final String label;
  const Tag(this.icon, this.iconColor, this.label);
}

const tagThr3 = Tag(Icons.local_fire_department, Color(0xFFE8563F), 'THR3');
const tagSync = Tag(Icons.sync, Color(0xFF3BA55D), 'SynC');
const tagRing = Tag(Icons.security, Color(0xFF4ADE80), 'RING');
const tagCmnd = Tag(Icons.terminal, Color(0xFFA78BFA), 'CMND');
const tagSkull = Tag(Icons.dangerous, Color(0xFF9CA3AF), 'skull');
const tagSnek = Tag(Icons.gavel, Color(0xFF93A6C8), 'snek');

/// Conversa direta (DM)
class DmChat {
  final String name;
  final String? avatar;
  final Tag? tag;
  final bool botTag; // selo azul "APP"
  final bool botAvatar; // avatar quadrado de bot
  final bool medals; // medalhas ao lado do nome
  final bool serif; // nome em serifa itálica
  final bool devSup; // sufixo "dev" sobrescrito
  final String preview;
  final String time;
  final Presence presence;

  const DmChat({
    required this.name,
    this.avatar,
    this.tag,
    this.botTag = false,
    this.botAvatar = false,
    this.medals = false,
    this.serif = false,
    this.devSup = false,
    required this.preview,
    required this.time,
    this.presence = Presence.none,
  });
}

const dms = [
  DmChat(
    name: 'Ghost',
    avatar: 'assets/avatars/av_ghost.jpg',
    tag: tagThr3,
    preview: 'Ghost: Amanhã nos se fala',
    time: '33m',
    presence: Presence.none,
  ),
  DmChat(
    name: 'Not.Rival.Dev',
    avatar: 'assets/avatars/av_silver.jpg',
    tag: tagSync,
    preview: 'Você: Tá bom',
    time: '6h',
    presence: Presence.none,
  ),
  DmChat(
    name: 'Nimo',
    botAvatar: true,
    botTag: true,
    preview: '/convite | nimo.app',
    time: '7h',
    presence: Presence.online,
  ),
  DmChat(
    name: 'Deltax',
    avatar: 'assets/avatars/av_duck.jpg',
    preview: 'Você: Vlw',
    time: '8h',
    presence: Presence.none,
  ),
  DmChat(
    name: 'TLK777yt',
    avatar: 'assets/avatars/av_hacker.jpg',
    tag: tagRing,
    preview: 'TLK777yt: Slk... fd',
    time: '9h',
    presence: Presence.none,
  ),
  DmChat(
    name: 'nossa',
    devSup: true,
    avatar: 'assets/avatars/av_robot.jpg',
    tag: tagSync,
    preview: 'NOSSAᵈᵉᵛ: Oloco',
    time: '11h',
    presence: Presence.none,
  ),
  DmChat(
    name: 'CARDOSO',
    avatar: 'assets/avatars/av_purple.jpg',
    tag: tagSync,
    preview: 'CARDOSO: Irei descansar tbm',
    time: '22h',
    presence: Presence.none,
  ),
  DmChat(
    name: 'ARTHURX9LL',
    avatar: 'assets/avatars/av_denolk.jpg',
    medals: true,
    preview: 'ARTHURX9LL: De qualquer for...',
    time: '23h',
    presence: Presence.none,
  ),
  DmChat(
    name: 'Q_244',
    avatar: 'assets/avatars/av_mono.jpg',
    tag: tagCmnd,
    preview: 'Você: Tá entregue',
    time: '2d',
    presence: Presence.none,
  ),
  DmChat(
    name: 'Santzz',
    avatar: 'assets/avatars/av_shadow.jpg',
    serif: true,
    preview: 'Você: Dnd',
    time: '2d',
    presence: Presence.none,
  ),
  DmChat(
    name: 'CARLIX BR',
    avatar: 'assets/avatars/av_sea.jpg',
    tag: tagSkull,
    preview: 'CARLIX BR: Se quiser deixar todas as fontes assi...',
    time: '2d',
    presence: Presence.none,
  ),
];

/// Ícone de servidor da barra lateral
class ServerTile {
  final String? text;
  final IconData? icon;
  final Color bg;
  final Color fg;
  final double radius;
  final double fontSize;
  final bool italic;
  final int badge;
  final bool bordered;

  const ServerTile({
    this.text,
    this.icon,
    this.bg = const Color(0xFF0A0A0C),
    this.fg = Colors.white,
    this.radius = 16,
    this.fontSize = 16,
    this.italic = false,
    this.badge = 0,
    this.bordered = false,
  });
}

const servers = [
  ServerTile(
    icon: Icons.local_fire_department,
    fg: Color(0xFFE11D2E),
    radius: 26,
  ),
  ServerTile(text: 'D.I.h', fontSize: 11, badge: 1, bordered: true),
  ServerTile(text: 'N', fontSize: 24, bordered: true),
  ServerTile(
    icon: Icons.sports_esports,
    bg: Color(0xFF3B2A6E),
    fg: Color(0xFFFFB454),
    badge: 11,
  ),
  ServerTile(
    text: 'PX',
    fg: Color(0xFFE11D2E),
    fontSize: 17,
    italic: true,
    radius: 26,
  ),
  ServerTile(icon: Icons.face_6, bg: Color(0xFF241A10), fg: Color(0xFFC9A06E)),
  ServerTile(text: 'SECRET', fontSize: 8, badge: 12, bordered: true),
  ServerTile(
    icon: Icons.person,
    fg: Color(0xFFE11D2E),
    radius: 26,
    bordered: true,
  ),
  ServerTile(icon: Icons.android, fg: Color(0xFF3DDC84), radius: 26),
  ServerTile(text: 'db', bg: Color(0xFFD9541E), fontSize: 17),
];
