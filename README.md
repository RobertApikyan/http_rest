REST Request Library
Build Status

A library for making REST requests to APIs.

Installation
To use this library in your project, add the following to your pubspec.yaml file:

yaml
Copy code
dependencies:
library_name: ^1.0.0
Then run flutter pub get to install the package.

Usage
Here's an example of how to use this library to make a GET request to the JSONPlaceholder API:

dart
Copy code
import 'package:library_name/library_name.dart';

void fetchData() async {
final response = await RestClient.get('https://jsonplaceholder.typicode.com/posts/1');
print(response.body);
}
In this example, we're using the get method from the RestClient class to make a GET request to the JSONPlaceholder API.

Documentation
For more information on how to use this library, please refer to the documentation.

Contributing
If you find any bugs or have feature requests, please file an issue or submit a pull request on the GitHub repository. We welcome any contributions that improve the functionality of this library.