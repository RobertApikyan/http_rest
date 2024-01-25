// / Implements RequestExecutor using dart's http library
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:http_rest/http_rest.dart';

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
          response = await _withTimeOut(client._get(uri,
              headers: rowRequest.request.headers,
              readProgressListener: request.readProgressListener,
              writeProgressListener: request.writeProgressListener,
              uploadChunkSize: request.writeChunkSize));
          break;
        case Methods.head:
          response = await _withTimeOut(client._head(uri,
              headers: rowRequest.request.headers,
              readProgressListener: request.readProgressListener,
              writeProgressListener: request.writeProgressListener,
              uploadChunkSize: request.writeChunkSize));
          break;
        case Methods.post:
          response = await _withTimeOut(client._post(uri,
              headers: rowRequest.request.headers,
              body: rowRequest.rowBody,
              encoding: request.encoding,
              readProgressListener: request.readProgressListener,
              writeProgressListener: request.writeProgressListener,
              uploadChunkSize: request.writeChunkSize));
          break;
        case Methods.put:
          response = await _withTimeOut(client._put(uri,
              headers: rowRequest.request.headers,
              body: rowRequest.rowBody,
              encoding: request.encoding,
              readProgressListener: request.readProgressListener,
              writeProgressListener: request.writeProgressListener,
              uploadChunkSize: request.writeChunkSize));
          break;
        case Methods.delete:
          response = await _withTimeOut(client._delete(uri,
              headers: rowRequest.request.headers,
              body: (rowRequest.rowBody ?? "") as String,
              readProgressListener: request.readProgressListener,
              writeProgressListener: request.writeProgressListener,
              uploadChunkSize: request.writeChunkSize));
          break;
        case Methods.patch:
          response = await _withTimeOut(client._patch(uri,
              headers: rowRequest.request.headers,
              body: rowRequest.rowBody,
              encoding: request.encoding,
              readProgressListener: request.readProgressListener,
              writeProgressListener: request.writeProgressListener,
              uploadChunkSize: request.writeChunkSize));
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
  Future<Response> _delete(Uri url,
      {Map<String, String>? headers,
        Object? body,
        Encoding? encoding,
        HttpRequestProgressListener? readProgressListener,
        HttpRequestProgressListener? writeProgressListener,
        int? uploadChunkSize}) =>
      _send(
          method: 'DELETE',
          url: url,
          headers: headers,
          body: body,
          encoding: encoding,
          readProgressListener: readProgressListener,
          writeProgressListener: writeProgressListener,
          uploadChunkSize: uploadChunkSize);

  Future<Response> _head(
      Uri url, {
        Map<String, String>? headers,
        HttpRequestProgressListener? readProgressListener,
        HttpRequestProgressListener? writeProgressListener,
        int? uploadChunkSize,
      }) =>
      _send(
          method: 'HEAD',
          url: url,
          headers: headers,
          readProgressListener: readProgressListener,
          writeProgressListener: writeProgressListener,
          uploadChunkSize: uploadChunkSize);

  Future<Response> _get(
      Uri url, {
        Map<String, String>? headers,
        HttpRequestProgressListener? readProgressListener,
        HttpRequestProgressListener? writeProgressListener,
        int? uploadChunkSize,
      }) =>
      _send(
        method: 'GET',
        url: url,
        headers: headers,
        readProgressListener: readProgressListener,
        writeProgressListener: writeProgressListener,
        uploadChunkSize: uploadChunkSize,
      );

  Future<Response> _post(
      Uri url, {
        Map<String, String>? headers,
        Object? body,
        Encoding? encoding,
        HttpRequestProgressListener? readProgressListener,
        HttpRequestProgressListener? writeProgressListener,
        int? uploadChunkSize,
      }) =>
      _send(
        method: 'POST',
        url: url,
        headers: headers,
        body: body,
        encoding: encoding,
        readProgressListener: readProgressListener,
        writeProgressListener: writeProgressListener,
        uploadChunkSize: uploadChunkSize,
      );

  Future<Response> _put(
      Uri url, {
        Map<String, String>? headers,
        Object? body,
        Encoding? encoding,
        HttpRequestProgressListener? readProgressListener,
        HttpRequestProgressListener? writeProgressListener,
        int? uploadChunkSize,
      }) =>
      _send(
        method: 'PUT',
        url: url,
        headers: headers,
        body: body,
        encoding: encoding,
        readProgressListener: readProgressListener,
        writeProgressListener: writeProgressListener,
        uploadChunkSize: uploadChunkSize,
      );

  Future<Response> _patch(
      Uri url, {
        Map<String, String>? headers,
        Object? body,
        Encoding? encoding,
        HttpRequestProgressListener? readProgressListener,
        HttpRequestProgressListener? writeProgressListener,
        int? uploadChunkSize,
      }) =>
      _send(
        method: 'PATCH',
        url: url,
        headers: headers,
        body: body,
        encoding: encoding,
        readProgressListener: readProgressListener,
        writeProgressListener: writeProgressListener,
        uploadChunkSize: uploadChunkSize,
      );

  /// Sends a streaming [Request] and returns a non-streaming [Response].
  Future<Response> _send({
    required String method,
    required Uri url,
    required Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    HttpRequestProgressListener? readProgressListener,
    HttpRequestProgressListener? writeProgressListener,
    int? uploadChunkSize,
  }) async {
    var request = _HttpRestRequest(method, url,
        onProgress: writeProgressListener, chunkSize: uploadChunkSize);

    if (headers != null) request.headers.addAll(headers);
    if (encoding != null) request.encoding = encoding;
    if (body != null) {
      if (body is String) {
        request.body = body;
      } else if (body is List) {
        request.bodyBytes = body.cast<int>();
      } else if (body is Map) {
        request.bodyFields = body.cast<String, String>();
      } else {
        throw ArgumentError('Invalid request body "$body".');
      }
    }
    final streamResponse = await send(request);
    return _trackResponse(streamResponse, readProgressListener);
  }
}

