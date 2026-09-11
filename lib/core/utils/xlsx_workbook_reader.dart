import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class XlsxSheetData {
  const XlsxSheetData({required this.name, required this.rows});

  final String name;
  final List<List<String>> rows;
}

class XlsxWorkbookData {
  const XlsxWorkbookData({required this.sheets});

  final List<XlsxSheetData> sheets;
}

class XlsxWorkbookReader {
  const XlsxWorkbookReader();

  XlsxWorkbookData read(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final workbookXml = _archiveText(archive, 'xl/workbook.xml');
    if (workbookXml == null || workbookXml.trim().isEmpty) {
      throw const FormatException(
        'The Excel workbook is missing its sheet list.',
      );
    }

    final relationships = _relationships(archive);
    final sharedStrings = _sharedStrings(archive);
    final workbook = XmlDocument.parse(workbookXml);
    final sheets = <XlsxSheetData>[];

    for (final sheet in workbook.findAllElements('sheet')) {
      final name = sheet.getAttribute('name')?.trim() ?? '';
      final relationshipId =
          sheet.getAttribute(
            'id',
            namespaceUri:
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
          ) ??
          sheet.getAttribute('r:id');
      final path = relationshipId == null
          ? null
          : relationships[relationshipId];
      if (name.isEmpty || path == null) continue;
      final sheetXml = _archiveText(archive, path);
      if (sheetXml == null) continue;
      sheets.add(
        XlsxSheetData(name: name, rows: _sheetRows(sheetXml, sharedStrings)),
      );
    }

    if (sheets.isEmpty) {
      throw const FormatException('No readable worksheets were found.');
    }
    return XlsxWorkbookData(sheets: List<XlsxSheetData>.unmodifiable(sheets));
  }

  Map<String, String> _relationships(Archive archive) {
    final xml = _archiveText(archive, 'xl/_rels/workbook.xml.rels');
    if (xml == null || xml.trim().isEmpty) return const <String, String>{};
    final document = XmlDocument.parse(xml);
    return <String, String>{
      for (final relationship in document.findAllElements('Relationship'))
        if ((relationship.getAttribute('Id') ?? '').isNotEmpty &&
            (relationship.getAttribute('Target') ?? '').isNotEmpty)
          relationship.getAttribute('Id')!: _resolveWorksheetPath(
            relationship.getAttribute('Target')!,
          ),
    };
  }

  String _resolveWorksheetPath(String target) {
    var path = target.replaceAll('\\', '/');
    while (path.startsWith('../')) {
      path = path.substring(3);
    }
    if (path.startsWith('/')) path = path.substring(1);
    return path.startsWith('xl/') ? path : 'xl/$path';
  }

  List<String> _sharedStrings(Archive archive) {
    final xml = _archiveText(archive, 'xl/sharedStrings.xml');
    if (xml == null || xml.trim().isEmpty) return const <String>[];
    final document = XmlDocument.parse(xml);
    return document
        .findAllElements('si')
        .map((item) {
          return item.findAllElements('t').map((text) => text.innerText).join();
        })
        .toList(growable: false);
  }

  List<List<String>> _sheetRows(String xml, List<String> sharedStrings) {
    final document = XmlDocument.parse(xml);
    final rows = <List<String>>[];
    for (final rowNode in document.findAllElements('row')) {
      final row = <String>[];
      for (final cell in rowNode.findElements('c')) {
        final column = _columnIndex(cell.getAttribute('r') ?? '');
        if (column < 0) continue;
        while (row.length <= column) {
          row.add('');
        }
        row[column] = _cellValue(cell, sharedStrings);
      }
      while (row.isNotEmpty && row.last.trim().isEmpty) {
        row.removeLast();
      }
      if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
    }
    return List<List<String>>.unmodifiable(rows);
  }

  String _cellValue(XmlElement cell, List<String> sharedStrings) {
    final type = cell.getAttribute('t') ?? '';
    if (type == 'inlineStr') {
      return cell.findAllElements('t').map((text) => text.innerText).join();
    }
    final values = cell.findElements('v');
    final raw = values.isEmpty ? '' : values.first.innerText.trim();
    if (type != 's') return raw;
    final index = int.tryParse(raw);
    return index == null || index < 0 || index >= sharedStrings.length
        ? ''
        : sharedStrings[index];
  }

  int _columnIndex(String reference) {
    final match = RegExp(r'^[A-Za-z]+').firstMatch(reference);
    if (match == null) return -1;
    var index = 0;
    for (final code in match.group(0)!.toUpperCase().codeUnits) {
      index = index * 26 + code - 64;
    }
    return index - 1;
  }

  String? _archiveText(Archive archive, String path) {
    final file = archive.findFile(path);
    if (file == null || !file.isFile) return null;
    return utf8.decode(file.content as List<int>, allowMalformed: true);
  }
}
