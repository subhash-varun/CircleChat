Here is a **complete, clean GitHub `README.md`** for your **Circle Chat** project with your **actual Firestore schema included** and **Subhash Varun as the author**.

You can **copy-paste this directly into `README.md`**.

---

```markdown
# Circle Chat 💬

Circle Chat is a **moderated real-time chat application** where users communicate inside controlled communities called **Bubbles**.

Every user must first **request access**, which triggers a **push notification to the admin**. Once approved, the admin assigns the user to a **Bubble**, allowing them to communicate with members of that Bubble.

The system combines **Flutter for the client**, **Firebase Firestore for real-time messaging**, and **Spring Boot for push notification services using Firebase Cloud Messaging (FCM)**.

---

# 🚀 Features

### 🔐 User Authentication
- Users sign up and log in using **Firebase Authentication**
- Secure identity management

### 🛂 Admin Approval System
- New user signup triggers **push notification to admin**
- Admin manually approves users
- Approved users are assigned to a **Bubble (group)**

### 💬 Bubble-Based Chat
- Users communicate **only within their assigned Bubble**
- Ensures organized and moderated conversations

### ⚡ Real-Time Messaging
- Messages stored in **Firebase Firestore**
- Real-time updates using Firestore listeners

### 🔔 Push Notifications
- Notifications sent for:
  - New user signup requests
  - New chat messages
- Implemented using **Firebase Cloud Messaging**
- Triggered through **Spring Boot backend**

---

# 🏗 System Architecture

```

Flutter App
|
| Firebase Authentication
|
Firebase Firestore (Real-time Database)
|
| FCM Token
|
Spring Boot Backend
|
| Firebase Cloud Messaging
|
Push Notifications → Admin / Users

```

---

# 🛠 Tech Stack

## Frontend
- Flutter
- Dart

## Backend
- Spring Boot
- Java
- REST APIs

## Cloud Services
- Firebase Firestore
- Firebase Authentication
- Firebase Cloud Messaging (FCM)
- Firebase Storage

## Tools
- Git
- Postman
- Maven

---

# 📂 Project Structure

## Flutter Client

```

lib/
│
├── models/
│ ├── conversation.dart
│ └── message.dart
│
├── services/
│ ├── firebase_service.dart
│ └── notification_service.dart
│
├── screens/
│ ├── login_screen.dart
│ ├── signup_screen.dart
│ └── chat_screen.dart
│
└── main.dart

```

---

## Spring Boot Notification Service

```

src/main/java/com/circlechat

├── controller
│ └── NotificationController.java
│
├── service
│ └── FCMService.java
│
├── config
│ └── FirebaseConfig.java
│
└── CircleChatApplication.java

```

---

# 📊 Firestore Database Structure

The chat system uses **Firestore collections for conversations and messages**.

---

# Conversations Collection

Each document represents a **chat session**.

```

conversations
│
└── {conversationId}
├── customer_id: string
├── assigned_to: string
├── status: "open"
├── last_message: string
├── last_message_at: timestamp
├── type: "general" | "order" | "delivery"
├── created_at: timestamp
└── updated_at: timestamp

````

### Conversation Model (Flutter)

```dart
class Conversation {
  final String id;
  final String customerId;
  final String? assignedTo;
  final String status;
  final String lastMessage;
  final DateTime lastMessageAt;
  final String type;
  final DateTime createdAt;
  final DateTime updatedAt;
}
````

---

# Messages Collection

Each message belongs to a **conversation thread**.

```

messages
│
└── {messageId}
├── sender_type: "customer" | "agent" | "system"
├── sender_ref: string
├── client_message_id: string
├── text: string
├── attachments: [url]
├── created_at: timestamp
└── customer_ref: string

```

### Message Model (Flutter)

```dart
class Message {
  final String id;
  final String senderType;
  final String senderRef;
  final String clientMessageId;
  final String text;
  final List<String> attachments;
  final DateTime createdAt;
  final String customerRef;
}
```

---

# 🔔 Push Notification Flow

1️⃣ User signs up in the Flutter app

2️⃣ User's **FCM token is saved in Firestore**

3️⃣ Backend detects signup request

4️⃣ **Spring Boot sends notification to admin**

5️⃣ Admin approves the user

6️⃣ User is assigned to a **Bubble**

7️⃣ User can now chat with Bubble members

---

# ⚙️ Setup Instructions

## 1️⃣ Clone the Repository

```

git clone https://github.com/yourusername/circle-chat.git
cd circle-chat

```

---

## 2️⃣ Setup Flutter Client

Install dependencies

```

flutter pub get

```

Add Firebase configuration files

```

android/app/google-services.json
ios/Runner/GoogleService-Info.plist

```

Run the app

```

flutter run

```

---

## 3️⃣ Setup Spring Boot Backend

Add Firebase Admin SDK credentials

```

src/main/resources/firebase-service-account.json

```

Run the backend

```

mvn spring-boot:run

```

or

```

./mvnw spring-boot:run

```

---

# 🔐 Security

* Firebase Authentication protects user identity
* Firestore security rules control message access
* Only approved users can access chat
* Conversations are restricted to assigned participants

---

# 🧠 Future Improvements

* Message read receipts
* Typing indicators
* Media sharing
* Group admin controls
* Chat search
* End-to-end encryption
* Web admin dashboard

---

# 👨‍💻 Author

**Subhash Varun**

Software Engineer
Java • Spring Boot • Flutter • Firebase

---

```

---

✅ This README is **clean enough for GitHub recruiters**.

If you want, I can also help you add **3 things that make a project look 10x more professional**:

- 🔥 **GitHub badges (Flutter, Firebase, Java, etc.)**
- 📱 **App screenshots section**
- 🧩 **Architecture diagram (looks very impressive in portfolios)**
```
