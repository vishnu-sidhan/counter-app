/// The StallPOS & Multi-Counter modular package.
///
/// Can be imported and used as a module in any Flutter host application.
library;

// Data Models
export 'data/models/counter_model.dart';
export 'data/models/counter_log_entry.dart';
export 'data/models/stall_models.dart';

// Centralized Storage Contracts & Implementations
export 'data/storage/app_storage.dart';
export 'data/storage/stall_storage.dart';
export 'data/storage/counter_storage.dart';
export 'data/storage/in_memory_storage.dart';
export 'data/services/stall_storage_service.dart';
export 'data/services/counter_storage_service.dart';

// Controllers
export 'controllers/counter_controller.dart';
export 'controllers/order_controller.dart';
export 'controllers/theme_controller.dart';

// Screens
export 'screens/stall_pos_screen.dart';
export 'screens/order_history_screen.dart';
export 'screens/home_screen.dart';
export 'screens/history_screen.dart';
export 'screens/main_navigation_screen.dart';

// Reusable Widgets
export 'widgets/stall_pos/stall_pos_widgets.dart';
export 'widgets/counter_card.dart';
export 'widgets/add_edit_counter_sheet.dart';
export 'widgets/payment_confirmation_dialog.dart';
export 'widgets/csv_import_dialog.dart';
export 'widgets/search_sort_bar.dart';
export 'widgets/empty_state.dart';

// Theme & Styling
export 'theme/app_theme.dart';

// Services
export 'services/csv_export_service.dart';
export 'services/csv_import_service.dart';

// Standalone Application Widget
export 'main.dart' show StallPosApp;
