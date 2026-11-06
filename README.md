# split_easy

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Asistente IA gratuito (Firebase Spark + Cloudflare Workers AI)

Firebase sigue gestionando el inicio de sesión. El backend del asistente usa un
Worker de Cloudflare y el modelo `@cf/meta/llama-3.1-8b-instruct-fp8`; no hace
falta desplegar Cloud Functions ni configurar Firebase Blaze. La cuota gratuita
de Workers AI es de 10.000 neuronas por día. Al agotarla, las respuestas fallan
hasta el siguiente reinicio de la cuota; no se hace una actualización automática
a un plan de pago.

1. Crea una cuenta Cloudflare y mantén el plan Workers Free. En la terminal:

   ```sh
   cd worker
   npm install
   npx wrangler login
   npx wrangler deploy
   ```

2. Copia la URL `https://spliteasy-assistant.<tu-subdominio>.workers.dev` que
   Wrangler muestra al desplegar.
3. Desde la raíz del proyecto, pasa esa URL al compilar o ejecutar Flutter:

   ```sh
   flutter run -d chrome --dart-define=ASSISTANT_WORKER_URL=https://spliteasy-assistant.<tu-subdominio>.workers.dev
   ```

   Para Android, compila el APK con el mismo `--dart-define`.
4. Inicia sesión en SplitEasy y abre **Asistente IA**.

El Worker valida el token de Firebase Authentication antes de aceptar mensajes,
limita cada conversación a 12 mensajes y no almacena el historial. No recibe
automáticamente grupos, gastos ni datos del perfil. El límite por usuario en el
Worker es de mejor esfuerzo; no reemplaza los límites globales de cuota de
Cloudflare.

## Fotos de perfil sin Firebase Storage

Las fotos de perfil se guardan como miniaturas optimizadas en el documento del
usuario en Cloud Firestore. Esto evita Firebase Storage y no requiere el plan
Blaze; las imágenes están disponibles para los usuarios que iniciaron sesión en
SplitEasy. La app limita la imagen a 320 × 320 píxeles y 256 KB para mantenerla
bajo el límite de tamaño de documentos de Firestore. Se aplican las cuotas
gratuitas de Firestore y cada perfil que lee la app incluye su foto.

Al crear un grupo también se puede elegir una foto opcional (miniatura de hasta
120 KB). La imagen se guarda en el documento del grupo y solo pueden verla sus
integrantes autenticados. Después de crear el grupo, la app no permite cambiar
esa foto; publica las reglas actualizadas de `firestore.rules` en Firebase para
hacer cumplir también esa restricción en el servidor:

```sh
firebase deploy --only firestore:rules
```

Al tocar el nombre del grupo se abre la lista de integrantes con el nombre
guardado al registrarse y su foto de perfil.
