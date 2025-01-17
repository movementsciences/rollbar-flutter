@import SystemConfiguration;
@import RollbarNotifier;
@import RollbarPLCrashReporter;

#import "RollbarFlutterPlugin.h"

@implementation RollbarFlutterPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    FlutterMethodChannel *channel = [
        FlutterMethodChannel methodChannelWithName:@"com.rollbar.flutter"
                                   binaryMessenger:[registrar messenger]];
    RollbarFlutterPlugin *instance = [[RollbarFlutterPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall *)call
                  result:(FlutterResult)result
{
    if ([@"initialize" isEqualToString:call.method]) {
        NSDictionary *arguments = call.arguments;
        RollbarConfig *config = [[RollbarConfig alloc] init];
        config.destination.accessToken = (NSString *)arguments[@"accessToken"];
        config.destination.environment = (NSString *)arguments[@"environment"];
        config.loggingOptions.codeVersion = (NSString *)arguments[@"codeVersion"];

        id<RollbarCrashCollector> collector = [[RollbarPLCrashCollector alloc] init];
        [Rollbar initWithConfiguration:config crashCollector:collector];

        result(nil);
    } else if ([@"persistencePath" isEqualToString:call.method]) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(
            NSDocumentDirectory, NSUserDomainMask, YES);
        result(paths.firstObject);
    } else if ([@"close" isEqualToString:call.method]) {
        // No closing necessary
        result(nil);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

@end
