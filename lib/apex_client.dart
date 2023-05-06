import 'dart:async';

import 'package:apex/apex_converter.dart';
import 'package:apex/apex_io.dart';
import 'package:apex/apex_middleware.dart';
import 'package:apex/apex_request_executor.dart';

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
/// There are default logging middlewares for requests and responses which ships with
/// the library, see [RequestLogger] and [ResponseLogger].
class RestClient {
  RestClient._(this._restRequestExecutor);

  /// This method is the entry point to start create a [RestClient],
  /// [RestRequestExecutor] should be provided as a parameter, which mainly executes
  /// the requests, [DefaultRestRequestExecutor] can be used for that which handles
  /// most of the cases for regular and multipart requests.
  /// Returns [RestClientBuilder] which provide a methods to add middlewares and
  /// request/response converters to [RestClient] instance.
  static RestClientBuilder builder(RestRequestExecutor requestExecutor) =>
      RestClientBuilder._(requestExecutor);

  final Map<Type, RestRequestConverter> _requestConverters = {};
  final Map<Type, RestResponseConverter> _responseConverters = {};
  final RestRequestExecutor _restRequestExecutor;
  final RestMiddleware<RestRowRequest> _requestMiddleware =
      RestMiddleware<RestRowRequest>();
  final RestMiddleware<RestRowResponse> _responseMiddleware =
      RestMiddleware<RestRowResponse>();

  /// Use this method to execute requests,
  /// Receives a single argument of [RestRequest], which represents the requests
  /// parameters, and returns [RestResponse] as a result.
  /// When you are calling the [RestClient.execute] method the ordering of the request pipeline is the following,
  ///
  /// [RestClient.execute] -> [RestRequestConverter.toRow] -> [RestMiddleware.next] -> [RestRequestExecutor.execute] -> [RestMiddleware.next] -> [RestResponseConverter.fromRow]
  ///
  /// Here are the descriptions of each pace in the request execution.
  /// [RestClient.execute] starts the request.
  /// [RestRequestConverter.toRow] converts the [RestRequest] to [RestRowRequest].
  /// [RestMiddleware.next] this calls all the request middlewares in the chain.
  /// [RestRequestExecutor.execute] handle the http request and returns [RestRowResponse].
  /// [RestMiddleware.next] this calls all the response middlewares in the chain.
  /// [RestResponseConverter.fromRow] converts the [RestRowRequest] to [RestRequest].
  /// eventually returns the result.
  Future<RestResponse> execute(RestRequest restRequest) async {

    RestRequestConverter requestConverter = _requestConverterForType(restRequest.requestConverterType);

    RestResponseConverter responseConverter = _responseConverterForType(restRequest.responseConverterType);

    RestRowRequest? rowRequest = requestConverter.toRow(restRequest);

    rowRequest = await _requestMiddleware.next(rowRequest);

    RestRowResponse rowResult = await _restRequestExecutor.execute(rowRequest);

    rowResult = await _responseMiddleware.next(rowResult);

    RestResponse? response = responseConverter.fromRow(rowResult);

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

  /// Use this method to add request converters to [RestClient]
  RestClientBuilder addRequestConverter(RestRequestConverter converter) {
    _client._requestConverters[converter.runtimeType] = converter;
    return this;
  }

  /// Use this method to add response converters to [RestClient]
  RestClientBuilder addResponseConverter(RestResponseConverter converter) {
    _client._responseConverters[converter.runtimeType] = converter;
    return this;
  }

  /// Use this method to add request middlewares to [RestClient]
  RestClientBuilder addRequestMiddleware(
      RestMiddleware<RestRowRequest> middleware) {
    _client._requestMiddleware.addNext(middleware);
    return this;
  }

  /// Use this method to add response middlewares to [RestClient]
  RestClientBuilder addResponseMiddleware(
      RestMiddleware<RestRowResponse> middleware) {
    _client._responseMiddleware.addNext(middleware);
    return this;
  }

  /// Call this method at the end of the [RestClient] configuration to get
  /// the [RestClient]'s instance.
  RestClient build() {
    // add
    _client._responseMiddleware.addNext(RestMiddleware());
    _client._requestMiddleware.addNext(RestMiddleware());
    return _client;
  }
}
