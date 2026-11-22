import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';
import '../models/group_deletion_proposal_model.dart';
import '../models/user_profile_model.dart';
import '../models/expense_model.dart';
import '../models/expense_proposal_model.dart';
import '../models/message_model.dart';
import '../models/balance_model.dart';
import '../models/history_entry_model.dart';

class FirestoreService {
  static const int maxChatImageBase64Length = 700 * 1024;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _usersRef => _db.collection('users');
  CollectionReference get _groupsRef => _db.collection('groups');
  CollectionReference _expensesRef(String groupId) =>
      _groupsRef.doc(groupId).collection('expenses');
  CollectionReference _proposalsRef(String groupId, String expenseId) =>
      _expensesRef(groupId).doc(expenseId).collection('proposals');
  CollectionReference _messagesRef(String groupId) =>
      _groupsRef.doc(groupId).collection('messages');
  CollectionReference _groupDeletionProposalsRef(String groupId) =>
      _groupsRef.doc(groupId).collection('group_proposals');
  CollectionReference _historyRef(String groupId) =>
      _groupsRef.doc(groupId).collection('history');

  // ---------------------------------------------------------------------
  // USUARIOS
  // ---------------------------------------------------------------------

  Future<void> upsertUser({
    required String uid,
    required String name,
    required String email,
    String? photoUrl,
  }) async {
    final userData = <String, dynamic>{
      'name': name,
      'email': email,
      'updatedAt': Timestamp.now(),
    };
    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      userData['photoUrl'] = photoUrl.trim();
    }
    await _usersRef.doc(uid).set(userData, SetOptions(merge: true));
  }

  Future<void> updateUserPhoto({
    required String uid,
    required List<int> imageBytes,
    required String contentType,
  }) async {
    await _usersRef
        .doc(uid)
        .set({
          'photoBase64': base64Encode(imageBytes),
          'photoContentType': contentType,
          'photoUrl': FieldValue.delete(),
          'avatarUrl': FieldValue.delete(),
          'updatedAt': Timestamp.now(),
        }, SetOptions(merge: true))
        .timeout(const Duration(seconds: 30));
  }

  Future<String?> getUserPhoto(String uid) async {
    final snapshot = await _usersRef.doc(uid).get();
    final data = snapshot.data() as Map<String, dynamic>?;
    return _photoSource(data);
  }

  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    final query = await _usersRef
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final userData = query.docs.first.data() as Map<String, dynamic>;
    return {
      ...userData,
      'uid': query.docs.first.id,
      'photoSource': _photoSource(userData),
    };
  }

  Future<Map<String, String>> getUserPhotoUrls(Iterable<String> userIds) async {
    final profiles = await getUserProfiles(userIds);
    final photoUrls = <String, String>{};
    for (final profile in profiles.values) {
      final photoSource = profile.photoSource;
      if (photoSource != null && photoSource.isNotEmpty) {
        photoUrls[profile.uid] = photoSource;
      }
    }
    return photoUrls;
  }

  Future<Map<String, UserProfile>> getUserProfiles(
    Iterable<String> userIds,
  ) async {
    final uniqueUserIds = userIds.toSet().where((uid) => uid.isNotEmpty);
    final snapshots = await Future.wait(
      uniqueUserIds.map((uid) => _usersRef.doc(uid).get()),
    );
    return {
      for (final snapshot in snapshots)
        if (snapshot.exists)
          snapshot.id: _userProfileFromData(
            snapshot.id,
            snapshot.data() as Map<String, dynamic>,
          ),
    };
  }

  UserProfile _userProfileFromData(String uid, Map<String, dynamic> data) {
    final name = data['name'];
    final email = data['email'];
    return UserProfile(
      uid: uid,
      name: name is String ? name.trim() : '',
      email: email is String ? email.trim() : '',
      photoSource: _photoSource(data),
    );
  }

  String? _photoSource(Map<String, dynamic>? data) {
    final photoBase64 = data?['photoBase64'];
    if (photoBase64 is String && photoBase64.isNotEmpty) {
      final contentType = data?['photoContentType'];
      final safeContentType =
          contentType is String && contentType.startsWith('image/')
          ? contentType
          : 'image/jpeg';
      return 'data:$safeContentType;base64,$photoBase64';
    }

    final photoUrl = data?['photoUrl'];
    final avatarUrl = data?['avatarUrl'];
    final legacyPhotoUrl = photoUrl is String && photoUrl.trim().isNotEmpty
        ? photoUrl
        : avatarUrl;
    return legacyPhotoUrl is String && legacyPhotoUrl.trim().isNotEmpty
        ? legacyPhotoUrl.trim()
        : null;
  }

  // ---------------------------------------------------------------------
  // GRUPOS
  // ---------------------------------------------------------------------

  String? _currentUidForGroupQuery(String requestedUid) {
    final authenticatedUid = FirebaseAuth.instance.currentUser?.uid;
    if (authenticatedUid == null || authenticatedUid.isEmpty) return null;
    if (requestedUid != authenticatedUid) return null;
    return authenticatedUid;
  }

  Stream<List<GroupModel>> watchUserGroups(String uid) {
    final authenticatedUid = _currentUidForGroupQuery(uid);
    if (authenticatedUid == null) {
      return Stream.error(
        StateError('Debes consultar grupos con el UID autenticado actual.'),
      );
    }

    return _groupsRef
        .where('memberIds', arrayContains: authenticatedUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => GroupModel.fromFirestore(doc)).toList(),
        );
  }

  Stream<List<GroupModel>> watchPendingInvitations(String uid) {
    final authenticatedUid = _currentUidForGroupQuery(uid);
    if (authenticatedUid == null) {
      return Stream.error(
        StateError(
          'Debes consultar invitaciones con el UID autenticado actual.',
        ),
      );
    }

    return _groupsRef
        .where('invitedIds', arrayContains: authenticatedUid)
        .snapshots()
        .map((snapshot) {
          final groups = snapshot.docs
              .map((doc) => GroupModel.fromFirestore(doc))
              .toList();
          groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return groups;
        });
  }

  Future<String> createGroup({
    required String name,
    required String description,
    required Map<String, String> memberNames,
    List<int>? photoBytes,
    String photoContentType = 'image/jpeg',
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId.isEmpty) {
      throw StateError('Debes iniciar sesión para crear un grupo.');
    }

    final invitedIds = memberNames.keys
        .where((uid) => uid != currentUserId)
        .toList();
    final allMemberNames = Map<String, String>.from(memberNames);
    allMemberNames.putIfAbsent(
      currentUserId,
      () =>
          FirebaseAuth.instance.currentUser?.displayName ??
          FirebaseAuth.instance.currentUser?.email ??
          'Usuario',
    );

    if (photoBytes != null && photoBytes.length > 120 * 1024) {
      throw StateError('La foto del grupo no puede superar los 120 KB.');
    }

    final groupData = <String, dynamic>{
      'name': name,
      'description': description,
      'createdBy': currentUserId,
      'members': [currentUserId],
      'memberIds': [currentUserId],
      'invitedIds': invitedIds,
      'memberNames': allMemberNames,
      'customCategories': <String>[],
      'createdAt': Timestamp.now(),
    };
    if (photoBytes != null) {
      groupData['photoBase64'] = base64Encode(photoBytes);
      groupData['photoContentType'] = photoContentType;
    }
    final doc = await _groupsRef.add(groupData);
    return doc.id;
  }

  Future<void> deleteGroup({required String groupId}) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId.isEmpty) {
      throw StateError('Debes iniciar sesión para eliminar un grupo.');
    }

    final groupRef = _groupsRef.doc(groupId);
    final groupSnapshot = await groupRef.get();
    final groupData = groupSnapshot.data() as Map<String, dynamic>?;
    final creatorId = groupData?['createdBy'];
    if (!groupSnapshot.exists ||
        creatorId is! String ||
        creatorId.trim().isEmpty ||
        creatorId.trim() != currentUserId.trim()) {
      throw StateError('Solo el creador puede eliminar este grupo.');
    }

    await _deleteGroupData(groupId);
  }

  Future<void> _deleteGroupData(String groupId) async {
    final groupRef = _groupsRef.doc(groupId);
    while (true) {
      final expenses = await _expensesRef(groupId).limit(500).get();
      if (expenses.docs.isEmpty) break;

      for (final expense in expenses.docs) {
        await _deleteCollectionInBatches(_proposalsRef(groupId, expense.id));
      }
      await _deleteDocumentsInBatches(
        expenses.docs.map((expense) => expense.reference),
      );
    }

    await _deleteCollectionInBatches(_messagesRef(groupId));
    await _deleteCollectionInBatches(_historyRef(groupId));
    await _deleteCollectionInBatches(_groupDeletionProposalsRef(groupId));
    await groupRef.delete();
  }

  Stream<GroupDeletionProposal?> watchGroupDeletionProposal(
    String groupId,
    String proposalId,
  ) {
    return _groupDeletionProposalsRef(groupId)
        .doc(proposalId)
        .snapshots()
        .map(
          (snapshot) => snapshot.exists
              ? GroupDeletionProposal.fromFirestore(snapshot)
              : null,
        );
  }

  Future<String> proposeGroupDeletion({
    required String groupId,
    required String proposedBy,
    required String proposedByName,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId != proposedBy) {
      throw StateError(
        'Inicia sesión con la cuenta que propone eliminar el grupo.',
      );
    }

    final groupRef = _groupsRef.doc(groupId);
    final groupSnapshot = await groupRef.get();
    if (!groupSnapshot.exists) {
      throw StateError('El grupo ya no existe.');
    }
    final groupData = groupSnapshot.data() as Map<String, dynamic>;
    final memberIds = List<String>.from(groupData['memberIds'] ?? []);
    if (!memberIds.contains(proposedBy)) {
      throw StateError('Solo un integrante puede proponer eliminar el grupo.');
    }
    if (memberIds.length < 2) {
      throw StateError(
        'La propuesta de eliminación requiere al menos dos integrantes.',
      );
    }

    final pendingProposals = await _groupDeletionProposalsRef(
      groupId,
    ).where('status', isEqualTo: 'pending').limit(1).get();
    if (pendingProposals.docs.isNotEmpty) {
      throw StateError('Ya existe una propuesta de eliminación pendiente.');
    }

    final proposalRef = _groupDeletionProposalsRef(groupId).doc();
    final messageRef = _messagesRef(groupId).doc();
    final batch = _db.batch();
    batch.set(proposalRef, {
      'groupId': groupId,
      'proposedBy': proposedBy,
      'proposedByName': proposedByName,
      'createdAt': Timestamp.now(),
      'status': 'pending',
      'type': 'delete_group',
      'responses': {proposedBy: 'accepted'},
    });
    batch.set(messageRef, {
      'type': 'group_delete_proposal',
      'senderId': proposedBy,
      'senderName': proposedByName,
      'proposalId': proposalRef.id,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': Timestamp.now(),
    });
    await batch.commit();
    return proposalRef.id;
  }

  Future<String> respondToGroupDeletionProposal({
    required String groupId,
    required String proposalId,
    required String uid,
    required String response,
  }) async {
    if (response != 'accepted' && response != 'rejected') {
      throw ArgumentError.value(response, 'response', 'Respuesta no válida.');
    }
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId != uid) {
      throw StateError(
        'Inicia sesión con la cuenta que responde la propuesta.',
      );
    }

    final groupRef = _groupsRef.doc(groupId);
    final proposalRef = _groupDeletionProposalsRef(groupId).doc(proposalId);
    var shouldDeleteGroup = false;

    final status = await _db.runTransaction<String>((transaction) async {
      final groupSnapshot = await transaction.get(groupRef);
      final proposalSnapshot = await transaction.get(proposalRef);
      if (!groupSnapshot.exists || !proposalSnapshot.exists) {
        throw StateError('El grupo o la propuesta ya no existe.');
      }

      final groupData = groupSnapshot.data() as Map<String, dynamic>;
      final proposalData = proposalSnapshot.data() as Map<String, dynamic>;
      if (proposalData['type'] != 'delete_group' ||
          proposalData['groupId'] != groupId) {
        throw StateError('La propuesta de eliminación no es válida.');
      }
      final memberIds = List<String>.from(groupData['memberIds'] ?? []);
      if (!memberIds.contains(uid)) {
        throw StateError('Solo un integrante puede responder esta propuesta.');
      }

      final responses = Map<String, String>.from(
        proposalData['responses'] ?? {},
      );
      final currentStatus = proposalData['status'] as String? ?? 'pending';
      if (currentStatus == 'pending') {
        if (responses.containsKey(uid)) return currentStatus;
        responses[uid] = response;
      }

      var finalStatus = currentStatus;
      if (currentStatus == 'pending') {
        if (response == 'rejected') {
          finalStatus = 'rejected';
        } else if (memberIds.every((memberId) {
          return responses[memberId] == 'accepted';
        })) {
          finalStatus = 'approved';
        }
      }

      if (currentStatus == 'pending') {
        transaction.update(proposalRef, {
          'responses': responses,
          'status': finalStatus,
        });
      }

      if (finalStatus == 'approved') {
        transaction.update(groupRef, {
          'groupDeletionApproved': true,
          'groupDeletionProposalId': proposalId,
        });
        shouldDeleteGroup = true;
      }
      return finalStatus;
    });

    if (shouldDeleteGroup) {
      await _deleteGroupData(groupId);
    }
    return status;
  }

  Future<void> _deleteCollectionInBatches(
    CollectionReference collection,
  ) async {
    while (true) {
      final documents = await collection.limit(500).get();
      if (documents.docs.isEmpty) return;
      await _deleteDocumentsInBatches(
        documents.docs.map((document) => document.reference),
      );
    }
  }

  Future<void> _deleteDocumentsInBatches(
    Iterable<DocumentReference> references,
  ) async {
    final batch = _db.batch();
    var count = 0;
    for (final reference in references) {
      batch.delete(reference);
      count++;
    }
    if (count > 0) await batch.commit();
  }

  Future<bool> inviteMemberToGroup({
    required String groupId,
    required String memberUid,
    required String memberName,
  }) async {
    final groupRef = _groupsRef.doc(groupId);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId.isEmpty) {
      throw StateError('Debes iniciar sesión para invitar integrantes.');
    }
    if (memberUid == currentUserId) return false;

    return _db.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupRef);
      if (!groupSnapshot.exists) {
        throw StateError('El grupo ya no existe.');
      }

      final groupData = groupSnapshot.data() as Map<String, dynamic>;
      final memberIds = List<String>.from(groupData['memberIds'] ?? const []);
      final invitedIds = List<String>.from(groupData['invitedIds'] ?? const []);
      if (!memberIds.contains(currentUserId)) {
        throw StateError('Solo los integrantes pueden invitar usuarios.');
      }
      if (memberIds.contains(memberUid) || invitedIds.contains(memberUid)) {
        return false;
      }

      transaction.update(groupRef, {
        'invitedIds': FieldValue.arrayUnion([memberUid]),
        'memberNames.$memberUid': memberName,
      });
      return true;
    });
  }

  Future<void> respondToGroupInvitation({
    required String groupId,
    required bool accept,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId.isEmpty) {
      throw StateError('Debes iniciar sesión para responder invitaciones.');
    }

    final groupRef = _groupsRef.doc(groupId);
    await _db.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupRef);
      if (!groupSnapshot.exists) {
        throw StateError('El grupo ya no existe.');
      }

      final groupData = groupSnapshot.data() as Map<String, dynamic>;
      final rawInvitedIds = groupData['invitedIds'];
      final rawMemberIds = groupData['memberIds'];
      final rawMembers = groupData['members'] ?? const <dynamic>[];
      if (rawInvitedIds is! List ||
          rawInvitedIds.any((uid) => uid is! String) ||
          rawMemberIds is! List ||
          rawMemberIds.any((uid) => uid is! String) ||
          rawMembers is! List ||
          rawMembers.any((uid) => uid is! String)) {
        throw StateError('Los datos de integrantes del grupo no son válidos.');
      }

      final invitedIds = List<String>.from(rawInvitedIds);
      if (!invitedIds.contains(currentUserId)) {
        throw StateError('Esta invitación ya no está pendiente.');
      }

      final memberIds = List<String>.from(rawMemberIds);
      final members = List<String>.from(rawMembers);
      invitedIds.remove(currentUserId);

      final updates = <String, dynamic>{'invitedIds': invitedIds};
      if (accept) {
        if (!memberIds.contains(currentUserId)) {
          memberIds.add(currentUserId);
        }
        if (!members.contains(currentUserId)) {
          members.add(currentUserId);
        }
        updates['memberIds'] = memberIds;
        updates['members'] = members;
      }
      transaction.update(groupRef, updates);
    });
  }

  Future<void> removeMemberFromGroup({
    required String groupId,
    required String memberUid,
  }) async {
    await _groupsRef.doc(groupId).update({
      'memberIds': FieldValue.arrayRemove([memberUid]),
      'members': FieldValue.arrayRemove([memberUid]),
      'memberNames.$memberUid': FieldValue.delete(),
    });
  }

  Future<void> addCustomCategory(String groupId, String category) async {
    await _groupsRef.doc(groupId).update({
      'customCategories': FieldValue.arrayUnion([category]),
    });
  }

  // ---------------------------------------------------------------------
  // GASTOS
  // ---------------------------------------------------------------------

  Stream<List<ExpenseModel>> watchGroupExpenses(String groupId) {
    return _expensesRef(groupId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => ExpenseModel.fromFirestore(doc)).toList(),
        );
  }

  Stream<ExpenseModel?> watchExpense(String groupId, String expenseId) {
    return _expensesRef(groupId)
        .doc(expenseId)
        .snapshots()
        .map((doc) => doc.exists ? ExpenseModel.fromFirestore(doc) : null);
  }

  /// [payments]: uid -> monto pagado. [participantShares]: uid -> monto
  /// que le corresponde pagar (según splitMode: igual, %, o manual).
  /// La suma de payments y la suma de participantShares deben ser
  /// ambas iguales a [amount].
  Future<void> addExpense({
    required String groupId,
    required String description,
    required double amount,
    required String category,
    required Map<String, double> payments,
    required Map<String, String> payerNames,
    required Map<String, double> participantShares,
    required String splitMode,
    required DateTime date,
    required String createdBy,
    required String createdByName,
  }) async {
    final doc = await _expensesRef(groupId).add({
      'description': description,
      'amount': amount,
      'category': category,
      'payments': payments,
      'payerNames': payerNames,
      'participantShares': participantShares,
      'splitMode': splitMode,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.now(),
      'settledParticipantIds': <String>[],
      'pendingSettlementIds': <String>[],
    });

    await _logHistory(
      groupId: groupId,
      expenseId: doc.id,
      expenseDescription: description,
      action: 'created',
      performedBy: createdBy,
      performedByName: createdByName,
    );
  }

  Future<void> deleteExpense(
    String groupId,
    String expenseId, {
    String? expenseDescription,
    String? performedBy,
    String? performedByName,
    String? details,
  }) async {
    await _expensesRef(groupId).doc(expenseId).delete();
    if (expenseDescription != null) {
      await _logHistory(
        groupId: groupId,
        expenseId: expenseId,
        expenseDescription: expenseDescription,
        action: 'deleted_free',
        performedBy: performedBy ?? '',
        performedByName: performedByName ?? '',
        details:
            details ?? 'Eliminado directamente desde la pantalla de detalle.',
      );
    }
  }

  /// Elimina un gasto directamente (sin consenso). Solo debe llamarse
  /// desde la UI cuando `expense.isFullySettled == true`.
  Future<void> deleteExpenseFreely({
    required String groupId,
    required ExpenseModel expense,
    required String performedBy,
    required String performedByName,
  }) async {
    await _expensesRef(groupId).doc(expense.id).delete();
    await _logHistory(
      groupId: groupId,
      expenseId: expense.id,
      expenseDescription: expense.description,
      action: 'deleted_free',
      performedBy: performedBy,
      performedByName: performedByName,
      details: 'Sin deudas pendientes, eliminado directamente.',
    );
    await sendSystemMessage(
      groupId: groupId,
      text:
          '🗑️ $performedByName eliminó "${expense.description}" (ya no tenía deudas pendientes).',
    );
  }

  Future<List<ExpenseModel>> getGroupExpensesOnce(String groupId) async {
    final snap = await _expensesRef(groupId).orderBy('date').get();
    return snap.docs.map((doc) => ExpenseModel.fromFirestore(doc)).toList();
  }

  // ---------------------------------------------------------------------
  // LIQUIDACIÓN POR GASTO (permite eliminar sin consenso una vez que ya
  // no queden deudas de ESE gasto en particular)
  // ---------------------------------------------------------------------

  /// Un participante avisa "ya pagué mi parte de este gasto". Queda
  /// pendiente hasta que un pagador lo confirme.
  Future<void> requestSettlement({
    required String groupId,
    required String expenseId,
    required String expenseDescription,
    required String uid,
    required String uidName,
  }) async {
    await _expensesRef(groupId).doc(expenseId).update({
      'pendingSettlementIds': FieldValue.arrayUnion([uid]),
    });
    await _messagesRef(groupId).add({
      'type': 'settlement_request',
      'senderId': uid,
      'senderName': uidName,
      'expenseId': expenseId,
      'expenseDescription': expenseDescription,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': Timestamp.now(),
    });
    await _logHistory(
      groupId: groupId,
      expenseId: expenseId,
      expenseDescription: expenseDescription,
      action: 'settlement_requested',
      performedBy: uid,
      performedByName: uidName,
    );
  }

  /// Un pagador confirma que recibió el pago de [uid] para este gasto.
  Future<void> confirmSettlement({
    required String groupId,
    required String expenseId,
    required String expenseDescription,
    required String uid,
    required String uidName,
    required String confirmedBy,
    required String confirmedByName,
  }) async {
    await _expensesRef(groupId).doc(expenseId).update({
      'pendingSettlementIds': FieldValue.arrayRemove([uid]),
      'settledParticipantIds': FieldValue.arrayUnion([uid]),
    });
    await _logHistory(
      groupId: groupId,
      expenseId: expenseId,
      expenseDescription: expenseDescription,
      action: 'settlement_confirmed',
      performedBy: confirmedBy,
      performedByName: confirmedByName,
      details: 'Pago de $uidName confirmado.',
    );
    await sendSystemMessage(
      groupId: groupId,
      text:
          '✅ $confirmedByName confirmó el pago de $uidName en "$expenseDescription".',
    );
  }

  // ---------------------------------------------------------------------
  // PROPUESTAS DE EDICIÓN / ELIMINACIÓN (requieren consenso de TODOS)
  // ---------------------------------------------------------------------

  Stream<List<ExpenseProposal>> watchProposals(
    String groupId,
    String expenseId,
  ) {
    return _proposalsRef(groupId, expenseId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => ExpenseProposal.fromFirestore(d)).toList(),
        );
  }

  Stream<ExpenseProposal?> watchProposal(
    String groupId,
    String expenseId,
    String proposalId,
  ) {
    return _proposalsRef(groupId, expenseId)
        .doc(proposalId)
        .snapshots()
        .map((doc) => doc.exists ? ExpenseProposal.fromFirestore(doc) : null);
  }

  Future<void> proposeExpenseEdit({
    required String groupId,
    required String expenseId,
    required String proposedBy,
    required String proposedByName,
    required Map<String, dynamic> oldValues,
    required Map<String, dynamic> newValues,
  }) async {
    final proposalRef = _proposalsRef(groupId, expenseId).doc();
    await proposalRef.set({
      'expenseId': expenseId,
      'proposedBy': proposedBy,
      'proposedByName': proposedByName,
      'createdAt': Timestamp.now(),
      'status': 'pending',
      'type': 'edit',
      'oldValues': oldValues,
      'newValues': newValues,
      'responses': {proposedBy: 'accepted'},
    });

    await _messagesRef(groupId).add({
      'type': 'proposal',
      'senderId': proposedBy,
      'senderName': proposedByName,
      'expenseId': expenseId,
      'proposalId': proposalRef.id,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': Timestamp.now(),
    });

    await _logHistory(
      groupId: groupId,
      expenseId: expenseId,
      expenseDescription: (oldValues['description'] ?? '').toString(),
      action: 'edit_proposed',
      performedBy: proposedBy,
      performedByName: proposedByName,
    );
  }

  /// Propone ELIMINAR un gasto (ej: se agregó por error), aunque
  /// todavía tenga deudas pendientes. Requiere que todos acepten.
  Future<void> proposeExpenseDeletion({
    required String groupId,
    required String expenseId,
    required String proposedBy,
    required String proposedByName,
    required Map<String, dynamic> expenseSnapshot,
  }) async {
    final proposalRef = _proposalsRef(groupId, expenseId).doc();
    await proposalRef.set({
      'expenseId': expenseId,
      'proposedBy': proposedBy,
      'proposedByName': proposedByName,
      'createdAt': Timestamp.now(),
      'status': 'pending',
      'type': 'delete',
      'oldValues': expenseSnapshot,
      'newValues': <String, dynamic>{},
      'responses': {proposedBy: 'accepted'},
    });

    await _messagesRef(groupId).add({
      'type': 'proposal',
      'senderId': proposedBy,
      'senderName': proposedByName,
      'expenseId': expenseId,
      'proposalId': proposalRef.id,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': Timestamp.now(),
    });

    await _logHistory(
      groupId: groupId,
      expenseId: expenseId,
      expenseDescription: (expenseSnapshot['description'] ?? '').toString(),
      action: 'delete_proposed',
      performedBy: proposedBy,
      performedByName: proposedByName,
    );
  }

  /// Registra la respuesta de un miembro a una propuesta (edición o
  /// eliminación). Si con esta respuesta TODOS ya aceptaron, el cambio
  /// se aplica automáticamente. Si alguien rechaza, queda descartada.
  Future<String> respondToProposal({
    required String groupId,
    required String expenseId,
    required String proposalId,
    required String uid,
    required String response, // 'accepted' | 'rejected'
    required List<String> groupMemberIds,
  }) async {
    final proposalRef = _proposalsRef(groupId, expenseId).doc(proposalId);
    final expenseRef = _expensesRef(groupId).doc(expenseId);

    late String finalStatus;
    late String proposalType;
    late String expenseDescription;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(proposalRef);
      if (!snap.exists) throw Exception('La propuesta ya no existe');
      final data = snap.data() as Map<String, dynamic>;

      final responses = Map<String, String>.from(data['responses'] ?? {});
      responses[uid] = response;

      String status = data['status'] ?? 'pending';
      proposalType = data['type'] ?? 'edit';
      expenseDescription = (data['oldValues']?['description'] ?? '').toString();

      if (status == 'pending') {
        if (response == 'rejected') {
          status = 'rejected';
        } else {
          final allAccepted = groupMemberIds.every(
            (m) => responses[m] == 'accepted',
          );
          if (allAccepted) status = 'approved';
        }
      }

      tx.update(proposalRef, {'responses': responses, 'status': status});

      if (status == 'approved') {
        if (proposalType == 'delete') {
          tx.delete(expenseRef);
        } else {
          final newValues = Map<String, dynamic>.from(data['newValues']);
          tx.update(expenseRef, {
            ...newValues,
            'lastEditedAt': Timestamp.now(),
          });
        }
      }

      finalStatus = status;
    });

    final actionPrefix = proposalType == 'delete' ? 'delete' : 'edit';
    if (finalStatus == 'approved' || finalStatus == 'rejected') {
      await _logHistory(
        groupId: groupId,
        expenseId: expenseId,
        expenseDescription: expenseDescription,
        action: '${actionPrefix}_$finalStatus',
        performedBy: uid,
        performedByName: '',
      );
    }

    return finalStatus;
  }

  // ---------------------------------------------------------------------
  // HISTORIAL DE CAMBIOS
  // ---------------------------------------------------------------------

  Stream<List<HistoryEntry>> watchHistory(String groupId) {
    return _historyRef(groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => HistoryEntry.fromFirestore(d)).toList(),
        );
  }

  Future<void> _logHistory({
    required String groupId,
    required String expenseId,
    required String expenseDescription,
    required String action,
    required String performedBy,
    required String performedByName,
    String? details,
  }) async {
    await _historyRef(groupId).add({
      'expenseId': expenseId,
      'expenseDescription': expenseDescription,
      'action': action,
      'performedBy': performedBy,
      'performedByName': performedByName,
      'details': details,
      'createdAt': Timestamp.now(),
    });
  }

  // ---------------------------------------------------------------------
  // CHAT GRUPAL
  // ---------------------------------------------------------------------

  Stream<List<ChatMessage>> watchMessages(String groupId) {
    return _messagesRef(groupId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => ChatMessage.fromFirestore(d)).toList(),
        );
  }

  /// Escucha mensajes de otros integrantes posteriores a la última lectura.
  /// `lastReadAt` vive en el documento del grupo, sin cambiar los modelos.
  Stream<int> watchUnreadMessageCount({
    required String groupId,
    required String uid,
  }) {
    return _groupsRef.doc(groupId).snapshots().asyncExpand((groupSnapshot) {
      if (!groupSnapshot.exists) {
        return Stream<int>.error(StateError('El grupo ya no existe.'));
      }

      final groupData = groupSnapshot.data() as Map<String, dynamic>;
      final readStates = groupData['lastReadAt'];
      final lastReadAt = readStates is Map ? readStates[uid] : null;
      final cutoff = lastReadAt is Timestamp
          ? lastReadAt
          : Timestamp.fromMillisecondsSinceEpoch(0);

      return _messagesRef(groupId)
          .where('timestamp', isGreaterThan: cutoff)
          .snapshots()
          .map(
            (messages) => messages.docs.where((document) {
              final data = document.data() as Map<String, dynamic>;
              final senderId = data['senderId'];
              return senderId is String &&
                  senderId != uid &&
                  senderId != 'system';
            }).length,
          );
    });
  }

  /// Marca como leídos los mensajes actuales del grupo para [uid].
  Future<void> markGroupMessagesRead({
    required String groupId,
    required String uid,
  }) async {
    await _groupsRef.doc(groupId).update({
      FieldPath(['lastReadAt', uid]): FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendTextMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    String? text,
    String? imageUrl,
    String? senderPhotoUrl,
  }) async {
    final message = <String, dynamic>{
      'type': 'text',
      'senderId': senderId,
      'senderName': senderName,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': Timestamp.now(),
    };
    if (text != null && text.trim().isNotEmpty) message['text'] = text.trim();
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      message['imageUrl'] = imageUrl.trim();
    }
    if (senderPhotoUrl != null && senderPhotoUrl.trim().isNotEmpty) {
      message['senderPhotoUrl'] = senderPhotoUrl.trim();
    }
    await _messagesRef(groupId).add(message);
  }

  Future<void> sendImageMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String imageBase64,
    required String imageContentType,
    String? text,
    String? senderPhotoUrl,
  }) async {
    if (imageBase64.length > maxChatImageBase64Length) {
      throw ArgumentError(
        'El comprobante supera el límite de 700 KB. '
        'Recórtalo o selecciona una imagen más liviana.',
      );
    }
    if (!imageContentType.startsWith('image/')) {
      throw ArgumentError.value(imageContentType, 'imageContentType');
    }

    final message = <String, dynamic>{
      'type': 'text',
      'senderId': senderId,
      'senderName': senderName,
      'imageBase64': imageBase64,
      'imageContentType': imageContentType,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': Timestamp.now(),
    };
    if (text != null && text.trim().isNotEmpty) message['text'] = text.trim();
    if (senderPhotoUrl != null && senderPhotoUrl.trim().isNotEmpty) {
      message['senderPhotoUrl'] = senderPhotoUrl.trim();
    }
    await _messagesRef(groupId).add(message);
  }

  Future<void> sendSystemMessage({
    required String groupId,
    required String text,
  }) async {
    await _messagesRef(groupId).add({
      'type': 'system',
      'senderId': 'system',
      'senderName': 'SplitEasy',
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': Timestamp.now(),
    });
  }

  /// Calcula el balance actual del grupo y publica un resumen en el
  /// chat, para que se note el efecto de "compensación" entre gastos
  /// (ej: lo que pagaste en una salida reduce lo que le debes a
  /// alguien de otra salida dentro del mismo grupo).
  Future<void> notifyBalanceUpdate(GroupModel group) async {
    final expenses = await getGroupExpensesOnce(group.id);
    final balances = calculateBalances(group: group, expenses: expenses);
    final settlements = simplifyDebts(balances);

    String text;
    if (settlements.isEmpty) {
      text = '📊 Balance actualizado: ¡todos están a mano en este grupo!';
    } else {
      final lines = settlements
          .map(
            (s) =>
                '• ${s.fromName} le debe ${_formatCurrency(s.amount)} a ${s.toName}',
          )
          .join('\n');
      text = '📊 Balance actualizado tras este movimiento:\n$lines';
    }

    await sendSystemMessage(groupId: group.id, text: text);
  }

  String _formatCurrency(double value) {
    final rounded = value.round();
    final str = rounded.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return '\$$buffer';
  }

  // ---------------------------------------------------------------------
  // CÁLCULO DE BALANCES (soporta pagadores múltiples y reparto
  // personalizado por %, montos manuales o partes iguales)
  // ---------------------------------------------------------------------

  List<MemberBalance> calculateBalances({
    required GroupModel group,
    required List<ExpenseModel> expenses,
  }) {
    final Map<String, double> paid = {for (var id in group.memberIds) id: 0};
    final Map<String, double> owed = {for (var id in group.memberIds) id: 0};

    for (final expense in expenses) {
      expense.payments.forEach((uid, amountPaid) {
        paid[uid] = (paid[uid] ?? 0) + amountPaid;
      });
      expense.participantShares.forEach((uid, shareAmount) {
        owed[uid] = (owed[uid] ?? 0) + shareAmount;
      });
    }

    return group.memberIds.map((uid) {
      return MemberBalance(
        uid: uid,
        name: group.memberNames[uid] ?? 'Usuario',
        totalPaid: paid[uid] ?? 0,
        totalOwed: owed[uid] ?? 0,
      );
    }).toList();
  }

  /// Simplifica las deudas del grupo al mínimo número de transacciones
  /// posibles (algoritmo greedy). Como se calcula sobre el balance
  /// ACUMULADO de todos los gastos del grupo, esto ya neta
  /// automáticamente pagos hechos en distintos gastos/salidas entre
  /// las mismas personas.
  List<SettlementTransaction> simplifyDebts(List<MemberBalance> balances) {
    final debtors = balances.where((b) => b.balance < -0.01).toList()
      ..sort((a, b) => a.balance.compareTo(b.balance));
    final creditors = balances.where((b) => b.balance > 0.01).toList()
      ..sort((a, b) => b.balance.compareTo(a.balance));

    final List<SettlementTransaction> transactions = [];

    final Map<String, double> pendingDebt = {
      for (var d in debtors) d.uid: -d.balance,
    };
    final Map<String, double> pendingCredit = {
      for (var c in creditors) c.uid: c.balance,
    };

    int i = 0, j = 0;
    while (i < debtors.length && j < creditors.length) {
      final debtor = debtors[i];
      final creditor = creditors[j];
      final amount = [
        pendingDebt[debtor.uid]!,
        pendingCredit[creditor.uid]!,
      ].reduce((a, b) => a < b ? a : b);

      if (amount > 0.01) {
        transactions.add(
          SettlementTransaction(
            fromUid: debtor.uid,
            fromName: debtor.name,
            toUid: creditor.uid,
            toName: creditor.name,
            amount: double.parse(amount.toStringAsFixed(2)),
          ),
        );
      }

      pendingDebt[debtor.uid] = pendingDebt[debtor.uid]! - amount;
      pendingCredit[creditor.uid] = pendingCredit[creditor.uid]! - amount;

      if (pendingDebt[debtor.uid]! < 0.01) i++;
      if (pendingCredit[creditor.uid]! < 0.01) j++;
    }

    return transactions;
  }
}
