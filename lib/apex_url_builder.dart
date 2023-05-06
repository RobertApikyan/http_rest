

class RestUrlBuilder {
  late final String _base;
  late final String _url;
  final _entryStore = <RestUrlEntry>{};
  final _entryHandlerStore = <Type, RestUrlEntryHandler>{};

  RestUrlBuilder base(String base) {
    _base = base;
    return this;
  }

  RestUrlBuilder addUrlEntry(RestUrlEntry entry) {
    _entryStore.add(entry);
    return this;
  }

  RestUrlBuilder addUrlEntryHandler(RestUrlEntryHandler handler) {
    _entryHandlerStore[handler.entryType] = handler;
    return this;
  }

  RestUrlBuilder url(String url) {
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

abstract class RestUrlEntryHandler<E extends RestUrlEntry> {
  Type get entryType;

  String onHandle(String url, E entry);
}

abstract class RestUrlEntry {
  String get key;
}

/// PATH, QUERY
abstract class CommonEntry extends RestUrlEntry {
  CommonEntry(this.name, this.value);

  final String name;
  final String value;
}

class Path extends CommonEntry {
  Path(String name, String value) : super(name, value);

  @override
  String get key => '{$name}';
}

class Query extends CommonEntry {
  Query(String name, String value) : super(name, value);

  @override
  String get key => name;
}

/// PATH, QUERY handlers
class PathEntryHandler extends RestUrlEntryHandler<Path> {
  @override
  Type get entryType => Path;

  @override
  String onHandle(String url, Path entry) {
    var path = '{${entry.name}}';
    var mutatedUrl = url.replaceAll(path, entry.value);
    return mutatedUrl;
  }
}

class QueryEntryHandler extends RestUrlEntryHandler<Query> {
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
class UrlBuilder extends RestUrlBuilder {
  UrlBuilder.base(String base) {
    super.base(base);
    addUrlEntryHandler(QueryEntryHandler());
    addUrlEntryHandler(PathEntryHandler());
  }

  @override
  UrlBuilder addUrlEntry(RestUrlEntry entry) =>
      super.addUrlEntry(entry) as UrlBuilder;

  @override
  UrlBuilder addUrlEntryHandler(RestUrlEntryHandler<RestUrlEntry> handler) =>
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
