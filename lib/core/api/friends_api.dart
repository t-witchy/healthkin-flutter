import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:healthkin_flutter/core/api/creature_api.dart';
import 'package:healthkin_flutter/core/repositories/auth_session.dart';

class FriendActiveCreature {
  final int friendId;
  final String friendName;
  final String creatureNickname;
  final String creatureImageUrl;

  FriendActiveCreature({
    required this.friendId,
    required this.friendName,
    required this.creatureNickname,
    required this.creatureImageUrl,
  });

  factory FriendActiveCreature.fromJson(Map<String, dynamic> json) {
    return FriendActiveCreature(
      friendId: json['friend_id'] as int,
      friendName: json['friend_name'] as String,
      creatureNickname: json['creature_nickname'] as String,
      creatureImageUrl: json['creature_image_url'] as String,
    );
  }
}

class FriendsApi {
  final http.Client _client;

  FriendsApi({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _headers() {
    final token = AuthSession.token ?? '';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetch the list of friends' active creatures.
  Future<List<FriendActiveCreature>> fetchFriendsActiveCreatures() async {
    final uri = Uri.parse('$baseUrl/api/friends/active-creatures/');
    final response = await _client.get(uri, headers: _headers());

    if (response.statusCode != 200) {
      throw _buildError(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response format from friends endpoint.');
    }

    final friendsJson = decoded['friends'];
    if (friendsJson is! List) return const [];

    return friendsJson
        .whereType<Map<String, dynamic>>()
        .map(FriendActiveCreature.fromJson)
        .toList();
  }

  /// Fetch all friends for a given user id, including their creature info.
  ///
  /// This expects a response compatible with [FriendActiveCreature].
  Future<List<FriendActiveCreature>> fetchFriendsForUser(int userId) async {
    final uri = Uri.parse('$baseUrl/api/friends/$userId/');
    final response = await _client.get(uri, headers: _headers());

    if (response.statusCode != 200) {
      throw _buildError(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(FriendActiveCreature.fromJson)
          .toList();
    }

    if (decoded is Map<String, dynamic> && decoded['friends'] is List) {
      final friendsJson = decoded['friends'] as List;
      return friendsJson
          .whereType<Map<String, dynamic>>()
          .map(FriendActiveCreature.fromJson)
          .toList();
    }

    return const [];
  }

  /// Send a friend invitation to the given email address.
  Future<void> sendFriendInvite(String email) async {
    final uri = Uri.parse('$baseUrl/api/friends/invitations/');
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{
        'email': email.trim(),
      }),
    );

    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      throw _buildError(response);
    }
  }

  Exception _buildError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail']?.toString() ??
            decoded['message']?.toString();
        if (detail != null && detail.isNotEmpty) {
          return Exception(detail);
        }
      }
    } catch (_) {
      // ignore parse error
    }
    return Exception(
      'Request failed with status ${response.statusCode}.',
    );
  }
}


