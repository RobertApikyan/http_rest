import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http_rest/http_rest.dart';

void main() async {
  group('CRUD', () {
    test_get_profile();
    test_post_create_profile();
    test_post_row_create();
  });
}

void test_get_profile() => test('test_make_calls_without_converter', () async {
      final client =
          HttpRestClient.builder(DefaultRequestExecutor(http.Client()))
              .addResponseConverter(JsonToMapResponseConverter())
              .addRequestConverter(MapToJsonRequestConverter())
              .addRequestMiddleware(RequestLogger())
              .addResponseMiddleware(ResponseLogger())
              .build();

      HttpRestRequest profile() => HttpRestRequest(
          method: Methods.get,
          responseConverterType: JsonToMapResponseConverter,
          url: UrlBuilder.base(
                  'https://my-json-server.typicode.com/RobertApikyan/JsonData/')
              .url('profile')
              .toString());

      final result = await client.execute(profile());

      expect(result.rowResponse.code, 200);
      expect(result.response is Map<String, dynamic>, true);

      final response = result.response;
      final isValidProfile = switch (response) {
        {
          "id": int id,
          "name": String name,
          "skills": [String first, ..., String last]
        } =>
          true,
        _ => false
      };
      expect(isValidProfile, true);
    });

void test_post_create_profile() =>
    test('test_make_calls_without_converter', () async {
      final client =
          HttpRestClient.builder(DefaultRequestExecutor(http.Client()))
              .addResponseConverter(JsonToMapResponseConverter())
              .addRequestConverter(MapToJsonRequestConverter())
              .build();

      HttpRestRequest profile() => HttpRestRequest(
              method: Methods.post,
              responseConverterType: JsonToMapResponseConverter,
              requestConverterType: MapToJsonRequestConverter,
              url: UrlBuilder.base(
                      'https://my-json-server.typicode.com/RobertApikyan/JsonData/')
                  .url('profile')
                  .toString(),
              body: {
                "id": 1,
                "bookName": "To Kill a Mockingbird",
                "author": "Harper Lee"
              });

      final result = await client.execute(profile());

      expect(result.rowResponse.code, 201);
      expect(result.response is Map<String, dynamic>, true);
    });

void test_post_row_create() =>
    test('test_make_calls_without_converter', () async {
      final client =
          HttpRestClient.builder(DefaultRequestExecutor(http.Client()))
              .addResponseConverter(JsonToMapResponseConverter())
              .addRequestConverter(MapToJsonRequestConverter())
              .build();

      HttpRestRequest profile() => HttpRestRequest(
          method: Methods.post,
          url: UrlBuilder.base(
                  'https://my-json-server.typicode.com/RobertApikyan/JsonData/')
              .url('profile')
              .toString(),
          body:
              '{"id": 1, "bookName": "To Kill a Mockingbird", "author": "Harper Lee"}');

      final result = await client.execute(profile());

      expect(result.rowResponse.code, 201);
      expect(result.response is Uint8List,true);
    });
