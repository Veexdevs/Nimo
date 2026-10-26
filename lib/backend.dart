import 'package:flutter/foundation.dart' show Uint8List;
import 'package:supabase_flutter/supabase_flutter.dart';

/// ============================================================
/// Conexão com o banco de dados (Supabase)
/// ============================================================
const supabaseUrl = 'https://eseriyzlsumsgluarvcw.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVzZXJpeXpsc3Vtc2dsdWFydmN3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMwMTk3NzAsImV4cCI6MjEwODU5NTc3MH0.pVCOd08kA5h65zdLtUYEU8t4FqCAIUJSQ8LKBdmf-2o';

SupabaseClient get supa => Supabase.instance.client;

bool get isLoggedIn => supa.auth.currentSession != null;

/// Perfil do usuário no Nimo
class NimoProfile {
  final String id;
  final String username;
  final String? displayName;
  final String? country;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? bio;
  final DateTime? createdAt;
  final String? email;

  const NimoProfile({
    required this.id,
    required this.username,
    this.displayName,
    this.country,
    this.avatarUrl,
    this.bannerUrl,
    this.bio,
    this.createdAt,
    this.email,
  });

  String get shownName =>
      (displayName != null && displayName!.trim().isNotEmpty)
          ? displayName!
          : username;

  factory NimoProfile.fromMap(Map<String, dynamic> m, {String? email}) {
    return NimoProfile(
      id: m['id'] as String,
      username: (m['username'] ?? '') as String,
      displayName: m['display_name'] as String?,
      country: m['country'] as String?,
      avatarUrl: m['avatar_url'] as String?,
      bannerUrl: m['banner_url'] as String?,
      bio: m['bio'] as String?,
      createdAt: m['created_at'] != null
          ? DateTime.tryParse(m['created_at'] as String)
          : null,
      email: email,
    );
  }
}

/// Busca o perfil do usuário logado
Future<NimoProfile?> fetchMyProfile() async {
  final user = supa.auth.currentUser;
  if (user == null) return null;
  final data = await supa
      .from('profiles')
      .select()
      .eq('id', user.id)
      .maybeSingle();
  if (data == null) return null;
  return NimoProfile.fromMap(data, email: user.email);
}

/// Atualiza a bio do usuário logado
Future<void> updateBio(String bio) async {
  final user = supa.auth.currentUser;
  if (user == null) return;
  await supa.from('profiles').update({
    'bio': bio.trim().isEmpty ? null : bio.trim(),
  }).eq('id', user.id);
}

/// Verifica se um nome único está disponível
Future<bool> usernameAvailable(String username) async {
  final r = await supa
      .from('profiles')
      .select('id')
      .ilike('username', username)
      .maybeSingle();
  return r == null;
}

/// Envia foto/banner para o storage e grava a URL no perfil.
/// Retorna a URL pública ou null em caso de falha.
Future<String?> uploadProfileImage({
  required Uint8List bytes,
  required bool banner,
}) async {
  final user = supa.auth.currentUser;
  if (user == null) return null;
  try {
    final path = '${user.id}/${banner ? 'banner' : 'avatar'}.jpg';
    await supa.storage.from('profiles').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
            cacheControl: '60',
          ),
        );
    final url = supa.storage.from('profiles').getPublicUrl(path);
    final bust = '$url?v=${DateTime.now().millisecondsSinceEpoch}';
    await supa.from('profiles').update(
        {banner ? 'banner_url' : 'avatar_url': bust}).eq('id', user.id);
    return bust;
  } catch (_) {
    return null;
  }
}

/// Mensagens de erro de autenticação em português
String authErrorMessage(Object e) {
  final msg = e is AuthException ? e.message.toLowerCase() : e.toString();
  if (msg.contains('invalid login credentials') ||
      msg.contains('invalid_credentials')) {
    return 'E-mail ou senha incorretos.';
  }
  if (msg.contains('already registered') ||
      msg.contains('user_already_exists')) {
    return 'Este e-mail já tem uma conta. Tente entrar.';
  }
  if (msg.contains('password')) {
    return 'Senha inválida. Use pelo menos 8 caracteres.';
  }
  if (msg.contains('rate limit') || msg.contains('too many')) {
    return 'Muitas tentativas. Aguarde um pouco e tente de novo.';
  }
  if (msg.contains('network') ||
      msg.contains('socket') ||
      msg.contains('failed host lookup')) {
    return 'Sem conexão. Verifique sua internet.';
  }
  return 'Algo deu errado. Tente novamente.';
}
