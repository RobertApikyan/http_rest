import 'dart:async';
import 'dart:convert' as converter;
import 'dart:io';

import 'package:http/http.dart';

import 'rest_abstract.dart';

/// PATH, QUERY
abstract class CommonEntry extends UrlEntry {
  CommonEntry(this.name, this.value);

  final String name;
  final String value;
}

class Path extends CommonEntry {
  Path(String name, String value) : super(name, value);

  @override
  String get key => '{$name}';
}

class Query extends CommonEntry {
  Query(String name, String value) : super(name, value);

  @override
  String get key => name;
}

/// PATH, QUERY handlers
class PathEntryHandler extends UrlEntryHandler<Path> {
  @override
  Type get entryType => Path;

  @override
  String onHandle(String url, Path entry) {
    var path = '{${entry.name}}';
    var mutatedUrl = url.replaceAll(path, entry.value);
    return mutatedUrl;
  }
}

class QueryEntryHandler extends UrlEntryHandler<Query> {
  @override
  Type get entryType => Query;

  static const _end = '&';
  static const _question = '?';

  @override
  String onHandle(String url, Query entry) {
    var isFirstQuery = !url.contains(_question);

    var mutatedUrl = url;

    if (isFirstQuery) {
      mutatedUrl = mutatedUrl + _firstQuery(entry.name, entry.value);
    } else {
      mutatedUrl = mutatedUrl + _nextQuery(entry.name, entry.value);
    }

    return mutatedUrl;
  }

  String _firstQuery(String name, String value) => '$_question$name=$value';

  String _nextQuery(String name, String value) => '$_end$name=$value';
}

/// URL builder with PATH and QUERY
class UrlBuilder extends GenericUrlBuilder {
  UrlBuilder.base(String base) {
    super.base(base);
    addUrlEntryHandler(QueryEntryHandler());
    addUrlEntryHandler(PathEntryHandler());
  }

  @override
  UrlBuilder addUrlEntry(UrlEntry entry) =>
      super.addUrlEntry(entry) as UrlBuilder;

  @override
  UrlBuilder addUrlEntryHandler(UrlEntryHandler<UrlEntry> handler) =>
      super.addUrlEntryHandler(handler) as UrlBuilder;

  @override
  UrlBuilder url(String url) => super.url(url) as UrlBuilder;

  UrlBuilder addQuery(String name, Object value) {
    addUrlEntry(Query(name, Uri.encodeQueryComponent(value.toString())));
    return this;
  }

  UrlBuilder addQueryArray(String name, List<Object> values) {
    for (final value in values) {
      addQuery(name, value);
    }
    return this;
  }

  UrlBuilder addPath(String name, Object value) {
    addUrlEntry(Path(name, value.toString()));
    return this;
  }
}

/// POST, GET, PUT, DELETE
class Post extends RestMethod {
  const Post();

  @override
  String toString() => 'Post';
}

class Get extends RestMethod {
  const Get();

  @override
  String toString() => 'Get';
}

class Put extends RestMethod {
  const Put();

  @override
  String toString() => 'Put';
}

class Delete extends RestMethod {
  const Delete();

  @override
  String toString() => 'Delete';
}

/// Rest methods container
class Methods {
  Methods._();

  static const post = Post();
  static const get = Get();
  static const put = Put();
  static const delete = Delete();
}

// / Implements RequestExecutor using dart's http library
class HttpRequestExecutor extends RequestExecutor {
  HttpRequestExecutor(this.client,{this.timeOutDuration = const Duration(minutes: 5)});

  final Client client;

  final Duration timeOutDuration;

  Future<Response> onTimeOut() async {
    throw const SocketException('SocketException');
  }

  Future<Response> withTimeOut(Future<Response> response) =>
      response.timeout(timeOutDuration, onTimeout: onTimeOut);

