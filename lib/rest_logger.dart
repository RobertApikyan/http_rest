import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:rest/rest_io.dart';
import 'package:rest/rest_method.dart';
import 'package:rest/rest_middleware.dart';

enum LogParts {
  headers,
  body,
  url,
  code;

  static const all = {url, headers, code, body};
}

/// Loggers
class RequestLogger extends RestMiddleware<RestRowRequest> {
  RequestLogger({this.logParts = LogParts.all});

  final Set<LogParts> logParts;

  @override
  Future<RestRowRequest> onNext(
      RestRowRequest row, RestMiddleware<RestRowRequest> nextMiddleware) async {
    final request = row.request;
    final rowBody = row.rowBody;

    log('');
    logDivider();
    tabbedLog('→ REQUEST →');

    if (logParts.contains(LogParts.url)) {
      _logUrl(request.method, request.url);
    }

    if (logParts.contains(LogParts.headers)) {
      _logHeaders(request.headers);
    }

    if (logParts.contains(LogParts.body)) {
      _logBody(rowBody);
    }

    logDivider();

    return await nextMiddleware.next(row);
  }
}

class ResponseLogger extends RestMiddleware<RestRowResponse> {
  ResponseLogger({this.logParts = LogParts.all});

  final Set<LogParts> logParts;

  @override
  Future<RestRowResponse> onNext(RestRowResponse row,
      RestMiddleware<RestRowResponse> nextMiddleware) async {
    log('');
    logDivider();
    tabbedLog('← RESPONSE ←');

    if (logParts.contains(LogParts.url)) {
      final request = row.request;
      _logUrl(request.method, request.url);
    }

    if (logParts.contains(LogParts.code)) {
      final code = row.code;
      if (code != null) {
        tabbedLog('CODE: $code');
      }
    }

    if (logParts.contains(LogParts.headers)) {
      _logHeaders(row.headers ?? {});
    }

    if (logParts.contains(LogParts.body)) {
      String? textBody;
      try {
        textBody = utf8.decode(row.rowBody!);
      } on Exception {
        //ignore
      }
      _logBody(textBody ?? row.rowBody);
    }

    logDivider();

    return await nextMiddleware.next(row);
  }
}

void _logUrl(RestMethods method, String url) {
  String endpoint = '${method.toString().toUpperCase()}: $url';
  tabbedLog(endpoint);
}

void _logHeaders(Map<String, String> headers) {
  String headerLogs = '';
  for (var headerKey in headers.keys) {
    headerLogs += '$headerKey : ${headers[headerKey]}\n\t\t\t\t';
  }
  tabbedLog("HEADERS:\t$headerLogs");
}

void _logBody(dynamic rowBody) {
  String body = rowBody is Uint8List
      ? 'Bytes(${rowBody.length})'
      : rowBody?.toString() ?? '';
  if (body.isEmpty) {
    tabbedLog('BODY:\tEMPTY');
  } else {
    tabbedLog('BODY:\t$body');
  }
}

const divider =
    '-------------------------------------------------------------------------------------------------------------------';

void logDivider() => tabbedLog(divider);

void tabbedLog(String message) => log(message);
