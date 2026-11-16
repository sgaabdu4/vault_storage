abstract final class FileMetadataKeys {
  static const fileId = 'fileId';
  static const filePath = 'filePath';
  static const secureKeyName = 'secureKeyName';
  static const nonce = 'nonce';
  static const mac = 'mac';
  static const extension = 'extension';
  static const streaming = 'streaming';
  static const chunkCount = 'chunkCount';
  static const chunkSize = 'chunkSize';
  static const chunks = 'chunks';
  static const chunkIndex = 'i';
  static const chunkLength = 'size';

  static String webChunk(String fileId, int chunkIndex) => '$fileId:c:$chunkIndex';
}
