import 'package:http/http.dart';
import 'package:http/http.dart' as http;
import 'package:http_rest/http_rest.dart';

class AuthorizationMiddleware extends Middleware<RowRequest> {
  @override
  Future<RowRequest> onNext(
      RowRequest row, Middleware<RowRequest> nextMiddleware) async {
    row.request.headers['Authorization'] = 'YOUR AUTHORIZATION TOKEN';
    return await super.onNext(row, nextMiddleware);
  }
}

class BooksAPI {
  final client = HttpRestClient.builder(DefaultRequestExecutor(http.Client()))
      .addResponseConverter(JsonToMapResponseConverter()) // Response Middleware
      .addResponseConverter(StringResponseConverter()) // Response Middleware
      .addRequestConverter(MapToJsonRequestConverter()) // Request converters
      .addRequestMiddleware(AuthorizationMiddleware()) // Request Middleware
      .addRequestMiddleware(RequestLogger()) // Request Middleware
      .addResponseMiddleware(ResponseLogger()) // Response Middlewares
      .build();

  UrlBuilder get _baseUrl => UrlBuilder.base(
      'https://my-json-server.typicode.com/RobertApikyan/JsonData/');

  // POST
  HttpRestRequest addBook(
          {required int id,
          required String bookName,
          required String author}) =>
      HttpRestRequest(
          method: Methods.post,
          requestConverterType: MapToJsonRequestConverter,
          // Specifies request converter type
          responseConverterType: JsonToMapResponseConverter,
          // Specifies response converter type
          url: _baseUrl.url('books').toString(),
          headers: {'Language': 'en'},
          body: {"id": id, "bookName": bookName, "author": author});

  // GET
  HttpRestRequest getBooks() => HttpRestRequest(
      method: Methods.get,
      requestConverterType: MapToJsonRequestConverter,
      // Specifies request converter type
      responseConverterType: JsonToMapResponseConverter,
      // Specifies response converter type
      url: _baseUrl.url('books').toString(),
      headers: {'Language': 'en'});

  // POST MULTIPART
  HttpRestRequest uploadBook(MultipartFile multipartFile,
          HttpMultipartRequestProgressListener progressListener) =>
      HttpRestRequest(
        method: Methods.post,
        responseConverterType: JsonToMapResponseConverter,
        url: 'book',
        headers: {'Language': 'en'},
        body: MultipartRequestBody(
          fields: {},
          files: [multipartFile],
          progressListener: progressListener,
        ),
      );
}

void main() async {
  final booksApi = BooksAPI();
  final booksResult = await booksApi.client.execute(booksApi.getBooks());
  if (booksResult.rowResponse.code == 200) {
    print(booksResult.response.toString());
  }

  final createBookResult = await booksApi.client.execute(booksApi.addBook(
      id: 1,
      bookName: 'UNIX Network Programming',
      author: 'W. Richard Stevens'));
  if (createBookResult.rowResponse.code == 201) {
    print(booksResult.response.toString());
  }

  // final uploadBookResult = await booksApi.client.execute(booksApi.uploadBook(
  //     await MultipartFile.fromPath('file', File('yourFilePath').path,
  //         filename: 'UNIX Network Programming.pdf',
  //         contentType: MediaType('video', 'webm')),
  //     (bytes, totalBytes) {}));
}
