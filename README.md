# 🎓 College Event Registration App

A Flutter-based college event management application designed to simplify event discovery, student registrations, event administration, and attendance tracking. The application uses Firebase Authentication and Cloud Firestore to support authentication and real-time event data management.

## 📌 About the Project

Managing college events manually can be time-consuming for students, faculty, and club coordinators. This application provides a centralized platform where students can explore college events, register for activities, track their registrations, and access event-related information.

Administrators can manage events and monitor registrations through dedicated management screens.

The project aims to make college event management more organized, accessible, and efficient.

## ✨ Features

### 👨‍🎓 Student Features
- **User Authentication:** Sign in and access the application.
- **Browse Events:** Explore available college events and view event details.
- **Event Registration:** Register for events through the application.
- **Seat Availability:** Track available seats and registration counts.
- **Registration Confirmation:** View registration status and confirmation details.
- **My Events:** Access registered events in one place.
- **Saved Events:** Save events for quick access later.
- **QR Tickets:** Access QR-based event tickets for registration and attendance workflows.
- **Gamification:** Earn badges and rewards through supported application activities.
- **Profile Management:** View and manage profile information.
- **Feedback:** Submit feedback about events and the application.

### 🛡️ Admin Features
- **Event Management:** Create, edit, and delete events.
- **Registration Management:** View event registrations and participant details.
- **Participant Tracking:** Monitor registrations and available seats.
- **Attendance Support:** Support QR-based ticket and attendance workflows.
- **Event Management Dashboard:** Access administrative event-management screens.
- **Poster-Free Event Creation:** Create and edit events without uploading posters. Events can use category-based visual placeholders instead.

### 🎨 User Interface
- Modern Flutter interface.
- Colourful, pastel-inspired design.
- Dedicated student and administrator screens.
- Responsive layouts for supported screen sizes.
- Event cards with visual placeholders when poster images are unavailable.

### 🔔 Communication
- WhatsApp-related functionality is included in the project. Actual message delivery depends on the configured integration, credentials, and backend services.

## 🧰 Technology Stack

| Technology | Purpose |
|---|---|
| Flutter | Cross-platform application development |
| Dart | Application programming language |
| Firebase Authentication | User authentication |
| Cloud Firestore | Event, registration, and application data |
| Firebase Storage | Previously used for event poster uploads; poster uploading is being removed |
| Git and GitHub | Version control and source-code hosting |

## 🏗️ Project Structure

```text
college_event_app/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   ├── event_model.dart
│   │   ├── registration_model.dart
│   │   ├── user_model.dart
│   │   └── whatsapp_notification_model.dart
│   ├── screens/
│   │   ├── admin/
│   │   └── student/
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── registration_service.dart
│   │   ├── gamification_service.dart
│   │   ├── storage_service.dart
│   │   └── whatsapp_service.dart
│   ├── utils/
│   └── widgets/
├── test/
├── functions/
├── pubspec.yaml
├── firebase.json
└── README.md
```

*Note: This is a representative structure. The exact files and responsibilities may vary as the project evolves.*

## ⚙️ Getting Started

### Prerequisites

Install the following tools before running the application:

- Flutter SDK
- Dart SDK (included with Flutter)
- Android Studio or Visual Studio Code
- Git
- A Firebase project

### 1. Clone the repository

```bash
git clone https://github.com/sruthi20-07/College_Event_Registrations_App.git
cd College_Event_Registrations_App
```

### 2. Switch to the development branch

The development work is maintained on the `irctc` branch.

```bash
git checkout irctc
```

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Configure Firebase

1. Open the Firebase Console and select your project.
2. Register or verify the Android application using its actual package name.
3. Configure Firebase Authentication and enable the sign-in methods required by the application.
4. Create or verify the Cloud Firestore database.
5. Configure the Firebase settings for your development environment.
6. Ensure the `firebase_options.dart` file is generated and correctly referenced by `main.dart`.

Do not commit private credentials, service-account keys, or API tokens to the repository.

