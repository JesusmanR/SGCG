import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';

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

  static const endpoint = String.fromEnvironment('OCR_GATEWAY_URL');
  static const accessToken = String.fromEnvironment('OCR_GATEWAY_TOKEN');

  bool get isConfigured => endpoint.isNotEmpty && accessToken.isNotEmpty;

  Future<ReceiptOcrSuggestion> analyze(XFile file) async {
    if (!isConfigured) {
      throw const ReceiptOcrException(
        'La lectura automática aún no está conectada al servicio OCR.',
      );
    }

    final extension = file.name.split('.').last.toLowerCase();
    final mimeType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'pdf' => 'application/pdf',
      _ => throw const ReceiptOcrException(
        'La lectura automática acepta imágenes JPG, PNG y archivos PDF.',
      ),
    };
    final bytes = await file.readAsBytes();
    if (bytes.length > 15 * 1024 * 1024) {
      throw const ReceiptOcrException('El archivo supera el límite de 15 MB.');
    }

    final uri = Uri.tryParse(endpoint);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const ReceiptOcrException(
        'La dirección del servicio OCR no está configurada correctamente.',
      );
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 20));
      request.headers.contentType = ContentType.json;
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );
      request.add(
        utf8.encode(
          jsonEncode({
            'fileName': file.name,
            'mimeType': mimeType,
            'contentBase64': base64Encode(bytes),
          }),
        ),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 90),
      );
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ReceiptOcrException(_errorMessage(responseBody));
      }
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final amount = data['amountCents'];
      final dateText = data['date'] as String?;
      return ReceiptOcrSuggestion(
        merchant: _clean(data['merchant'] as String?),
        amountCents: amount is num && amount > 0 ? amount.round() : null,
        currency: _clean(data['currency'] as String?),
        date: dateText == null ? null : DateTime.tryParse(dateText),
        confidence: (data['confidence'] as num?)?.toDouble(),
      );
    } on ReceiptOcrException {
      rethrow;
    } on SocketException {
      throw const ReceiptOcrException(
        'No se pudo conectar al servicio. Revisa tu conexión a internet.',
      );
    } on HttpException {
      throw const ReceiptOcrException('No se pudo procesar el comprobante.');
    } on FormatException {
      throw const ReceiptOcrException(
        'El servicio devolvió una respuesta que no se pudo leer.',
      );
    } catch (_) {
      throw const ReceiptOcrException(
        'No se pudo completar la lectura. Puedes continuar llenando el gasto manualmente.',
      );
    } finally {
      client.close(force: true);
    }
  }

  String _errorMessage(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['message'] as String? ??
          'El servicio no pudo leer el comprobante.';
    } catch (_) {
      return 'El servicio no pudo leer el comprobante.';
    }
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}

class ReceiptOcrException implements Exception {
  const ReceiptOcrException(this.message);
  final String message;
}
