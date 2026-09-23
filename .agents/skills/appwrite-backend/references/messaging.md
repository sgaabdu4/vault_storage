# Messaging

## Overview

Send push, email, SMS to users.

---

## Push Notifications

### Create Topic

```dart
// Dart
final topic = await messaging.createTopic(
    topicId: ID.unique(),
    name: 'product-updates',
);
```

### Subscribe Users

```dart
// Dart - Subscribe user to topic
await messaging.createSubscriber(
    topicId: 'product-updates',
    subscriberId: ID.unique(),
    targetId: userId,
);
```

### Send Push to Topic

```dart
// Dart
await messaging.createPush(
    messageId: ID.unique(),
    title: 'New Feature!',
    body: 'Check out our latest update.',
    topics: ['product-updates'],
);
```

```python
# Python
messaging.create_push(
    message_id=ID.unique(),
    title='New Feature!',
    body='Check out our latest update.',
    topics=['product-updates'],
)
```

```typescript
// TypeScript
await messaging.createPush({
    messageId: ID.unique(),
    title: 'New Feature!',
    body: 'Check out our latest update.',
    topics: ['product-updates'],
});
```

### Rich Push (Image, Sound, Data)

```dart
// Dart — full parameter set
await messaging.createPush(
    messageId: ID.unique(),
    title: 'Order Shipped!',
    body: 'Your package is on its way.',
    topics: ['order-updates'],
    image: 'https://yourcdn.com/shipment-banner.webp', // rich notification image
    sound: 'notification_chime',                        // custom sound file name
    badge: 1,                                            // iOS badge count
    action: 'https://yourapp.com/orders/123',           // tap opens this URL
    data: {'orderId': '123', 'status': 'shipped'},      // custom payload for app logic
);
```

| Parameter | Effect |
|-----------|--------|
| `image` | Image in expanded notification (URL) |
| `sound` | Custom sound (file in app bundle) |
| `badge` | iOS badge count |
| `action` | URL/deep link on tap |
| `data` | Key-value payload for app logic (user-invisible) |

### Silent / Background Push

Data-only push, triggers background refresh:

```dart
// Dart — silent push (data only, omit title/body)
await messaging.createPush(
    messageId: ID.unique(),
    topics: ['sync'],
    data: {'action': 'refresh_cache', 'version': '42'},
);
```

---

## Email

### Configure SMTP Provider

Console → Messaging → Providers → Add SMTP.

### Send Email

```dart
// Dart
await messaging.createEmail(
    messageId: ID.unique(),
    subject: 'Welcome!',
    content: '<h1>Hello</h1><p>Welcome to our app.</p>',
    topics: ['onboarding'],
    html: true,
);
```

```python
# Python
messaging.create_email(
    message_id=ID.unique(),
    subject='Welcome!',
    content='<h1>Hello</h1><p>Welcome to our app.</p>',
    topics=['onboarding'],
    html=True,
)
```

```typescript
// TypeScript
await messaging.createEmail({
    messageId: ID.unique(),
    subject: 'Welcome!',
    content: '<h1>Hello</h1><p>Welcome to our app.</p>',
    topics: ['onboarding'],
    html: true,
});
```

---

## SMS

### Configure SMS Provider

Supported: Twilio, Vonage, MSG91, Telesign, Textmagic.

### Send SMS

```dart
// Dart
await messaging.createSms(
    messageId: ID.unique(),
    content: 'Your verification code is 123456',
    topics: ['verification'],
);
```

---

## Direct Targeting

Send to users, not topics.

```dart
// Dart - Send to specific users
await messaging.createPush(
    messageId: ID.unique(),
    title: 'Personal Alert',
    body: 'Your order shipped!',
    users: ['user_123', 'user_456'],
);
```

---

## Scheduled Messages

Send at time.

```dart
// Dart
await messaging.createPush(
    messageId: ID.unique(),
    title: 'Reminder',
    body: 'Your subscription expires tomorrow',
    topics: ['subscribers'],
    scheduledAt: DateTime.now().add(Duration(days: 1)).toIso8601String(),
);
```

---

## Message Status

Track delivery.

```dart
// Dart
final message = await messaging.getMessage(messageId: 'msg_123');

print(message.status); // draft, scheduled, processing, sent, failed
print(message.deliveredTotal);
```

---

## Targets

User devices for push.

```dart
// Dart - List user's targets
final targets = await users.listTargets(userId: 'user_123');

for (final target in targets.targets) {
    print('${target.providerType}: ${target.identifier}');
}
```

---

## Performance Tips

1. **Use topics** - Batch > individual
2. **Schedule off-peak** - Dodge rate limits
3. **Track opens** - Monitor engagement
4. **Segment users** - Targeted topics

---

## FCM Setup

1. Create Firebase project
2. Download service account JSON
3. Add to Console → Messaging → Providers → FCM

---

## APNS Setup (iOS)

1. Create APNs key in Apple Developer
2. Download .p8 file
3. Add to Console → Messaging → Providers → APNS

---

## Related

- Functions for triggered messages
- Realtime for instant updates
