import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PunchLogExporter {
  static Future<void> exportCsv(String csv) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${dir.path}/punch_log_$stamp.csv';

    final file = File(path);
    await file.writeAsString(csv, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      text: 'Punch Log CSV',
      subject: 'Punch Log CSV',
    );
  }
}