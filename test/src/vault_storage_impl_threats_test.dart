import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/mock/freerasp_mock.dart'
    if (dart.library.io) 'package:freerasp/freerasp.dart'
    show ThreatCallback;
import 'package:vault_storage/src/security/security_exceptions.dart';
import 'package:vault_storage/src/security/vault_security_config.dart';
import 'package:vault_storage/src/vault_storage_impl.dart';

import '../mocks.dart';
import '../test_context.dart';

class _ThreatCase {
  const _ThreatCase({
    required this.threat,
    required this.entry,
    required this.blocking,
    required this.exception,
  });

  final SecurityThreat threat;
  final VoidCallback? Function(ThreatCallback) entry;
  final VaultSecurityConfig blocking;
  final Matcher exception;
}

const _allowing = VaultSecurityConfig(
  blockOnJailbreak: false,
  blockOnTampering: false,
  blockOnHooks: false,
);

final _environmentThreats = <_ThreatCase>[
  _ThreatCase(
    threat: .jailbreak,
    entry: (callback) => callback.onPrivilegedAccess,
    blocking: _allowing.copyWith(blockOnJailbreak: true),
    exception: isA<JailbreakDetectedException>(),
  ),
  _ThreatCase(
    threat: .tampering,
    entry: (callback) => callback.onAppIntegrity,
    blocking: _allowing.copyWith(blockOnTampering: true),
    exception: isA<TamperingDetectedException>(),
  ),
  _ThreatCase(
    threat: .debugging,
    entry: (callback) => callback.onDebug,
    blocking: _allowing.copyWith(blockOnDebug: true),
    exception: isA<DebugDetectedException>(),
  ),
  _ThreatCase(
    threat: .hooks,
    entry: (callback) => callback.onHooks,
    blocking: _allowing.copyWith(blockOnHooks: true),
    exception: isA<HookingDetectedException>(),
  ),
  _ThreatCase(
    threat: .emulator,
    entry: (callback) => callback.onSimulator,
    blocking: _allowing.copyWith(blockOnEmulator: true),
    exception: isA<EmulatorDetectedException>(),
  ),
  _ThreatCase(
    threat: .unofficialStore,
    entry: (callback) => callback.onUnofficialStore,
    blocking: _allowing.copyWith(blockOnUnofficialStore: true),
    exception: isA<UnofficialStoreDetectedException>(),
  ),
];

void main() {
  group('Threat callback', () {
    late TestContext testContext;

    setUpAll(MocksHelper.registerFallbackValues);

    setUp(() {
      testContext = TestContext()..setUpCommon();
    });

    tearDown(() {
      testContext.tearDownCommon();
    });

    for (final threatCase in _environmentThreats) {
      group('${threatCase.threat}', () {
        test('marks the environment insecure and runs the app callback', () {
          int calls = 0;
          final storage = testContext.createStorage(
            securityConfig: _allowing.copyWith(threatCallbacks: {threatCase.threat: () => calls++}),
          );

          threatCase.entry(storage.threatCallback())?.call();

          expect(storage.isSecureEnvironment, isFalse);
          expect(calls, 1);
        });

        test('throws its exception when the config blocks it', () {
          final storage = testContext.createStorage(securityConfig: threatCase.blocking);

          expect(
            () => threatCase.entry(storage.threatCallback())?.call(),
            throwsA(threatCase.exception),
          );
          expect(storage.isSecureEnvironment, isFalse);
        });
      });
    }

    test('a threat without an environment effect leaves the environment secure', () {
      int calls = 0;
      final storage = testContext.createStorage(
        securityConfig: _allowing.copyWith(threatCallbacks: {.screenshot: () => calls++}),
      );

      storage.threatCallback().onScreenshot?.call();

      expect(storage.isSecureEnvironment, isTrue);
      expect(calls, 1);
    });

    test('every other threat reaches its own app callback', () {
      final seen = <SecurityThreat>[];
      final storage = testContext.createStorage(
        securityConfig: _allowing.copyWith(
          threatCallbacks: {
            for (final threat in SecurityThreat.values) threat: () => seen.add(threat),
          },
        ),
      );
      final callback = storage.threatCallback();

      for (final entry in [
        callback.onScreenRecording,
        callback.onSystemVPN,
        callback.onPasscode,
        callback.onSecureHardwareNotAvailable,
        callback.onDevMode,
        callback.onAdbEnabled,
        callback.onMultiInstance,
        callback.onAutomation,
      ]) {
        entry?.call();
      }

      expect(seen, [
        SecurityThreat.screenRecording,
        SecurityThreat.systemVPN,
        SecurityThreat.passcode,
        SecurityThreat.secureHardware,
        SecurityThreat.developerMode,
        SecurityThreat.adbEnabled,
        SecurityThreat.multiInstance,
        SecurityThreat.automation,
      ]);
    });

    test('without a security config a threat changes nothing', () {
      final storage = testContext.createStorage();

      storage.threatCallback().onPrivilegedAccess?.call();

      expect(storage.isSecureEnvironment, isTrue);
    });

    group('RASP start', () {
      late List<String?> printed;
      late DebugPrintCallback originalDebugPrint;
      final started = <String>[];

      setUp(() {
        printed = [];
        originalDebugPrint = debugPrint;
        debugPrint = (message, {wrapWidth}) => printed.add(message);
        started.clear();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('talsec.app/freerasp/methods'),
          (call) async {
            started.add(call.method);
            return null;
          },
        );
      });

      tearDown(() {
        debugPrint = originalDebugPrint;
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('talsec.app/freerasp/methods'),
          null,
        );
      });

      test('an unsupported platform logs once and starts nothing', () async {
        debugDefaultTargetPlatformOverride = .macOS;
        final storage = testContext.createStorage();

        await storage.startRaspProtection(const VaultSecurityConfig(enableLogging: true));

        expect(printed, hasLength(1));
        expect(printed.single, contains('macOS'));
        expect(started, isEmpty);
      });

      test('an unsupported platform stays quiet without logging', () async {
        debugDefaultTargetPlatformOverride = .linux;
        final storage = testContext.createStorage();

        await storage.startRaspProtection(const VaultSecurityConfig());

        expect(printed, isEmpty);
        expect(started, isEmpty);
      });

      test('a supported platform starts the protection and logs both steps', () async {
        debugDefaultTargetPlatformOverride = .android;
        final storage = testContext.createStorage();

        await storage.startRaspProtection(
          VaultSecurityConfig(
            enableLogging: true,
            androidPackageName: 'com.example.app',
            androidSigningCertHashes: [base64Encode(.filled(32, 0))],
          ),
        );

        expect(started, isNotEmpty);
        expect(printed, hasLength(2));
      });
    });
  });
}
