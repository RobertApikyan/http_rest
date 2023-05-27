

class _HttpRestUrlBuilder {
  late final String _base;
  late final String _url;
  final _entryStore = <UrlEntry>{};
  final _entryHandlerStore = <Type, UrlEntryHandler>{};

  _HttpRestUrlBuilder base(String base) {
    _base = base;
    return this;
  }

  _HttpRestUrlBuilder addUrlEntry(UrlEntry entry) {
    _entryStore.add(entry);
    return this;
  }

  _HttpRestUrlBuilder addUrlEntryHandler(UrlEntryHandler handler) {
    _entryHandlerStore[handler.entryType] = handler;
    return this;
  }

  _HttpRestUrlBuilder url(String url) {
    _url = url;
    return this;
  }

  @override
  String toString() {
    var url = _base + _url;
    for (var entry in _entryStore) {
      final handler = _entryHandlerStore[entry.runtimeType];
      if (handler != null) {
        url = handler.onHandle(url, entry);
      } else {
        throw '';
      }
    }
    return url;
  }
}

/// The base class which finds the url entries in the given url by the UrlEntry.key
/// and makes the appropriate modifications to the url, by returning the modified
/// URL as a result of [onHandle] method.
abstract class UrlEntryHandler<E extends UrlEntry> {
  /// The type of the [UrlEntry] that this [UrlEntryHandler] is responsible for.
  Type get entryType;

  /// Override this method and implement the handling of the url, see the examples
  /// in the [QueryEntryHandler] and [PathEntryHandler].
  String onHandle(String url, E entry);
}

/// The base class which used by [UrlEntryHandler] to identify the entries in
/// the url by the provided [key].
abstract class UrlEntry {
  /// This [key] is used by the [UrlEntryHandler] to identify the entry in the given URL.
  String get key;
}

/// The base implementation of [UrlEntry] class that represents the basic element of the URL,
/// with the entry [name] and [value] .
/// The entry could be a query (https://example.com?id=1) or a single part of the
/// url (https://example.com/{userId}/profile). The prime examples of
/// [CommonEntry] implementation are [Query] and [Path] classes.
abstract class CommonEntry extends UrlEntry {
  CommonEntry(this.name, this.value);

  final String name;
  final String value;
}

/// The implementation of [CommonEntry] which handles the "path" in the URL.
/// For a given url https://example.com/{userId}/profile the {userId} is a path entry,
/// with the [name] parameter equal to "userId" and eventually the [name]={userId} will be replaced
/// with the [value]=15 by the [PathEntryHandler], so we will end up with https://example.com/15/profile.
class Path extends CommonEntry {
  Path(String name, String value) : super(name, value);

  @override
  String get key => '{$name}';
}

/// The implementation of [CommonEntry] which handles the "query" in the URL.
/// The [QueryEntryHandler] will add given [Query] entries the the end of the URL in a
/// given order.
class Query extends CommonEntry {
  Query(String name, String value) : super(name, value);

  @override
  String get key => name;
}

/// The [UrlEntryHandler] which will replace all the URL paths with the given structure {<path_name>}
/// with the appropriate values.
/// For a given url https://example.com/{userId}/profile the {userId} is a path entry,
/// with the [name] parameter equal to "userId" and eventually the [name]={userId} will be replaced
/// with the [value]=15 by the [PathEntryHandler], so we will end up with https://example.com/15/profile.
class PathEntryHandler extends UrlEntryHandler<Path> {
  @override
  Type get entryType => Path;

  @override
  String onHandle(String url, Path entry) {
    var path = '{${entry.name}}';
    var mutatedUrl = url.replaceAll(path, entry.value);
    return mutatedUrl;
  }
}

/// The [QueryEntryHandler] will add given [Query] entries the the end of the URL in a
/// given order.
class QueryEntryHandler extends UrlEntryHandler<Query> {
  @override
  Type get entryType => Query;

  static const _end = '&';
  static const _question = '?';

  @override
  String onHandle(String url, Query entry) {
    var isFirstQuery = !url.contains(_question);

    var mutatedUrl = url;

    if (isFirstQuery) {
      mutatedUrl = mutatedUrl + _firstQuery(entry.name, entry.value);
    } else {
      mutatedUrl = mutatedUrl + _nextQuery(entry.name, entry.value);
    }

    return mutatedUrl;
  }

  String _firstQuery(String name, String value) => '$_question$name=$value';

  String _nextQuery(String name, String value) => '$_end$name=$value';
}

/// This class is a helper for URL path manipulations. It provides a way to keep
/// the base url, then add a request path to it and apply some query and path
/// params to it.
/// Here is the example usage of it.
/// ```dart
/// UrlBuilder get baseUrl => UrlBuilder.base('https://example.com');
///
/// final requestUrl = baseUrl
///               .url('users/{userId}/documents/{documentId}')
///               .addPath('userId', '123')
///               .addPath('documentId', '456')
///               .addQuery('type', 'education')
///               .addQuery('name', 'calculus')
///               .toString()
///
/// The value of requestUrl will be
/// https://example.com/users/123/documents/456?type=education&name=calculus
///
class UrlBuilder extends _HttpRestUrlBuilder {
  UrlBuilder.base(String base) {
    super.base(base);
    addUrlEntryHandler(QueryEntryHandler());
    addUrlEntryHandler(PathEntryHandler());
  }

  @override
  UrlBuilder addUrlEntry(UrlEntry entry) =>
      super.addUrlEntry(entry) as UrlBuilder;

  @override
  UrlBuilder addUrlEntryHandler(UrlEntryHandler<UrlEntry> handler) =>
      super.addUrlEntryHandler(handler) as UrlBuilder;

  @override
  UrlBuilder url(String url) => super.url(url) as UrlBuilder;

  UrlBuilder addQuery(String name, Object value) {
    addUrlEntry(Query(name, Uri.encodeQueryComponent(value.toString())));
    return this;
  }

  UrlBuilder addQueryArray(String name, List<Object> values) {
    for (final value in values) {
      addQuery(name, value);
    }
    return this;
  }

  UrlBuilder addPath(String name, Object value) {
    addUrlEntry(Path(name, value.toString()));
    return this;
  }
}
