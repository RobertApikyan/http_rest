## 1.0.0-alpha.1

* The initial alpha version of the HTTP REST library.
* Middlewares (Interceptors)
* Request/Response body converters
* Multipart requests with progress
* Request/Response logger

## 1.0.0-alpha.2

* Removed redundant imports.
* Shortened pubspec.yaml description up until 180 chars.

## 1.0.0-alpha.3

* README minor changes.

## 1.0.0-alpha.4

## 1.0.1 

* Added addRequestOverrideMiddleware method to HttpRestClientBuilder, so each request will be streamed through the provided middleware before passing to request converter.