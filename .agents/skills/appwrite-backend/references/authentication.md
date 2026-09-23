# Authentication Patterns

## MFA/2FA

### List Available Factors

```dart
final factors = await account.listMfaFactors();
// Returns: totp, email, phone, recoveryCode
```

### TOTP Setup

```dart
// Create TOTP authenticator
final totp = await account.createMfaAuthenticator(type: 'totp');
// totp.secret - Base32 secret for authenticator app
// totp.uri - OTP auth URI for QR code

// Verify TOTP to activate
await account.updateMfaAuthenticator(type: 'totp', otp: '123456');
```

### MFA Challenge Flow

```dart
try {
    await account.createEmailPasswordSession(email: email, password: password);
} on AppwriteException catch (e) {
    if (e.type == 'user_more_factors_required') {
        final challenge = await account.createMfaChallenge(factor: 'totp');
        await account.updateMfaChallenge(
            challengeId: challenge.$id, otp: userEnteredCode);
    }
}
```

### Recovery Codes

```dart
final codes = await account.createMfaRecoveryCodes();
// Store securely — one-time use

// Regenerate (invalidates previous)
final newCodes = await account.updateMfaRecoveryCodes();
```

---

## Client Account Basics

Use client SDKs for user-owned account flows.

```dart
final account = Account(client);

await account.create(
    userId: ID.unique(),
    email: 'user@example.com',
    password: 'password',
    name: 'User',
);

await account.createEmailPasswordSession(
    email: 'user@example.com',
    password: 'password',
);

final user = await account.get();
await account.deleteSession(sessionId: 'current');
```

```typescript
await account.create({
    userId: ID.unique(),
    email: 'user@example.com',
    password: 'password',
});

await account.createEmailPasswordSession({ email, password });
const user = await account.get();
await account.deleteSession({ sessionId: 'current' });
```

---

## SSR Authentication

Server-side session for Next.js, SvelteKit, Nuxt, etc.

### Create Session Server-Side

```typescript
export async function POST({ request }) {
    const { email, password } = await request.json();

    const client = new Client()
        .setEndpoint('https://cloud.appwrite.io/v1')
        .setProject('PROJECT_ID');

    const account = new Account(client);
    const session = await account.createEmailPasswordSession({ email, password });

    return new Response(JSON.stringify({ success: true }), {
        headers: {
            'Set-Cookie': `a_session_[PROJECT_ID]=${session.secret}; Path=/; HttpOnly; Secure; SameSite=Strict`,
        },
    });
}
```

### Verify Session Server-Side

```typescript
export async function GET({ cookies }) {
    const session = cookies.get('a_session_[PROJECT_ID]');
    const client = new Client()
        .setEndpoint('https://cloud.appwrite.io/v1')
        .setProject('PROJECT_ID')
        .setSession(session);

    const account = new Account(client);

    try {
        const user = await account.get();
        return { user };
    } catch {
        return { user: null };
    }
}
```

---

### Python SSR Flow

```python
admin_client = (
    Client()
    .set_endpoint('https://cloud.appwrite.io/v1')
    .set_project('PROJECT_ID')
    .set_key('API_KEY')
)

@app.post('/login')
def login():
    account = Account(admin_client)
    session = account.create_email_password_session(
        email=request.json['email'],
        password=request.json['password'],
    )

    resp = make_response({'success': True})
    resp.set_cookie(
        'a_session_[PROJECT_ID]',
        session['secret'],
        httponly=True,
        secure=True,
        samesite='Strict',
        expires=session['expire'],
        path='/',
    )
    return resp

@app.get('/user')
def get_user():
    session = request.cookies.get('a_session_[PROJECT_ID]')
    if not session:
        return {'error': 'Unauthorized'}, 401

    session_client = (
        Client()
        .set_endpoint('https://cloud.appwrite.io/v1')
        .set_project('PROJECT_ID')
        .set_session(session)
        .set_forwarded_user_agent(request.headers.get('user-agent'))
    )

    return Account(session_client).get()
```

For Python OAuth SSR, redirect with `create_o_auth2_token(...)`, then exchange
callback `userId` + `secret` with `create_session(...)` and set the same
`a_session_<PROJECT_ID>` cookie.

---

## SSR Hardening

Use exact cookie name: `a_session_<PROJECT_ID>`. Generic `session` cookie breaks Appwrite SSR patterns.

Use admin client to create session or call privileged APIs. Use per-request session client to read user-scoped data.

Forward browser user agent on session client for debug + security context.

```dart
final adminClient = Client()
    .setEndpoint('https://cloud.appwrite.io/v1')
    .setProject('PROJECT_ID')
    .setKey('API_KEY');

final session = request.cookies['a_session_[PROJECT_ID]'];
final sessionClient = Client()
    .setEndpoint('https://cloud.appwrite.io/v1')
    .setProject('PROJECT_ID');

if (session != null) {
    sessionClient.setSession(session);
    sessionClient.setForwardedUserAgent(request.headers['user-agent']);
}
```

```python
admin_client = Client().set_endpoint('https://cloud.appwrite.io/v1').set_project('PROJECT_ID').set_key('API_KEY')

session = request.cookies.get('a_session_[PROJECT_ID]')
session_client = Client().set_endpoint('https://cloud.appwrite.io/v1').set_project('PROJECT_ID')

if session:
    session_client.set_session(session)
    session_client.set_forwarded_user_agent(request.headers.get('user-agent'))
```

