class AppUser {
  final int id;
  final String? name;
  final String? email;
  final String? phone;
  final String? countryIso;
  final String? address;
  /// Profile photo, when the API provides one (several key spellings are
  /// accepted); the account screen falls back to initials otherwise.
  final String? avatarUrl;

  AppUser({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.countryIso,
    this.address,
    this.avatarUrl,
  });

  /// First letters of up to two name words, e.g. "Demo User" → "DU".
  String get initials {
    final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
    final letters = parts.map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as int,
    name: json['name'] as String?,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    countryIso: json['country_iso'] as String?,
    address: json['address'] as String?,
    avatarUrl: (json['profile_photo'] ?? json['avatar_url'] ?? json['avatar'] ?? json['profile_photo_url'] ?? json['image']) as String?,
  );
}
