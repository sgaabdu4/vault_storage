# Test Structure Documentation

This document describes the organization and structure of the test suite for the Vault Storage Service.

## Test Organization

### Main Test Directories

- `test/unit/vault_storage/` - Modular tests for the main VaultStorage functionality
- `test/src/` - Tests for specific modules and utilities
- `test/integration/` - Integration tests (if any)

### Unit Test Files

The main vault storage tests are organized into focused, modular files:

1. **`key_value_operations_test.dart`** - Tests for basic key-value storage operations
   - get/set/delete/clear operations
   - Error handling for serialization issues
   - JSON encoding/decoding edge cases

2. **`secure_file_operations_test.dart`** - Tests for secure file storage
   - saveSecureFile/getSecureFile/deleteSecureFile operations
   - Encryption/decryption workflows
   - Web vs native platform handling
   - File metadata management

3. **`normal_file_operations_test.dart`** - Tests for normal file storage
   - saveNormalFile/getNormalFile/deleteNormalFile operations
   - Path provider integration
   - Web vs native platform handling
   - Base64 encoding for web storage

4. **`service_lifecycle_test.dart`** - Tests for service initialization and disposal
   - Service initialization and ready state
   - Box creation and configuration
   - Secure key generation and management
   - Cleanup and disposal operations

5. **`box_configuration_test.dart`** - Tests for storage box configuration
   - Box type to storage key mapping
   - Configuration validation

6. **`extension_integration_test.dart`** - Tests for extension method integration
   - JSON encoding/decoding extension usage
   - Base64 extension usage
   - Metadata handling extensions

### Module-Specific Tests

Tests in `test/src/` are organized by module:

- `constants/storage_keys_test.dart` - Tests for storage key constants
- `errors/storage_error_test.dart` - Tests for all error classes
- `extensions/storage_extensions_test.dart` - Tests for extension methods
- `storage/file_operations_test.dart` - Tests for FileOperations class
- `storage/task_execution_test.dart` - Tests for TaskExecutor class
- `storage/encryption_helpers_test.dart` - Tests for encryption utilities

### Test Helpers

- `test_context.dart` - Common test setup and teardown utilities
- `mocks.dart` - Mock class definitions
- `mocks.mocks.dart` - Generated mock implementations

## Coverage Goals

The test suite aims for maximum code coverage:
- **Current Coverage**: 98.5% (262 of 266 lines)
- **Target**: Close to 100% line coverage
- **Uncovered Lines**: Primarily private constructors and some edge cases

## Running Tests

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Generate HTML coverage report
genhtml coverage/lcov.info -o coverage/html

# Run specific test file
flutter test test/unit/vault_storage/key_value_operations_test.dart

# Run tests for specific module
flutter test test/src/extensions/
```

## Test Patterns

### Common Test Structure
- Each test file follows a consistent structure with descriptive group names
- Tests are organized by functionality (get/set/delete, etc.)
- Error cases are tested alongside success cases
- Both web and native platform scenarios are covered where applicable

### Mock Usage
- Mocks are used for external dependencies (Hive boxes, Flutter Secure Storage, etc.)
- The `test_context.dart` provides common mock setup to reduce duplication
- Mock behavior is configured per test to simulate various scenarios

### Async Testing
- All storage operations are async and properly awaited in tests
- Error handling is tested using functional programming patterns (Either types)
- Background operations and isolate usage are properly mocked

## Maintenance Guidelines

1. **Adding New Tests**: Place tests in the appropriate module-specific directory
2. **Updating Tests**: When adding new functionality, ensure corresponding tests are added
3. **Coverage**: Run coverage reports regularly to identify gaps
4. **Cleanup**: Remove outdated or duplicate tests promptly
5. **Documentation**: Update this README when changing test structure
