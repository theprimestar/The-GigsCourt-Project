import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getServices() async {
    final response = await _client
        .from('services')
        .select()
        .eq('is_active', true)
        .order('category')
        .order('name');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> requestCustomService({
    required String userId,
    required String serviceName,
  }) async {
    await _client.from('service_requests').insert({
      'user_id': userId,
      'requested_name': serviceName.trim(),
      'status': 'pending',
    });
  }

  Future<void> saveProfileLocation({
    required String userId,
    required double lat,
    required double lng,
    required String address,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final idToken = await user.getIdToken(false);
    if (idToken == null) throw Exception('Failed to get ID token');

    final response = await http.post(
      Uri.parse('https://paohowngwtpffbdxxije.supabase.co/functions/v1/save-profile-location'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'lat': lat,
        'lng': lng,
        'address': address,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to save location');
    }
  }

  Future<List<Map<String, dynamic>>> getNearbyProfiles({
    required double viewerLat,
    required double viewerLng,
    int limit = 20,
    double? cursorDistance,
    String? cursorId,
  }) async {
    final response = await _client.rpc('get_nearby_profiles', params: {
      'viewer_lat': viewerLat,
      'viewer_lng': viewerLng,
      'p_limit': limit,
      'p_cursor_distance': cursorDistance,
      'p_cursor_id': cursorId,
    });

    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<List<Map<String, dynamic>>> getTopNearbyProviders({
    required double viewerLat,
    required double viewerLng,
    int limit = 10,
    double? cursorDistance,
    String? cursorId,
  }) async {
    final response = await _client.rpc('get_top_nearby_providers', params: {
      'viewer_lat': viewerLat,
      'viewer_lng': viewerLng,
      'p_limit': limit,
      'p_cursor_distance': cursorDistance,
      'p_cursor_id': cursorId,
    });

    return List<Map<String, dynamic>>.from(response as List);
  }
}
