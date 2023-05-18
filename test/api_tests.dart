import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http_rest/http_rest.dart';

void main() async {
  test_get_profile();
}

UrlBuilder baseUrl() => UrlBuilder.base(
    'https://my-json-server.typicode.com/RobertApikyan/JsonData/');

HttpRestRequest profile() => HttpRestRequest(
      method: Methods.post,
      url: baseUrl().url('profile').toString(),
    );

void test_get_profile() => test('test_make_calls_without_converter', () async {
      final client =
          HttpRestClient.builder(DefaultRequestExecutor(http.Client()))
              .addResponseConverter(JsonToMapResponseConverter())
              .addRequestConverter(MapToJsonRequestConverter())
              .build();

      HttpRestRequest profile() => HttpRestRequest(
          method: Methods.post,
          responseConverterType: JsonToMapResponseConverter,
          url: UrlBuilder.base(
                  'https://my-json-server.typicode.com/RobertApikyan/JsonData/')
              .url('profile')
              .toString());

      final result = await client.execute(profile());

      expect(result.rowResponse.code, 201);
      expect(result.response is Map<String, dynamic>, true);
      if (result.response
          case {"id": int id, "name": String name, "skills": [String a]}) ;
    });
