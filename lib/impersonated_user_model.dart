class ImpersonatedUser {
  final String id;
  final String name;
  final String resourceType; // 'Practitioner' or 'Patient'

  ImpersonatedUser({
    required this.id,
    required this.name,
    required this.resourceType,
  });
}