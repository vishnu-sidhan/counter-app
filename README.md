# StallPOS ⚡

A modern, ergonomic, offline-first Stall Point-of-Sale (POS) and Multi-Counter system built with Flutter and Material 3. Designed for fast one-handed thumb interaction (Fitts's Law), zero-config persistence, goal tracking, bulk CSV imports, event/food counter ticketing, and centralized storage adaptability.

StallPOS is built as both a **standalone web application** (optimized for tablets, POS terminals, and mobile browsers) and a **reusable modular Flutter package** that can be embedded directly into other host applications.

---

## ✨ Features

- **⚡ Fast Stall POS & Kitchen Ticket Queue:**
  - Counter POS tailored for food stalls, pop-ups, events, and festival booths.
  - One-tap cart additions, category-filtered views, variant selection sheets, and real-time total revenue tally.
  - Flexible payment handling: Pay Now / Pay Later workflows, linked add-ons, and payment confirmation dialogs.
  - FIFO kitchen queue with automated order numbers (#1, #2...) and elapsed time tracking.
  - Item Summary view consolidating preparation queues across all active tickets with single-tap completion chips.
  - Comprehensive order history with filters, metrics, and CSV export.
- **🔌 Reusable Flutter Module & Package:**
  - Can be consumed as an embedded module in external Flutter applications.
  - Exported entrypoints: [`package:counter_app/counter_app.dart`](file:///Users/vishnusidhan/Desktop/Development/Apps/counter-app/lib/counter_app.dart) (full suite) or [`package:counter_app/stall_pos.dart`](file:///Users/vishnusidhan/Desktop/Development/Apps/counter-app/lib/stall_pos.dart) (POS domain only).
- **💾 Centralized & Swappable Storage Architecture:**
  - Decoupled storage contracts: [`StallStorage`](file:///Users/vishnusidhan/Desktop/Development/Apps/counter-app/lib/data/storage/stall_storage.dart) and [`CounterStorage`](file:///Users/vishnusidhan/Desktop/Development/Apps/counter-app/lib/data/storage/counter_storage.dart).
  - Defaults out-of-the-box to local device storage ([`shared_preferences`](https://pub.dev/packages/shared_preferences)).
  - Single-line registry swap via [`AppStorage.configure(...)`](file:///Users/vishnusidhan/Desktop/Development/Apps/counter-app/lib/data/storage/app_storage.dart) to connect any cloud backend (Firebase, Supabase, Custom REST API) without modifying core widgets.
  - Core package remains lean and 100% free of hardcoded HTTP or vendor networking dependencies.
- **🌐 Interactive UI-Based Cloud Storage Configuration:**
  - The [`example/`](file:///Users/vishnusidhan/Desktop/Development/Apps/counter-app/example) host app includes a live configuration modal allowing users to enter custom cloud backend details directly from the UI:
    - Custom Base URL and Bearer Auth Token / API Key.
    - Multi-tenant Stall ID (`X-Stall-Id` header).
    - Offline fallback cache toggle.
    - Live "Test Connection" probe with instant diagnostic feedback.
    - Status pill in the AppBar (`🟢 Remote: api.domain.com` vs `⚪ Local Storage`).
- **📥 Bulk CSV Import:**
  - Bulk import POS menu items and Counters directly from `.csv` files or raw text paste.
  - Live preview with row-by-row validation, item counts, and diagnostic warnings for invalid rows.
  - Choice of **Append** (preserving current items) or **Replace All** modes.
- **Thumb-Friendly Ergonomics (Fitts's Law):**
  - Oversized primary `+` touch target (72×60dp) with elevated tactile feedback for rapid tapping.
  - Subtle secondary `-` decrement button bounded at zero by default (optional negative bounds supported).
  - Native haptic feedback on every increment, decrement, and reset.
- **Goal & Target Tracking:**
  - Optional goal targets with real-time linear progress bars, live percentage indicators, and goal achievement badges.
- **Activity History & CSV Export:**
  - Complete audit log tracking every tap (increment, decrement, reset) with timestamps and resulting counts.
  - Filter activity feed by counter or view all events together.
  - Instant RFC 4180 CSV export/download with HTML5 Blob support on Web.
- **Safety & Recovery:**
  - Swipe-to-delete cards (`Dismissible`) with instant floating `UNDO` SnackBar.
  - Accidental reset prevention via confirmation dialogs.
- **Material 3 Design:**
  - Seamless Dark and Light theme support matching system settings.
  - High-contrast typography with animated count transitions.
  - Curated 12-color dynamic category palette with automatic random color assignment.

---

## 🏛️ Architecture & Project Structure

The project follows clean Separation of Concerns using native Flutter `ChangeNotifier`, `ListenableBuilder`, and pure storage abstractions:

```text
stall-pos/
├── lib/                                     # Core Reusable Package
│   ├── counter_app.dart                     # Primary package entrypoint
│   ├── stall_pos.dart                       # POS domain module entrypoint
│   ├── main.dart                            # Standalone web app entrypoint (StallPosApp)
│   ├── controllers/
│   │   ├── counter_controller.dart          # Counter state management & search/sort
│   │   └── order_controller.dart            # Stall POS cart, queue, and order lifecycle
│   ├── data/
│   │   ├── models/
│   │   │   ├── counter_log_entry.dart       # Counter audit log model
│   │   │   ├── counter_model.dart           # Counter model with JSON serialization
│   │   │   └── stall_models.dart            # MenuItem, StallOrder, CartItem models
│   │   ├── services/
│   │   │   ├── counter_storage_service.dart # Default SharedPreferences counter adapter
│   │   │   └── stall_storage_service.dart   # Default SharedPreferences stall adapter
│   │   └── storage/
│   │       ├── app_storage.dart             # Central singleton storage registry
│   │       ├── counter_storage.dart         # Abstract contract for counter storage
│   │       ├── in_memory_storage.dart       # In-memory storage mock implementations
│   │       └── stall_storage.dart           # Abstract contract for stall storage
│   ├── screens/
│   │   ├── history_screen.dart              # Counter audit log screen with CSV export
│   │   ├── home_screen.dart                 # Counters list view with search & filters
│   │   ├── main_navigation_screen.dart      # Navigation between Counters and Stall POS
│   │   ├── order_history_screen.dart        # Past orders, revenue analytics, & CSV export
│   │   └── stall_pos_screen.dart            # Fast POS screen with cart, queue, & summary
│   ├── services/
│   │   ├── csv_download_stub.dart           # Cross-platform stub for CSV export
│   │   ├── csv_download_web.dart            # Web HTML5 blob download implementation
│   │   ├── csv_export_service.dart          # RFC 4180 export generator
│   │   └── csv_import_service.dart          # RFC 4180 parser and file picking service
│   ├── theme/
│   │   ├── app_theme.dart                   # Light & Dark M3 themes
│   │   └── category_colors.dart             # Category color engine & vibrant palette
│   └── widgets/
│       ├── add_edit_counter_sheet.dart      # Modal for creating and editing counters
│       ├── counter_card.dart                # Fitts's Law ergonomic counter card
│       ├── csv_import_dialog.dart           # Dual-mode CSV file and text parser dialog
│       ├── empty_state.dart                 # Illustrated empty state widgets
│       └── search_sort_bar.dart             # Search bar and sorting filter controls
│
├── example/                                 # Consumer Host Application & Web Runner
│   ├── lib/
│   │   ├── configurable_remote_storage.dart # Live HTTP StallStorage adapter
│   │   ├── main.dart                        # Example app consuming package & live switching
│   │   └── remote_storage_config_dialog.dart# UI dialog for configuring cloud endpoints
│   ├── web/                                 # Web platform runner (index.html, manifest, icons)
│   ├── test/
│   │   └── configurable_remote_storage_test.dart
│   └── pubspec.yaml
│
└── test/                                    # 115 comprehensive unit & widget tests
```

---

## 📦 Using as a Package in Other Apps

You can add `counter_app` to your own Flutter application's `pubspec.yaml`:

```yaml
dependencies:
  counter_app:
    git:
      url: https://github.com/vishnu-sidhan/stall-pos.git
      ref: main
    # Or local path during development:
    # path: ../path/to/stall-pos
```

### 1. Embedding the Stall POS Screen

```dart
import 'package:flutter/material.dart';
import 'package:counter_app/counter_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const StallPosScreen(),
    );
  }
}
```

### 2. Custom Remote Storage Adapter (Firebase / Supabase / REST)

To persist stall data to your own cloud backend, implement the [`StallStorage`](file:///Users/vishnusidhan/Desktop/Development/Apps/counter-app/lib/data/storage/stall_storage.dart) interface and register it with `AppStorage`:

```dart
import 'package:counter_app/counter_app.dart';

class MyCloudStorage implements StallStorage {
  @override
  Future<List<MenuItem>> loadMenu() async {
    // Fetch menu from your backend (e.g. Firebase Firestore / Supabase / REST)
    return [];
  }

  @override
  Future<void> saveMenu(List<MenuItem> items) async {
    // Save menu to your backend
  }

  @override
  Future<List<StallOrder>> loadOrders() async {
    // Fetch active orders
    return [];
  }

  @override
  Future<void> saveOrders(List<StallOrder> orders) async {
    // Save orders to cloud
  }

  @override
  Future<int> loadNextToken() async => 1;

  @override
  Future<void> saveNextToken(int token) async {}

  @override
  Future<List<StallOrder>> clearCompletedOrders() async => [];

  @override
  Future<int> archiveCompletedOrders({
    Duration threshold = const Duration(hours: 24),
    List<StallOrder>? explicitOrders,
  }) async => 0;

  @override
  Future<List<StallOrder>> loadArchivedOrders() async => [];

  @override
  Future<void> clearAllOrders({bool resetToken = false}) async {}
}

// In your app initialization:
void configureStorage() {
  AppStorage.configure(
    stallStorage: MyCloudStorage(),
  );
}
```

---

## 📥 CSV Bulk Import & File Structure

You can create POS menu items and counters in bulk by uploading a `.csv` file or pasting raw CSV text directly into the import dialog. Access this via the **Upload CSV** button (`Icons.upload_file_rounded`) in the AppBar or on empty screen states.

### 1. POS Menu Items CSV Structure

| Column Header | Required | Data Type | Default Value | Description & Constraints | Example |
| :--- | :---: | :---: | :---: | :--- | :--- |
| `name` | **Yes** | String | — | Name of the menu item (cannot be empty). | `Masala Chai` |
| `price` | **Yes** | Number | — | Price in currency (must be > 0). Currency symbols (`₹`, `$`, `€`, `Rs.`) are stripped automatically. | `20.00` |
| `category` | No | String | `'General'` | Category tag used for filter chips. If blank, defaults to `General`. | `Beverages` |
| `color` | No | Hex / Name | *Random* | Category / item theme color (e.g. `#EA580C`, `0xFF059669`, `emerald`). **If omitted, a random color is automatically assigned.** | `#EA580C` |

#### Example `menu_items.csv`:
```csv
name,price,category,color
Masala Chai,20,Beverages,#EA580C
Filter Coffee,25,Beverages,#EA580C
Mango Lassi,50,Beverages,
Veg Samosa,20,Snacks,#059669
Paneer Roll,70,Fast Food,
"Combo Meal (Burger, Fries & Drink)",150,Combos,#7C3AED
Chicken Biryani,180,Main Course,crimson
Mineral Water,20,Beverages,
```

### 2. Counters CSV Structure

| Column Header | Required | Data Type | Default Value | Description & Constraints | Example |
| :--- | :---: | :---: | :---: | :--- | :--- |
| `title` | **Yes** | String | — | Name of the counter (cannot be empty). | `Daily Water Glasses` |
| `count` | No | Integer | `0` | Starting initial count. | `0` |
| `step` | No | Integer | `1` | Increment/decrement step amount (>= 1). | `1` |
| `target` | No | Integer | `null` | Optional goal target for progress tracking. | `8` |
| `allowNegative` | No | Boolean | `false` | Set to `true`, `1`, or `yes` to allow count below zero. | `false` |
| `colorHex` | No | Hex / Int | `0xFF2563EB` | Counter theme accent color (hex like `0xFF0284C7` or `#0284C7`). | `0xFF0284C7` |

#### Example `counters.csv`:
```csv
title,count,step,target,allowNegative,colorHex
Daily Water Glasses,0,1,8,false,0xFF0284C7
Workout Pushups,0,5,100,false,0xFF059669
Book Pages Read,0,1,50,false,0xFFD97706
Inventory Tally,10,1,,false,0xFF7C3AED
Cash Flow Delta,0,10,,true,0xFFDC2626
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.10.8` / `Flutter 3.38+`)
- Google Chrome (or any modern Chromium/WebKit browser)

### Running the Example Web App Locally
To run the full POS application with the interactive cloud storage configuration UI:

```bash
# Navigate to the example app
cd example

# Install dependencies
flutter pub get

# Run on Web in Chrome
flutter run -d chrome
```

### Deploying to GitHub Pages

#### 1. Automated Deployment (GitHub Actions)
The repository includes an automated CI/CD workflow ([`.github/workflows/deploy.yml`](file:///Users/vishnusidhan/Desktop/Development/Apps/counter-app/.github/workflows/deploy.yml)).
- **Trigger**: Automatically runs on every push to the `main` branch or manually via **Workflow Dispatch** in the GitHub Actions tab.
- **Pipeline**: Runs static analysis (`dart analyze`) and automated tests (`flutter test`) for both root package and example app, compiles the web release bundle (`flutter build web --release --base-href "/stall-pos/"`), and deploys directly to the `gh-pages` branch.

#### 2. Building the Web Bundle Locally
To build the production bundle locally for inspection or testing:
```bash
cd example
flutter build web --release --base-href "/stall-pos/"
```
The compiled output will be located in `example/build/web/`.

---

## 🧪 Testing & Quality Assurance

Run static analysis across the codebase:
```bash
# Root package
dart analyze

# Example app
cd example && dart analyze
```

Run the complete test suite:
```bash
# Root package test suite (115 tests)
flutter test

# Example app test suite (6 tests)
cd example && flutter test
```

### Test Coverage Highlights:
- **`test/centralized_storage_test.dart`**: Verifies `AppStorage` singleton swapping, `InMemoryStallStorage` CRUD lifecycle, archiving, and controller integration.
- **`example/test/configurable_remote_storage_test.dart`**: Verifies UI config serialization, `ConfigurableRemoteStorage` API client, `testConnection()` endpoint diagnostics, and offline fallback.
- **`test/stall_pos_screen_test.dart` & `test/stall_pos_widget_features_test.dart`**: End-to-end POS workflows, cart calculations, pay later / confirmation flows, add-on linking, and item preparation queues.
- **`test/order_history_screen_test.dart`**: Analytics metrics calculation, order search/filtering, and CSV export.
- **`test/csv_import_service_test.dart` & `test/csv_import_dialog_test.dart`**: RFC 4180 parsing, live preview validation, and append vs replace modes.
- **`test/counter_controller_test.dart` & `test/widget_test.dart`**: Counter state mutations, bounds checking, audit logging, and search/sort operations.

---

## 📦 Tech Stack

| Dependency | Purpose |
| :--- | :--- |
| **Flutter (Dart 3)** | Core UI framework with sound null safety |
| **`shared_preferences`** | Default offline persistence backed by `window.localStorage` on Web |
| **`file_picker`** | File picking for CSV imports |
| **`csv`** | RFC 4180 compliant CSV parsing and serialization |
| **`uuid`** | Collision-resistant unique IDs for counters, menu items, and orders |
| **`intl`** | Timestamp, date formatting, and currency handling |
| **`http`** *(example)* | Cloud REST API communication in example host app |
| **`flutter_launcher_icons`** | Web favicon and PWA manifest icon generation |

---

## 📄 License
This project is open-source and available under the [MIT License](LICENSE).
