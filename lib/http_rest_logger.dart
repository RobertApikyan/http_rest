import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'http_rest_io.dart';
import 'http_rest_method.dart';
import 'http_rest_middleware.dart';

/// This enum can be used to specify which part of the request need to logged
/// by [RequestLogger] and [ResponseLogger]
enum LogParts {
  headers,
  body,
  url,
  code;

  static const all = {url, headers, code, body};
}

typedef LoggingInterceptor = Future<void> Function(List<String> buffer);

/// The [RequestLogger] is a default logger implementation for the requests.
/// Here is how the logged request's structure looks like.
///
/// → REQUEST →
/// <rest method>: <URL>
/// HEADERS:	<header1> : <value>
/// 				  <header2> : <value>
/// BODY:	<body text or bytes>
///
/// Here is how real logged PUT request looks like in the console.
///  -------------------------------------------------------------------------------------------------------------------
///  → REQUEST →
///  PUT: https://example.com/api/v1/user/324234
///  HEADERS:	Content-Type : application/json
///				  Authorization : eyJhbGciOi....
/// 				Language : EN
/// 				Version : 1.1.76
///
///  BODY:	{"firstName":"Joe"}
///  -------------------------------------------------------------------------------------------------------------------
/// The [RequestLogger] is a descendant of [Middleware], you can derive from
/// the [Middleware] and create you own request logger.
class RequestLogger extends Middleware<RowRequest> with _RestLoggerMixin {
  RequestLogger({this.logParts = LogParts.all, this.loggingInterceptor});

  final Set<LogParts> logParts;
  @override
  final LoggingInterceptor? loggingInterceptor;

  @override
  Future<RowRequest> onNext(RowRequest row, Middleware<RowRequest> nextMiddleware) async {
    final request = row.request;
    final rowBody = row.rowBody;

    await _log('', collect: true);
    await _log(_divider, collect: true);
    await _log('→ REQUEST →', collect: true);

    if (logParts.contains(LogParts.url)) {
      await _logUrl(request.method, request.url);
    }

    if (logParts.contains(LogParts.headers)) {
      await _logHeaders(request.headers);
    }

    if (logParts.contains(LogParts.body)) {
      await _logBody(rowBody);
    }

    await _log(_divider, collect: false);

    return await nextMiddleware.next(row);
  }
}

/// The [ResponseLogger] is a default logger implementation for the responses.
/// Here is how the logged response's structure looks like.
///
///  ← RESPONSE ←
///  <rest method>: <URL>
///  CODE: <value>
///  HEADERS:	<header1> : <value>
/// 				  <header2> : <value>
///
///  BODY:	<body text or bytes>
///
/// Here is how real logged PUT request's response looks like in the console.
/// -------------------------------------------------------------------------------------------------------------------
///  ← RESPONSE ←
///  PUT: https://example.com/api/v1/user/324234
///  CODE: 200
///  HEADERS:	connection : keep-alive
/// 				date : Thu, 04 May 2023 19:02:10 GMT
/// 				transfer-encoding : chunked
/// 				vary : accept-encoding
/// 				content-encoding : gzip
/// 				strict-transport-security : max-age=15724800; includeSubDomains
/// 				content-type : application/json
///
///  BODY:  {"message":"Success"}
///  -------------------------------------------------------------------------------------------------------------------
/// The [ResponseLogger] is a descendant of [Middleware], you can derive from
/// the [Middleware] and create you own response logger.
class ResponseLogger extends Middleware<RowResponse> with _RestLoggerMixin {
  ResponseLogger({this.logParts = LogParts.all, this.loggingInterceptor});

  final Set<LogParts> logParts;
  @override
  final LoggingInterceptor? loggingInterceptor;

  @override
  Future<RowResponse> onNext(RowResponse row, Middleware<RowResponse> nextMiddleware) async {
    await _log('', collect: true);
    await _log(_divider, collect: true);
    await _log('← RESPONSE ←', collect: true);

    if (logParts.contains(LogParts.url)) {
      final request = row.request;
      await _logUrl(request.method, request.url);
    }

    if (logParts.contains(LogParts.code)) {
      final code = row.code;
      if (code != null) {
        await _log('CODE: $code', collect: true);
      }
    }

    if (logParts.contains(LogParts.headers)) {
      await _logHeaders(row.headers ?? {});
    }

    if (logParts.contains(LogParts.body)) {
      String? textBody;
      try {
        textBody = utf8.decode(row.bodyBytes!);
      } on Exception {
        //ignore
      }
      await _logBody(textBody ?? row.bodyBytes);
    }

    await _log(_divider, collect: false);

    return await nextMiddleware.next(row);
  }
}

mixin _RestLoggerMixin {
  final _divider =
      '-------------------------------------------------------------------------------------------------------------------';
  abstract final LoggingInterceptor? loggingInterceptor;
  List<String> messageBuffer = [];

  Future<void> _logUrl(Methods method, String url) async {
    String endpoint = '${method.name.toString().toUpperCase()}: $url';
    await _log(endpoint, collect: true);
  }

  Future<void> _logHeaders(Map<String, String> headers) async {
    String headerLogs = '';
    for (var headerKey in headers.keys) {
      headerLogs += '$headerKey : ${headers[headerKey]}\n\t\t\t\t';
    }
    await _log("HEADERS:\t$headerLogs", collect: true);
  }

  Future<void> _logBody(dynamic rowBody) async {
    String body = rowBody is Uint8List ? 'Bytes(${rowBody.length})' : rowBody?.toString() ?? '';
    if (body.isEmpty) {
      await _log('BODY:\tEMPTY', collect: true);
    } else {
      await _log('BODY:\n\t$body', collect: true);
    }
  }

  Future<void> _log(String message, {required bool collect}) async {
    if (collect) {
      messageBuffer.add(message);
    } else {
      if (loggingInterceptor case LoggingInterceptor interceptor) {
        await interceptor([...messageBuffer]);
      } else {
        for (var message in messageBuffer) {
          log(message);
        }
      }
      messageBuffer.clear();
    }
  }
}
