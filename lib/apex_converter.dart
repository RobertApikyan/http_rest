import 'dart:convert';

import 'package:apex/apex_io.dart';

/// This class is a base request converter definition, derive from this class
/// and implement the [toRow] method, which responsibility is to convert the
/// [ApexRequest] to [RowResponse]. The library ships with pre defined
/// request converters such as [MapToJsonRequestConverter], which converts the
/// body [Map] provided by [ApexRequest.body] to JSON [String].
abstract class RequestConverter {

  factory RequestConverter.empty() => _EmptyRequestConverter();

  RequestConverter();

  RowRequest toRow(ApexRequest request);
}

/// This class is a base response converter definition, derive from this class
/// and implement the [fromRow] method, which responsibility is to convert the
/// [RowResponse] to [ApexResponse]. The library ships with pre defined
/// response converters such as [JsonToMapResponseConverter], which converts the
/// received body bytes from [RowResponse.bodyBytes] to [Map] representation of
/// JSON result.
abstract class ResponseConverter {

  factory ResponseConverter.empty() => _EmptyResponseConverter();

  ResponseConverter();

  ApexResponse fromRow(RowResponse rowResponse);
}

class _EmptyRequestConverter extends RequestConverter {
  @override
  RowRequest toRow(ApexRequest request) => RowRequest(request, request.body);
}

class _EmptyResponseConverter extends ResponseConverter {
  @override
  ApexResponse fromRow(RowResponse rowResponse) =>
      ApexResponse(rowResponse.request, rowResponse, rowResponse.bodyBytes);
}

/// [MapToJsonRequestConverter], which converts the
/// body [Map] provided by [ApexRequest.body] to JSON [String],
/// it uses the [JsonCodec] from dart.convert library to encode
/// the provided [ApexRequest.body] to JSON string.
class MapToJsonRequestConverter extends RequestConverter {
  @override
  RowRequest toRow(ApexRequest request) {
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
    return RowRequest(request, jsonBody);
  }
}

/// [JsonToMapResponseConverter] converts the
/// received body bytes from [RowResponse.bodyBytes] to [Map] representation of
/// JSON result.class, it uses the [JsonCodec] from dart.convert library to decode
/// the json result.
class JsonToMapResponseConverter extends ResponseConverter {
  @override
  ApexResponse fromRow(RowResponse rowResponse) {
    dynamic jsonMap;
    final rowBody = rowResponse.bodyBytes;
    if (rowBody != null && rowBody.isNotEmpty) {
      final rowBodyUtf8 = utf8.decode(rowBody);
      jsonMap = json.decode(rowBodyUtf8);
    }
    return ApexResponse(rowResponse.request, rowResponse, jsonMap);
  }
}

/// This response converter converts the response [RowResponse.bodyBytes] to
/// utf8 encoded string.
class StringResponseConverter extends ResponseConverter {
  @override
  ApexResponse fromRow(RowResponse rowResponse) {
    String? stringBody;
    final rowBody = rowResponse.bodyBytes;
    if (rowBody != null) {
      final rowBodyUtf8 = utf8.decode(rowBody);
      stringBody = rowBodyUtf8;
    }
    return ApexResponse(rowResponse.request, rowResponse, stringBody);
  }
}


