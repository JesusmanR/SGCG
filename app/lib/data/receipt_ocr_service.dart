import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

class ReceiptOcrSuggestion {
  const ReceiptOcrSuggestion({
    this.merchant,
    this.amountCents,
    this.currency,
    this.date,
    this.confidence,
  });

  final String? merchant;
  final int? amountCents;
  final String? currency;
  final DateTime? date;
  final double? confidence;
}

class ReceiptOcrService {
  const ReceiptOcrService();

  static const maxFileBytes = 15 * 1024 * 1024;
  static const maxPdfPages = 10;

  bool get isConfigured => _findRuntime() != null;

  Future<ReceiptOcrSuggestion> analyze(XFile file) async {
    final runtime = _findRuntime();
    if (runtime == null) {
      throw const ReceiptOcrException(
        'No se encontró el motor de lectura local. Reinstala la aplicación.',
      );
    }
    final size = await file.length();
    if (size == 0 || size > maxFileBytes) {
      throw const ReceiptOcrException(
        'El comprobante debe pesar entre 1 byte y 15 MB.',
      );
    }

    final extension = path.extension(file.name).toLowerCase();
    final text = switch (extension) {
      '.jpg' || '.jpeg' || '.png' => await _recognizeImage(runtime, file.path),
      '.pdf' => await _recognizePdf(runtime, file),
      _ => throw const ReceiptOcrException(
        'La lectura local acepta imágenes JPG, PNG y archivos PDF.',
      ),
    };
    final suggestion = _ReceiptParser.parse(text);
    if (suggestion.merchant == null &&
        suggestion.amountCents == null &&
        suggestion.date == null) {
      throw const ReceiptOcrException(
        'No se encontraron datos legibles. Puedes registrar el gasto manualmente.',
      );
    }
    return suggestion;
  }

  Future<String> _recognizeImage(_TesseractRuntime runtime, String imagePath) {
    return _recognizePath(runtime, imagePath);
  }

  Future<String> _recognizePdf(_TesseractRuntime runtime, XFile file) async {
    PdfDocument? document;
    final temporaryImages = <File>[];
    try {
      document = await PdfDocument.openFile(file.path);
      if (document.pagesCount > maxPdfPages) {
        throw const ReceiptOcrException(
          'Para la lectura automática, el PDF puede tener hasta 10 páginas.',
        );
      }
      final temporaryDirectory = await getTemporaryDirectory();
      final pageTexts = <String>[];
      for (
        var pageNumber = 1;
        pageNumber <= document.pagesCount;
        pageNumber++
      ) {
        final page = await document.getPage(pageNumber);
        try {
          final rendered = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: PdfPageImageFormat.png,
          );
          if (rendered == null) {
            throw const ReceiptOcrException(
              'No se pudo convertir una página del PDF para su lectura.',
            );
          }
          final image = File(
            path.join(
              temporaryDirectory.path,
              'sgcg_ocr_${DateTime.now().microsecondsSinceEpoch}_$pageNumber.png',
            ),
          );
          await image.writeAsBytes(rendered.bytes, flush: true);
          temporaryImages.add(image);
          pageTexts.add(await _recognizePath(runtime, image.path));
        } finally {
          await page.close();
        }
      }
      return pageTexts.join('\n');
    } on ReceiptOcrException {
      rethrow;
    } catch (_) {
      throw const ReceiptOcrException(
        'No se pudo abrir el PDF. Prueba con una imagen clara del comprobante.',
      );
    } finally {
      await document?.close();
      for (final image in temporaryImages) {
        if (await image.exists()) await image.delete();
      }
    }
  }

  Future<String> _recognizePath(
    _TesseractRuntime runtime,
    String imagePath,
  ) async {
    try {
      final result = await Process.run(
        runtime.executable.path,
        [
          imagePath,
          'stdout',
          '-l',
          'spa',
          '--tessdata-dir',
          runtime.tessdata.path,
          '--oem',
          '1',
          '--psm',
          '6',
        ],
        workingDirectory: runtime.directory.path,
      ).timeout(const Duration(seconds: 60));
      if (result.exitCode != 0) {
        throw const ReceiptOcrException(
          'El motor no pudo leer esta imagen. Prueba con una foto más nítida.',
        );
      }
      return result.stdout.toString();
    } on ReceiptOcrException {
      rethrow;
    } on ProcessException {
      throw const ReceiptOcrException(
        'No se pudo iniciar el motor de lectura local.',
      );
    } on Exception {
      throw const ReceiptOcrException(
        'La lectura tardó demasiado. Intenta con una imagen más pequeña.',
      );
    }
  }

  _TesseractRuntime? _findRuntime() {
    final executableDirectory = path.dirname(Platform.resolvedExecutable);
    final currentDirectory = Directory.current.path;
    final candidates = [
      path.join(executableDirectory, 'ocr'),
      path.join(currentDirectory, 'ocr'),
      path.join(currentDirectory, '.tools', 'tesseract'),
      path.normalize(path.join(currentDirectory, '..', '.tools', 'tesseract')),
    ];
    for (final candidate in candidates) {
      final executable = File(path.join(candidate, 'tesseract.exe'));
      final tessdata = Directory(path.join(candidate, 'tessdata'));
      if (executable.existsSync() &&
          File(path.join(tessdata.path, 'spa.traineddata')).existsSync()) {
        return _TesseractRuntime(
          directory: Directory(candidate),
          executable: executable,
          tessdata: tessdata,
        );
      }
    }
    return null;
  }
}

