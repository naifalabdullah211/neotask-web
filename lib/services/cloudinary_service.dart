import 'dart:convert';
import 'package:http/http.dart' as http;

/// Direct-from-client (unsigned) file/image uploads to Cloudinary.
///
/// Uses an UNSIGNED upload preset ("Neotask") specifically because this app
/// has no backend server — putting a *signed* preset's API Secret in Flutter
/// web code would expose it to anyone opening browser DevTools. Unsigned
/// presets are Cloudinary's supported mechanism for exactly this scenario:
/// the preset itself (configured in the Cloudinary console) constrains what
/// the client is allowed to do, so no secret ever needs to ship in the app.
///
/// `resource_type=auto` lets a single endpoint accept both images and
/// arbitrary files (PDF, Word, etc.) — Cloudinary infers the right resource
/// type per upload.
class CloudinaryService {
  static const String _cloudName = 'unofnu8o';
  static const String _uploadPreset = 'Neotask';

  static Uri get _uploadUri =>
      Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/auto/upload');

  /// Uploads [bytes] (already read from an XFile/PlatformFile — works on
  /// both Web and Android since we never touch dart:io File) and returns
  /// the secure HTTPS URL Cloudinary assigns to the uploaded asset.
  ///
  /// Throws a descriptive [Exception] on any non-2xx response so calling
  /// UI code can show a meaningful error instead of a silent failure.
  static Future<String> uploadBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    final request = http.MultipartRequest('POST', _uploadUri)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'فشل رفع الملف (Cloudinary ${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final secureUrl = data['secure_url'] as String?;
    if (secureUrl == null || secureUrl.isEmpty) {
      throw Exception('رد Cloudinary لا يحتوي على رابط الملف');
    }
    return secureUrl;
  }
}
