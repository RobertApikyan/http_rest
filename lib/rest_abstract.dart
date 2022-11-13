import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:meta/meta.dart';

class RestClient {
  RestClient._private(this._rowRequestExecutor);

  final Map<Type, RequestConverter> _requestConverters = {};
  final Map<Type, ResponseConverter> _responseConverters = {};
  final RequestExecutor _rowRequestExecutor;
  final Middleware<RowRequest> _requestMiddleware = Middleware<RowRequest>();
  final Middleware<RowResponse> _responseMiddleware = Middleware<RowResponse>();

  Future<RestResponse> execute(RestRequest restRequest) async {
    RequestConverter requestConverter =
        getRequestConverter(restRequest.requestConverterType);
    ResponseConverter responseConverter =
        getResponseConverter(restRequest.responseConverterType);

    RowRequest rowRequest = requestConverter.toRow(restRequest);

    rowRequest = await _requestMiddleware.next(rowRequest);

    RowResponse rowResult = await _rowRequestExecutor.execute(rowRequest);

    rowResult = await _responseMiddleware.next(rowResult);

    RestResponse response = responseConverter.fromRow(rowResult);

    return response;
  }

  RequestConverter getRequestConverter(Type converterType) {
    RequestConverter? converter = _requestConverters[converterType];
    if (converter != null) {
      return converter;
    } else {
      throw Exception(
          'RequestConverter is not specified for type $converterType');
    }
  }

  ResponseConverter getResponseConverter(Type converterType) {
    ResponseConverter? converter = _responseConverters[converterType];
    if (converter != null) {
      return converter;
    } else {
      throw Exception(
          'ResponseConverter is not specified for type $converterType');
    }
  }
}

abstract class RestClientBuilder {
  RestClientBuilder addRequestConverter(RequestConverter converter);

  RestClientBuilder addResponseConverter(ResponseConverter converter);

  RestClientBuilder addRequestMiddleware(Middleware<RowRequest> middleware);

  RestClientBuilder addResponseMiddleware(Middleware<RowResponse> middleware);

  RestClient build();
}

// Starting point
class Rest implements RestClientBuilder {
  Rest.builder(RequestExecutor requestExecutor) {
    _client = RestClient._private(requestExecutor);
  }

  late final RestClient _client;

  @override
  RestClientBuilder addRequestConverter(RequestConverter converter) {
    _client._requestConverters[converter.runtimeType] = converter;
    return this;
  }

  @override
  RestClientBuilder addResponseConverter(ResponseConverter converter) {
    _client._responseConverters[converter.runtimeType] = converter;
    return this;
  }

  @override
  RestClientBuilder addRequestMiddleware(Middleware<RowRequest> middleware) {
    _client._requestMiddleware._addNext(middleware);
    return this;
  }

  @override
  RestClientBuilder addResponseMiddleware(Middleware<RowResponse> middleware) {
    _client._responseMiddleware._addNext(middleware);
    return this;
  }

  @override
  RestClient build() {
    // add
    _client._responseMiddleware._addNext(Middleware());
    _client._requestMiddleware._addNext(Middleware());
    return _client;
  }
}

class Middleware<R> {
  Middleware<R>? _next;

  void _addNext(Middleware<R> middleWare) {
    if (_next == null) {
      _next = middleWare;
    } else {
      _next?._addNext(middleWare);
    }
  }

  Future<R> next(R row) async {
    final next = _next;
    if (next == null) {
      return row;
    } else {
      return await onNext(row, next);
    }
  }

  @protected
  Future<R> onNext(R row, Middleware<R> nextMiddleware) async =>
      await nextMiddleware.next(row);
}

abstract class RestMethod {
  const RestMethod();
}

class RestRequest {
  RestRequest(
      {required this.method,
      required this.url,
      required this.requestConverterType,
      required this.responseConverterType,
      Map<String, String>? headers,
      this.body,
      this.encoding})
      : this.headers = {...(headers ?? {})};

  final RestMethod method;
  final String url;
  final Map<String, String> headers;
  final dynamic body;
  final Encoding? encoding;
  final Type requestConverterType;
  final Type responseConverterType;
}

class RowRequest {
  const RowRequest(this.request, this.rowBody, this.encoding);

  final RestRequest request;
  final dynamic rowBody;
  final Encoding? encoding;
}

class RestResponse {
  RestResponse(this.request, this.rowResponse, this.response);

  final RestRequest request;
  final RowResponse rowResponse;
  final dynamic response;
}

class RowResponse {
  const RowResponse(this.request, this.code, this.rowBody, this.headers, this.contentLength, this.isRedirect, this.persistentConnection, this.reasonPhrase);

  const RowResponse.undefined(RestRequest request)
      : this(request, null, null,null,null,null,null,null);

  final RestRequest request;
  final int? code;
  final Uint8List? rowBody;
  final Map<String, String>? headers;
  final int? contentLength;
  final bool? isRedirect;
  final bool? persistentConnection;
  final String? reasonPhrase;
}

abstract class RequestConverter {
  RowRequest toRow(RestRequest request);
}

abstract class ResponseConverter {
  RestResponse fromRow(RowResponse rowResponse);
}

abstract class RequestExecutor {
  Future<RowResponse> execute(RowRequest rowRequest);
}

class GenericUrlBuilder {
  late final String _base;
  late final String _url;
  final _entryStore = <UrlEntry>{};
  final _entryHandlerStore = <Type, UrlEntryHandler>{};

  GenericUrlBuilder base(String base) {
    _base = base;
    return this;
  }

  GenericUrlBuilder addUrlEntry(UrlEntry entry) {
    _entryStore.add(entry);
    return this;
  }

  GenericUrlBuilder addUrlEntryHandler(UrlEntryHandler handler) {
    _entryHandlerStore[handler.entryType] = handler;
    return this;
  }

  GenericUrlBuilder url(String url) {
    _url = url;
    return this;
  }

  @override
  String toString() {
    var url = _base + _url;
    for (var entry in _entryStore) {
      final handler = _entryHandlerStore[entry.runtimeType];
      if (handler != null) {
        url = handler.onHandle(url, entry);
      } else {
        throw '';
      }
    }
    return url;
  }
}

abstract class UrlEntryHandler<E extends UrlEntry> {
  Type get entryType;

  String onHandle(String url, E entry);
}

abstract class UrlEntry {
  String get key;
}
