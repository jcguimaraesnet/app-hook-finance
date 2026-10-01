// Spec: docs/specs/api/endpoints.md
// Spec: docs/specs/api/proxy.md

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'config.dart';

/// Resultado de validação de config — distingue ok de erros específicos.
class ValidationResult {
  final bool ok;
  final String? message;
  const ValidationResult.ok() : ok = true, message = null;
  const ValidationResult.fail(this.message) : ok = false;
}

class ApiClient {
  final Dio _dio;
  final ApiConfig _config;

  ApiClient(this._config) : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
        )) {
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        request: false,
        requestBody: false,
        responseBody: false,
        responseHeader: false,
        error: true,
        logPrint: (line) => debugPrint('[dio] $line'),
      ));
    }
  }

  Future<Map<String, dynamic>> get(
    String action, {
    Map<String, dynamic> params = const {},
  }) async {
    final query = <String, dynamic>{
      'action': action,
      'token': _config.token,
      ...params,
    }..removeWhere((_, v) => v == null);
    final r = await _dio.getUri(
      Uri.parse(_config.apiBase).replace(
        queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
      ),
    );
    return _decode(r.data);
  }

  /// `receiveTimeout` por chamada: o default de 60s do BaseOptions não serve
  /// para `newInvoice`, que lê a planilha inteira, insere ~37 linhas, formata,
  /// pinta e ainda mexe na aba de config — tudo dentro de um lock.
  Future<Map<String, dynamic>> post(
    String action,
    Map<String, dynamic> body, {
    Duration? receiveTimeout,
  }) async {
    // text/plain evita preflight CORS no Apps Script direto.
    final payload = {
      'action': action,
      'token': _config.token,
      ...body,
    };
    final r = await _dio.postUri(
      Uri.parse(_config.apiBase),
      data: jsonEncode(payload),
      options: Options(
        headers: {'Content-Type': 'text/plain'},
        responseType: ResponseType.plain,
        receiveTimeout: receiveTimeout,
      ),
    );
    return _decode(r.data);
  }

  Map<String, dynamic> _decode(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String) {
      // O Apps Script às vezes responde uma página HTML em vez de JSON — erro
      // de deploy/permissão, ou limite de chamadas em sequência. jsonDecode
      // nisso lança FormatException com o HTML inteiro na mensagem, que vaza
      // para a SnackBar e não diz nada ao usuário.
      final inicio = raw.trimLeft();
      if (inicio.startsWith('<')) {
        throw const FormatException(
          'O servidor respondeu uma página HTML em vez de dados. '
          'Pode ser limite de chamadas ou problema no deploy do Apps Script — '
          'tente de novo em alguns segundos.',
        );
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    throw FormatException('Resposta inesperada do servidor: $raw');
  }

  /// Visível para teste: o decode é o ponto onde uma resposta não-JSON do Apps
  /// Script vira mensagem de erro do app.
  @visibleForTesting
  Map<String, dynamic> decodeForTest(Object? raw) => _decode(raw);
}

/// Valida URL+token tentando lastEntries(n=1). Retorna mensagem específica
/// quando falha (timeout, network, unauthorized, etc).
Future<ValidationResult> validateConfig(ApiConfig config) async {
  if (!config.isConfigured) {
    return const ValidationResult.fail('Token vazio.');
  }
  try {
    final client = ApiClient(config);
    final r = await client.get('lastEntries', params: {'n': 1});
    if (r['ok'] == true) return const ValidationResult.ok();
    final err = r['error'];
    if (err == 'unauthorized') {
      return const ValidationResult.fail('Token inválido.');
    }
    return ValidationResult.fail('Backend respondeu: $err');
  } on DioException catch (e) {
    final msg = switch (e.type) {
      DioExceptionType.connectionTimeout => 'Tempo esgotado conectando.',
      DioExceptionType.receiveTimeout => 'Backend demorou demais (>60s).',
      DioExceptionType.connectionError =>
        'Sem conexão. Confira sua internet.',
      DioExceptionType.badResponse =>
        'Backend retornou HTTP ${e.response?.statusCode}.',
      _ => 'Erro de rede: ${e.message}',
    };
    return ValidationResult.fail(msg);
  } catch (e) {
    return ValidationResult.fail('Erro: $e');
  }
}
