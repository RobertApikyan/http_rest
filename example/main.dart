import 'dart:io';

import 'package:http/http.dart';
import 'package:http_rest/http_rest.dart';
import 'package:http/http.dart' as http;

final httpClient = HttpRestClient.builder(DefaultRequestExecutor(http.Client()))
    .addResponseConverter(JsonToMapResponseConverter()) // Request converters
    .addRequestConverter(MapToJsonRequestConverter()) // Response converters
    .addRequestMiddleware(AuthorizationMiddleware())
    .addRequestMiddleware(RequestLogger()) // Middlewares
    .addResponseMiddleware(ResponseLogger())
    .build();

void main() async {
  // final result = await httpClient.execute(HttpRestRequest(
  //     method: Methods.get,
  //     responseConverterType: JsonToMapResponseConverter,
  //     url: 'https://my-json-server.typicode.com/RobertApikyan/JsonData/profile'));
}

void _postRequest() async {
  final httpClient = HttpRestClient.builder(
          DefaultRequestExecutor(http.Client()))
      .addResponseConverter(JsonToMapResponseConverter()) // Request converters
      .addRequestConverter(MapToJsonRequestConverter()) // Response converters
      .addRequestMiddleware(AuthorizationMiddleware())
      .addRequestMiddleware(RequestLogger()) // Middlewares
      .addResponseMiddleware(ResponseLogger())
      .build();

  // This request will add a book to library
  final result = await httpClient.execute(HttpRestRequest(
      method: Methods.post,
      // Specifies request converter type
      requestConverterType: MapToJsonRequestConverter,
      // Specifies response converter type
      responseConverterType: JsonToMapResponseConverter,
      url: 'https://example.com/books',
      headers: {'Language': 'en'},
      body: {"id": 2, "bookName": "1984", "author": "George Orwell"}));

  if (result.rowResponse.code == 201) {
    print(result.response); // instance of Map
  }
}

class AuthorizationMiddleware extends Middleware<RowRequest> {
  @override
  Future<RowRequest> onNext(
      RowRequest row, Middleware<RowRequest> nextMiddleware) async {
    row.request.headers['Authorization'] = 'YOUR AUTHORIZATION TOKEN';
    return await super.onNext(row, nextMiddleware);
  }
}

void _logParts() {
  final httpClient =
      HttpRestClient.builder(DefaultRequestExecutor(http.Client()))
          .addRequestMiddleware(RequestLogger(
              logParts: {LogParts.url, LogParts.headers})) // Middlewares
          .addResponseMiddleware(
              ResponseLogger(logParts: {LogParts.url, LogParts.headers}))
          .build();
}

void uploadBook(MultipartFile multipartFile) =>
    httpClient.execute(HttpRestRequest(
      responseConverterType: StringResponseConverter,
      method: Methods.post,
      url: 'https://example.come/book',
      headers: {'Language': 'en'},
      body: MultipartRequestBody(
        fields: {},
        files: [multipartFile],
        progressListener: (bytes, totalBytes) {
          // watch the progress
        },
      ),
    ));
