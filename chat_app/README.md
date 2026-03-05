# Circle Chat 💬

Circle Chat is a **moderated real-time chat application** where users communicate inside controlled groups called **Bubbles**.

Users must first **request access**, which triggers a **push notification to the admin**. After approval, the admin assigns the user to a Bubble where they can chat with other members.

The system uses **Flutter for the client**, **Firebase Firestore for real-time messaging**, and **Spring Boot for push notifications using Firebase Cloud Messaging (FCM)**.

---

## 🚀 Features

- User signup/login using **Firebase Authentication**
- **Admin approval system** for new users
- **Bubble-based group chat**
- **Real-time messaging** using Firestore
- **Push notifications** using FCM
- Media attachments support via **Firebase Storage**

---

## 🛠 Tech Stack

**Frontend**
- Flutter
- Dart

**Backend**
- Spring Boot
- Java

**Cloud**
- Firebase Firestore
- Firebase Authentication
- Firebase Cloud Messaging (FCM)
- Firebase Storage

---

## 🏗 Architecture

Flutter App
│
Firebase Authentication
│
Firestore (Messages & Conversations)
│
Spring Boot Backend
│
Firebase Cloud Messaging
│
Push Notifications


---

## 📊 Firestore Structure

### Conversations

conversations/{conversationId}
├─ customer_id
├─ assigned_to
├─ status
├─ last_message
├─ last_message_at
├─ type
├─ created_at
└─ updated_at

### Messages

messages/{messageId}
├─ sender_type
├─ sender_ref
├─ client_message_id
├─ text
├─ attachments
├─ created_at
└─ customer_ref

---

## ⚙️ Setup

### Clone repository

```bash
git clone https://github.com/yourusername/circle-chat.git
cd circle-chat
Run Flutter app
flutter pub get
flutter run
Run Spring Boot backend
mvn spring-boot:run
👨‍💻 Author

Subhash Varun

Java • Spring Boot • Flutter • Firebase
---
