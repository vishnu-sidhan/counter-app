import 'package:intl/intl.dart';
import '../data/models/counter_log_entry.dart';
import 'csv_download_stub.dart'
    if (dart.library.io) 'csv_download_io.dart'
    if (dart.library.js_interop) 'csv_download_web.dart';

/// Service for formatting and exporting counter activity history to CSV.
class CsvExportService {
  CsvExportService._();

  /// Converts a list of [CounterLogEntry] into a standard RFC 4180 CSV string.
  static String generateCsv(List<CounterLogEntry> logs) {
    final buffer = StringBuffer();
    // CSV Header row
    buffer.writeln('ID,Timestamp,Date,Time,Counter Title,Action,Change,Resulting Count');

    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('h:mm:ss a');

    for (final log in logs) {
      final safeTitle = '"${log.counterTitle.replaceAll('"', '""')}"';
      final changeStr = log.changeAmount >= 0 ? '+${log.changeAmount}' : '${log.changeAmount}';
      buffer.writeln(
        '${log.id},'
        '${log.timestamp.toIso8601String()},'
        '${dateFormat.format(log.timestamp)},'
        '${timeFormat.format(log.timestamp)},'
        '$safeTitle,'
        '${log.actionType.label},'
        '$changeStr,'
        '${log.resultingCount}',
      );
    }
    return buffer.toString();
  }

  /// Generates the CSV and triggers a platform-appropriate download or share action.
  static Future<void> exportHistoryCsv({
    required List<CounterLogEntry> logs,
    String? counterTitle,
  }) async {
    if (logs.isEmpty) return;

    final csvContent = generateCsv(logs);
    final nowStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final prefix = counterTitle != null && counterTitle.trim().isNotEmpty
        ? counterTitle.trim().replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_').toLowerCase()
        : 'counter_activity';
    final filename = '${prefix}_$nowStr.csv';

    await saveOrShareCsv(
      csvContent: csvContent,
      filename: filename,
    );
  }
}
