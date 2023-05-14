import 'dart:async';

import 'package:http_rest/http_rest_converter.dart';
import 'package:http_rest/http_rest_io.dart';
import 'package:http_rest/http_rest_middleware.dart';
import 'package:http_rest/http_rest_request_executor.dart';

/// This is the main class which wires converters, middlewares and request
/// executors together. To create an instance of [HttpRestClient] use the [HttpRestClient.builder] method
/// and provide a [RequestExecutor]'s implementation, the "HttpRest" library ships with a
/// default implementation [DefaultRequestExecutor], you can use it or create your own
/// implementation of [RequestExecutor].
/// After calling the [HttpRestClient.builder] provide request/response converters and
/// middlewares.
///
/// Here is an example on how to build a [HttpRestClient]
/// final HttpRestClient client =
///       HttpRestClient.builder(DefaultRequestExecutor(Client()))
///           .addRequestConverter(MapToJsonRequestConverter())
///           .addResponseConverter(JsonToMapResponseConverter())
///           .addResponseMiddleware(ResponseLogger())
///           .addRequestMiddleware(RequestLogger())
///           .build();
/// ```
///
/// Library ships with the most required request/response converters such as
/// JSON to Map [JsonToMapResponseConverter] and Map to JSON [MapToJsonRequestConverter] converters
/// for more check the [HttpRest_converter].
/// There are default logging middlewares for requests and responses which ships with
/// the library, see [RequestLogger] and [ResponseLogger].
class HttpRestClient {
  HttpRestClient._(this._requestExecutor);

  /// This method is the entry point to start create a [HttpRestClient],
  /// [RequestExecutor] should be provided as a parameter, which mainly executes
  /// the requests, [DefaultRequestExecutor] can be used for that which handles
  /// most of the cases for regular and multipart requests.
  /// Returns [HttpRestClientBuilder] which provide a methods to add middlewares and
  /// request/response converters to [HttpRestClient] instance.
  static HttpRestClientBuilder builder(RequestExecutor requestExecutor) =>
      HttpRestClientBuilder._(requestExecutor);

  final Map<Type, RequestConverter> _requestConverters = {};
  final Map<Type, ResponseConverter> _responseConverters = {};
  final RequestExecutor _requestExecutor;
  final Middleware<RowRequest> _requestMiddleware =
      Middleware<RowRequest>();
  final Middleware<RowResponse> _responseMiddleware =
      Middleware<RowResponse>();

  /// Use this method to execute requests,
  /// Receives a single argument of [HttpRestRequest], which represents the requests
  /// parameters, and returns [HttpRestResponse] as a result.
  /// When you are calling the [HttpRestClient.execute] method the ordering of the request pipeline is the following,
  ///
  /// [HttpRestClient.execute] -> [RequestConverter.toRow] -> [Middleware.next] -> [RequestExecutor.execute] -> [Middleware.next] -> [ResponseConverter.fromRow]
  ///
  /// Here are the descriptions of each pace in the request execution.
  /// [HttpRestClient.execute] starts the request.
  /// [RequestConverter.toRow] converts the [HttpRestRequest] to [RowRequest].
  /// [Middleware.next] this calls all the request middlewares in the chain.
  /// [RequestExecutor.execute] handle the http request and returns [RowResponse].
  /// [Middleware.next] this calls all the response middlewares in the chain.
  /// [ResponseConverter.fromRow] converts the [RowRequest] to [HttpRestRequest].
  /// eventually returns the result.
  Future<HttpRestResponse> execute(HttpRestRequest request) async {

    RequestConverter requestConverter = _requestConverterForType(request.requestConverterType);

    ResponseConverter responseConverter = _responseConverterForType(request.responseConverterType);

    RowRequest? rowRequest = requestConverter.toRow(request);

    rowRequest = await _requestMiddleware.next(rowRequest);

    RowResponse rowResult = await _requestExecutor.execute(rowRequest);

    rowResult = await _responseMiddleware.next(rowResult);

    HttpRestResponse? response = responseConverter.fromRow(rowResult);

    return response;
  }

  RequestConverter _requestConverterForType(Type? converterType) {
    if(converterType == null){
      return RequestConverter.empty();
    }
    RequestConverter? converter = _requestConverters[converterType];
    if (converter != null) {
      return converter;
    } else {
      throw Exception(
          'RequestConverter is not specified in the client for type $converterType');
    }
  }

  ResponseConverter _responseConverterForType(Type? converterType) {
    if(converterType == null){
      return ResponseConverter.empty();
    }
    ResponseConverter? converter = _responseConverters[converterType];
    if (converter != null) {
      return converter;
    } else {
      throw Exception(
          'ResponseConverter is not specified in the client for type $converterType');
    }
  }
}

// Starting point
class HttpRestClientBuilder {
  HttpRestClientBuilder._(RequestExecutor requestExecutor) {
    _client = HttpRestClient._(requestExecutor);
  }

  late final HttpRestClient _client;

  /// Use this method to add request converters to [HttpRestClient]
  HttpRestClientBuilder addRequestConverter(RequestConverter converter) {
    _client._requestConverters[converter.runtimeType] = converter;
    return this;
  }

  /// Use this method to add response converters to [HttpRestClient]
  HttpRestClientBuilder addResponseConverter(ResponseConverter converter) {
    _client._responseConverters[converter.runtimeType] = converter;
    return this;
  }

  /// Use this method to add request middlewares to [HttpRestClient]
  HttpRestClientBuilder addRequestMiddleware(
      Middleware<RowRequest> middleware) {
    _client._requestMiddleware.addNext(middleware);
    return this;
  }

  /// Use this method to add response middlewares to [HttpRestClient]
  HttpRestClientBuilder addResponseMiddleware(
      Middleware<RowResponse> middleware) {
    _client._responseMiddleware.addNext(middleware);
    return this;
  }

  /// Call this method at the end of the [HttpRestClient] configuration to get
  /// the [HttpRestClient]'s instance.
  HttpRestClient build() {
    // add
    _client._responseMiddleware.addNext(Middleware());
    _client._requestMiddleware.addNext(Middleware());
    return _client;
  }
}
