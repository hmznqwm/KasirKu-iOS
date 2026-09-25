import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';

void main() {
  test('test excel cell values', () {
    var excel = Excel.createExcel();
    var sheet = excel['Sheet1'];
    sheet.appendRow([
      TextCellValue('kode'),
      TextCellValue('nama'),
      TextCellValue('hargaBeli'),
      TextCellValue('hargaJual'),
    ]);
    sheet.appendRow([
      TextCellValue('BRG-001'),
      TextCellValue('Produk Test'),
      const IntCellValue(8000),
      const DoubleCellValue(10000.5),
    ]);

    var bytes = excel.encode()!;
    var decoded = Excel.decodeBytes(bytes);
    var table = decoded.tables['Sheet1']?.rows ?? [];

    for (var row in table) {
      for (var cell in row) {
        var val = cell?.value;
        expect(val, isNotNull);
      }
    }
  });
}
