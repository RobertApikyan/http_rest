import 'package:apex/apex.dart';
import 'package:http/http.dart';

void main() {

  final client =
      RestClient.builder(DefaultRestRequestExecutor(Client())).build();

  client.execute(RestRequest(
      method: RestMethods.post,
      url: '',));
}
