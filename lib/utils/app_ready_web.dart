// ignore: deprecated_member_use
import 'dart:html' as html;

void notifyAppReady() {
  html.window.dispatchEvent(html.Event('neotask-app-ready'));
}
