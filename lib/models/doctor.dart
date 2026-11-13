class Doctor {
  const Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.facility,
    required this.address,
    required this.distanceKm,
    required this.availability,
    required this.qualifications,
    required this.phone,
    required this.bio,
    this.verified = false,
  });

  final String id;
  final String name;
  final String specialty;
  final String facility;
  final String address;
  final double distanceKm;
  final String availability;
  final String qualifications;
  final String phone;
  final String bio;
  final bool verified;
}
