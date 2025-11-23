# Technical Debt

This document tracks technical debt and temporary code that should be addressed in future versions.

## High Priority

### 1. Remove v2.x Legacy Format Support (Target: v5.0)
**Location:** 
- `lib/src/vault_storage_impl.dart` - `_getFromBoxBase()` method
- `lib/src/extensions/storage_extensions.dart` - `JsonSafe.decode()` method

**Description:**
Legacy support for reading v2.x data stored as plain JSON strings without type markers. In v3.0, we detect strings and decode them using `decodeJsonSafely<T>()`. This adds overhead to every read operation.

**Migration Path:**
- v3.x → v4.x: Keep backward compatibility, add deprecation warnings in docs
- v5.0: Remove legacy string detection entirely
- All data will be expected to use v3+ wrapper format with type markers

**Code to Remove:**
```dart
// In _getFromBoxBase()
if (stored is String) {
  return stored.decodeJsonSafely<T>();
}
```

**Impact:** 
- Simplifies read path (remove one branch)
- ~5-10% performance improvement on reads
- Breaking change - requires data migration from v2.x users

---

## Medium Priority

### 2. Simplify Type Coercion Logic (Target: v4.0)
**Location:**
- `lib/src/vault_storage_impl.dart` - `_coerceToType<T>()` method
- `lib/src/extensions/storage_extensions.dart` - `JsonSafe._coerceType<T>()` method
- `lib/src/extensions/storage_extensions.dart` - `JsonSafe.decode()` type marker paths (lines 245-261)

**Description:**
Current implementation handles String→int/double parsing for v2.x compatibility, plus type coercion in type marker paths (e.g., reading int as String). This adds complexity and error handling overhead.

**Added in v3.0:** Type coercion now applied to all type marker paths to handle users changing their type expectations:
```dart
if (encodedValue.startsWith(_intMarker)) {
  final value = int.parse(...);
  return _coerceType<T>(value);  // ← Allows reading int as String, etc.
}
```

**Recommendation:**
After v2.x support is dropped in v5.0, decide if we want to keep flexible type coercion or enforce strict types. Options:

**Option A (Strict):** Remove coercion, throw errors on mismatch
```dart
if (encodedValue.startsWith(_intMarker)) {
  final value = int.parse(...);
  if (value is! T) throw TypeMismatchError();
  return value as T;
}
```

**Option B (Simple Coercion):** Keep only basic conversions
```dart
if (T == int && value is num) return value.toInt() as T;
if (T == double && value is num) return value.toDouble() as T;
if (T == String && value != null) return value.toString() as T;
// Throw for everything else
```

---

### 3. Remove Redundant Error Messages (Target: v4.0)
**Location:**
- `lib/src/vault_storage_impl.dart` - `_coerceToType()` error messages
- `lib/src/extensions/storage_extensions.dart` - `_coerceType()` error messages

**Description:**
Error messages mention "Consider clearing corrupted data" which is application-level guidance. Storage layer should just report the mismatch.

**Simplify to:**
```dart
throw StorageReadError('Type mismatch: expected $T, got ${value.runtimeType}');
```

---

## Low Priority

### 4. Consolidate Type Coercion (Target: v5.0)
**Location:**
- `lib/src/vault_storage_impl.dart` - `_coerceToType<T>()` 
- `lib/src/extensions/storage_extensions.dart` - `JsonSafe._coerceType<T>()`

**Description:**
Same logic exists in two places with slightly different error types (`StorageReadError` vs `StorageSerializationError`). Could be unified into a single utility.

**Recommendation:**
Extract to `lib/src/utils/type_coercion.dart` with clear separation:
```dart
class TypeCoercion {
  static T coerce<T>(dynamic value) {
    // Unified logic
  }
}
```

Then wrap with appropriate error types in each location.

---

## Notes

- All breaking changes should be documented in CHANGELOG with migration guides
- Consider adding runtime warnings (debugPrint) one version before removal
- Test coverage should be maintained for legacy paths until removal
