import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/imagekit_config.dart';

class ImageKitService {
  Future<String> uploadPhoto({
    required List<int> fileBytes,
    required String fileName,
    required String folder,
  }) async {
    // Get auth token from Supabase edge function
    final authResponse =
        await http.get(Uri.parse(ImageKitConfig.authEndpoint));

    if (authResponse.statusCode != 200) {
      throw Exception('Failed to get upload token');
    }

    final authData = jsonDecode(authResponse.body);

    // Upload to ImageKit
    final uploadRequest = http.MultipartRequest(
      'POST',
      Uri.parse('https://upload.imagekit.io/api/v1/files/upload'),
    );

    uploadRequest.fields['publicKey'] = ImageKitConfig.publicKey;
    uploadRequest.fields['token'] = authData['token'];
    uploadRequest.fields['signature'] = authData['signature'];
    uploadRequest.fields['expire'] = authData['expire'].toString();
    uploadRequest.fields['fileName'] = fileName;
    uploadRequest.fields['folder'] = folder;
    uploadRequest.fields['useUniqueFileName'] = 'true';

    uploadRequest.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
    );

    final uploadResponse = await uploadRequest.send();
    final responseBody = await uploadResponse.stream.bytesToString();
    final result = jsonDecode(responseBody);

    if (uploadResponse.statusCode != 200) {
      throw Exception(result['message'] ?? 'Upload failed');
    }

    return result['url'] as String;
  }
}
