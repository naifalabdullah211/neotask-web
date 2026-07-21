import 'dart:io';

Future<List<int>> readAudioBytes(String path) async {
  final file = File(path);
  return file.readAsBytes();
}
