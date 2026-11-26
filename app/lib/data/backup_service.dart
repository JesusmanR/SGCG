import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';

import 'app_database.dart';
import 'attachment_storage.dart';

class BackupService {
  BackupService(this.database, {AttachmentStorage? storage})
    : storage = storage ?? AttachmentStorage();

  static const formatName = 'sgcg-local-backup';
  static const formatVersion = 1;

  final AppDatabase database;
  final AttachmentStorage storage;

  Future<String?> createBackup() async {
    final now = DateTime.now();
    final suggestedName =
        'control_gastos_${now.year}${_twoDigits(now.month)}${_twoDigits(now.day)}.sgcgbak';
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Respaldo de Control de gastos',
          extensions: ['sgcgbak'],
        ),
      ],
    );
    if (location == null) return null;

    final tables = await database.rowsForBackup();
    final attachments = (tables['attachments'] as List)
        .cast<Map<String, dynamic>>();
    final files = <String, String>{};
    for (final attachment in attachments) {
      final relativePath = attachment['relativePath'] as String;
      final file = await storage.resolve(relativePath);
      if (file == null) {
        throw StateError(
          'No se encontró el archivo adjunto ${attachment['originalName']}.',
        );
      }
      files[relativePath] = base64Encode(await file.readAsBytes());
    }

    final backup = {
      'format': formatName,
      'formatVersion': formatVersion,
      'schemaVersion': database.schemaVersion,
      'createdAt': now.toUtc().toIso8601String(),
      'tables': tables,
      'files': files,
    };
    await File(location.path).writeAsString(
      const JsonEncoder.withIndent('  ').convert(backup),
      flush: true,
    );
    return location.path;
  }

  Future<String?> restoreBackup() async {
    final selected = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Respaldo de Control de gastos',
          extensions: ['sgcgbak'],
        ),
      ],
    );
    if (selected == null) return null;

    final document = jsonDecode(await selected.readAsString());
    if (document is! Map<String, dynamic> ||
        document['format'] != formatName ||
        document['formatVersion'] != formatVersion ||
        document['schemaVersion'] != database.schemaVersion ||
        document['tables'] is! Map ||
        document['files'] is! Map) {
      throw const FormatException(
        'Este archivo no es compatible con esta versión de Control de gastos.',
      );
    }

    final tables = Map<String, dynamic>.from(document['tables'] as Map);
    final attachmentRows = (tables['attachments'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final files = Map<String, dynamic>.from(document['files'] as Map);
    final currentTables = await database.rowsForBackup();
    final oldAttachmentRows = (currentTables['attachments'] as List)
        .cast<Map<String, dynamic>>();
    final createdPaths = <String>[];

    try {
      for (final attachment in attachmentRows) {
        final oldPath = attachment['relativePath'] as String;
        final encoded = files[oldPath];
        if (encoded is! String) {
          throw const FormatException(
            'El respaldo está incompleto: falta un archivo adjunto.',
          );
        }
        final bytes = base64Decode(encoded);
        final stored = await storage.saveBytes(
          originalName: attachment['originalName'] as String,
          bytes: bytes,
        );
        createdPaths.add(stored.relativePath);
        attachment['relativePath'] = stored.relativePath;
        attachment['extension'] = stored.extension;
        attachment['sizeBytes'] = stored.sizeBytes;
      }
      tables['attachments'] = attachmentRows;
      await database.replaceFromBackup(tables);
      for (final attachment in oldAttachmentRows) {
        await storage.delete(attachment['relativePath'] as String);
      }
      return selected.name;
    } catch (_) {
      for (final relativePath in createdPaths) {
        await storage.delete(relativePath);
      }
      rethrow;
    }
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
