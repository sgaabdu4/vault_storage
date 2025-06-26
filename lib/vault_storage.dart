/// A barrel file that exports the public-facing API of the vault storage.
///
/// This file is the single entry point for other parts of the application to
/// access the vault storage's features. It exports the essential interfaces,
/// models, enums, and errors, simplifying imports and decoupling
/// feature modules from the internal implementation details of the service.
library;

// Interfaces and Models
export 'src/interface/i_vault_storage.dart';
export 'src/enum/storage_box_type.dart';
export 'src/errors/storage_error.dart';
export 'src/vault_storage_impl.dart';
