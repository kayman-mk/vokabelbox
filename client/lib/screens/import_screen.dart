import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../app_theme.dart';
import '../importing/csv_document.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({required this.api, required this.vocabularySet, super.key});

  final ApiClient api;
  final VocabularySet vocabularySet;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  static const _maxFileBytes = 2 * 1024 * 1024;
  CsvDocument? _document;
  String _delimiter = ',';
  String? _fileName;
  String? _error;
  List<Vocabulary> _existingWords = [];
  int _promptColumn = 0;
  int _answerColumn = 1;
  bool _busy = false;
  ImportResult? _result;

  Future<void> _pickFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );
      if (files == null || files.files.isEmpty) return;
      final file = files.files.single;
      final bytes = file.bytes;
      if (bytes == null) throw const FormatException('Die Datei konnte nicht gelesen werden.');
      if (bytes.length > _maxFileBytes) {
        throw const FormatException('Die CSV-Datei darf höchstens 2 MB groß sein.');
      }
      final content = utf8.decode(bytes, allowMalformed: false);
      final delimiter = detectCsvDelimiter(content);
      final document = parseCsvDocument(content, delimiter);
      final existingWords = await widget.api.getWords(widget.vocabularySet.id);
      if (!mounted) return;
      setState(() {
        _document = document;
        _csvContent = content;
        _delimiter = delimiter;
        _fileName = file.name;
        _existingWords = existingWords;
        _promptColumn = _guessColumn(document.headers, const ['prompt', 'word', 'term', 'front', 'vorderseite', 'wort']);
        _answerColumn = _guessColumn(document.headers, const ['answer', 'translation', 'meaning', 'back', 'übersetzung', 'antwort']);
        if (_answerColumn == _promptColumn) _answerColumn = document.headers.length > 1 ? (_promptColumn == 0 ? 1 : 0) : _promptColumn;
        _error = null;
        _result = null;
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  int _guessColumn(List<String> headers, List<String> names) {
    final lowered = headers.map((header) => header.toLowerCase()).toList();
    final index = lowered.indexWhere(names.contains);
    return index < 0 ? 0 : index;
  }

  void _changeDelimiter(String value) {
    final content = _csvContent;
    if (content == null) return;
    try {
      final document = parseCsvDocument(content, value);
      setState(() {
        _document = document;
        _delimiter = value;
        _promptColumn = 0;
        _answerColumn = document.headers.length > 1 ? 1 : 0;
        _error = null;
      });
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  String? _csvContent;

  List<_PreviewRow> _previewRows() {
    final document = _document;
    if (document == null) return [];
    final existing = _existingWords.map((word) => _key(word.prompt, word.answer)).toSet();
    final seen = <String>{};
    return [
      for (var index = 0; index < document.rows.length; index++)
        _previewRow(document.rows[index], index + 2, existing, seen),
    ];
  }

  _PreviewRow _previewRow(List<String> cells, int rowNumber, Set<String> existing, Set<String> seen) {
    if (cells.length != _document!.headers.length) {
      return _PreviewRow(rowNumber: rowNumber, prompt: '', answer: '', error: 'Anzahl der Spalten passt nicht zur Kopfzeile');
    }
    final prompt = cells[_promptColumn].trim();
    final answer = cells[_answerColumn].trim();
    if (prompt.isEmpty || answer.isEmpty) {
      return _PreviewRow(rowNumber: rowNumber, prompt: prompt, answer: answer, error: 'Vorderseite und Übersetzung sind erforderlich');
    }
    if (prompt.runes.length > 255 || answer.runes.length > 500) {
      return _PreviewRow(rowNumber: rowNumber, prompt: prompt, answer: answer, error: 'Text ist zu lang');
    }
    final key = _key(prompt, answer);
    final duplicate = existing.contains(key) || !seen.add(key);
    return _PreviewRow(rowNumber: rowNumber, prompt: prompt, answer: answer, duplicate: duplicate);
  }

  String _key(String prompt, String answer) => '${prompt.trim().toLowerCase()}\u0000${answer.trim().toLowerCase()}';

  Future<void> _import() async {
    final rows = _previewRows().where((row) => row.error == null).toList();
    if (rows.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.importWords(
        widget.vocabularySet.id,
        rows.map((row) => ImportRow(prompt: row.prompt, answer: row.answer)).toList(),
      );
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _previewRows();
    final validRows = rows.where((row) => row.error == null).length;
    final invalidRows = rows.length - validRows;
    final duplicateRows = rows.where((row) => row.duplicate).length;
    final columnsMapped = _promptColumn != _answerColumn;
    final document = _document;

    return Scaffold(
      appBar: AppBar(backgroundColor: vokabelPaper, title: const Text('CSV importieren')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Ziel-Lernbox: ${widget.vocabularySet.name}', style: const TextStyle(color: vokabelMuted)),
                const SizedBox(height: 20),
                if (_result != null)
                  _ImportComplete(result: _result!, invalidRows: invalidRows)
                else if (document == null)
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Wähle eine UTF-8-CSV-Datei mit Kopfzeile aus. Unterstützt werden Komma und Semikolon als Trennzeichen.', style: TextStyle(color: vokabelMuted, height: 1.5)),
                    const SizedBox(height: 16),
                    FilledButton.icon(onPressed: _pickFile, icon: const Icon(Icons.upload_file_rounded), label: const Text('CSV-Datei auswählen')),
                  ])
                else ...[
                  Row(children: [
                    Expanded(child: Text(_fileName ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                    TextButton.icon(onPressed: _pickFile, icon: const Icon(Icons.swap_horiz_rounded), label: const Text('Andere Datei')),
                  ]),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _delimiter,
                    decoration: const InputDecoration(labelText: 'Trennzeichen'),
                    items: const [DropdownMenuItem(value: ',', child: Text('Komma (,)')), DropdownMenuItem(value: ';', child: Text('Semikolon (;)'))],
                    onChanged: (value) { if (value != null) _changeDelimiter(value); },
                  ),
                  const SizedBox(height: 16),
                  Wrap(spacing: 16, runSpacing: 12, children: [
                    SizedBox(width: 320, child: DropdownButtonFormField<int>(
                      value: _promptColumn,
                      decoration: const InputDecoration(labelText: 'Spalte für Vorderseite'),
                      items: [for (var i = 0; i < document.headers.length; i++) DropdownMenuItem(value: i, child: Text(document.headers[i], overflow: TextOverflow.ellipsis))],
                      onChanged: (value) { if (value != null) setState(() => _promptColumn = value); },
                    )),
                    SizedBox(width: 320, child: DropdownButtonFormField<int>(
                      value: _answerColumn,
                      decoration: const InputDecoration(labelText: 'Spalte für Übersetzung'),
                      items: [for (var i = 0; i < document.headers.length; i++) DropdownMenuItem(value: i, child: Text(document.headers[i], overflow: TextOverflow.ellipsis))],
                      onChanged: (value) { if (value != null) setState(() => _answerColumn = value); },
                    )),
                  ]),
                  const SizedBox(height: 20),
                  Text('${rows.length} Datenzeilen · $invalidRows ungültig · $duplicateRows mögliche Duplikate', style: const TextStyle(color: vokabelMuted)),
                  if (!columnsMapped) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Wähle unterschiedliche Spalten für Vorderseite und Übersetzung.', style: TextStyle(color: Color(0xFFB42318)))),
                  const SizedBox(height: 10),
                  ...rows.take(20).map((row) => _PreviewTile(row: row)),
                  if (rows.length > 20) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('Vorschau der ersten 20 von ${rows.length} Zeilen', style: const TextStyle(color: vokabelMuted))),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy || validRows == 0 || !columnsMapped ? null : _import,
                    icon: _busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.file_download_done_rounded),
                    label: Text('Gültige Zeilen importieren ($validRows)'),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow {
  const _PreviewRow({required this.rowNumber, required this.prompt, required this.answer, this.error, this.duplicate = false});

  final int rowNumber;
  final String prompt;
  final String answer;
  final String? error;
  final bool duplicate;
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.row});

  final _PreviewRow row;

  @override
  Widget build(BuildContext context) {
    final status = row.error ?? (row.duplicate ? 'Duplikat – wird übersprungen' : null);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFEAECF2)), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Text('Zeile ${row.rowNumber}', style: const TextStyle(color: vokabelMuted, fontSize: 12)), if (status != null) ...[const SizedBox(width: 10), Expanded(child: Text(status, style: TextStyle(color: row.error != null ? const Color(0xFFB42318) : vokabelMuted, fontSize: 12)))]]),
        const SizedBox(height: 6),
        Text('${row.prompt}  →  ${row.answer}', style: const TextStyle(color: vokabelInk)),
      ]),
    );
  }
}

class _ImportComplete extends StatelessWidget {
  const _ImportComplete({required this.result, required this.invalidRows});

  final ImportResult result;
  final int invalidRows;

  @override
  Widget build(BuildContext context) => Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.check_circle_outline_rounded, color: vokabelAccent, size: 34),
            const SizedBox(height: 12),
            const Text('Import abgeschlossen', style: TextStyle(color: vokabelInk, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text('Hinzugefügt: ${result.created}'),
            Text('Als Duplikate übersprungen: ${result.skippedDuplicates}'),
            Text('Ungültige Zeilen ausgelassen: $invalidRows'),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Fertig')),
          ]),
        ),
      );
}
