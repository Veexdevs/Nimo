import 'package:flutter/material.dart';
import 'theme.dart';

enum Presence { online, idle, dnd, offline }

Color presenceColor(Presence p) {
  switch (p) {
    case Presence.online:
      return NimoColors.green;
    case Presence.idle:
      return NimoColors.yellow;
    case Presence.dnd:
      return NimoColors.red;
    case Presence.offline:
      return NimoColors.grey;
  }
}

// Gradientes de avatar
const g1 = [Color(0xFFF43F5E), Color(0xFFF97316)];
const g2 = [Color(0xFF38BDF8), Color(0xFF6366F1)];
const g3 = [Color(0xFF0F766E), Color(0xFF22D3EE)];
const g4 = [Color(0xFF27272A), Color(0xFF52525B)];
const g5 = [Color(0xFF7C3AED), Color(0xFFD946EF)];
const g6 = [Color(0xFF18181B), Color(0xFF3F3F46)];
const gBlue = [Color(0xFF1668FF), Color(0xFF3B82FF)];
const gPurple = [Color(0xFF7C3AED), Color(0xFFA78BFA)];
const gCyan = [Color(0xFF0891B2), Color(0xFF22D3EE)];
const gPink = [Color(0xFFDB2777), Color(0xFFF472B6)];

/// Quem postou status (fileira do topo)
class StatusUser {
  final String emoji;
  final List<Color> gradient;
  final bool isNew; // status não visto = anel verde animado
  const StatusUser(this.emoji, this.gradient, this.isNew);
}

const statusUsers = [
  StatusUser('🤖', g1, true),
  StatusUser('😎', g2, true),
  StatusUser('🐉', g3, true),
  StatusUser('🖤', g4, false),
  StatusUser('💜', g5, false),
  StatusUser('👤', g6, false),
];

/// Conversa direta (DM)
class DmChat {
  final String name;
  final String letter;
  final List<Color> gradient;
  final String? chip;
  final bool botChip;
  final String preview;
  final String time;
  final Presence presence;
  final bool logoAvatar;
  final bool italic;

  const DmChat({
    required this.name,
    this.letter = '',
    this.gradient = g4,
    this.chip,
    this.botChip = false,
    required this.preview,
    required this.time,
    this.presence = Presence.offline,
    this.logoAvatar = false,
    this.italic = false,
  });
}

const dms = [
  DmChat(
    name: 'Lua',
    letter: 'L',
    gradient: gPurple,
    chip: '🌙 LUAR',
    preview: 'Lua: Amanhã nos se fala',
    time: '33m',
    presence: Presence.online,
  ),
  DmChat(
    name: 'Pedrok.Dev',
    letter: 'P',
    gradient: gCyan,
    chip: '🎮 SynC',
    preview: 'Você: Tá bom',
    time: '6h',
    presence: Presence.online,
  ),
  DmChat(
    name: 'Nimo',
    logoAvatar: true,
    chip: '✓ APP',
    botChip: true,
    preview: '/convite | nimo.app',
    time: '7h',
    presence: Presence.online,
  ),
  DmChat(
    name: 'Deltax',
    letter: 'D',
    gradient: gPink,
    preview: 'Você: Vlw',
    time: '8h',
    presence: Presence.idle,
  ),
  DmChat(
    name: 'TLK777yt',
    letter: 'T',
    gradient: g3,
    chip: '⚔️ RING',
    preview: 'TLK777yt: Slk... fd',
    time: '9h',
    presence: Presence.online,
  ),
  DmChat(
    name: 'nossa.dev',
    letter: 'N',
    gradient: g2,
    chip: '🧩 SynC',
    preview: 'NOSSA.dev: Oloco',
    time: '11h',
    presence: Presence.dnd,
  ),
  DmChat(
    name: 'CARDOSO',
    letter: 'C',
    gradient: g1,
    chip: '🔧 SynC',
    preview: 'CARDOSO: Irei descansar tbm',
    time: '22h',
    presence: Presence.online,
  ),
  DmChat(
    name: '🏅 ARTHURX9',
    letter: 'A',
    gradient: gBlue,
    preview: 'ARTHURX9: 🏅 De qualquer for...',
    time: '23h',
    presence: Presence.offline,
  ),
  DmChat(
    name: 'Q_244',
    letter: 'Q',
    gradient: g6,
    chip: '💀 CMND',
    preview: 'Você: Tá entregue',
    time: '2d',
    presence: Presence.offline,
  ),
  DmChat(
    name: 'Santzz',
    letter: 'S',
    gradient: g4,
    italic: true,
    preview: 'Você: Dnd',
    time: '2d',
    presence: Presence.offline,
  ),
  DmChat(
    name: 'CARLIX BR',
    letter: 'C',
    gradient: g5,
    chip: '☠️ skull',
    preview: 'CARLIX BR: Se quiser deixar todas as fontes assi...',
    time: '2d',
    presence: Presence.online,
  ),
];

/// Servidores da barra lateral
class ServerItem {
  final String label;
  final List<Color> gradient;
  final int badge;
  const ServerItem(this.label, this.gradient, [this.badge = 0]);
}

const servers = [
  ServerItem('🐉', g1, 1),
  ServerItem('NB', gBlue),
  ServerItem('GZ', gPurple, 11),
  ServerItem('PX', g3),
  ServerItem('SC', g6, 12),
  ServerItem('🎵', gPink),
];
