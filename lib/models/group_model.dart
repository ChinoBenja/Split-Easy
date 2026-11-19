import 'package:cloud_firestore/cloud_firestore.dart';

/// Representa un grupo de gastos compartidos (H.4 - Gestión de grupos)
class GroupModel {
  final String id;
  final String name;
  final String description;
  final String createdBy;
  final List<String> memberIds;
  final List<String> invitedIds;
  final Map<String, String> memberNames; // uid -> nombre visible
  final String? photoSource;
  final List<String> customCategories;
  final DateTime createdAt;

  GroupModel({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.memberIds,
    this.invitedIds = const [],
    required this.memberNames,
    this.photoSource,
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
      invitedIds: List<String>.from(data['invitedIds'] ?? []),
      memberNames: Map<String, String>.from(data['memberNames'] ?? {}),
      photoSource: _photoSource(data),
      customCategories: List<String>.from(data['customCategories'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    String? photoBase64;
    String? photoContentType;
    final source = photoSource;
    final commaIndex = source?.indexOf(',') ?? -1;
    if (source != null && source.startsWith('data:image/') && commaIndex >= 0) {
      photoContentType = source.substring(5, commaIndex);
      photoBase64 = source.substring(commaIndex + 1);
    }

    final data = <String, dynamic>{
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'memberIds': memberIds,
      'invitedIds': invitedIds,
      'memberNames': memberNames,
      'customCategories': customCategories,
      'createdAt': Timestamp.fromDate(createdAt),
    };
    if (photoBase64 != null) data['photoBase64'] = photoBase64;
    if (photoContentType != null) {
      data['photoContentType'] = photoContentType;
    }
    return data;
  }

  static String? _photoSource(Map<String, dynamic> data) {
    final photoBase64 = data['photoBase64'];
    if (photoBase64 is! String || photoBase64.isEmpty) return null;
    final contentType = data['photoContentType'];
    final safeContentType =
        contentType is String && contentType.startsWith('image/')
        ? contentType
        : 'image/jpeg';
    return 'data:$safeContentType;base64,$photoBase64';
  }
}
