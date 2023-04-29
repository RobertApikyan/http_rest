import 'dart:convert';

import 'package:rest/rest_io.dart';

abstract class RestRequestConverter {
  RestRowRequest toRow(RestRequest request);
}

abstract class RestResponseConverter {
  RestResponse fromRow(RestRowResponse rowResponse);
}

/// Convert RowRequest <-> RowResponse using dart's json converter
class MapToJsonConverter extends RestRequestConverter {
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
    return RestRowRequest(request, jsonBody, request.encoding);
  }
}

class JsonToMapConverter extends RestResponseConverter {
  @override
  RestResponse fromRow(RestRowResponse rowResponse) {
    dynamic jsonMap;
    final rowBody = rowResponse.rowBody;
    if (rowBody != null && rowBody.isNotEmpty) {
      final rowBodyUtf8 = utf8.decode(rowBody);
      jsonMap = json.decode(rowBodyUtf8);
    }
    return RestResponse(rowResponse.request, rowResponse, jsonMap);
  }
}

class StringConverter extends RestResponseConverter {
  @override
  RestResponse fromRow(RestRowResponse rowResponse) {
    String? stringBody;
    final rowBody = rowResponse.rowBody;
    if (rowBody != null) {
      final rowBodyUtf8 = utf8.decode(rowBody);
      stringBody = rowBodyUtf8;
    }
    return RestResponse(rowResponse.request, rowResponse, stringBody);
  }
}

class UInt8ListConverter extends RestResponseConverter {
  @override
  RestResponse fromRow(RestRowResponse rowResponse) =>
      RestResponse(rowResponse.request, rowResponse, rowResponse.rowBody);
}