class _TesseractRuntime {
  const _TesseractRuntime({
    required this.directory,
    required this.executable,
    required this.tessdata,
  });

  final Directory directory;
  final File executable;
  final Directory tessdata;
}

class _ReceiptParser {
  static ReceiptOcrSuggestion parse(String rawText) {
    final lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final normalizedLines = lines.map(_normalize).toList();
    final merchant = _findMerchant(lines, normalizedLines);
    final amountResult = _findTotal(lines, normalizedLines);
    final date = _findDate(rawText);
    final confidences = <double>[
      if (merchant != null) 0.55,
      if (amountResult != null) amountResult.$2,
      if (date != null) 0.65,
    ];
    return ReceiptOcrSuggestion(
      merchant: merchant,
      amountCents: amountResult?.$1,
      currency: amountResult == null ? null : 'COP',
      date: date,
      confidence: confidences.isEmpty
          ? null
          : confidences.reduce((a, b) => a + b) / confidences.length,
    );
  }

  static String? _findMerchant(List<String> lines, List<String> normalized) {
    final ignoredLabels = [
      'FACTURA',
      'RECIBO',
      'NIT',
      'FECHA',
      'HORA',
      'TELEFONO',
      'TEL',
      'DIRECCION',
      'REGIMEN',
      'CLIENTE',
      'CAJERO',
      'CAJA',
      'RESOLUCION',
      'DOCUMENTO',
      'PUNTO DE VENTA',
      'COPIA',
    ];
    for (var i = 0; i < lines.length && i < 8; i++) {
      final value = lines[i]
          .replaceAll(RegExp(r'^[^A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+'), '')
          .trim();
      final plain = normalized[i];
      if (value.length < 3 || value.length > 60) continue;
      if (ignoredLabels.any(
        (label) => plain == label || plain.startsWith('$label '),
      )) {
        continue;
      }
      final letters = RegExp(
        r'[A-ZÁÉÍÓÚÜÑ]',
        caseSensitive: false,
      ).allMatches(value).length;
      final digits = RegExp(r'\d').allMatches(value).length;
      if (letters >= 3 && digits <= letters ~/ 2) return value;
    }
    return null;
  }

  static (int, double)? _findTotal(
    List<String> lines,
    List<String> normalized,
  ) {
    final priorityLabels = [
      'TOTAL A PAGAR',
      'TOTAL PAGADO',
      'GRAN TOTAL',
      'VALOR TOTAL',
      'TOTAL',
      'PAGADO',
      'A PAGAR',
    ];
    for (final label in priorityLabels) {
      for (var i = 0; i < lines.length; i++) {
        final current = normalized[i];
        if (!current.contains(label) || current.contains('SUBTOTAL')) continue;
        final candidates = _amountCandidates(lines[i]);
        if (candidates.isNotEmpty) {
          return (candidates.last, label == 'TOTAL' ? 0.72 : 0.84);
        }
        if (i + 1 < lines.length) {
          final nextCandidates = _amountCandidates(lines[i + 1]);
          if (nextCandidates.isNotEmpty) {
            return (nextCandidates.last, 0.68);
          }
        }
      }
    }
    return null;
  }

  static List<int> _amountCandidates(String line) {
    final matches = RegExp(
      r'(?<!\d)(?:\$\s*)?\d[\d., ]{1,14}\d|(?<!\d)\d{1,12}(?!\d)',
    ).allMatches(line);
    final values = <int>[];
    for (final match in matches) {
      final cents = _parseAmount(match.group(0)!);
      if (cents != null && cents > 0 && cents <= 100000000000) {
        values.add(cents);
      }
    }
    return values;
  }

  static int? _parseAmount(String raw) {
    var value = raw.replaceAll(RegExp(r'[^\d.,]'), '').replaceAll(' ', '');
    if (value.isEmpty) return null;
    final lastDot = value.lastIndexOf('.');
    final lastComma = value.lastIndexOf(',');
    final separator = lastDot > lastComma ? '.' : ',';
    final separatorIndex = separator == '.' ? lastDot : lastComma;
    if (separatorIndex >= 0) {
      final trailingDigits = value.length - separatorIndex - 1;
      final otherSeparator = separator == '.' ? ',' : '.';
      if (trailingDigits == 1 || trailingDigits == 2) {
        value = value
            .replaceAll(otherSeparator, '')
            .replaceFirst(separator, '.');
      } else {
        value = value.replaceAll(RegExp(r'[.,]'), '');
      }
    }
    final amount = double.tryParse(value);
    if (amount == null || !amount.isFinite || amount <= 0) return null;
    return (amount * 100).round();
  }

  static DateTime? _findDate(String text) {
    final normalized = _normalize(text);
    final patterns = [
      RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{4})\b'),
      RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b'),
    ];
    final colombian = patterns[0].firstMatch(normalized);
    if (colombian != null) {
      return _validDate(
        int.parse(colombian.group(3)!),
        int.parse(colombian.group(2)!),
        int.parse(colombian.group(1)!),
      );
    }
    final iso = patterns[1].firstMatch(normalized);
    if (iso != null) {
      return _validDate(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }
    return null;
  }

  static DateTime? _validDate(int year, int month, int day) {
    if (year < 2000 ||
        year > DateTime.now().year + 1 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      return null;
    }
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  static String _normalize(String value) => value
      .toUpperCase()
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll('Ü', 'U')
      .replaceAll('Ñ', 'N');
}

class ReceiptOcrException implements Exception {
  const ReceiptOcrException(this.message);
  final String message;
}
