Future<void> exportPdfForWeb(List<int> bytes, String filename) =>
    _unsupportedExport();

Future<void> exportPdfForNative(List<int> bytes, String filename) =>
    _unsupportedExport();

Future<void> exportExcelForWeb(List<int> bytes, String filename) =>
    _unsupportedExport();

Future<void> exportExcelForNative(List<int> bytes, String filename) =>
    _unsupportedExport();

Future<void> _unsupportedExport() async {
  throw UnsupportedError('No hay un exportador disponible para esta plataforma.');
}