Future<Response> _trackResponse(StreamedResponse streamResponse,
    HttpRequestProgressListener? progressListener) async {
  if (progressListener == null) {
    return Response.fromStream(streamResponse);
  }
  final totalBytes = streamResponse.contentLength ?? 0;
  int receivedBytes = 0;
  var completer = Completer<Uint8List>();
  var sink = ByteConversionSink.withCallback(
          (bytes) => completer.complete(Uint8List.fromList(bytes)));
  streamResponse.stream.listen((value) {
    receivedBytes += value.length;
    progressListener.call(receivedBytes, totalBytes);
    sink.add(value);
  }, onError: completer.completeError, onDone: sink.close, cancelOnError: true);
  final body = await completer.future;
  return Future<Response>(() => Response.bytes(body, streamResponse.statusCode,
      request: streamResponse.request,
      headers: streamResponse.headers,
      isRedirect: streamResponse.isRedirect,
      persistentConnection: streamResponse.persistentConnection,
      reasonPhrase: streamResponse.reasonPhrase));
}

class _HttpRestRequest extends Request {
  /// Creates a new [_HttpRestRequest].
  _HttpRestRequest(String method, Uri url,
      {required this.onProgress, required this.chunkSize})
      : super(method, url);

  final HttpRequestProgressListener? onProgress;
  final int? chunkSize;

  /// Freezes all mutable fields and returns a single-subscription [ByteStream]
  /// that will emit the request body.
  @override
  ByteStream finalize() {
    final byteStream = super.finalize();
    final onProgress = this.onProgress;
    final chunkSize = this.chunkSize;
    if (onProgress == null || chunkSize == null || chunkSize <= 0) {
      return byteStream;
    }

    final total = contentLength;
    int bytes = 0;

    final chunkTr = StreamTransformer.fromHandlers(
      handleData: (List<int> list, EventSink<List<int>> sink) {
        for (int i = 0; i < list.length; i += chunkSize) {
          int end = (i + chunkSize < list.length) ? i + chunkSize : list.length;
          sink.add(list.sublist(i, end));
        }
      },
    );

    final stream = byteStream.transform(chunkTr);

    final progressTr = StreamTransformer.fromHandlers(
      handleData: (List<int> data, EventSink<List<int>> sink) {
        bytes += data.length;
        onProgress(bytes, total);
        sink.add(data);
      },
    );

    return ByteStream(stream.transform(progressTr));
  }
}

class _ProgressedMultipartRequest extends MultipartRequest {
  /// Creates a new [_ProgressedMultipartRequest].
  _ProgressedMultipartRequest(
      String method,
      Uri url, {
        required this.onProgress,
      }) : super(method, url);

  final HttpRequestProgressListener? onProgress;

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
