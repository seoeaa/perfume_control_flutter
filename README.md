# Perfume Control Flutter

[![Build Status](https://github.com/USER_NAME/perfume_control_flutter/actions/workflows/build.yml/badge.svg)](https://github.com/USER_NAME/perfume_control_flutter/actions)

Приложение для управления парфюмерной системой через Bluetooth. Позволяет настраивать интенсивность, расписание и отслеживать статус устройства.

## Особенности
- **Bluetooth Low Energy (BLE)**: Быстрое и надежное подключение к устройству.
- **Интуитивный интерфейс**: Современный дизайн с использованием Google Fonts (Outfit).
- **Управление расписанием**: Настройка рабочих циклов и пауз.
- **Кроссплатформенность**: Поддержка Android и iOS.

## Стек технологий
- **Framework**: [Flutter](https://flutter.dev)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Bluetooth**: [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus)
- **Dependency Injection**: [get_it](https://pub.dev/packages/get_it)

## Установка и запуск

### Требования
- Flutter SDK (см. `pubspec.yaml` для версии SDK)
- Android Studio / VS Code с плагинами Dart и Flutter

### Шаги
1. Склонируйте репозиторий:
   ```bash
   git clone https://github.com/USER_NAME/perfume_control_flutter.git
   ```
2. Установите зависимости:
   ```bash
   flutter pub get
   ```
3. Запустите приложение:
   ```bash
   flutter run
   ```

## Сборка

### Android
Сборка APK:
```bash
flutter build apk --release
```

### iOS
Сборка iOS (требуется macOS и Xcode):
```bash
flutter build ios --release
```

## Автоматизация
Проект настроен с использованием **GitHub Actions** для автоматической сборки Android APK и iOS runner при каждом пуше в ветку `main`.

---
*Разработано с помощью Antigravity.*
