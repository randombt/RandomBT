import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';

class CloudinaryService {
  static final CloudinaryPublic cloudinary = CloudinaryPublic(
    "szyxahsw",
    "RandomBT",
    cache: false,
  );

  static Future<String?> uploadImage(String path) async {
    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      return response.secureUrl;
    } catch (e) {
      debugPrint('Cloudinary image upload failed: $e');
      return null;
    }
  }
}
