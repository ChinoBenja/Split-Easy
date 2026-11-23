import 'dart:async';

extension InitialStreamTimeout<T> on Stream<T> {
  Stream<T> withInitialTimeout(Duration duration, {required String operation}) {
    return Stream<T>.multi((controller) {
      var receivedEvent = false;
      final timer = Timer(duration, () {
        if (!receivedEvent) {
          controller.addError(
            TimeoutException(
              'No se recibieron datos para $operation en '
              '${duration.inSeconds} segundos.',
              duration,
            ),
          );
        }
      });
      final subscription = listen(
        (event) {
          if (!receivedEvent) {
            receivedEvent = true;
            timer.cancel();
          }
          controller.add(event);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!receivedEvent) {
            receivedEvent = true;
            timer.cancel();
          }
          controller.addError(error, stackTrace);
        },
        onDone: () {
          timer.cancel();
          controller.close();
        },
        cancelOnError: false,
      );

      controller.onPause = () => subscription.pause();
      controller.onResume = subscription.resume;
      controller.onCancel = () {
        timer.cancel();
        return subscription.cancel();
      };
    }, isBroadcast: isBroadcast);
  }
}
