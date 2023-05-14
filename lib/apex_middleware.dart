
/// The descendant of this class can be used as a request or response middleware.
/// For the request middleware specify the [R] generic type as a[RowRequest],
/// for the response middleware specify the [R] generic type as a [RowResponse]
/// After extending from the [Middleware] override the [onNext] async method
/// and implement your custom logic, after call the [next] method
/// ```dart
/// await nextMiddleware.next(row)
/// ```
///  which will call the next middleware in the chain.
///  Here is the example of request middleware
///  ```dart
///  class CustomMiddleware extends Middleware<RowRequest> {
///
///   @override
///   Future<RowRequest> onNext(
///       RowRequest row, Middleware<RowRequest> nextMiddleware) async {
///     // Your logic here
///     return await nextMiddleware.next(row);
///   }
/// }
///  ```
/// You can also check the [RequestLogger] and [ResponseLogger] for more examples.
class Middleware<R> {
  Middleware<R>? _next;

  /// This method adds a middleware to the chain.
  /// This method is called by the Apex library, no need to call it manually,
  /// instead use [ApexClientBuilder.addRequestMiddleware] and [ApexClientBuilder.addResponseMiddleware]
  void addNext(Middleware<R> middleWare) {
    if (_next == null) {
      _next = middleWare;
    } else {
      _next?.addNext(middleWare);
    }
  }

  /// This method will call next middleware in the chain. Initially this method get
  /// called by the [ApexClient].
  Future<R> next(R row) async {
    final next = _next;
    if (next == null) {
      return row;
    } else {
      return await onNext(row, next);
    }
  }

  /// Override this method and implement your custom logic inside it.
  /// After call await nextMiddleware.next(row) to run the next middleware in
  /// the chain.
  Future<R> onNext(R row, Middleware<R> nextMiddleware) async =>
      await nextMiddleware.next(row);
}
