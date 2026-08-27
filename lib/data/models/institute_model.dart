import 'package:cloud_firestore/cloud_firestore.dart';

class InstituteModel {
  final String id;
  final String name;
  final String location;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  const InstituteModel({
    required this.id,
    required this.name,
    required this.location,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  factory InstituteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InstituteModel(
      id: doc.id,
      name: data['name'] ?? '',
      location: data['location'] ?? '',
      createdBy: data['created_by'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
      isActive: data['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'location': location,
      'created_by': createdBy,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'is_active': isActive,
    };
  }

  InstituteModel copyWith({
    String? id,
    String? name,
    String? location,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return InstituteModel(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  // Mirrors UserModel.toString(): this can reach an error reporter (a raw
  // error object is stringified before PII scrubbing, and scrubbing free-form
  // names is not reliable). web/privacy.html states the app collects no
  // geographic-location data, so `location` in particular must never travel
  // with a crash report — do NOT restore `name`/`location` here for debugging
  // convenience.
  @override
  String toString() {
    return 'InstituteModel(id: $id)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InstituteModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
