# Push Backend (Spring Boot)

Spring Boot service for FCM push notifications in Jhol Jhal chat.

## Prerequisites

- Java 21
- Maven 3.9+
- Firebase service account JSON (Admin SDK)

## Configure

Set environment variable:

```bash
FIREBASE_SERVICE_ACCOUNT_PATH=/absolute/path/to/serviceAccountKey.json
```

## Run

```bash
mvn spring-boot:run
```

Service starts on `http://localhost:8080`.

## Docker

Build image:

```bash
docker build -t <dockerhub-username>/jholjhal-push-backend:latest .
```

Run container:

```bash
docker run --rm -p 8080:8080 \
  -e FIREBASE_SERVICE_ACCOUNT_PATH=/app/config/serviceAccountKey.json \
  -v /absolute/path/to/serviceAccountKey.json:/app/config/serviceAccountKey.json:ro \
  <dockerhub-username>/jholjhal-push-backend:latest
```

## API

### Register device token

`POST /api/push/tokens/register`

```json
{
  "userRef": "user_uid_123",
  "token": "fcm_token_here",
  "platform": "android"
}
```

### Unregister device token

`POST /api/push/tokens/unregister`

```json
{
  "userRef": "user_uid_123",
  "token": "fcm_token_here"
}
```

### Send chat message push

`POST /api/push/messages/send`

```json
{
  "recipientRef": "recipient_uid_456",
  "senderRef": "sender_uid_123",
  "conversationId": "conversation_abc",
  "messageId": "message_xyz",
  "title": "New message",
  "body": "Hello from chat!",
  "data": {
    "type": "chat_message"
  }
}
```

### Send test to one token

`POST /api/push/test/send-to-token?token=...&title=Test&body=Hello`

## Notes

- Current token storage is in-memory (`TokenRegistryService`) for fast local development.
- For production, replace it with persistent storage (e.g., PostgreSQL/Redis/Firestore table).
