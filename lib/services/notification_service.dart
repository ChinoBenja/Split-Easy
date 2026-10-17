import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Servicio de notificaciones push (Requerimiento funcional:
/// "Enviar notificaciones push a los usuarios cuando se registre
/// un nuevo gasto").
///
/// IMPORTANTE: este servicio deja todo listo del lado del cliente
/// (permisos, token, escucha de mensajes), pero el ENVÍO real de la
/// notificación cuando otro usuario agrega un gasto requiere una
/// Cloud Function (o backend) que escuche la colección `expenses`
/// y dispare el push a los `fcmToken` de los demás miembros del grupo.
/// El cliente por sí solo no puede notificar a otros dispositivos.
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Pide permisos y guarda el token del dispositivo en el documento
  /// del usuario para que el backend/Cloud Function pueda usarlo.
  Future<void> initialize(String uid) async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await _messaging.getToken();
    if (token != null) {
      await _db.collection('users').doc(uid).set(
        {'fcmToken': token},
        SetOptions(merge: true),
      );
    }

    // Actualiza el token si Firebase lo renueva
    _messaging.onTokenRefresh.listen((newToken) {
      _db.collection('users').doc(uid).set(
        {'fcmToken': newToken},
        SetOptions(merge: true),
      );
    });
  }

  /// Escucha mensajes recibidos mientras la app está abierta (foreground).
  /// Conecta esto a un paquete de notificaciones locales
  /// (ej: flutter_local_notifications) si quieres mostrar un banner.
  void listenForegroundMessages(void Function(RemoteMessage) onMessage) {
    FirebaseMessaging.onMessage.listen(onMessage);
  }

  /// Se dispara cuando el usuario toca la notificación y la app
  /// estaba en segundo plano.
  void listenNotificationTaps(void Function(RemoteMessage) onTap) {
    FirebaseMessaging.onMessageOpenedApp.listen(onTap);
  }
}

/// Ejemplo de la Cloud Function (Node.js) que deberías crear en el
/// backend de Firebase para completar el flujo — la dejo como
/// referencia, no forma parte del código Flutter:
///
/// exports.onExpenseCreated = functions.firestore
///   .document('groups/{groupId}/expenses/{expenseId}')
///   .onCreate(async (snap, context) => {
///     const expense = snap.data();
///     const group = await admin.firestore()
///       .collection('groups').doc(context.params.groupId).get();
///     const payerIds = Object.keys(expense.payments || {});
///     const memberIds = group.data().memberIds
///       .filter(uid => !payerIds.includes(uid));
///     const tokens = await Promise.all(memberIds.map(async uid => {
///       const user = await admin.firestore().collection('users').doc(uid).get();
///       return user.data()?.fcmToken;
///     }));
///     const payerNames = Object.values(expense.payerNames || {}).join(' y ');
///     await admin.messaging().sendEachForMulticast({
///       tokens: tokens.filter(Boolean),
///       notification: {
///         title: 'Nuevo gasto en el grupo',
///         body: `${payerNames} agregó "${expense.description}"`,
///       },
///     });
///   });
