import 'package:flutter_test/flutter_test.dart';
import 'package:vokabelbox/importing/csv_document.dart';

void main() {
  group('detectCsvDelimiter', () {
    test('detects semicolons and ignores delimiters inside quoted headers', () {
      expect(detectCsvDelimiter('"word, original";translation\nHaus;house'), ';');
    });

    test('defaults to comma', () {
      expect(detectCsvDelimiter('word,translation\nhouse, Haus'), ',');
    });
  });

  group('parseCsvDocument', () {
    test('removes a UTF-8 BOM and parses quoted delimiters and escaped quotes', () {
      final document = parseCsvDocument('\uFEFFword;translation\r\n"house;home";"a ""quoted"" answer"\r\n', ';');

      expect(document.headers, ['word', 'translation']);
      expect(document.rows, [
        ['house;home', 'a "quoted" answer'],
      ]);
    });

    test('rejects files without two named header columns', () {
      expect(() => parseCsvDocument('word\nhouse', ','), throwsFormatException);
      expect(() => parseCsvDocument('word,,translation\nhouse,x, Haus', ','), throwsFormatException);
    });

    test('rejects files without data and more than 500 rows', () {
      expect(() => parseCsvDocument('word,translation\n', ','), throwsFormatException);
      final rows = List<String>.filled(501, 'word,translation').join('\n');
      expect(() => parseCsvDocument('word,translation\n$rows', ','), throwsFormatException);
    });
  });
}
