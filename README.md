# Multi Counter ⚡

A modern, offline-first, ergonomic Multi-Counter and tally tracker built with Flutter and Material 3. Designed for fast one-handed thumb interaction (Fitts's Law), zero-config persistence, goal tracking, and multi-criteria organization.

---

## ✨ Features

- **Thumb-Friendly Ergonomics (Fitts's Law):**
  - Oversized primary `+` touch target (72×60dp) with elevated tactile feedback for rapid tapping.
  - Subtle secondary `-` decrement button bounded at zero by default (optional negative bounds supported).
  - Native haptic feedback on every increment (`lightImpact`), decrement (`selectionClick`), and reset (`mediumImpact`).
- **Goal & Target Tracking:**
  - Optional goal targets with real-time linear progress bars, live percentage indicators, and goal achievement badges.
- **Offline-First Persistence:**
  - Zero-configuration local storage using `shared_preferences` with JSON serialization.
  - Optimistic UI updates with silent background writes.
  - Cross-platform support: iOS, Android, macOS, Windows, Linux, and Web (backed by `window.localStorage`).
- **Dynamic Organization:**
  - Real-time search by title with quick-clear button.
  - Multi-criteria sorting: *Alphabetical* (default), *Recently Updated*, and *Highest Count*.
  - 10 curated color themes (Sapphire, Emerald, Sunset, Crimson, Violet, Teal, Amber, Rose, Indigo, Slate).
- **Safety & Recovery:**
  - Swipe-to-delete cards (`Dismissible`) with instant floating `UNDO` SnackBar.
  - Accidental reset prevention via confirmation dialog.
- **Material 3 Design:**
  - Seamless Dark and Light theme support matching system settings.
  - High-contrast typography with animated count transitions (>= 38sp bold).

---

## 🏛️ Architecture & Project Structure

The project follows clean Separation of Concerns using native Flutter `ChangeNotifier` and `ListenableBuilder`:

```text
lib/
├── controllers/
│   └── counter_controller.dart          # State management, search, sort, and background persistence
├── data/
│   ├── models/
│   │   └── counter_model.dart           # Immutable domain model with JSON serialization & goal helpers
│   └── services/
│       └── counter_storage_service.dart # SharedPreferences wrapper for robust offline JSON storage
├── screens/
│   └── home_screen.dart                 # Material 3 scaffold with animated list, dismissibles, and FAB
├── theme/
│   └── app_theme.dart                   # Light & Dark M3 themes + curated 10-color categorization palette
├── widgets/
│   ├── add_edit_counter_sheet.dart      # Bottom sheet modal for creating and editing counters
│   ├── counter_card.dart                # Fitts's Law ergonomic card with tactile tap targets & haptics
│   ├── empty_state.dart                 # Illustrated empty & no-search-results states
│   └── search_sort_bar.dart             # Real-time search bar and sort filter selector
└── main.dart                            # Application entry point with async storage initialization
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.10.8` / `Flutter 3.38+`)
- Android Studio / Xcode / Chrome (depending on your target platform)

### Installation & Running

1. **Clone or navigate to the repository:**
   ```bash
   cd counter-app
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run on your connected device or emulator:**
   ```bash
   # Run on default connected device
   flutter run

   # Run on Web (Chrome)
   flutter run -d chrome

   # Run on macOS desktop
   flutter run -d macos
   ```

---

## 🧪 Testing & Verification

Run static analysis to verify code quality:
```bash
dart analyze
```

Run the complete unit and widget test suite:
```bash
flutter test
```

### Test Coverage Highlights:
- `test/counter_model_test.dart`: Serialization/deserialization, default attributes, goal progress calculations.
- `test/counter_controller_test.dart`: Controller state mutations, increment/decrement bounds, reset, edit, search query filtering, sorting, and undo restoration.
- `test/widget_test.dart`: End-to-end user interaction flow from empty state to counter creation and tapping.

---

## 📦 Tech Stack

| Dependency | Purpose |
| :--- | :--- |
| **Flutter (Dart 3)** | Core framework & sound null safety |
| **`shared_preferences`** | Offline persistence across all platforms (Mobile, Desktop, Web) |
| **`uuid`** | Collision-resistant unique IDs for counters |
| **`intl`** | Timestamp formatting |
| **`flutter_launcher_icons`** | Automated multi-platform app icon generation |

---

## 📄 License
This project is open-source and available under the [MIT License](LICENSE).
