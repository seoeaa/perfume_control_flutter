# LI Perfume

<p align="center">
  <img src="assets/logo.jpg" width="128" alt="Logo">
</p>

Приложение для управления парфюмерными системами автомобилей **Li Auto (Lixiang)** через Bluetooth.

## Основные возможности
- **Управление тремя ароматами**: Независимая настройка каналов (Аромат A, B, C).
- **Регулировка интенсивности**: Выбор одного из трех уровней (Легкий, Средний, Насыщенный) для каждого канала.
- **Мониторинг уровня состава**: Отображение остатка парфюма в процентах для своевременной замены.
- **Ионизация воздуха**: Отдельное управление функцией ионизации для улучшения качества воздуха.
- **Управление питанием**: Дистанционное включение и выключение устройства.
- **Диагностика и логи**: Встроенная консоль логов для отладки подключения.
- **Быстрая поддержка**: Прямая связь с разработчиками через Telegram.

## Технологический стек
- **Framework**: Flutter (Dart)
- **Bluetooth**: Flutter Blue Plus
- **UI**: Google Fonts (Outfit), Custom Glassmorphism Design
- **CI/CD**: GitHub Actions (Android & iOS)

> [!NOTE]
> Последняя версия приложения всегда доступна в разделе **Releases**.

## Запуск
```bash
flutter pub get
flutter run
```

## Сборка
```bash
flutter build apk --release
```

[![Build Status](https://github.com/seoeaa/perfume_control_flutter/actions/workflows/build.yml/badge.svg)](https://github.com/seoeaa/perfume_control_flutter/actions)
Проект настроен для автоматической сборки APK и iOS Runner при каждом пуше.

---
*Created with Antigravity*
