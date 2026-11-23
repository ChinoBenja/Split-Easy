import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:split_easy/utils/stream_timeout.dart';

void main() {
  test('reports an initial timeout and forwards a later event', () async {
    final source = StreamController<int>();
    final receivedTimeout = Completer<Object>();
    final receivedValue = Completer<int>();

    final subscription = source.stream
        .withInitialTimeout(
          const Duration(milliseconds: 20),
          operation: 'prueba',
        )
        .listen(
          receivedValue.complete,
          onError: (Object error) => receivedTimeout.complete(error),
        );

    expect(await receivedTimeout.future, isA<TimeoutException>());
    source.add(42);
    expect(await receivedValue.future, 42);

    await subscription.cancel();
    await source.close();
  });

  test('cancels the timer after the first event', () async {
    final source = StreamController<int>();
    final receivedValue = Completer<int>();
    final errors = <Object>[];

    final subscription = source.stream
        .withInitialTimeout(
          const Duration(milliseconds: 20),
          operation: 'prueba',
        )
        .listen(receivedValue.complete, onError: errors.add);

    source.add(7);
    expect(await receivedValue.future, 7);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(errors, isEmpty);

    await subscription.cancel();
    await source.close();
  });
}
