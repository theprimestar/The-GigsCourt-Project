import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveProfile({
    required String userId,
    required String fullName,
    required List<String> services,
    required String bio,
    required String phone,
    String? profilePicUrl,
    List<String>? workPhotos,
  }) async {
    await _firestore.collection('profiles').doc(userId).set({
      'full_name': fullName,
      'services': services,
      'bio': bio,
      'phone': phone,
      'profile_pic_url': profilePicUrl,
      'work_photos': workPhotos ?? [],
      'onboarding_completed': true,
      'credits': 5,
      'rating': 0,
      'review_count': 0,
      'gig_count': 0,
      'show_phone': true,
      'push_enabled': true,
      'email_enabled': false,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> getProfilesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final List<Map<String, dynamic>> results = [];
    for (int i = 0; i < ids.length; i += 10) {
      final batch = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snapshot = await _firestore
          .collection('profiles')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in snapshot.docs) {
        results.add({
          'id': doc.id,
          ...doc.data(),
        });
      }
    }
    return results;
  }

  Future<Map<String, dynamic>?> getProfileById(String userId) async {
    final doc = await _firestore.collection('profiles').doc(userId).get();
    if (!doc.exists) return null;
    return {
      'id': doc.id,
      ...doc.data()!,
    };
  }
}
