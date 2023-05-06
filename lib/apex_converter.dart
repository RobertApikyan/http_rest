import 'dart:convert';

import 'package:apex/apex_io.dart';

/// This class is a base request converter definition, derive from this class
/// and implement the [toRow] method, which responsibility is to convert the
/// [RestRequest] to [RestRowResponse]. The library ships with pre defined
/// request converters such as [MapToJsonRequestConverter], which converts the
/// body [Map] provided by [RestRequest.body] to JSON [String].
abstract class RestRequestConverter {

  factory RestRequestConverter.empty() => _EmptyRequestConverter();

  RestRequestConverter();

  RestRowRequest toRow(RestRequest request);
}

/// This class is a base response converter definition, derive from this class
/// and implement the [fromRow] method, which responsibility is to convert the
/// [RestRowResponse] to [RestResponse]. The library ships with pre defined
/// response converters such as [JsonToMapResponseConverter], which converts the
/// received body bytes from [RestRowResponse.bodyBytes] to [Map] representation of
/// JSON result.
abstract class RestResponseConverter {

  factory RestResponseConverter.empty() => _EmptyResponseConverter();

  RestResponseConverter();

  RestResponse fromRow(RestRowResponse rowResponse);
}

class _EmptyRequestConverter extends RestRequestConverter {
  @override
  RestRowRequest toRow(RestRequest request) => RestRowRequest(request, request.body);
}

class _EmptyResponseConverter extends RestResponseConverter {
  @override
  RestResponse fromRow(RestRowResponse rowResponse) =>
      RestResponse(rowResponse.request, rowResponse, rowResponse.bodyBytes);
}

/// [MapToJsonRequestConverter], which converts the
/// body [Map] provided by [RestRequest.body] to JSON [String],
/// it uses the [JsonCodec] from dart.convert library to encode
/// the provided [RestRequest.body] to JSON string.
class MapToJsonRequestConverter extends RestRequestConverter {
  @override
  RestRowRequest toRow(RestRequest request) {
    String? jsonBody;
    if (request.body != null) {
      if (request.body is Map) {
        jsonBody = json.encode(request.body);
      } else {
        jsonBody = request.body.toString();
      }
    } else {
      jsonBody = '';
    }
    return RestRowRequest(request, jsonBody);
  }
}

/// [JsonToMapResponseConverter] converts the
/// received body bytes from [RestRowResponse.bodyBytes] to [Map] representation of
/// JSON result.class, it uses the [JsonCodec] from dart.convert library to decode
/// the json result.
class JsonToMapResponseConverter extends RestResponseConverter {
  @override
  RestResponse fromRow(RestRowResponse rowResponse) {
    dynamic jsonMap;
    final rowBody = rowResponse.bodyBytes;
    if (rowBody != null && rowBody.isNotEmpty) {
      final rowBodyUtf8 = utf8.decode(rowBody);
      jsonMap = json.decode(rowBodyUtf8);
    }
    return RestResponse(rowResponse.request, rowResponse, jsonMap);
  }
}

/// This response converter converts the response [RestRowResponse.bodyBytes] to
/// utf8 encoded string.
class StringResponseConverter extends RestResponseConverter {
  @override
  RestResponse fromRow(RestRowResponse rowResponse) {
    String? stringBody;
    final rowBody = rowResponse.bodyBytes;
    if (rowBody != null) {
      final rowBodyUtf8 = utf8.decode(rowBody);
      stringBody = rowBodyUtf8;
    }
    return RestResponse(rowResponse.request, rowResponse, stringBody);
  }
}


