import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/vault_storage.dart';

void main() {
  test('a jailbreak gets its own warning', () {
    expect(
      initializationFailure(const JailbreakDetectedException()),
      'Security Warning: Jailbreak detected - app may have limited functionality',
    );
  });

  test('tampering asks for a reinstall from the official source', () {
    expect(
      initializationFailure(const TamperingDetectedException()),
      'Security Error: App tampering detected - please reinstall from official source',
    );
  });

  test('another security threat reports its type and message', () {
    expect(
      initializationFailure(const SecurityThreatException('Debugger', 'attached')),
      'Security threat detected: Debugger - attached',
    );
  });

  test('any other error is reported as an initialization error', () {
    expect(initializationFailure(StateError('boom')), 'Initialization Error: Bad state: boom');
  });
}
