import 'dart:convert';
import 'dart:typed_data';

import 'apex_method.dart';

/// This class represents the properties of rest request
/// it allows to configure request's [method], URL path by [url], [headers],
/// [requestConverterType] which will convert the [RestRequest] to [RestRowRequest],
/// [responseConverterType] which will convert the [RestRowResponse] to [RestResponse],
/// and request [encoding].
class RestRequest {
  RestRequest(
      {required this.method,
      required this.url,
      this.requestConverterType,
      this.responseConverterType,
      Map<String, String>? headers,
      this.body,
      this.encoding})
      : headers = {...(headers ?? {})};

  final RestMethods method;
  final String url;
  final Map<String, String> headers;
  final dynamic body;
  final Encoding? encoding;
  final Type? requestConverterType;
  final Type? responseConverterType;
}

/// This class represents more row level of [RestRequest], which means it contains
/// the converted Rest request's body and initial [request].
/// The [rowBody] get defined by the [RestRequestConverter], for example the
/// [MapToJsonRequestConverter] converts the [Map] body to JSON [String], and get
/// assigned to [rowBody], then the converted JSON [String] file get used by  [RestRequestExecutor]
class RestRowRequest {
  const RestRowRequest(this.request, this.rowBody);

  final RestRequest request;
  final dynamic rowBody;
}

/// This class represents the response, get returned by [RestClient.execute] method.
/// It contains the original [request],
/// the [rowResponse] instance of [RestRowResponse], which contains all the response info, like
/// the response headers, code, body bytes, and more (see [RestRowResponse]).
/// The [response] parameter is converted response, which get created by provided [RestResponseConverter],
/// as an example the [JsonToMapResponseConverter] get the [RestRowResponse.bodyBytes] and convert them
/// to [Map].
class RestResponse {
  RestResponse(this.request, this.rowResponse, this.response);

  final RestRequest request;
  final RestRowResponse rowResponse;
  final dynamic response;
}

/// This class represents the rest row response, which contains
/// original [request], the response [code], response body bytes [bodyBytes],
/// [headers], [contentLength], and more meta info related to response.
/// The instance of [RestRowResponse] get passed throughout to response middlewares
/// and then to provided to [RestResponseConverter] from the [RestRequest]'s instance.
class RestRowResponse {
  const RestRowResponse(
      this.request,
      this.code,
      this.bodyBytes,
      this.headers,
      this.contentLength,
      this.isRedirect,
      this.persistentConnection,
      this.reasonPhrase);

  const RestRowResponse.undefined(RestRequest request)
      : this(request, null, null, null, null, null, null, null);

  final RestRequest request;
  final int? code;
  final Uint8List? bodyBytes;
  final Map<String, String>? headers;
  final int? contentLength;
  final bool? isRedirect;
  final bool? persistentConnection;
  final String? reasonPhrase;
}
