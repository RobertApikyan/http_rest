// / Implements RequestExecutor using dart's http library
import 'dart:io';

import 'package:http/http.dart';
import 'package:rest/reset_multipart_request.dart';
import 'package:rest/rest_client.dart';
import 'package:rest/rest_io.dart';
import 'package:rest/rest_method.dart';

/// This abstract class is the main handler for http calls.
/// Derive from this class and implement the [execute] method, which receives
/// the [RestRowRequest] as an argument and returns [RestRowResponse] as a result.
/// The actual http call should happen in the [execute] method's body.
/// To create a [RestClient] instance, first and foremost you will need to provide an implementation of
/// [RestRequestExecutor] to [RestClient.builder] as shown in the example below.
/// ```dart
/// final RestClient client =
///       RestClient.builder(DefaultRestRequestExecutor(Client()))
///           .addRequestConverter(MapToJsonRequestConverter())
///           .addResponseConverter(JsonToMapResponseConverter())
///           .addResponseMiddleware(ResponseLogger())
///           .addRequestMiddleware(RequestLogger())
///           .build();
/// ```
abstract class RestRequestExecutor {
  /// Override this method and implement http call by using the parameters from
  /// the [rowRequest].
  Future<RestRowResponse> execute(RestRowRequest rowRequest);
}

/// This class is a default implementation of the [RestRequestExecutor], and uses
/// [Client] from the "http" library (link:https://pub.dev/packages/http) for request execution.
/// [DefaultRestRequestExecutor] supports regular Rest method requests and as well as multipart
/// requests, see [MultipartRestRequestBody] for multipart request example.
class DefaultRestRequestExecutor extends RestRequestExecutor {
  /// Any [Client] implementation from the "http" library (link:https://pub.dev/packages/http).
  /// [timeOutDuration] configures the request's result wait duration, if request will
  /// rich the [timeOutDuration] the [SocketException] will be thrown.
  DefaultRestRequestExecutor(this.client,
      {this.timeOutDuration = const Duration(minutes: 5)});

  final Client client;

  final Duration timeOutDuration;

  Future<Response> _onTimeOut() async {
    throw const SocketException('SocketException');
  }

  Future<Response> _withTimeOut(Future<Response> response) =>
      response.timeout(timeOutDuration, onTimeout: _onTimeOut);

  @override
  Future<RestRowResponse> execute(RestRowRequest rowRequest) async {
    Response? response;
    Uri uri = Uri.parse(rowRequest.request.url);

    final request = rowRequest.request;

    if (request.body is MultipartRestRequestBody) {
      final multipartRequestBody = request.body as MultipartRestRequestBody;

      final multipartRequest = ProgressedMultipartRequest(
          request.method.name, uri,
          onProgress: multipartRequestBody.progressListener);

      multipartRequest.fields.addAll(multipartRequestBody.fields);
      multipartRequest.files.addAll(multipartRequestBody.files);

      final requestHeaders = request.headers;
      multipartRequest.headers.addAll(requestHeaders);

      response = await _withTimeOut(multipartRequest
          .send()
          .then((streamResponse) => Response.fromStream(streamResponse)));
    } else {
      switch (request.method) {
        case RestMethods.get:
          response = await _withTimeOut(
              client.get(uri, headers: rowRequest.request.headers));
          break;
        case RestMethods.head:
          response = await _withTimeOut(
              client.head(uri, headers: rowRequest.request.headers));
          break;
        case RestMethods.post:
          response = await _withTimeOut(client.post(uri,
              headers: rowRequest.request.headers,
              body: rowRequest.rowBody,
              encoding: request.encoding));
          break;
        case RestMethods.put:
          response = await _withTimeOut(client.put(uri,
              headers: rowRequest.request.headers,
              body: rowRequest.rowBody,
              encoding: request.encoding));
          break;
        case RestMethods.delete:
          response = await _withTimeOut(client._deleteWithBody(uri,
              headers: rowRequest.request.headers,
              body: (rowRequest.request.body ?? "") as String));
          break;
        case RestMethods.patch:
          response = await _withTimeOut(client.patch(uri,
              headers: rowRequest.request.headers,
              body: rowRequest.rowBody,
              encoding: request.encoding));
          break;
      }
    }

    RestRowResponse rowResponse =
        _fromHttpResponse(response, rowRequest.request);

    return rowResponse;
  }

  RestRowResponse _fromHttpResponse(Response? response, RestRequest request) {
    if (response != null) {
      return RestRowResponse(
          request,
          response.statusCode,
          response.bodyBytes,
          response.headers,
          response.contentLength,
          response.isRedirect,
          response.persistentConnection,
          response.reasonPhrase);
    } else {
      return RestRowResponse.undefined(request);
    }
  }
}

extension _ClientExtentions on Client {
  Future<Response> _deleteWithBody(
    Object url, {
    required String body,
    Map<String, String>? headers,
  }) async {
    final uri = url is String ? Uri.parse(url) : url as Uri;
    final request = Request('DELETE', uri);

    if (headers != null) {
      request.headers.addAll(headers);
    }
    request.body = body;

    return Response.fromStream(await send(request));
  }
}
