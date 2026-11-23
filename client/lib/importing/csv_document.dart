import 'package:csv/csv.dart';

class CsvDocument {
  const CsvDocument({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;
}

String detectCsvDelimiter(String content) {
  var commas = 0;
  var semicolons = 0;
  var quoted = false;
  for (var index = 0; index < content.length; index++) {
    final character = content[index];
    if (character == '"') {
      if (quoted && index + 1 < content.length && content[index + 1] == '"') {
        index++;
      } else {
        quoted = !quoted;
      }
    } else if (!quoted && (character == '\n' || character == '\r')) {
      break;
    } else if (!quoted && character == ',') {
      commas++;
    } else if (!quoted && character == ';') {
      semicolons++;
    }
  }
  return semicolons > commas ? ';' : ',';
}

CsvDocument parseCsvDocument(String content, String delimiter) {
  final source = content.startsWith('\uFEFF') ? content.substring(1) : content;
  final parsed = CsvToListConverter(
    fieldDelimiter: delimiter,
    shouldParseNumbers: false,
  ).convert(source);
  if (parsed.isEmpty) {
    throw const FormatException('Die CSV-Datei ist leer.');
  }

  final headers = parsed.first.map((value) => value.toString().trim()).toList();
  if (headers.length < 2 || headers.every((header) => header.isEmpty)) {
    throw const FormatException('Die Kopfzeile muss mindestens zwei Spalten enthalten.');
  }
  if (headers.any((header) => header.isEmpty)) {
    throw const FormatException('Alle Spalten der Kopfzeile müssen benannt sein.');
  }

  final rows = parsed.skip(1).map((row) => row.map((value) => value.toString()).toList()).where((row) => row.any((value) => value.trim().isNotEmpty)).toList();
  if (rows.isEmpty) {
    throw const FormatException('Die CSV-Datei enthält keine Datenzeilen.');
  }
  if (rows.length > 500) {
    throw const FormatException('Eine Datei darf höchstens 500 Datenzeilen enthalten.');
  }
  return CsvDocument(headers: headers, rows: rows);
}
