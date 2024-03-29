import 'dart:convert';
import 'dart:typed_data';

import 'http_rest_method.dart';

/// Used to provide multipart request's progress.
typedef HttpRequestProgressListener = void Function(int bytes, int totalBytes);

/// This class represents the properties of rest request
/// it allows to configure request's [method], URL path by [url], [headers],
/// [requestConverterType] which will convert the [HttpRestRequest] to [RowRequest],
/// [responseConverterType] which will convert the [RowResponse] to [HttpRestResponse],
/// and request [encoding].
class HttpRestRequest {
  HttpRestRequest({required this.method,
    required this.url,
    this.requestConverterType,
    this.responseConverterType,
    Map<String, String>? headers,
    this.body,
    this.encoding,
    this.readProgressListener,
    this.writeProgressListener,
    this.writeChunkSize
  }) : headers = {...(headers ?? {})};

  final Methods method;
  final String url;
  final Map<String, String> headers;
  final dynamic body;
  final Encoding? encoding;
  final Type? requestConverterType;
  final Type? responseConverterType;
  final HttpRequestProgressListener? readProgressListener;
  final HttpRequestProgressListener? writeProgressListener;
  final int? writeChunkSize;
}

/// This class represents more row level of [HttpRestRequest], which means it contains
/// the converted HttpRest request's body and initial [request].
/// The [rowBody] get defined by the [RequestConverter], for example the
/// [MapToJsonRequestConverter] converts the [Map] body to JSON [String], and get
/// assigned to [rowBody], then the converted JSON [String] file get used by  [RequestExecutor]
class RowRequest {
  const RowRequest(this.request, this.rowBody);

  final HttpRestRequest request;
  final dynamic rowBody;
}

/// This class represents the response, get returned by [HttpRestClient.execute] method.
/// It contains the original [request],
/// the [rowResponse] instance of [RowResponse], which contains all the response info, like
/// the response headers, code, body bytes, and more (see [RowResponse]).
/// The [response] parameter is converted response, which get created by provided [ResponseConverter],
/// as an example the [JsonToMapResponseConverter] get the [RowResponse.bodyBytes] and convert them
/// to [Map].
class HttpRestResponse {
  HttpRestResponse(this.request, this.rowResponse, this.response);

  final HttpRestRequest request;
  final RowResponse rowResponse;
  final dynamic response;
}

/// This class represents the rest row response, which contains
/// original [request], the response [code], response body bytes [bodyBytes],
/// [headers], [contentLength], and more meta info related to response.
/// The instance of [RowResponse] get passed throughout to response middlewares
/// and then to provided to [ResponseConverter] from the [HttpRestRequest]'s instance.
class RowResponse {
  const RowResponse(this.request,
      this.code,
      this.bodyBytes,
      this.headers,
      this.contentLength,
      this.isRedirect,
      this.persistentConnection,
      this.reasonPhrase);

  const RowResponse.undefined(HttpRestRequest request)
      : this(
      request,
      null,
      null,
      null,
      null,
      null,
      null,
      null);

  final HttpRestRequest request;
  final int? code;
  final Uint8List? bodyBytes;
  final Map<String, String>? headers;
  final int? contentLength;
  final bool? isRedirect;
  final bool? persistentConnection;
  final String? reasonPhrase;
}
