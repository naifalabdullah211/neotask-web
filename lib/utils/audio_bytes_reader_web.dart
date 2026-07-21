import 'package:http/http.dart' as http;

/// On Web, `record_web`'s `stop()` resolves to a `blob:` URL for the
/// recorded audio, which is fetchable via a plain HTTP GET within the
/// same browser context (standard `fetch`/XHR behavior for blob: URLs).
Future<List<int>> readAudioBytes(String path) async {
  final response = await http.get(Uri.parse(path));
  return response.bodyBytes;
}
