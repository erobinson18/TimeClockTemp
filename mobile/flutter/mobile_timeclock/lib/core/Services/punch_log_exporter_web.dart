// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;

class PunchLogExporter {
  static Future<void> exportCsv(String csv) async {
    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final stamp = DateTime.now().millisecondsSinceEpoch;

    html.AnchorElement(href: url)
      ..download = 'punch_log_$stamp.csv'
      ..style.display = 'none'
      ..click();

    html.Url.revokeObjectUrl(url);
  }
}