import 'dart:async';
import 'dart:isolate';

import 'package:meta/meta.dart';
import 'package:rollbar_common/rollbar_common.dart';

import '../data/payload/breadcrumb.dart';
import '../sender/sender.dart';
import '../wrangler/wrangler.dart';
import '../config.dart';
import '../context.dart';
import '../event.dart';
import '../telemetry.dart';
import 'async_notifier.dart';

/// An asynchronous notifier that leverages Dart's Isolated execution contexts
/// to achieve asynchrony via a separate thread.
@sealed
@immutable
@internal
class IsolatedNotifier extends AsyncNotifier {
  final SendPort _sendPort;
  final ReceivePort _receivePort;
  final Isolate _isolate;

  IsolatedNotifier._(
    super.config,
    this._isolate,
    this._receivePort,
    this._sendPort,
  );

  @override
  void notify(Event event) {
    _sendPort.send(event);
  }

  @override
  void dispose() {
    _receivePort.close();
    _isolate.kill(priority: Isolate.beforeNextEvent);
  }

  static Future<IsolatedNotifier> spawn(Config config) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(_IsolatedNotifier$Isolate.run, Tuple2(receivePort.sendPort, config),
        paused: false, errorsAreFatal: true, debugName: 'IsolatedNotifier\$Isolate');
    final sendPort = await receivePort.first;

    return IsolatedNotifier._(config, isolate, receivePort, sendPort);
  }
}

extension _IsolatedNotifier$Isolate on IsolatedNotifier {
  static late final Wrangler wrangler;
  static late final Sender sender;
  static late final Telemetry telemetry;
  static late final Context context;

  static Future<void> run(Tuple2<SendPort, Config> tuple) async {
    final sendPort = tuple.first;
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    final config = tuple.second;
    sender = config.sender(config);
    wrangler = config.wrangler(config);
    telemetry = Telemetry(config);
    context = Context();

    await for (final Event event in receivePort) {
      if (event.setUser) {
        context.user = event.user;
      } else if (event.breadcrumb != null) {
        telemetry.add(event.breadcrumb!);
      } else {
        telemetry.removeExpired();

        final payload = await wrangler.payload(
          event: event.copyWith(context: context, telemetry: telemetry),
        );
        await sender.send(payload.toMap());
      }
    }
  }
}
