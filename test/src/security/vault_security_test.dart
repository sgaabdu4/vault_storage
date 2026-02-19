import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/vault_storage.dart';

import '../../mocks.dart';
import '../../test_context.dart';

void main() {
  group('VaultStorage Security Features', () {
    late TestContext testContext;

    setUpAll(() {
      MocksHelper.registerFallbackValues();
    });

    setUp(() {
      testContext = TestContext();
      testContext.setUpCommon();
    });

    tearDown(() {
      testContext.tearDownCommon();
    });

    group('VaultSecurityConfig', () {
      test('should create default config with security disabled', () {
        const config = VaultSecurityConfig();

        expect(config.enableRaspProtection, isFalse);
        expect(config.isProd, isTrue);
        expect(config.watcherMail, isNull);
        expect(config.threatCallbacks, isNull);
        expect(config.blockOnJailbreak, isTrue);
        expect(config.blockOnDebug, isFalse);
        expect(config.blockOnTampering, isTrue);
        expect(config.enableLogging, isFalse);
      });

      test('should create development config', () {
        final config = VaultSecurityConfig.development(
          watcherMail: 'dev@test.com',
        );

        expect(config.enableRaspProtection, isTrue);
        expect(config.isProd, isFalse);
        expect(config.watcherMail, equals('dev@test.com'));
        expect(config.blockOnJailbreak, isFalse);
        expect(config.blockOnDebug, isFalse);
        expect(config.blockOnTampering, isFalse);
        expect(config.enableLogging, isTrue);
      });

      test('should create production config', () {
        final config = VaultSecurityConfig.production(
          watcherMail: 'security@prod.com',
        );

        expect(config.enableRaspProtection, isTrue);
        expect(config.isProd, isTrue);
        expect(config.watcherMail, equals('security@prod.com'));
        expect(config.blockOnJailbreak, isTrue);
        expect(config.blockOnDebug, isTrue);
        expect(config.blockOnTampering, isTrue);
        expect(config.blockOnUnofficialStore, isTrue);
        expect(config.enableLogging, isFalse);
      });

      test('should copy with updated values', () {
        const originalConfig = VaultSecurityConfig();
        final updatedConfig = originalConfig.copyWith(
          enableRaspProtection: true,
          watcherMail: 'test@example.com',
          blockOnDebug: true,
        );

        expect(updatedConfig.enableRaspProtection, isTrue);
        expect(updatedConfig.watcherMail, equals('test@example.com'));
        expect(updatedConfig.blockOnDebug, isTrue);
        // Other values should remain the same
        expect(updatedConfig.isProd, equals(originalConfig.isProd));
        expect(updatedConfig.blockOnJailbreak, equals(originalConfig.blockOnJailbreak));
      });

      test('should handle threat callbacks', () {
        bool jailbreakCallbackCalled = false;
        bool tamperingCallbackCalled = false;

        final config = VaultSecurityConfig(
          threatCallbacks: {
            SecurityThreat.jailbreak: () => jailbreakCallbackCalled = true,
            SecurityThreat.tampering: () => tamperingCallbackCalled = true,
          },
        );

        // Simulate calling the callbacks
        config.threatCallbacks?[SecurityThreat.jailbreak]?.call();
        config.threatCallbacks?[SecurityThreat.tampering]?.call();

        expect(jailbreakCallbackCalled, isTrue);
        expect(tamperingCallbackCalled, isTrue);
      });

      test('should mask sensitive data in toString', () {
        const config = VaultSecurityConfig(
          enableRaspProtection: true,
          watcherMail: 'sensitive@email.com',
        );

        final stringRepresentation = config.toString();
        expect(stringRepresentation, contains('watcherMail: ***'));
        expect(stringRepresentation, isNot(contains('sensitive@email.com')));
      });
    });

    group('Security Exceptions', () {
      test('JailbreakDetectedException should have correct message', () {
        const exception = JailbreakDetectedException();

        expect(exception.threatType, equals('Jailbreak'));
        expect(exception.message, contains('jailbroken or rooted'));
        expect(exception.toString(), contains('SecurityThreatException: Jailbreak'));
      });

      test('TamperingDetectedException should have correct message', () {
        const exception = TamperingDetectedException();

        expect(exception.threatType, equals('Tampering'));
        expect(exception.message, contains('tampering detected'));
        expect(exception.toString(), contains('SecurityThreatException: Tampering'));
      });

      test('SecurityThreatException should handle cause', () {
        const cause = 'Original error';
        const exception = SecurityThreatException('Test', 'Test message', cause);

        expect(exception.cause, equals(cause));
        expect(exception.toString(), contains('caused by: $cause'));
      });
    });

    group('VaultStorage without Security', () {
      test('should create storage without security config', () {
        final storage = VaultStorage.create();
        expect(storage, isNotNull);
      });

      test('should initialize without security parameters', () async {
        // Use the test context storage which has proper mocking setup
        final storage = testContext.vaultStorage;

        // Reset initialization state for testing
        storage.isVaultStorageReady = false;

        // Mock the secure storage for initialization
        when(() => testContext.mockSecureStorage.read(key: any(named: 'key')))
            .thenAnswer((_) async => null);
        when(() => testContext.mockSecureStorage.write(
              key: any(named: 'key'),
              value: any(named: 'value'),
            )).thenAnswer((_) async {});

        // Should not throw when no security parameters provided
        await expectLater(storage.init(), completes);

        // Verify storage is ready after init
        expect(storage.isVaultStorageReady, isTrue);
      });
    });

    group('SecurityThreat enum', () {
      test('should have all expected threat types', () {
        const expectedThreats = [
          SecurityThreat.jailbreak,
          SecurityThreat.tampering,
          SecurityThreat.debugging,
          SecurityThreat.hooks,
          SecurityThreat.emulator,
          SecurityThreat.unofficialStore,
          SecurityThreat.screenshot,
          SecurityThreat.screenRecording,
          SecurityThreat.systemVPN,
          SecurityThreat.passcode,
          SecurityThreat.secureHardware,
          SecurityThreat.developerMode,
          SecurityThreat.adbEnabled,
          SecurityThreat.multiInstance,
          SecurityThreat.automation,
        ];

        expect(SecurityThreat.values, containsAll(expectedThreats));
        expect(SecurityThreat.values.length, equals(expectedThreats.length));
      });
    });
  });
}