```typescript
const adminClient = new Client()
    .setEndpoint('https://cloud.appwrite.io/v1')
    .setProject('PROJECT_ID')
    .setKey('API_KEY');

const session = req.cookies['a_session_[PROJECT_ID]'];
const sessionClient = new Client()
    .setEndpoint('https://cloud.appwrite.io/v1')
    .setProject('PROJECT_ID');

if (session) {
    sessionClient.setSession(session);
    sessionClient.setForwardedUserAgent(req.headers['user-agent']);
}
```

---

## Server Users Service

Use server SDK `Users` for admin user management only.

```dart
final users = Users(client);
await users.create(userId: ID.unique(), email: 'user@example.com', password: 'password');
final list = await users.list(queries: [Query.limit(25)]);
final user = await users.get(userId: 'user_123');
await users.delete(userId: 'user_123');
```

```python
users = Users(client)
users.create(user_id=ID.unique(), email='user@example.com', password='password')
users.list(queries=[Query.limit(25)])
users.get(user_id='user_123')
users.delete(user_id='user_123')
```

---

## User Labels

Role-based permissions. Server SDK only.

```dart
await users.updateLabels(userId: 'user_123', labels: ['premium', 'beta-tester']);

// Use in permissions
Permission.read(Role.label('premium'))
Permission.update(Role.label('admin'))
```

---

## JWT for Functions

JWT for server-side user context.

```dart
final jwt = await users.createJWT(userId: 'user_123');

final client = Client()
    .setEndpoint('https://cloud.appwrite.io/v1')
    .setProject('PROJECT_ID')
    .setJWT(jwt.jwt);
```

### Function-Injected User JWT

`x-appwrite-user-jwt` = the caller's JWT injected into the function runtime on
client-SDK executions. Its payload carries exactly `userId` + `sessionId` +
`exp`.

- `Account(client).getSession(sessionId: 'current')` under that JWT fails → never resolve the session through it
- decode the payload segment yourself for `userId`/`sessionId`
- payload claims alone = untrusted identity → validate the token with `Account(client).get()` and assert `user.$id == claims.userId` before authorizing anything
- project with the JWT auth method disabled → `account.createJWT()` / `/account/jwts` returns `501`; the injected function JWT is unaffected

```dart
import 'dart:convert';
import 'dart:io';

import 'package:dart_appwrite/dart_appwrite.dart';

// `FunctionContext` and `adaptFunctionContext` are the verified project
// boundary described in functions.md.
final class UserJwtClaims {
  const UserJwtClaims({required this.userId, required this.sessionId});

  final String userId;
  final String sessionId;
}

UserJwtClaims? readUserJwtClaims(String jwt) {
  final parts = jwt.split('.');
  if (parts.length != 3) return null;
  final segment = parts[1];
  final padded =
      segment.padRight(segment.length + (4 - segment.length % 4) % 4, '=');
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(base64Url.decode(padded)));
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, Object?>) return null;
  final userId = decoded['userId'];
  final sessionId = decoded['sessionId'];
  if (userId is! String || sessionId is! String) return null;
  if (userId.isEmpty || sessionId.isEmpty) return null;
  return UserJwtClaims(userId: userId, sessionId: sessionId);
}

Future<Object?> main(Object rawContext) async {
  final FunctionContext context = adaptFunctionContext(rawContext);
  final String? jwt = context.req.headers['x-appwrite-user-jwt'];
  if (jwt == null || jwt.isEmpty) {
    return context.res.json({'error': 'Unauthorized'}, status: 401);
  }

  final claims = readUserJwtClaims(jwt);
  if (claims == null) {
    return context.res.json({'error': 'Unauthorized'}, status: 401);
  }

  final endpoint = Platform.environment['APPWRITE_FUNCTION_API_ENDPOINT'];
  final projectId = Platform.environment['APPWRITE_FUNCTION_PROJECT_ID'];
  if (endpoint == null || projectId == null) {
    throw StateError('Missing Appwrite Function configuration');
  }

  final user = await Account(
    Client().setEndpoint(endpoint).setProject(projectId).setJWT(jwt),
  ).get();
  if (user.$id != claims.userId) {
    return context.res.json({'error': 'Unauthorized'}, status: 401);
  }

  return context.res.json({'ok': true});
}
```

---

## Security Settings

Console → Auth → Security:

| Setting | Description |
|---------|-------------|
| Password dictionary | Block common passwords |
| Password history | Prevent password reuse |
| Personal data | Block name/email in password |
| Session limits | Max sessions per user |
| Session length | Default session duration |

---

## Email Policies

Use Auth email policies to block signup/update emails by category:

| Policy | Blocks |
|--------|--------|
| Free providers | Gmail, Yahoo, Outlook, similar consumer inboxes |
| Aliased addresses | Plus-tags/subaddresses/provider aliases |
| Disposable providers | Temporary/throwaway inboxes |

Configure in Console → Auth → Security or via server SDK Project service. Policies apply to user creation and email updates; existing users keep sessions and can still log in.

---

## Email/Password Auth

```dart
// Create account
await account.create(userId: ID.unique(), email: 'user@example.com', password: 'password');

// Create session
await account.createEmailPasswordSession(email: 'user@example.com', password: 'password');
```

---

## Related

- [auth-methods.md](auth-methods.md) — OAuth, magic link, OTP, anonymous, phone, custom token, session mgmt
- Teams for group permissions
- Permissions for access control
