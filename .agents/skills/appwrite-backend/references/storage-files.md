# Storage and Files

## File Tokens

File tokens provide temporary, shareable URLs without exposing API keys.

### Generate Token

```dart
final token = await storage.createFileToken(
    bucketId: 'uploads', fileId: 'file_123', expire: 3600);

final downloadUrl = '${client.endPoint}/storage/buckets/uploads/files/file_123/download?token=${token.token}';
```

Python and TypeScript follow the same pattern with `create_file_token()` / `createFileToken()`.

### Use Cases

- Public file sharing (open access)
- Expiring download links
- Email attachments
- Third-party integrations

---

## Chunked Uploads

Large files upload in chunks. SDKs handle this automatically.
Current SDKs can upload chunks in parallel when the runtime supports overlapping HTTP requests. Keep `createFile` calls unchanged; update the official SDK instead of writing custom chunk/upload HTTP.

### Limits

Max file size = bucket `maximumFileSize`, capped by the deployed plan/server
config. Bind the deployed value before sizing an upload path; never assume a
tier ceiling. See [limits.md](limits.md).

### Example

```dart
// Dart - Large file upload
import 'dart:io';

final file = await File('/path/to/large-file.zip').readAsBytes();

final result = await storage.createFile(
    bucketId: 'uploads',
    fileId: ID.unique(),
    file: InputFile.fromBytes(bytes: file, filename: 'large-file.zip'),
);
```

```python
# Python - Large file upload
from appwrite.input_file import InputFile

result = storage.create_file(
    bucket_id='uploads',
    file_id=ID.unique(),
    file=InputFile.from_path('/path/to/large-file.zip'),
)
```

```typescript
// TypeScript - Large file upload
import { InputFile } from 'node-appwrite';

const result = await storage.createFile({
    bucketId: 'uploads',
    fileId: ID.unique(),
    file: InputFile.fromPath('/path/to/large-file.zip', 'large-file.zip'),
});
```

---

## InputFile Factories

Use SDK factories. Do not custom-build multipart Appwrite requests.

```dart
InputFile.fromPath(path: '/path/to/file.png', filename: 'file.png')
InputFile.fromBytes(bytes: uint8List, filename: 'file.png')
```

```python
InputFile.from_path('/path/to/file.png')
InputFile.from_bytes(b'hello', filename='file.txt')
InputFile.from_string('hello', filename='file.txt')
```

```typescript
import { InputFile } from 'node-appwrite/file';

InputFile.fromPath('/path/to/file.png', 'file.png')
InputFile.fromBuffer(buffer, 'file.png')
InputFile.fromStream(readable, 'file.png', sizeInBytes)   // size required
InputFile.fromPlainText('hello', 'hello.txt')
```

`fromStream` avoids buffering the whole file in memory — use it for any upload
whose size approaches the process memory budget. It is the only factory that
requires an explicit byte size; a wrong size corrupts the upload.

For browser uploads, pass the selected `File` object from the client SDK rather
than a server `InputFile`.

---

## File Previews

Generate image transformations server-side.

```dart
// Dart - Thumbnail
final preview = storage.getFilePreview(
    bucketId: 'images',
    fileId: 'img_123',
    width: 200,
    height: 200,
    quality: 80,
    output: 'webp',
);
```

### Preview Parameters

| Parameter | Description |
|-----------|-------------|
| `width` | Output width (max 4000) |
| `height` | Output height (max 4000) |
| `gravity` | Crop focus (center, top-left, etc.) |
| `quality` | JPEG/WebP quality (0-100) |
| `borderWidth` | Border width in pixels |
| `borderColor` | Border color (hex) |
| `borderRadius` | Corner radius |
| `opacity` | Transparency (0-1) |
| `rotation` | Rotation degrees |
| `background` | Background color (hex) |
| `output` | Format (jpeg, png, webp, gif, avif, heic) |

### Image Format Support

Appwrite supports HEIC, AVIF, and modern formats.

#### Input Formats

- HEIC/HEIF (iPhone photos)
- AVIF (modern compression)
- WebP, PNG, JPEG, GIF, SVG, BMP, TIFF

#### Convert HEIC to WebP

```dart
final preview = storage.getFilePreview(
    bucketId: 'photos', fileId: 'heic_photo', output: 'webp', quality: 85);
```

#### AVIF (Best Compression)

AVIF produces 50% smaller files than JPEG at similar quality.

```dart
// Dart - Generate AVIF thumbnail
final avifThumb = storage.getFilePreview(
    bucketId: 'images',
    fileId: 'img_123',
    width: 400,
    output: 'avif',
    quality: 75,
);
```

---

## Bucket Configuration

### Create Bucket

```dart
final bucket = await storage.createBucket(
    bucketId: 'uploads',
    name: 'User Uploads',
    permissions: [
        Permission.read(Role.any()),
        Permission.create(Role.users()),
    ],
    fileSecurity: true,
    maximumFileSize: 10 * 1024 * 1024, // 10 MB
    allowedFileExtensions: ['jpg', 'png', 'pdf'],
    compression: 'gzip',
    encryption: true,
    antivirus: true,
);
```

### Bucket Settings

| Setting | Description |
|---------|-------------|
| `fileSecurity` | Individual file permissions |
| `maximumFileSize` | Max bytes per file |
| `allowedFileExtensions` | Whitelist extensions |
| `compression` | gzip, zstd, or none. Files >20 MB skip compression automatically. |
| `encryption` | AES-256 at rest |
| `antivirus` | Scan uploads |

---

## Permissions

### Bucket-Level

```dart
// Anyone can read, authenticated users can upload
final bucket = await storage.createBucket(
    bucketId: 'public',
    name: 'Public Files',
    permissions: [
        Permission.read(Role.any()),
        Permission.create(Role.users()),
    ],
);
```

### File-Level

Requires `fileSecurity: true` on bucket.

```dart
// Upload with specific permissions
final file = await storage.createFile(
    bucketId: 'documents',
    fileId: ID.unique(),
    file: uploadFile,
    permissions: [
        Permission.read(Role.user(userId)),
        Permission.update(Role.user(userId)),
        Permission.delete(Role.user(userId)),
    ],
);
```

---

## Download Patterns

### Direct Download

```dart
final bytes = await storage.getFileDownload(
    bucketId: 'uploads',
    fileId: 'file_123',
);
```

### View in Browser

```dart
final viewUrl = storage.getFileView(
    bucketId: 'uploads',
    fileId: 'file_123',
);
```

### With Token (Public)

```dart
final token = await storage.createFileToken(
    bucketId: 'uploads',
    fileId: 'file_123',
    expire: 86400, // 24 hours
);
// Share token URL without auth
```

---

## Performance Tips

1. **Use WebP** — Smaller than JPEG with better quality
2. **Generate thumbnails** — Use previews, not full images
3. **Enable compression** — gzip for text, zstd for binaries (Appwrite skips files >20 MB)
4. **Batch uploads** — Upload multiple files per request
5. **Put a CDN in front** — Cloudflare, Bunny, or CloudFront cache files at the edge and cut origin load

### CDN Setup (Self-Hosted)

Point CDN at Appwrite storage endpoint. Repeat requests resolve at the edge.

```
User → CDN (edge cache) → Appwrite Storage (origin)
```

**Cloudflare:** Add domain, point DNS to Appwrite, cache `/v1/storage/` paths, set TTL to ~1 hour.

---

## Related

- Permissions for access control
- Functions for processing uploads
- [performance.md](performance.md) — Optimization checklist
