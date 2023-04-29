import 'dart:async';
import 'package:rest/rest_converter.dart';
import 'package:rest/rest_io.dart';
import 'package:rest/rest_middleware.dart';
import 'package:rest/rest_request_executor.dart';

class RestClient {
  RestClient._(this._rowRequestExecutor);

  static RestClientBuilder builder(RestRequestExecutor requestExecutor) =>
      RestClientBuilder._(requestExecutor);

  final Map<Type, RestRequestConverter> _requestConverters = {};
  final Map<Type, RestResponseConverter> _responseConverters = {};
  final RestRequestExecutor _rowRequestExecutor;
  final RestMiddleware<RestRowRequest> _requestMiddleware =
      RestMiddleware<RestRowRequest>();
  final RestMiddleware<RestRowResponse> _responseMiddleware =
      RestMiddleware<RestRowResponse>();

  Future<RestResponse> execute(RestRequest restRequest) async {
    List<RestRequestConverter> requestConverters = restRequest
        .requestConverterTypes
        .map((converterType) => _requestConverterForType(converterType))
        .toList();

    List<RestResponseConverter> responseConverters = restRequest
        .responseConverterTypes
        .map((converterType) => _responseConverterForType(converterType))
        .toList();

    RestRowRequest? rowRequest;
    for (final requestConverter in requestConverters) {
      rowRequest = requestConverter.toRow(restRequest);
    }

    rowRequest = await _requestMiddleware.next(rowRequest!);

    RestRowResponse rowResult = await _rowRequestExecutor.execute(rowRequest);

    rowResult = await _responseMiddleware.next(rowResult);

    RestResponse? response;
    for(final responseConverter in responseConverters) {
      response = responseConverter.fromRow(rowResult);
    }

    return response!;
  }

  RestRequestConverter _requestConverterForType(Type converterType) {
    RestRequestConverter? converter = _requestConverters[converterType];
    if (converter != null) {
      return converter;
    } else {
      throw Exception(
          'RequestConverter is not specified in the client for type $converterType');
    }
  }

  RestResponseConverter _responseConverterForType(Type converterType) {
    RestResponseConverter? converter = _responseConverters[converterType];
    if (converter != null) {
      return converter;
    } else {
      throw Exception(
          'ResponseConverter is not specified in the client for type $converterType');
    }
  }
}

// Starting point
class RestClientBuilder {
  RestClientBuilder._(RestRequestExecutor requestExecutor) {
    _client = RestClient._(requestExecutor);
  }

  late final RestClient _client;

  RestClientBuilder addRequestConverter(RestRequestConverter converter) {
    _client._requestConverters[converter.runtimeType] = converter;
    return this;
  }

  RestClientBuilder addResponseConverter(RestResponseConverter converter) {
    _client._responseConverters[converter.runtimeType] = converter;
    return this;
  }

  RestClientBuilder addRequestMiddleware(
      RestMiddleware<RestRowRequest> middleware) {
    _client._requestMiddleware.addNext(middleware);
    return this;
  }

  RestClientBuilder addResponseMiddleware(
      RestMiddleware<RestRowResponse> middleware) {
    _client._responseMiddleware.addNext(middleware);
    return this;
  }

  RestClient build() {
    // add
    _client._responseMiddleware.addNext(RestMiddleware());
    _client._requestMiddleware.addNext(RestMiddleware());
    return _client;
  }
}
