import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// IO implementation for saving or sharing CSV files on mobile and desktop.
Future<void> saveOrShareCsv({
  required String csvContent,
  required String filename,
}) async {
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/$filename');
  await file.writeAsString(csvContent);

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv')],
      subject: filename,
    ),
  );
}
