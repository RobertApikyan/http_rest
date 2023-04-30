// / Implements RequestExecutor using dart's http library
import 'dart:io';

import 'package:http/http.dart';
import 'package:rest/reset_multipart_request.dart';
import 'package:rest/rest_io.dart';
import 'package:rest/rest_method.dart';

abstract class RestRequestExecutor {
  Future<RestRowResponse> execute(RestRowRequest rowRequest);
}

class DefaultRestRequestExecutor extends RestRequestExecutor {
  DefaultRestRequestExecutor(this.client,
      {this.timeOutDuration = const Duration(minutes: 5)});

  final Client client;

  final Duration timeOutDuration;

  Future<Response> onTimeOut() async {
    throw const SocketException('SocketException');
  }

  Future<Response> withTimeOut(Future<Response> response) =>
      response.timeout(timeOutDuration, onTimeout: onTimeOut);

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

      response = await withTimeOut(multipartRequest
          .send()
          .then((streamResponse) => Response.fromStream(streamResponse)));
    } else {
      switch (request.method) {
        case RestMethods.get:
          response = await withTimeOut(
              client.get(uri, headers: rowRequest.request.headers));
          break;
        case RestMethods.head:
          response = await withTimeOut(
              client.head(uri, headers: rowRequest.request.headers));
          break;
        case RestMethods.post:
          response = await withTimeOut(client.post(uri,
              headers: rowRequest.request.headers,
              body: rowRequest.rowBody,
              encoding: request.encoding));
          break;
        case RestMethods.put:
          response = await withTimeOut(client.put(uri,
              headers: rowRequest.request.headers,
              body: rowRequest.rowBody,
              encoding: request.encoding));
          break;
        case RestMethods.delete:
          response = await withTimeOut(client.patch(uri,
              headers: rowRequest.request.headers,
              body: rowRequest.rowBody,
              encoding: request.encoding));
          break;
        case RestMethods.patch:
          response = await withTimeOut(client._deleteWithBody(uri,
              headers: rowRequest.request.headers,
              body: rowRequest.request.body as String));
          break;
      }
    }

    RestRowResponse rowResponse =
        fromHttpResponse(response, rowRequest.request);

    return rowResponse;
  }

  RestRowResponse fromHttpResponse(Response? response, RestRequest request) {
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
