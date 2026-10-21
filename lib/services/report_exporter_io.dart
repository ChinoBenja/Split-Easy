import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> exportPdfForWeb(List<int> bytes, String filename) async {
  throw UnsupportedError(
    'La descarga web no está disponible en esta plataforma.',
  );
}

Future<void> exportExcelForWeb(List<int> bytes, String filename) async {
  throw UnsupportedError(
    'La descarga web no está disponible en esta plataforma.',
  );
}

Future<void> exportPdfForNative(List<int> bytes, String filename) =>
    _saveAndShare(bytes, filename, 'application/pdf');

Future<void> exportExcelForNative(List<int> bytes, String filename) =>
    _saveAndShare(
      bytes,
      filename,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );

Future<void> _saveAndShare(
  List<int> bytes,
  String filename,
  String mimeType,
) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$filename');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([
      XFile(file.path, mimeType: mimeType, name: filename),
    ]);
  } catch (error) {
    throw Exception('No se pudo guardar o compartir "$filename": $error');
  }
}
