import 'dart:async';

import 'package:http_rest/http_rest.dart';

/// The `HttpRestClient ` class acts as the central hub, coordinating the flow of
/// requests and responses, and allowing for extensibility and customization at
/// various stages through request and response converters, middlewares, and the
/// RequestExecutor class.
///
/// When a request is made through the HttpRestClient, the following steps occur:
///
/// Request Conversion: The request object is passed through the request converter,
/// which transforms it into the appropriate format for sending over the network.
/// This ensures compatibility with the API endpoint and handles any necessary data conversions.
///
/// Request Middlewares: The converted request then goes through a chain of request middlewares.
/// These middlewares allow you to inject custom logic before the request is sent.
/// Examples of request middleware functionalities include authentication, adding headers,
/// or modifying the request payload.
///
/// Request Execution: The processed request is passed to the RequestExecutor class,
/// which handles the actual execution of the HTTP request. The RequestExecutor interacts with the network layer,
/// communicates with the API endpoint, and receives the raw response.
///
/// Response Middlewares: The response received from the RequestExecutor is then
/// passed through a chain of response middlewares. These middlewares enable you to
/// manipulate and process the response before it is returned to the caller.
/// Common use cases for response middlewares include parsing response data,
/// error handling, or logging.
///
/// Response Conversion: After going through the response middlewares, the response
/// is passed to the response converter. The response converter transforms the raw
/// response into a structured format that aligns with your application's needs.
/// This conversion step ensures that the response is in a format that can be easily
/// consumed and understood by your code.
///
/// Result Return: Finally, the converted response is returned as the result of the
/// original request made through the HttpRestClient. The caller receives the processed
/// response, which can be further processed or used to update the application's state.
///
/// To create an instance of [HttpRestClient] use the [HttpRestClient.builder] method
/// and provide a [RequestExecutor]'s implementation, the "HttpRest" library ships with a
/// default implementation [DefaultRequestExecutor], you can use it or create your own
/// implementation of [RequestExecutor].
/// After calling the [HttpRestClient.builder] provide request/response converters and
/// middlewares.
///
/// Here is an example on how to build a [HttpRestClient]
///
/// ```dart
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

  final Middleware<HttpRestRequest> _requestOverrideMiddleware =
  Middleware<HttpRestRequest>();
  final Map<Type, RequestConverter> _requestConverters = {};
  final Map<Type, ResponseConverter> _responseConverters = {};
  final RequestExecutor _requestExecutor;
  final Middleware<RowRequest> _requestMiddleware = Middleware<RowRequest>();
  final Middleware<RowResponse> _responseMiddleware = Middleware<RowResponse>();

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

    request = await _requestOverrideMiddleware.next(request);

    RequestConverter requestConverter =
        _requestConverterForType(request.requestConverterType);

    ResponseConverter responseConverter =
        _responseConverterForType(request.responseConverterType);

    RowRequest? rowRequest = requestConverter.toRow(request);

    rowRequest = await _requestMiddleware.next(rowRequest);

    RowResponse rowResult = await _requestExecutor.execute(rowRequest);

    rowResult = await _responseMiddleware.next(rowResult);

    HttpRestResponse? response = responseConverter.fromRow(rowResult);

    return response;
  }

  RequestConverter _requestConverterForType(Type? converterType) {
    if (converterType == null) {
      return RequestConverter.empty();
    }
    RequestConverter? converter = _requestConverters[converterType];
    if (converter != null) {
      return converter;
    } else {
      throw Exception(
          'RequestConverter is not specified in the [$runtimeType] client for type $converterType');
    }
  }

  ResponseConverter _responseConverterForType(Type? converterType) {
    if (converterType == null) {
      return ResponseConverter.empty();
    }
    ResponseConverter? converter = _responseConverters[converterType];
    if (converter != null) {
      return converter;
    } else {
      throw Exception(
          'ResponseConverter is not specified in the [$runtimeType] client for type $converterType');
    }
  }
}

/// This class allows to config and build a [HttpRestClient].
/// Use [HttpRestClient.builder] method to build a client, [HttpRestClientBuilder] allows to
/// add multiple request and response [Middleware]s, [RequestConverter]s, [ResponseConverter]s, also
/// configure the client with a custom [RequestExecutor].
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

  /// Use this method to add request override middlewares to [HttpRestClient],
  /// Will override stream each request through provided middleware before passing it
  /// to requrest converter (@see [addRequestConverter])
  HttpRestClientBuilder addRequestOverrideMiddleware(
      Middleware<HttpRestRequest> middleware) {
    _client._requestOverrideMiddleware.addNext(middleware);
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
    // Add the tail middlewares.
    _client._requestOverrideMiddleware.addNext(Middleware());
    _client._responseMiddleware.addNext(Middleware());
    _client._requestMiddleware.addNext(Middleware());
    return _client;
  }
}
