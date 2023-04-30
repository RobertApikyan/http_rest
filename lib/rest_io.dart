

import 'dart:convert';
import 'dart:typed_data';
import 'package:rest/rest_method.dart';

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

class RestRowRequest {
  const RestRowRequest(this.request, this.rowBody, this.encoding);

  final RestRequest request;
  final dynamic rowBody;
  final Encoding? encoding;
}

class RestResponse {
  RestResponse(this.request, this.rowResponse, this.response);

  final RestRequest request;
  final RestRowResponse rowResponse;
  final dynamic response;
}

class RestRowResponse {
  const RestRowResponse(
      this.request,
      this.code,
      this.rowBody,
      this.headers,
      this.contentLength,
      this.isRedirect,
      this.persistentConnection,
      this.reasonPhrase);

  const RestRowResponse.undefined(RestRequest request)
      : this(request, null, null, null, null, null, null, null);

  final RestRequest request;
  final int? code;
  final Uint8List? rowBody;
  final Map<String, String>? headers;
  final int? contentLength;
  final bool? isRedirect;
  final bool? persistentConnection;
  final String? reasonPhrase;
}
