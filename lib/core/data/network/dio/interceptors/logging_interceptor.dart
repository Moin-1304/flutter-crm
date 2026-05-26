library;

import 'dart:convert';

import 'package:dio/dio.dart';

/// Log Level
enum Level {
  /// No logs.
  none,

  /// Logs request and response lines.
  ///
  /// Example:
  ///  ```
  ///  --> POST /greeting
  ///
  ///  <-- 200 OK
  ///  ```
  basic,

  /// Logs request and response lines and their respective headers.
  ///
  ///  Example:
  /// ```
  /// --> POST /greeting
  /// Host: example.com
  /// Content-Type: plain/text
  /// Content-Length: 3
  /// --> END POST
  ///
  /// <-- 200 OK
  /// Content-Type: plain/text
  /// Content-Length: 6
  /// <-- END HTTP
  /// ```
  headers,

  /// Logs request and response lines and their respective headers and bodies (if present).
  ///
  /// Example:
  /// ```
  /// --> POST /greeting
  /// Host: example.com
  /// Content-Type: plain/text
  /// Content-Length: 3
  ///
  /// Hi?
  /// --> END POST
  ///
  /// <-- 200 OK
  /// Content-Type: plain/text
  /// Content-Length: 6
  ///
  /// Hello!
  /// <-- END HTTP
  /// ```
  body,
}

/// DioLoggingInterceptor
/// Simple logging interceptor for dio.
///
/// Inspired the okhttp-logging-interceptor and referred to pretty_dio_logger.
class LoggingInterceptor extends Interceptor {
  static const int _responsePayloadMaxChars = 3000;

  /// Log Level
  final Level level;

  /// Log printer; defaults logPrint log to console.
  /// In flutter, you'd better use debugPrint.
  /// you can also write log in a file.
  void Function(Object object) logPrint;

  /// Print compact json response
  final bool compact;

  final JsonDecoder decoder = const JsonDecoder();
  final JsonEncoder encoder = const JsonEncoder.withIndent('  ');

  LoggingInterceptor({
    this.level = Level.body,
    this.compact = false,
    this.logPrint = print,
  });

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (level == Level.none) {
      return handler.next(options);
    }

    logPrint('--> ${options.method} ${options.uri}');

    if (level == Level.basic) {
      return handler.next(options);
    }

    logPrint('[DIO][HEADERS]');
    options.headers.forEach((key, value) {
      logPrint('$key:$value');
    });

    if (level == Level.headers) {
      logPrint('[DIO][HEADERS]--> END ${options.method}');
      return handler.next(options);
    }

    final data = options.data;
    if (data != null) {
      if (data is Map) {
        if (compact) {
          logPrint('<-- Request payload');
          logPrint('$data');
        } else {
          _prettyPrintJson(data, label: '<-- Request payload');
        }
      } else if (data is FormData) {
        logPrint('<-- Request payload');
        logPrint('[FormData]');
      } else {
        logPrint('<-- Request payload');
        logPrint(data.toString());
      }
    }

    logPrint('[DIO]--> END ${options.method}');

    return handler.next(options);
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    if (level == Level.none) {
      return handler.next(response);
    }

    logPrint(
        '<-- ${response.statusCode} ${(response.statusMessage?.isNotEmpty ?? false) ? response.statusMessage : '' '${response.requestOptions.uri}'}');

    if (level == Level.basic) {
      return handler.next(response);
    }

    logPrint('[DIO][HEADER]');
    response.headers.forEach((key, value) {
      logPrint('$key:$value');
    });
    logPrint('[DIO][HEADERS]<-- END ${response.requestOptions.method}');
    if (level == Level.headers) {
      return handler.next(response);
    }
    final data = response.data;
    if (_isEmptyPayload(data)) {
      logPrint('<-- Response payload');
      logPrint('[empty]');
    } else {
      _printTruncatedResponsePayload(data);
    }

    logPrint('[DIO]<-- END HTTP');
    return handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    if (level == Level.none) {
      return handler.next(err);
    }

    logPrint('[DIO]<-- HTTP FAILED: $err');

    return handler.next(err);
  }

  void _prettyPrintJson(Object input, {required String label}) {
    final prettyString = encoder.convert(input);
    logPrint(label);
    prettyString.split('\n').forEach((element) => logPrint(element));
  }

  bool _isEmptyPayload(dynamic data) {
    if (data == null) return true;
    if (data is String) return data.trim().isEmpty;
    if (data is List || data is Map) return false;
    return false;
  }

  void _printTruncatedResponsePayload(dynamic data) {
    final payload = _stringifyPayload(data);
    logPrint('<-- Response payload');
    if (payload.length <= _responsePayloadMaxChars) {
      logPrint(payload);
      return;
    }
    logPrint(payload.substring(0, _responsePayloadMaxChars));
    logPrint('[truncated ${payload.length - _responsePayloadMaxChars} chars]');
  }

  String _stringifyPayload(dynamic data) {
    if (data is String) return data;
    if (data is Map || data is List) {
      if (compact) return data.toString();
      try {
        return encoder.convert(data);
      } catch (_) {
        return data.toString();
      }
    }
    return data.toString();
  }
}
