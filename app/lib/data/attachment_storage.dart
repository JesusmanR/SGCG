import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class StoredAttachment {
  const StoredAttachment({
    required this.originalName,
    required this.relativePath,
    required this.extension,
    required this.sizeBytes,
  });
  final String originalName;
  final String relativePath;
  final String extension;
  final int sizeBytes;
}

class AttachmentStorage {
  static const directoryName = 'attachments';

  Future<StoredAttachment> save(XFile source) async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory(path.join(root.path, directoryName));
    await directory.create(recursive: true);
    final extension = path
        .extension(source.name)
        .replaceFirst('.', '')
        .toLowerCase();
    final safeName =
        '${DateTime.now().microsecondsSinceEpoch}_${source.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}';
    final destination = File(path.join(directory.path, safeName));
    final stored = await File(source.path).copy(destination.path);
    return StoredAttachment(
      originalName: source.name,
      relativePath: path.join(directoryName, path.basename(stored.path)),
      extension: extension,
      sizeBytes: await stored.length(),
    );
  }

  Future<File?> resolve(String relativePath) async {
    final root = await getApplicationSupportDirectory();
    final file = File(path.join(root.path, relativePath));
    return await file.exists() ? file : null;
  }

  Future<void> delete(String relativePath) async {
    final file = await resolve(relativePath);
    if (file != null) await file.delete();
  }
}
