![](https://raw.githubusercontent.com/RobertApikyan/http_rest/main/doc/assets/intro.png)
# HTTP REST

HTTP REST provides all the necessary tools to simplify and streamline your HTTP interactions. It is a lightweight and vercetile networking library based on the popular Flutter's [http](https://pub.dev/packages/http) library and serves as an enhancement, providing additional features and functionalities such as 

* Middlewares (Interceptors)
* Request/Response body converters
* Multipart requests with progress
* Request/Response logger

## Getting Started

Create the instance of `HttpRestClient`, then run the `HttpRestReqeust`.

```dart
import 'package:http/http.dart' as http;
import 'package:http_rest/http_rest.dart';
/// ...
  final httpClient =
  HttpRestClient.builder(DefaultRequestExecutor(http.Client()))
      .addResponseConverter(JsonToMapResponseConverter()) // Request converter
      .addRequestConverter(MapToJsonRequestConverter()) // Response converter
      .addRequestMiddleware(RequestLogger()) // Request Middleware
      .addResponseMiddleware(ResponseLogger()) // Response Middleware
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
      body: {
        "id":2,
        "bookName":"1984",
        "author":"George Orwell"
      }));

  if(result.rowResponse.code == 201){
    print(result.response); // instance of Map
  }
...
```
The same `httpClient` instance can be used to run other HTTP requests as well.

```dart
// The request will get the library books.
final result = await httpClient.execute(HttpRestRequest(
      method: Methods.get,
      responseConverterType: JsonToMapResponseConverter,
      url: 'https://example.com/books?count='$10''))
```

## Middlewares

HttpRestClient uses middleware chains to modify requests and responses.

Here is how to create a request middleware that adds an authorization header to each `HttpRestRequest `.

```dart
class AuthorizationMiddleware extends Middleware<RowRequest> {
  @override
  Future<RowRequest> onNext(
      RowRequest row, Middleware<RowRequest> nextMiddleware) async {
    row.request.headers['Authorization'] = 'YOUR AUTHORIZATION TOKEN';
    return await super.onNext(row, nextMiddleware);
  }
}
```
And add it while building the instance of `HttpRestClient` as shown below

```dart
  final httpClient = HttpRestClient.builder(
          DefaultRequestExecutor(http.Client()))
      .addResponseConverter(JsonToMapResponseConverter())
      .addRequestConverter(MapToJsonRequestConverter()) 
      .addRequestMiddleware(AuthorizationMiddleware()) // Added
      .addRequestMiddleware(RequestLogger()) 
      .addResponseMiddleware(ResponseLogger())
      .build();
```
Hence, the 'Authorization' header will be added to every request that has been executed by the `httpClient`. 
Note that `RequestLogger` and `ResponseLogger` are also middlewares.

Any number of request and response Middlewares can be added to `HttpRestClient`, and they will be called as a chain in the same order as has been added.

## Converters

Converters are used to convert request and response bodies. Library ships with a few default converters 

`MapToJsonRequestConverter` used to convert request's map body to JSON string.
`JsonToMapResponseConverter` used to convert response body bytes to map object.
`StringResponseConverter` used to convert response body bytes to String.

Each `HttpRestRequest` can specify the request and response converter type, and `HttpRestClient` will use specified converters to convert the request and response bodies.

```dart
// The request will get the library books.
final result = await httpClient.execute(HttpRestRequest(
      method: Methods.get,
      // Converts Request body to JSON
      responseConverterType: JsonToMapResponseConverter,
      url: 'https://example.com/books?count='$10''))
```

Here is how to create a converter that converts received body bytes to map instance.

```dart
import 'dart:convert';

class JsonToMapResponseConverter extends ResponseConverter {
  @override
  HttpRestResponse fromRow(RowResponse rowResponse) {
    dynamic jsonMap;
    final rowBody = rowResponse.bodyBytes;
    if (rowBody != null && rowBody.isNotEmpty) {
      final rowBodyUtf8 = utf8.decode(rowBody);
      jsonMap = json.decode(rowBodyUtf8);
    }
    return HttpRestResponse(rowResponse.request, rowResponse, jsonMap);
  }
}
```

Notice that `fromRow` method receives instance of `RowResponse` and returns instance of `HttpRestResponse`. 
* `RowResponse` is lower level of response model, it contains `bodyBytes` of response and more, like response code and response headers. 
* `HttpRestResponse` is what `await client.execute(HttpRestRequest(...))` returns, it contains instance of original `HttpRestRequest`, `RowResponse` and converted body `jsonMap`.

## Request Logging

`RequestLogger` and `ResponseLogger` are used to log the network interactions in the console.

Here is how logged request looks like in the console.

```
→ REQUEST →
POST: https://example.com/books
HEADERS:    Content-Type : application/json
            Authorization : eyJhbGciOi....
            Language : EN
            Version : 1.1.76
BODY:	{"id":2, "bookName":"1984", "author":"George Orwell"}

← RESPONSE ←
POST: https://example.com/books
CODE: 200
HEADERS:    connection : keep-alive
            date : Thu, 04 May 2023 19:02:10 GMT
            transfer-encoding : chunked
            vary : accept-encoding
            content-encoding : gzip
            strict-transport-security : max-age=15724800; includeSubDomains
            content-type : application/json

BODY:  {"message":"Success"}
```

Control loaggable parts of the request with `LogParts` enum

```dart
enum LogParts {
  headers,
  body,
  url,
  code;

  static const all = {url, headers, code, body}; // default
}
```

By default, all the parts of the request and response are logged. Here is how to specify Logger to log only  URL and headers. 

```dart
  final httpClient = HttpRestClient.builder(
      DefaultRequestExecutor(http.Client()))
//...
      .addRequestMiddleware(RequestLogger(logParts: {LogParts.url,LogParts.headers})) // Middlewares
      .addResponseMiddleware(ResponseLogger(logParts: {LogParts.url,LogParts.headers}))
      .build();
```

## Multipart Request

For the multipart request just provide a `MultipartRequestBody` to `HttpRestRequest`'s body.

Here is how to create a multipart request to upload a book and watch the progress.

```dart
void uploadBook(MultipartFile multipartFile) =>
    httpClient.execute(HttpRestRequest(
      method: Methods.post,
      url: 'https://example.come/book',
      body: MultipartRequestBody(
        fields: {},
        files: [multipartFile],
        progressListener: (bytes, totalBytes) {
          // watch the progress
		  final progress = bytes / totalBytes
        },
      ),
    ));
``` 

## Request Executor

The `RequestExecutor` is responible for running actual http requests and return the result. It's an abstract class, with a single abstract method `execute`
```
abstract class RequestExecutor {
  /// Override this method and implement http call by using the parameters from
  /// the [rowRequest].
  Future<RowResponse> execute(RowRequest rowRequest);
}
```

`DefaultRequestExecutor` is a default implementation of `RequestExecutor` and uses [http](https://pub.dev/packages/http) library for network interactions. 

## HttpRestClient

The `HttpRestClient ` class acts as the central hub, coordinating the flow of requests and responses, and allowing for extensibility and customization at various stages through request and response converters, middlewares, and the RequestExecutor class.

When a request is made through the HttpRestClient, the following steps occur:

1. **Request Conversion**: The request object is passed through the request converter, which transforms it into the appropriate format for sending over the network. This ensures compatibility with the API endpoint and handles any necessary data conversions.

2. **Request Middlewares**: The converted request then goes through a chain of request middlewares. These middlewares allow you to inject custom logic before the request is sent. Examples of request middleware functionalities include authentication, adding headers, or modifying the request payload.

3. **Request Execution**: The processed request is passed to the RequestExecutor class, which handles the actual execution of the HTTP request. The RequestExecutor interacts with the network layer, communicates with the API endpoint, and receives the raw response.

4. **Response Middlewares**: The response received from the RequestExecutor is then passed through a chain of response middlewares. These middlewares enable you to manipulate and process the response before it is returned to the caller. Common use cases for response middlewares include parsing response data, error handling, or logging.

5. **Response Conversion**: After going through the response middlewares, the response is passed to the response converter. The response converter transforms the raw response into a structured format that aligns with your application's needs. This conversion step ensures that the response is in a format that can be easily consumed and understood by your code.

6. **Result Return**: Finally, the converted response is returned as the result of the original request made through the HttpRestClient. The caller receives the processed response, which can be further processed or used to update the application's state.

## Conclusion 

In summary, the HTTP REST Library simplifies and enhances RESTful API integration. With support for RESTful methods, middlewares, converters, and multipart requests, it streamlines HTTP interactions. It provides customization options, abstraction, error handling, and enhanced logging, making it a valuable tool for building robust applications.

Please fill free to ask a question or open an issue in the github I will be happy to answer.
