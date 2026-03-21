# CalendarApp 📅

A cross-platform calendar app built with Flutter, available on Android and Windows.
Create events, set reminders, and manage your schedule with a minimal dark aesthetic.

![Flutter](https://img.shields.io/badge/Flutter-3.41.5-blue)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows-green)

<img width="1254" height="700" alt="image" src="https://github.com/user-attachments/assets/acf39c21-db48-4ca7-9326-72c439d81543" />

<img width="1258" height="704" alt="image" src="https://github.com/user-attachments/assets/45ad52bb-d8ee-45e0-9577-7b6de88395f7" />

## Features

- 📅 Monthly, 2-week and weekly calendar views
- ➕ Create and edit events
- 🎨 Color coded events
- ⏰ Reminder notifications (Android)
- 💾 Fully local storage
- 🗓️ Date and time picker

## Setup

1. Clone the repo
2. Install dependencies:
```bash
flutter pub get
```
3. Run:
```bash
flutter run
```

## Build

**Android APK:**
```bash
flutter build apk --release
```

**Windows EXE:**
```bash
flutter build windows
```

## Tech Stack

- Flutter / Dart
- table_calendar
- shared_preferences
- intl
- flutter_local_notifications (Android)

## Version

Current: 1.0.0