  @override
  Future<RowResponse> execute(RowRequest rowRequest) async {
    Response? response;
    Uri uri = Uri.parse(rowRequest.request.url);

    final request = rowRequest.request;

    if (request is HttpMultipartRequest) {
      final multipartRequest = ProgressedMultipartRequest(
          request.method.toString(), uri,
          onProgress: request.progressListener);

      multipartRequest.fields.addAll(request.fields);
      multipartRequest.files.addAll(request.files);

      final requestHeaders = request.headers;
      multipartRequest.headers.addAll(requestHeaders);

      response = await withTimeOut(multipartRequest
          .send()
          .then((streamResponse) => Response.fromStream(streamResponse)));
    } else {
      if (request.method is Get) {
        response = await withTimeOut(
            client.get(uri, headers: rowRequest.request.headers));
      }
      if (request.method is Post) {
        response = await withTimeOut(client.post(uri,
            headers: rowRequest.request.headers,
            body: rowRequest.rowBody,
            encoding: request.encoding));
      }
      if (request.method is Put) {
        response = await withTimeOut(client.put(uri,
            headers: rowRequest.request.headers,
            body: rowRequest.rowBody,
            encoding: request.encoding));
      }
      if (request.method is Delete) {
        response = await withTimeOut(client.deleteWithBody(uri,
            headers: rowRequest.request.headers,
            body: rowRequest.request.body as String));
      }
    }

    RowResponse rowResponse = fromHttpResponse(response, rowRequest.request);

    return rowResponse;
  }

  HttpClientRequest addHeaders(
      HttpClientRequest request, Map<String, String> headers) {
    for (var entry in headers.entries) {
      request.headers.add(entry.key, entry.value);
    }
    return request;
  }

  RowResponse fromHttpResponse(Response? response, RestRequest request) {
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

/// Convert RowRequest <-> RowResponse using dart's json converter
class MapToJsonConverter extends RequestConverter {
  @override
  RowRequest toRow(RestRequest request) {
    String? jsonBody;
    if (request.body != null) {
      if (request.body is Map) {
        jsonBody = converter.json.encode(request.body);
      } else {
        jsonBody = request.body.toString();
      }
    } else {
      jsonBody = '';
    }
    return RowRequest(request, jsonBody, request.encoding);
  }
}

class JsonToMapConverter extends ResponseConverter {
  @override
  RestResponse fromRow(RowResponse rowResponse) {
    dynamic jsonMap;
    final rowBody = rowResponse.rowBody;
    if (rowBody != null && rowBody.isNotEmpty) {
      final rowBodyUtf8 = converter.utf8.decode(rowBody);
      jsonMap = converter.json.decode(rowBodyUtf8);
    }
    return RestResponse(
        rowResponse.request, rowResponse, jsonMap);
  }
}

class StringConverter extends ResponseConverter {
  @override
  RestResponse fromRow(RowResponse rowResponse) {
    String? stringBody;
    final rowBody = rowResponse.rowBody;
    if (rowBody != null) {
      final rowBodyUtf8 = converter.utf8.decode(rowBody);
      stringBody = rowBodyUtf8;
    }
    return RestResponse(
        rowResponse.request, rowResponse, stringBody);
  }
}

class UInt8ListConverter extends ResponseConverter {
  @override
  RestResponse fromRow(RowResponse rowResponse) => RestResponse(
      rowResponse.request, rowResponse, rowResponse.rowBody);
}

// Common RestRequests
class HttpRequest extends RestRequest {
  HttpRequest(
      {required RestMethod method,
      required String url,
      Map<String, String>? headers,
      body,
      Type requestConverterType = MapToJsonConverter,
      Type responseConverterType = JsonToMapConverter,
      converter.Encoding? encoding})
      : super(
            method: method,
            url: url,
            headers: headers,
            body: body,
            requestConverterType: requestConverterType,
            responseConverterType: responseConverterType,
            encoding: encoding);
}

typedef HttpMultipartRequestProgressListener = void Function(
    int bytes, int totalBytes);

class HttpMultipartRequest extends RestRequest {
  HttpMultipartRequest({
    required RestMethod method,
    required String url,
    required this.files,
    required this.fields,
    this.progressListener,
    Map<String, String>? headers,
    Type requestConverterType = MapToJsonConverter,
    Type responseConverterType = JsonToMapConverter,
  }) : super(
            method: method,
            url: url,
            headers: headers,
            body: null,
            requestConverterType: requestConverterType,
            responseConverterType: responseConverterType);

  final Map<String, String> fields;
  final List<MultipartFile> files;
  final HttpMultipartRequestProgressListener? progressListener;
}

extension ClientExtentions on Client {
  Future<Response> deleteWithBody(
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

class ProgressedMultipartRequest extends MultipartRequest {
  /// Creates a new [ProgressedMultipartRequest].
  ProgressedMultipartRequest(
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

    final total = this.contentLength;
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
