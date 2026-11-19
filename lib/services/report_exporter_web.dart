// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

import 'package:printing/printing.dart';

Future<void> exportPdfForNative(List<int> bytes, String filename) async {
  throw UnsupportedError('Compartir PDF nativo no está disponible en la Web.');
}

Future<void> exportExcelForNative(List<int> bytes, String filename) async {
  throw UnsupportedError(
    'Compartir Excel nativo no está disponible en la Web.',
  );
}

Future<void> exportPdfForWeb(List<int> bytes, String filename) {
  return Printing.sharePdf(
    bytes: Uint8List.fromList(bytes),
    filename: filename,
  );
}

Future<void> exportExcelForWeb(List<int> bytes, String filename) async {
  final blob = html.Blob([
    Uint8List.fromList(bytes),
  ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