**Important:** The application is being adapted to work without Firebase Storage poster uploads. Firebase Storage billing should not be required for event creation if no other feature depends on Storage.

### 5. Run the application

Check your connected devices:

```bash
flutter devices
```

Run on Chrome:

```bash
flutter run -d chrome
```

Run on a connected Android device:

```bash
flutter run
```

### 6. Build the Android APK

Generate a release APK:

```bash
flutter build apk --release
```

The generated APK is available at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## 🧪 Testing

Run the automated tests:

```bash
flutter test
```

Check for code issues:

```bash
flutter analyze
```

Test important workflows manually before deployment:

- Student sign-in and authentication.
- Event creation and editing without a poster.
- Event browsing and event-detail loading.
- Event registration and seat-count updates.
- Registration confirmation and QR-ticket access.
- Saved events and profile screens.
- Administrator registration and participant views.
- Feedback submission and WhatsApp integration, where configured.

## 🚀 Future Enhancements

The following features are **planned possibilities**, not claims about currently implemented functionality.

### 🔔 1. Smart Notifications
- Push notifications for upcoming events.
- Registration confirmation and cancellation notifications.
- Reminders before an event starts.
- Notifications when registration is nearly full.

### 💳 2. Secure Payment Integration
- Integration with a payment gateway such as Razorpay.
- Payment receipts and transaction history.
- Payment verification and refund handling.
- Automatic registration confirmation after verified payment.

### 🤖 3. AI-Powered Event Recommendations
- Recommend events based on student interests and previous registrations.
- Add intelligent event search.
- Provide a chatbot to answer questions about events, schedules, and registration rules.

### 📅 4. Calendar Integration
- Add events to Google Calendar.
- Display event schedules and reminders.
- Detect scheduling conflicts between events.

### 📲 5. QR-Based Attendance Improvements
- QR scanning through the administrator's device.
- One-time ticket validation.
- Duplicate check-in prevention.
- Live attendance dashboards and downloadable reports.

### 📊 6. Advanced Analytics Dashboard
- Registration and attendance statistics.
- Event popularity comparisons.
- Department-wise participation reports.
- Export reports to CSV, Excel, or PDF.

### 🏫 7. Multi-College Support
- Support multiple colleges and campuses.
- Add department and club-specific event management.
- Introduce institution-level administrator roles.

### 🔐 8. Role-Based Access Control
- Separate student, club coordinator, faculty, and super-admin permissions.
- Restrict event editing and participant data access.
- Add secure Firestore rules and server-side authorization.

### 🌐 9. Multilingual Support
- English and Telugu language options.
- Localized event descriptions and notifications.
- Accessible text sizes and screen-reader support.

### 🏆 10. Enhanced Gamification
- Leaderboards and participation points.
- Rewards for attending events.
- Digital participation certificates.
- Achievement badges and event streaks.

### 📄 11. Digital Certificates
- Automatically generate participation certificates.
- Provide downloadable PDF certificates.
- Add certificate verification using a unique ID or QR code.

### 🌱 12. Offline and Performance Improvements
- Cache event information for offline viewing.
- Improve loading speed and pagination.
- Optimize images and reduce unnecessary network requests.
- Improve accessibility and support additional screen sizes.

## 🔒 Security Considerations

- Use Firebase Authentication to identify users.
- Enforce role-based access through properly designed Firestore Security Rules.
- Validate registration limits and payment status on a trusted backend.
- Never store passwords or private API tokens in source code.
- Avoid publicly exposing participant information.
- Test security rules before deploying the application.

## 🤝 Contributing

Contributions and suggestions are welcome.

1. Fork the repository.
2. Create a feature branch.
3. Implement and test your changes.
4. Commit your changes with a descriptive message.
5. Submit a pull request.

## 👩‍💻 Project Maintainer

**Sruthi Vindula**

GitHub: [@sruthi20-07](https://github.com/sruthi20-07)

## 📜 License

No license has been specified yet. Add an appropriate open-source license if you intend to permit public reuse, modification, or distribution.

---

⭐ If you find this project useful, consider starring the repository and sharing suggestions for improvement.
