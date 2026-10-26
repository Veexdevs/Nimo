// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Navega a página inteira para outra URL (troca de domínio)
void gotoUrl(String url) {
  html.window.location.href = url;
}

/// Remove o fragmento (#...) da URL sem recarregar a página
void cleanUrlFragment() {
  final path = html.window.location.pathname ?? '/';
  html.window.history.replaceState(null, '', path);
}
