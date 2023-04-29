import 'dart:async';

import 'package:http/http.dart';

typedef HttpMultipartRequestProgressListener = void Function(
    int bytes, int totalBytes);

class MultipartRestRequestBody {
  const MultipartRestRequestBody({
    required this.fields,
    required this.files,
    this.progressListener,
  });

  final Map<String, String> fields;
  final List<MultipartFile> files;
  final HttpMultipartRequestProgressListener? progressListener;
}

class ProgressedMultipartRequest extends MultipartRequest {
  /// Creates a new [ProgressedMultipartRequest].
  ProgressedMultipartRequest(
    String method,
    Uri url, {
    required this.onProgress,
  }) : super(method, url);

  late final void Function(int bytes, int totalBytes)? onProgress;

  /// Freezes all mutable fields and returns a single-subscription [ByteStream]
  /// that will emit the request body.
  @override
  ByteStream finalize() {
    final byteStream = super.finalize();
    final onProgress = this.onProgress;
    if (onProgress == null) {
      return byteStream;
    }

    final total = contentLength;
    int bytes = 0;

    final t = StreamTransformer.fromHandlers(
      handleData: (List<int> data, EventSink<List<int>> sink) {
        bytes += data.length;
        onProgress(bytes, total);
        sink.add(data);
      },
    );

    final stream = byteStream.transform(t);
    return ByteStream(stream);
  }
}
