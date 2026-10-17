import 'package:cloud_firestore/cloud_firestore.dart';

/// Representa un grupo de gastos compartidos (H.4 - Gestión de grupos)
class GroupModel {
  final String id;
  final String name;
  final String description;
  final String createdBy;
  final List<String> memberIds;
  final Map<String, String> memberNames; // uid -> nombre visible
  final List<String> customCategories;
  final DateTime createdAt;

  GroupModel({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.memberIds,
    required this.memberNames,
    this.customCategories = const [],
    required this.createdAt,
  });

  factory GroupModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      createdBy: data['createdBy'] ?? '',
      memberIds: List<String>.from(data['memberIds'] ?? []),
      memberNames: Map<String, String>.from(data['memberNames'] ?? {}),
      customCategories: List<String>.from(data['customCategories'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'memberIds': memberIds,
      'memberNames': memberNames,
      'customCategories': customCategories,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
