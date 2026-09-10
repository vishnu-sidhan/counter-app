/// Dedicated StallPOS module entrypoint.
///
/// Use this library when embedding only the Point of Sale and Order Management
/// features into an existing host application.
library;

// Data Models
export 'data/models/stall_models.dart';

// Storage Contracts & Implementations
export 'data/storage/app_storage.dart';
export 'data/storage/stall_storage.dart';
export 'data/storage/in_memory_storage.dart';
export 'data/services/stall_storage_service.dart';

// Controllers
export 'controllers/order_controller.dart';
export 'controllers/theme_controller.dart';

// Screens
export 'screens/stall_pos_screen.dart';
export 'screens/order_history_screen.dart';

// Widgets
export 'widgets/stall_pos/stall_pos_widgets.dart';
export 'widgets/payment_confirmation_dialog.dart';

// Theme
export 'theme/app_theme.dart';

// Services
export 'services/csv_export_service.dart' show CsvExportService;

// Standalone Application Widget
export 'main.dart' show StallPosApp;
