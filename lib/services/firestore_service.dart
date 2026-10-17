import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../models/expense_proposal_model.dart';
import '../models/message_model.dart';
import '../models/balance_model.dart';
import '../models/history_entry_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _usersRef => _db.collection('users');
  CollectionReference get _groupsRef => _db.collection('groups');
  CollectionReference _expensesRef(String groupId) =>
      _groupsRef.doc(groupId).collection('expenses');
  CollectionReference _proposalsRef(String groupId, String expenseId) =>
      _expensesRef(groupId).doc(expenseId).collection('proposals');
  CollectionReference _messagesRef(String groupId) =>
      _groupsRef.doc(groupId).collection('messages');
  CollectionReference _historyRef(String groupId) =>
      _groupsRef.doc(groupId).collection('history');

  // ---------------------------------------------------------------------
  // USUARIOS
  // ---------------------------------------------------------------------

  Future<void> upsertUser({
    required String uid,
    required String name,
    required String email,
  }) async {
    await _usersRef.doc(uid).set({
      'name': name,
      'email': email,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    final query = await _usersRef
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return {'uid': query.docs.first.id, ...query.docs.first.data() as Map};
  }

  // ---------------------------------------------------------------------
  // GRUPOS
  // ---------------------------------------------------------------------

  Stream<List<GroupModel>> watchUserGroups(String uid) {
    return _groupsRef
        .where('memberIds', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => GroupModel.fromFirestore(doc)).toList());
  }

  Future<String> createGroup({
    required String name,
    required String description,
    required String createdBy,
    required Map<String, String> memberNames,
  }) async {
    final doc = await _groupsRef.add({
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'memberIds': memberNames.keys.toList(),
      'memberNames': memberNames,
      'customCategories': <String>[],
      'createdAt': Timestamp.now(),
    });
    return doc.id;
  }

  Future<void> addMemberToGroup({
    required String groupId,
    required String memberUid,
    required String memberName,
  }) async {
    await _groupsRef.doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([memberUid]),
      'memberNames.$memberUid': memberName,
    });
  }

  Future<void> removeMemberFromGroup({
    required String groupId,
    required String memberUid,
  }) async {
    await _groupsRef.doc(groupId).update({
      'memberIds': FieldValue.arrayRemove([memberUid]),
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
        .map((snap) =>
            snap.docs.map((doc) => ExpenseModel.fromFirestore(doc)).toList());
  }

  Stream<ExpenseModel?> watchExpense(String groupId, String expenseId) {
    return _expensesRef(groupId).doc(expenseId).snapshots().map(
        (doc) => doc.exists ? ExpenseModel.fromFirestore(doc) : null);
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
        details: details ?? 'Eliminado directamente desde la pantalla de detalle.',
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
      text: '🗑️ $performedByName eliminó "${expense.description}" (ya no tenía deudas pendientes).',
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
      text: '✅ $confirmedByName confirmó el pago de $uidName en "$expenseDescription".',
    );
  }

  // ---------------------------------------------------------------------
  // PROPUESTAS DE EDICIÓN / ELIMINACIÓN (requieren consenso de TODOS)
  // ---------------------------------------------------------------------

  Stream<List<ExpenseProposal>> watchProposals(String groupId, String expenseId) {
    return _proposalsRef(groupId, expenseId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ExpenseProposal.fromFirestore(d)).toList());
  }

  Stream<ExpenseProposal?> watchProposal(
      String groupId, String expenseId, String proposalId) {
    return _proposalsRef(groupId, expenseId).doc(proposalId).snapshots().map(
        (doc) => doc.exists ? ExpenseProposal.fromFirestore(doc) : null);
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
          final allAccepted =
              groupMemberIds.every((m) => responses[m] == 'accepted');
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
        .map((snap) => snap.docs.map((d) => HistoryEntry.fromFirestore(d)).toList());
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
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map((d) => ChatMessage.fromFirestore(d)).toList());
  }

  Future<void> sendTextMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    await _messagesRef(groupId).add({
      'type': 'text',
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'createdAt': Timestamp.now(),
    });
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
          .map((s) =>
              '• ${s.fromName} le debe ${_formatCurrency(s.amount)} a ${s.toName}')
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
      for (var d in debtors) d.uid: -d.balance
    };
    final Map<String, double> pendingCredit = {
      for (var c in creditors) c.uid: c.balance
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
        transactions.add(SettlementTransaction(
          fromUid: debtor.uid,
          fromName: debtor.name,
          toUid: creditor.uid,
          toName: creditor.name,
          amount: double.parse(amount.toStringAsFixed(2)),
        ));
      }

      pendingDebt[debtor.uid] = pendingDebt[debtor.uid]! - amount;
      pendingCredit[creditor.uid] = pendingCredit[creditor.uid]! - amount;

      if (pendingDebt[debtor.uid]! < 0.01) i++;
      if (pendingCredit[creditor.uid]! < 0.01) j++;
    }

    return transactions;
  }
}
