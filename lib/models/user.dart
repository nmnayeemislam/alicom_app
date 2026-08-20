class AppUser {
  final int id;
  final String? name;
  final String? email;
  final String? phone;
  final String? countryIso;
  final String? address;

  AppUser({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.countryIso,
    this.address,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as int,
    name: json['name'] as String?,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    countryIso: json['country_iso'] as String?,
    address: json['address'] as String?,
  );
}
