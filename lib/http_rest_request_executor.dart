// / Implements RequestExecutor using dart's http library
import 'dart:async';
import 'dart:io';

import 'package:http_rest/http_rest.dart';
import 'package:http/http.dart';

/// This abstract class is the main handler for http calls.
/// Derive from this class and implement the [execute] method, which receives
/// the [RowRequest] as an argument and returns [RowResponse] as a result.
/// The actual http call should happen in the [execute] method's body.
/// To create a [HttpRestClient] instance, first and foremost you will need to provide an implementation of
/// [RequestExecutor] to [HttpRestClient.builder] as shown in the example below.
/// ```dart
/// final HttpRestClient client =
///       HttpRestClient.builder(DefaultRequestExecutor(Client()))
///           .addRequestConverter(MapToJsonRequestConverter())
///           .addResponseConverter(JsonToMapResponseConverter())
///           .addResponseMiddleware(ResponseLogger())
///           .addRequestMiddleware(RequestLogger())
///           .build();
/// ```
abstract class RequestExecutor {
  /// Override this method and implement http call by using the parameters from
  /// the [rowRequest].
  Future<RowResponse> execute(RowRequest rowRequest);
}

/// This class is a default implementation of the [RequestExecutor], and uses
/// [Client] from the "http" library (link:https://pub.dev/packages/http) for request execution.
/// [DefaultRequestExecutor] supports regular Rest method requests and as well as multipart
/// requests, see [MultipartRequestBody] for multipart request example.
class DefaultRequestExecutor extends RequestExecutor {
  /// Any [Client] implementation from the "http" library (link:https://pub.dev/packages/http).
  /// [timeOutDuration] configures the request's result wait duration, if request will
  /// rich the [timeOutDuration] the [SocketException] will be thrown.
  DefaultRequestExecutor(this.client,
      {this.timeOutDuration = const Duration(minutes: 5)});

  final Client client;

  final Duration timeOutDuration;

  Future<Response> _onTimeOut() async {
    throw const SocketException('SocketException');
  }

  Future<Response> _withTimeOut(Future<Response> response) =>
      response.timeout(timeOutDuration, onTimeout: _onTimeOut);

  @override
  Future<RowResponse> execute(RowRequest rowRequest) async {
    Response? response;
    Uri uri = Uri.parse(rowRequest.request.url);

    final request = rowRequest.request;

    if (request.body is MultipartRequestBody) {
      final multipartRequestBody = request.body as MultipartRequestBody;

      final multipartRequest = _ProgressedMultipartRequest(
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
        case Methods.get:
          response = await _withTimeOut(
              client.get(uri, headers: rowRequest.request.headers));
          break;
        case Methods.head:
          response = await _withTimeOut(
              client.head(uri, headers: rowRequest.request.headers));
          break;
        case Methods.post:
          response = await _withTimeOut(client.post(uri,
              headers: rowRequest.request.headers,
              body: rowRequest.rowBody,
              encoding: request.encoding));
          break;
        case Methods.put:
          response = await _withTimeOut(client.put(uri,
              headers: rowRequest.request.headers,
              body: rowRequest.rowBody,
              encoding: request.encoding));
          break;
        case Methods.delete:
          response = await _withTimeOut(client._deleteWithBody(uri,
              headers: rowRequest.request.headers,
              body: (rowRequest.request.body ?? "") as String));
          break;
        case Methods.patch:
          response = await _withTimeOut(client.patch(uri,
              headers: rowRequest.request.headers,
              body: rowRequest.rowBody,
              encoding: request.encoding));
          break;
      }
    }

    RowResponse rowResponse = _fromHttpResponse(response, rowRequest.request);

    return rowResponse;
  }

  RowResponse _fromHttpResponse(Response? response, HttpRestRequest request) {
    if (response != null) {
      return RowResponse(
          request,
          response.statusCode,
          response.bodyBytes,
          response.headers,
          response.contentLength,
          response.isRedirect,
          response.persistentConnection,
          response.reasonPhrase);
    } else {
      return RowResponse.undefined(request);
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

class _ProgressedMultipartRequest extends MultipartRequest {
  /// Creates a new [_ProgressedMultipartRequest].
  _ProgressedMultipartRequest(
    String method,
    Uri url, {
    required this.onProgress,
  }) : super(method, url);

  late final void Function(int bytes, int totalBytes)? onProgress;

  /// Freezes all mutable fields and returns a single-subscription [ByteStream]
  /// that will emit the request body.
  @override
  ByteStream finalize() {
    final byteStream = super.finalize();
    final onProgress = this.onProgress;
    if (onProgress == null) {
      return byteStream;
    }

    final total = contentLength;
    int bytes = 0;

    final t = StreamTransformer.fromHandlers(
      handleData: (List<int> data, EventSink<List<int>> sink) {
        bytes += data.length;
        onProgress(bytes, total);
        sink.add(data);
      },
    );

    final stream = byteStream.transform(t);
    return ByteStream(stream);
  }
}
