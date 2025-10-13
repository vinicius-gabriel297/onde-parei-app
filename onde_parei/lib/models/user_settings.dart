class UserSettings {
  final String userId;
  final String displayName;
  final bool isDarkMode;
  final String language;

  UserSettings({
    required this.userId,
    required this.displayName,
    this.isDarkMode = false,
    this.language = 'pt_BR',
  });

  UserSettings copyWith({
    String? userId,
    String? displayName,
    bool? isDarkMode,
    String? language,
  }) {
    return UserSettings(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      language: language ?? this.language,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'isDarkMode': isDarkMode,
      'language': language,
    };
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      userId: json['userId'] ?? '',
      displayName: json['displayName'] ?? '',
      isDarkMode: json['isDarkMode'] ?? false,
      language: json['language'] ?? 'pt_BR',
    );
  }
}
