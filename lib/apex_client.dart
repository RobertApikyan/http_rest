import 'dart:async';

import 'package:apex/apex_converter.dart';
import 'package:apex/apex_io.dart';
import 'package:apex/apex_middleware.dart';
import 'package:apex/apex_request_executor.dart';

/// This is the main class which wires converters, middlewares and request
/// executors together. To create an instance of [ApexClient] use the [ApexClient.builder] method
/// and provide a [RequestExecutor]'s implementation, the "apex" library ships with a
/// default implementation [DefaultRequestExecutor], you can use it or create your own
/// implementation of [RequestExecutor].
/// After calling the [ApexClient.builder] provide request/response converters and
/// middlewares.
///
/// Here is an example on how to build a [ApexClient]
/// final ApexClient client =
///       ApexClient.builder(DefaultRequestExecutor(Client()))
///           .addRequestConverter(MapToJsonRequestConverter())
///           .addResponseConverter(JsonToMapResponseConverter())
///           .addResponseMiddleware(ResponseLogger())
///           .addRequestMiddleware(RequestLogger())
///           .build();
/// ```
///
/// Library ships with the most required request/response converters such as
/// JSON to Map [JsonToMapResponseConverter] and Map to JSON [MapToJsonRequestConverter] converters
/// for more check the [apex_converter].
/// There are default logging middlewares for requests and responses which ships with
/// the library, see [RequestLogger] and [ResponseLogger].
class ApexClient {
  ApexClient._(this._requestExecutor);

  /// This method is the entry point to start create a [ApexClient],
  /// [RequestExecutor] should be provided as a parameter, which mainly executes
  /// the requests, [DefaultRequestExecutor] can be used for that which handles
  /// most of the cases for regular and multipart requests.
  /// Returns [ApexClientBuilder] which provide a methods to add middlewares and
  /// request/response converters to [ApexClient] instance.
  static ApexClientBuilder builder(RequestExecutor requestExecutor) =>
      ApexClientBuilder._(requestExecutor);

  final Map<Type, RequestConverter> _requestConverters = {};
  final Map<Type, ResponseConverter> _responseConverters = {};
  final RequestExecutor _requestExecutor;
  final Middleware<RowRequest> _requestMiddleware =
      Middleware<RowRequest>();
  final Middleware<RowResponse> _responseMiddleware =
      Middleware<RowResponse>();

  /// Use this method to execute requests,
  /// Receives a single argument of [ApexRequest], which represents the requests
  /// parameters, and returns [ApexResponse] as a result.
  /// When you are calling the [ApexClient.execute] method the ordering of the request pipeline is the following,
  ///
  /// [ApexClient.execute] -> [RequestConverter.toRow] -> [Middleware.next] -> [RequestExecutor.execute] -> [Middleware.next] -> [ResponseConverter.fromRow]
  ///
  /// Here are the descriptions of each pace in the request execution.
  /// [ApexClient.execute] starts the request.
  /// [RequestConverter.toRow] converts the [ApexRequest] to [RowRequest].
  /// [Middleware.next] this calls all the request middlewares in the chain.
  /// [RequestExecutor.execute] handle the http request and returns [RowResponse].
  /// [Middleware.next] this calls all the response middlewares in the chain.
  /// [ResponseConverter.fromRow] converts the [RowRequest] to [ApexRequest].
  /// eventually returns the result.
  Future<ApexResponse> execute(ApexRequest request) async {

    RequestConverter requestConverter = _requestConverterForType(request.requestConverterType);

    ResponseConverter responseConverter = _responseConverterForType(request.responseConverterType);

    RowRequest? rowRequest = requestConverter.toRow(request);

    rowRequest = await _requestMiddleware.next(rowRequest);

    RowResponse rowResult = await _requestExecutor.execute(rowRequest);

    rowResult = await _responseMiddleware.next(rowResult);

    ApexResponse? response = responseConverter.fromRow(rowResult);

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
class ApexClientBuilder {
  ApexClientBuilder._(RequestExecutor requestExecutor) {
    _client = ApexClient._(requestExecutor);
  }

  late final ApexClient _client;

  /// Use this method to add request converters to [ApexClient]
  ApexClientBuilder addRequestConverter(RequestConverter converter) {
    _client._requestConverters[converter.runtimeType] = converter;
    return this;
  }

  /// Use this method to add response converters to [ApexClient]
  ApexClientBuilder addResponseConverter(ResponseConverter converter) {
    _client._responseConverters[converter.runtimeType] = converter;
    return this;
  }

  /// Use this method to add request middlewares to [ApexClient]
  ApexClientBuilder addRequestMiddleware(
      Middleware<RowRequest> middleware) {
    _client._requestMiddleware.addNext(middleware);
    return this;
  }

  /// Use this method to add response middlewares to [ApexClient]
  ApexClientBuilder addResponseMiddleware(
      Middleware<RowResponse> middleware) {
    _client._responseMiddleware.addNext(middleware);
    return this;
  }

  /// Call this method at the end of the [ApexClient] configuration to get
  /// the [ApexClient]'s instance.
  ApexClient build() {
    // add
    _client._responseMiddleware.addNext(Middleware());
    _client._requestMiddleware.addNext(Middleware());
    return _client;
  }
}
