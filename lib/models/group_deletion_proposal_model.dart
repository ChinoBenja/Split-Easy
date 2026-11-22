import 'package:cloud_firestore/cloud_firestore.dart';

class GroupDeletionProposal {
  const GroupDeletionProposal({
    required this.id,
    required this.groupId,
    required this.proposedBy,
    required this.proposedByName,
    required this.createdAt,
    required this.status,
    required this.responses,
  });

  final String id;
  final String groupId;
  final String proposedBy;
  final String proposedByName;
  final DateTime createdAt;
  final String status;
  final Map<String, String> responses;

  bool hasResponded(String uid) => responses.containsKey(uid);

  List<String> pendingMembers(List<String> memberIds) =>
      memberIds.where((uid) => !responses.containsKey(uid)).toList();

  factory GroupDeletionProposal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupDeletionProposal(
      id: doc.id,
      groupId: data['groupId'] as String? ?? '',
      proposedBy: data['proposedBy'] as String? ?? '',
      proposedByName: data['proposedByName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'pending',
      responses: Map<String, String>.from(data['responses'] ?? {}),
    );
  }
}
