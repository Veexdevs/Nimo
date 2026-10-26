import 'package:flutter/material.dart';

enum Presence { online, idle, dnd, none }

/// Quem postou status (fileira do topo)
class StatusUser {
  final String avatar;
  final bool isNew; // não visto = anel verde
  const StatusUser(this.avatar, this.isNew);
}

/// Nenhuma conta criada ainda — sem status
const statusUsers = <StatusUser>[];

/// Insígnia/tag ao lado do nome
class Tag {
  final IconData icon;
  final Color iconColor;
  final String label;
  const Tag(this.icon, this.iconColor, this.label);
}

/// Conversa direta (DM)
class DmChat {
  final String name;
  final String? avatar;
  final Tag? tag;
  final bool botTag;
  final bool botAvatar;
  final bool medals;
  final bool serif;
  final bool devSup;
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

/// Nenhuma conta criada ainda — sem conversas
const dms = <DmChat>[];

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

/// Nenhum servidor criado ainda
const servers = <ServerTile>[];
