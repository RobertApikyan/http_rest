import 'package:http/http.dart';
import 'package:rest/rest.dart';

void main() {
  final client =
      RestClient.builder(DefaultRestRequestExecutor(Client())).build();

  client.execute(RestRequest(
      method: RestMethods.post,
      url: '',
      requestConverterTypes: [],
      responseConverterTypes: []));
}
