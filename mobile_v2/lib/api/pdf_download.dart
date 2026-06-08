import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../config/api_config.dart';

class PdfDownload {
  static Future<String?> downloadPatientReport({
    required int reportId,
    required int reportPatientId,
    required String? token,
  }) async {
    if (token == null) return 'Нет авторизации';
    try {
      final uri = Uri.parse(
          '${ApiConfig.baseUrl}/reports/$reportId/patient/$reportPatientId/pdf');
      final resp = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/pdf, application/json',
        },
      );
      if (resp.statusCode != 200) {
        return 'HTTP ${resp.statusCode}: ${resp.body.length > 200 ? '${resp.body.substring(0, 200)}…' : resp.body}';
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/report-$reportId-patient-$reportPatientId.pdf');
      await file.writeAsBytes(resp.bodyBytes, flush: true);
      final open = await OpenFilex.open(file.path);
      if (open.type != ResultType.done) return 'Не удалось открыть PDF: ${open.message}';
      return null;
    } catch (e) {
      return 'Ошибка: $e';
    }
  }
}
