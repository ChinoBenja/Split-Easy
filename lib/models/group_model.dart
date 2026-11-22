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
    final rawData = doc.data();
    final data = rawData is Map ? rawData : const <Object?, Object?>{};
    return GroupModel(
      id: doc.id,
      name: _stringValue(data['name']),
      description: _stringValue(data['description']),
      createdBy: _stringValue(data['createdBy']),
      memberIds: _stringList(data['memberIds']),
      invitedIds: _stringList(data['invitedIds']),
      memberNames: _stringMap(data['memberNames']),
      photoSource: _photoSource(data),
      customCategories: _stringList(data['customCategories']),
      createdAt: _dateValue(data['createdAt']) ?? DateTime.now(),
    );
  }

  static String _stringValue(Object? value) => value is String ? value : '';

  static List<String> _stringList(Object? value) {
    if (value is! Iterable) return <String>[];
    return value.whereType<String>().where((item) => item.isNotEmpty).toList();
  }

  static Map<String, String> _stringMap(Object? value) {
    if (value is! Map) return <String, String>{};
    return {
      for (final entry in value.entries)
        if (entry.key case final String key)
          if (entry.value case final String item) key: item,
    };
  }

  static DateTime? _dateValue(Object? value) =>
      value is Timestamp ? value.toDate() : null;

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

  static String? _photoSource(Map<Object?, Object?> data) {
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
