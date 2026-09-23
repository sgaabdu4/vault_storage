# Avatars

## Website Screenshots

Capture screenshot of any URL.

```dart
// Dart
final screenshot = avatars.getScreenshot(
    url: 'https://example.com',
    width: 1280,
    height: 720,
);
```

```python
# Python
screenshot = avatars.get_screenshot(
    url='https://example.com',
    width=1280,
    height=720,
)
```

```typescript
// TypeScript
const screenshot = await avatars.getScreenshot({
    url: 'https://example.com',
    width: 1280,
    height: 720,
});
```

### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `url` | Target URL (required) | - |
| `width` | Screenshot width | 1920 |
| `height` | Screenshot height | 1080 |

### Use Cases

- Link previews
- OG image gen
- Competitor monitor
- Docs

---

## Initials Avatars

Gen avatars from user names.

```dart
// Dart
final avatar = avatars.getInitials(
    name: 'John Doe',
    width: 100,
    height: 100,
    background: 'ff5733',
);
```

```python
# Python
avatar = avatars.get_initials(
    name='John Doe',
    width=100,
    height=100,
    background='ff5733',
)
```

```typescript
// TypeScript
const avatar = await avatars.getInitials({
    name: 'John Doe',
    width: 100,
    height: 100,
    background: 'ff5733',
});
```

---

## Flags

Country flag images by ISO code.

```dart
// Dart - US flag
final flag = avatars.getFlag(code: 'us', width: 100);
```

---

## Credit Card Icons

```dart
// Dart - Visa icon
final icon = avatars.getCreditCard(code: 'visa', width: 100);
```

Codes: `visa`, `mastercard`, `amex`, `discover`, `jcb`, `unionpay`, `diners`

---

## Browser Icons

```dart
// Dart
final icon = avatars.getBrowser(code: 'chrome', width: 50);
```

Supported: `chrome`, `firefox`, `safari`, `edge`, `opera`, `brave`

---

## Favicon Fetch

Get favicon from any domain.

```dart
// Dart
final favicon = avatars.getFavicon(url: 'https://github.com');
```

---

## QR Codes

Gen QR from text/URL.

```dart
// Dart
final qr = avatars.getQR(
    text: 'https://example.com/link',
    size: 300,
    margin: 2,
);
```

```python
# Python
qr = avatars.get_qr(
    text='https://example.com/link',
    size=300,
    margin=2,
)
```

```typescript
// TypeScript
const qr = await avatars.getQR({
    text: 'https://example.com/link',
    size: 300,
    margin: 2,
});
```

---

## Image Avatars

Gen placeholder images.

```dart
// Dart - Placeholder
final image = avatars.getImage(
    url: 'https://picsum.photos/200',
    width: 200,
    height: 200,
);
```

---

## Performance Tips

1. **Cache avatars** - URLs deterministic
2. **Use CDN** - serve from edge
3. **Size right** - match output dim to display size
4. **Batch w/ SSR** - pre-gen for SSR pages

---

## Related

- Storage for custom avatars
- Functions for custom gen
