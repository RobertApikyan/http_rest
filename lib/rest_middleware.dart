

class RestMiddleware<R> {
  RestMiddleware<R>? _next;

  void addNext(RestMiddleware<R> middleWare) {
    if (_next == null) {
      _next = middleWare;
    } else {
      _next?.addNext(middleWare);
    }
  }

  Future<R> next(R row) async {
    final next = _next;
    if (next == null) {
      return row;
    } else {
      return await onNext(row, next);
    }
  }

  Future<R> onNext(R row, RestMiddleware<R> nextMiddleware) async =>
      await nextMiddleware.next(row);
}