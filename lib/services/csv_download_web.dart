import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Web implementation for downloading CSV directly in the browser.
Future<void> saveOrShareCsv({
  required String csvContent,
  required String filename,
}) async {
  final bytes = utf8.encode(csvContent);
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = filename;
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
