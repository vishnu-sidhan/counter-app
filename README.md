# StallPOS ⚡

A modern, offline-first, ergonomic Stall Point-of-Sale (POS) and Multi-Counter system built with Flutter and Material 3. Designed for fast one-handed thumb interaction (Fitts's Law), zero-config persistence, goal tracking, bulk CSV imports, and event/food counter ticketing.

---

## ✨ Features

- **Thumb-Friendly Ergonomics (Fitts's Law):**
  - Oversized primary `+` touch target (72×60dp) with elevated tactile feedback for rapid tapping.
  - Subtle secondary `-` decrement button bounded at zero by default (optional negative bounds supported).
  - Native haptic feedback on every increment (`lightImpact`), decrement (`selectionClick`), and reset (`mediumImpact`).
- **⚡ Stall POS & Kitchen Ticket Queue:**
  - Fast counter POS for food stalls, pop-ups, events, and festival booths.
  - One-tap cart additions, running order summaries, and real-time total revenue tally.
  - FIFO kitchen queue with automated order numbers (#1, #2...) and elapsed time tracking.
  - Complete order history with timestamps, completion metrics, and revenue breakdown.
- **📥 Bulk CSV Import:**
  - Bulk import POS menu items and Counters directly from `.csv` files or raw text paste.
  - Live preview with row-by-row validation, item counts, and diagnostic warnings for invalid rows.
  - Choice of **Append** (preserving current items) or **Replace All** modes.
- **Goal & Target Tracking:**
  - Optional goal targets with real-time linear progress bars, live percentage indicators, and goal achievement badges.
- **Offline-First Persistence:**
  - Zero-configuration local storage using `shared_preferences` with JSON serialization.
  - Optimistic UI updates with silent background writes.
  - Cross-platform support: iOS, Android, macOS, Windows, Linux, and Web (backed by `window.localStorage`).
- **Dynamic Organization:**
  - Real-time search by title with quick-clear button.
  - Multi-criteria sorting: *Alphabetical* (default), *Recently Updated*, and *Highest Count*.
  - 10 curated color themes for counters (Sapphire, Emerald, Sunset, Crimson, Violet, Teal, Amber, Rose, Indigo, Slate).
  - **Dynamic Category Colors** for POS menu items: Automatic random color assignment for categories when colors are not defined, visual category indicator chips, colored group headings, and item card accent strips.
- **Activity History & CSV Export:**
  - Complete audit log tracking every tap (increment, decrement, reset) with timestamps and resulting counts.
  - Filter activity feed by counter or view all events together.
  - Instant CSV export/download with RFC 4180 compliance, working seamlessly across Web, Mobile, and Desktop.
- **Safety & Recovery:**
  - Swipe-to-delete cards (`Dismissible`) with instant floating `UNDO` SnackBar.
  - Accidental reset prevention via confirmation dialog.
- **Material 3 Design:**
  - Seamless Dark and Light theme support matching system settings.
  - High-contrast typography with animated count transitions (>= 38sp bold).

---

## 📥 CSV Bulk Import & File Structure

You can create POS menu items and counters in bulk by uploading a `.csv` file or pasting raw CSV text directly into the import dialog. Access this via the **Upload CSV** button (`Icons.upload_file_rounded`) in the AppBar or on empty screen states.

### 1. POS Menu Items CSV Structure

Use this structure to bulk-create menu items for the **Stall POS** screen.

#### Column Specifications:

| Column Header | Required | Data Type | Default Value | Description & Constraints | Example |
| :--- | :---: | :---: | :---: | :--- | :--- |
| `name` | **Yes** | String | — | Name of the menu item (cannot be empty). | `Masala Chai` |
| `price` | **Yes** | Number | — | Price in currency (must be > 0). Currency symbols (`₹`, `$`, `€`, `Rs.`) are stripped automatically. | `20.00` |
| `category` | No | String | `'General'` | Category tag used for filter chips. If blank, defaults to `General`. | `Beverages` |
| `color` | No | Hex / Name | *Random* | Category / item theme color (e.g. `#EA580C`, `0xFF059669`, `emerald`). **If omitted or blank, a random color is automatically assigned.** | `#EA580C` |

> [!NOTE]
> - Header row is case-insensitive. Synonyms accepted:
>   - Name: `name`, `item`, `title`, `product`, `item_name`
>   - Price: `price`, `rate`, `cost`, `amount`, `mrp`
>   - Category: `category`, `cat`, `group`, `type`, `section`
>   - Color: `color`, `colorhex`, `color_hex`, `colour`
> - Complies with standard **RFC 4180**: Fields containing commas or quotes must be enclosed in double quotes (e.g. `"Chai, Special Masala"`). To include a quote inside a field, escape it with double quotes (e.g. `"Double ""Deluxe"" Burger"`).
> - **Automatic Random Colors**: If a color is not defined for a category or row, a random vibrant color is deterministically selected from a curated 12-color Material 3 palette, maintaining visual consistency across the session.

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

---

### 2. Counters CSV Structure

Use this structure to bulk-create counters for the **Counters** tracker screen.

#### Column Specifications:

| Column Header | Required | Data Type | Default Value | Description & Constraints | Example |
| :--- | :---: | :---: | :---: | :--- | :--- |
| `title` | **Yes** | String | — | Name of the counter (cannot be empty). | `Daily Water Glasses` |
| `count` | No | Integer | `0` | Starting initial count. | `0` |
| `step` | No | Integer | `1` | Increment/decrement step amount (>= 1). | `1` |
| `target` | No | Integer | `null` | Optional goal target for progress tracking. | `8` |
| `allowNegative` | No | Boolean | `false` | Set to `true`, `1`, or `yes` to allow count below zero. | `false` |
| `colorHex` | No | Hex / Int | `0xFF2563EB` | Counter theme accent color (hex like `0xFF0284C7` or `#0284C7`). | `0xFF0284C7` |

> [!NOTE]
> Header row synonyms accepted:
> - Title: `title`, `name`, `counter`, `counter_title`
> - Count: `count`, `value`, `initial`, `initial_count`
> - Step: `step`, `step_value`, `increment`
> - Target: `target`, `goal`, `target_count`
> - Allow Negative: `allownegative`, `allow_negative`, `negative`
> - Color: `colorhex`, `color_hex`, `color`

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

### 3. Import Options

When importing CSV data, you can choose between two modes:
- **Append (Default):** Adds the newly parsed items to your existing menu or counters list without deleting anything.
- **Replace All:** Replaces your existing list with the newly imported dataset.

---

## 🏛️ Architecture & Project Structure

The project follows clean Separation of Concerns using native Flutter `ChangeNotifier` and `ListenableBuilder`:

```text
lib/
├── controllers/
│   └── counter_controller.dart          # Counter state management, search, sort, and bulk import
├── data/
│   ├── models/
│   │   ├── counter_log_entry.dart       # Audit log model for counter actions
│   │   ├── counter_model.dart           # Immutable domain model with JSON serialization & goal helpers
│   │   └── stall_models.dart            # MenuItem and StallOrder models with JSON serialization
│   └── services/
│       ├── counter_storage_service.dart # SharedPreferences wrapper for robust offline JSON storage
│       └── stall_storage_service.dart   # Persistence service for stall menus and kitchen orders
├── screens/
│   ├── history_screen.dart              # Counter audit log screen with CSV export
│   ├── home_screen.dart                 # Counters list view with search, filter, and CSV import
│   ├── main_navigation_screen.dart      # Bottom navigation switching between Counters and Stall POS
│   ├── order_history_screen.dart        # Stall POS past orders and revenue analytics
│   └── stall_pos_screen.dart            # Fast POS screen with cart, FIFO kitchen queue, and CSV import
├── services/
│   ├── csv_download_io.dart             # Mobile/Desktop CSV download/share implementation
│   ├── csv_download_stub.dart           # Platform stub for CSV export
│   ├── csv_download_web.dart            # Web HTML5 blob download implementation
│   ├── csv_export_service.dart          # RFC 4180 export generator for logs and orders
│   └── csv_import_service.dart          # RFC 4180 parser and cross-platform file picking service
├── theme/
│   ├── app_theme.dart                   # Light & Dark M3 themes + curated 10-color categorization palette
│   └── category_colors.dart             # Category color engine, 12-color vibrant palette, & random fallback
├── widgets/
│   ├── add_edit_counter_sheet.dart      # Bottom sheet modal for creating and editing counters
│   ├── counter_card.dart                # Fitts's Law ergonomic card with tactile tap targets & haptics
│   ├── csv_import_dialog.dart           # Dual-mode CSV file uploader and live text parser dialog
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
- `test/csv_import_service_test.dart`: RFC 4180 parsing, quotes escaping, commas inside fields, currency symbol stripping, invalid row skipping, and counter parsing.
- `test/csv_import_dialog_test.dart`: File/paste tabs, sample template loading, live preview, append vs replace selection, and import execution.
- `test/stall_pos_screen_test.dart`: Full POS workflows, cart calculations, FIFO kitchen queue, order completions, category filtering, and CSV menu import.
- `test/order_history_screen_test.dart`: Metrics calculation, order filtering, and order CSV export.
- `test/counter_model_test.dart`: Serialization/deserialization, default attributes, goal progress calculations.
- `test/counter_controller_test.dart`: Controller state mutations, increment/decrement bounds, reset, edit, search query filtering, sorting, bulk import, and undo restoration.
- `test/widget_test.dart`: End-to-end user interaction flow from empty state to counter creation, tapping, navigation, and CSV counter import.

---

## 📦 Tech Stack

| Dependency | Purpose |
| :--- | :--- |
| **Flutter (Dart 3)** | Core framework & sound null safety |
| **`file_picker`** | Cross-platform file selection (Web, macOS, iOS, Android, Linux, Windows) |
| **`csv`** | RFC 4180 compliant CSV serialization and parsing |
| **`shared_preferences`** | Offline persistence across all platforms (Mobile, Desktop, Web) |
| **`uuid`** | Collision-resistant unique IDs for counters and menu items |
| **`intl`** | Timestamp and currency formatting |
| **`share_plus`** | Platform-native file sharing and export |
| **`path_provider`** | Local temporary filesystem storage for file exports |
| **`flutter_launcher_icons`** | Automated multi-platform app icon generation |

---

## 📄 License
This project is open-source and available under the [MIT License](LICENSE).
