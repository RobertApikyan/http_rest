import 'package:http/http.dart';

/// Used to provide multipart request's progress.
typedef HttpMultipartRequestProgressListener = void Function(
    int bytes, int totalBytes);

/// This class is used to make a multipart request. The instance of this class
/// need to be passed to [HttpRestRequest.body].
/// This class also provides [progressListener] which can be used to track the progress.
class MultipartRequestBody {
  const MultipartRequestBody({
    required this.fields,
    required this.files,
    this.progressListener,
  });

  final Map<String, String> fields;
  final List<MultipartFile> files;
  final HttpMultipartRequestProgressListener? progressListener;
}
