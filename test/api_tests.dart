import 'package:apex/apex.dart';
import 'package:http/http.dart' as http;

void main() {

  final client =
      ApexClient.builder(DefaultRequestExecutor(http.Client())).build();

  client.execute(ApexRequest(
      method: Methods.post,
      url: '',));
}
