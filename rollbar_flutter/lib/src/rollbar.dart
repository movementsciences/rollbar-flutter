import 'dart:async';

import 'package:meta/meta.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:rollbar_dart/rollbar.dart';

import 'flutter_error.dart';
import 'platform_transformer.dart';

extension _Methods on MethodChannel {
  Future<void> initialize({required Config config}) async => await invokeMethod('initialize', config.toMap());

  /// The platform-specific path where we can persist data if needed.
  Future<String> get persistencePath async => await invokeMethod('persistencePath');
}

typedef RollbarClosure = FutureOr<void> Function();

@sealed
class RollbarFlutter {
  static const _platform = MethodChannel('com.rollbar.flutter');

  final Config config;

  RollbarFlutter._create(this.config);

  static Future<RollbarFlutter> initialize(Config config) async {
    WidgetsFlutterBinding.ensureInitialized();

    final instance = RollbarFlutter._create(config);

    await Rollbar.run(config.copyWith(
      framework: 'flutter',
      persistencePath: await _platform.persistencePath,
      transformer: (_) => PlatformTransformer(),
    ));

    await _platform.initialize(config: config);

    if (config.handleUncaughtErrors) {
      FlutterError.onError = RollbarFlutterError.onError;
    }

    return instance;
  }

  Future<void> runApp(RollbarClosure appRunner) async {
    if (config.handleUncaughtErrors) {
      await runZonedGuarded(() async {
        await appRunner();
      }, (exception, stackTrace) {
        Rollbar.error(exception, stackTrace);
      });
    } else {
      await appRunner();
    }
  }

  static Future<void> run(
    Config config,
    RollbarClosure appRunner,
  ) async {
    await RollbarFlutter.initialize(config).then((rf) => rf.runApp(appRunner));
  }
}
