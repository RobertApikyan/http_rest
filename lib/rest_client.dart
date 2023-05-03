import 'dart:async';

import 'package:rest/rest_converter.dart';
import 'package:rest/rest_io.dart';
import 'package:rest/rest_middleware.dart';
import 'package:rest/rest_request_executor.dart';

/// This is the main class which wires converters, middlewares and request
/// executors together. To create an instance of [RestClient] use the [RestClient.builder] method
/// and provide a [RestRequestExecutor]'s implementation, the "rest" library ships with a
/// default implementation [DefaultRestRequestExecutor], you can use it or create your own
/// implementation of [RestRequestExecutor].
/// After calling the [RestClient.builder] provide request/response converters and
/// middlewares.
///
/// Here is an example on how to build a [RestClient]
/// final RestClient client =
///       RestClient.builder(DefaultRestRequestExecutor(Client()))
///           .addRequestConverter(MapToJsonRequestConverter())
///           .addResponseConverter(JsonToMapResponseConverter())
///           .addResponseMiddleware(ResponseLogger())
///           .addRequestMiddleware(RequestLogger())
///           .build();
/// ```
///
/// Library ships with the most required request/response converters such as
/// JSON to Map [JsonToMapResponseConverter] and Map to JSON [MapToJsonRequestConverter] converters
/// for more check the [rest_converter].
/// There are default logging middlewares for requests and responses,
/// see [RequestLogger] and [ResponseLogger] ... TODO CONTINUE
class RestClient {
  RestClient._(this._restRequestExecutor);

  static RestClientBuilder builder(RestRequestExecutor requestExecutor) =>
      RestClientBuilder._(requestExecutor);

  final Map<Type, RestRequestConverter> _requestConverters = {};
  final Map<Type, RestResponseConverter> _responseConverters = {};
  final RestRequestExecutor _restRequestExecutor;
  final RestMiddleware<RestRowRequest> _requestMiddleware =
      RestMiddleware<RestRowRequest>();
  final RestMiddleware<RestRowResponse> _responseMiddleware =
      RestMiddleware<RestRowResponse>();

  Future<RestResponse> execute(RestRequest restRequest) async {

    RestRequestConverter requestConverters = _requestConverterForType(restRequest.requestConverterType);

    RestResponseConverter responseConverters = _responseConverterForType(restRequest.responseConverterType);

    RestRowRequest? rowRequest = requestConverters.toRow(restRequest);

    rowRequest = await _requestMiddleware.next(rowRequest);

    RestRowResponse rowResult = await _restRequestExecutor.execute(rowRequest);

    rowResult = await _responseMiddleware.next(rowResult);

    RestResponse? response = responseConverters.fromRow(rowResult);

    return response;
  }

  RestRequestConverter _requestConverterForType(Type? converterType) {
    if(converterType == null){
      return RestRequestConverter.empty();
    }
    RestRequestConverter? converter = _requestConverters[converterType];
    if (converter != null) {
      return converter;
    } else {
      throw Exception(
          'RequestConverter is not specified in the client for type $converterType');
    }
  }

  RestResponseConverter _responseConverterForType(Type? converterType) {
    if(converterType == null){
      return RestResponseConverter.empty();
    }
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
