import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'apex_io.dart';
import 'apex_method.dart';
import 'apex_middleware.dart';


/// This enum can be used to specify which part of the request need to logged
/// by [RequestLogger] and [ResponseLogger]
enum LogParts {
  headers,
  body,
  url,
  code;

  static const all = {url, headers, code, body};
}

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
/// The [RequestLogger] is a descendant of [RestMiddleware], you can derive from
/// the [RestMiddleware] and create you own request logger.
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
/// The [ResponseLogger] is a descendant of [RestMiddleware], you can derive from
/// the [RestMiddleware] and create you own response logger.
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
        textBody = utf8.decode(row.bodyBytes!);
      } on Exception {
        //ignore
      }
      _logBody(textBody ?? row.bodyBytes);
    }

    logDivider();

    return await nextMiddleware.next(row);
  }
}

void _logUrl(RestMethods method, String url) {
  String endpoint = '${method.name.toString().toUpperCase()}: $url';
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
    tabbedLog('BODY:\n\t$body');
  }
}

const divider =
    '-------------------------------------------------------------------------------------------------------------------';

void logDivider() => tabbedLog(divider);

void tabbedLog(String message) => log(message);
