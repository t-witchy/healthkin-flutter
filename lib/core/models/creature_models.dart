import 'dart:convert';

/// Represents a selectable creature template returned from the backend.
class CreatureTemplate {
  final int id;
  final String name;
  final String? description;
  final int rarity;
  final String? imageUrl;
  final String? animationUrl;

  CreatureTemplate({
    required this.id,
    required this.name,
    required this.rarity,
    this.description,
    this.imageUrl,
    this.animationUrl,
  });

  factory CreatureTemplate.fromJson(Map<String, dynamic> json) {
    return CreatureTemplate(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      rarity: json['rarity'] is int
          ? json['rarity'] as int
          : int.tryParse(json['rarity']?.toString() ?? '') ?? 0,
      imageUrl: json['image_url'] as String?,
      animationUrl: json['animation_url'] as String?,
    );
  }

  static List<CreatureTemplate> listFromJson(dynamic json) {
    if (json is List) {
      return json
          .whereType<Map<String, dynamic>>()
          .map(CreatureTemplate.fromJson)
          .toList();
    }
    return const [];
  }
}

/// Represents the user's first creature instance created via the API.
class UserCreatureInstance {
  final int id;
  final String nickname;
  final String displayName;
  final bool isActive;
  final CreatureTemplate creature;

  UserCreatureInstance({
    required this.id,
    required this.nickname,
    required this.displayName,
    required this.isActive,
    required this.creature,
  });

  factory UserCreatureInstance.fromJson(Map<String, dynamic> json) {
    return UserCreatureInstance(
      id: json['id'] as int,
      nickname: json['nickname'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      creature: CreatureTemplate.fromJson(
        (json['creature'] as Map).cast<String, dynamic>(),
      ),
    );
  }

  static UserCreatureInstance? tryDecode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return UserCreatureInstance.fromJson(decoded);
      }
    } catch (_) {
      // ignore
    }
    return null;
  }
}


