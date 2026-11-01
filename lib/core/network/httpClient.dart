import 'package:http/http.dart' as real_http;

export 'package:http/http.dart' hide get, post, patch, delete;

/// Global callback invoked when an HTTP 401 Unauthorized response is received.
void Function()? onUnauthorizedResponse;

Future<real_http.Response> get(Uri url, {Map<String, String>? headers}) async {
  final response = await real_http.get(url, headers: headers);
  _checkUnauthorized(response);
  return response;
}

Future<real_http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) async {
  final response = await real_http.post(url, headers: headers, body: body);
  _checkUnauthorized(response);
  return response;
}

Future<real_http.Response> patch(Uri url, {Map<String, String>? headers, Object? body}) async {
  final response = await real_http.patch(url, headers: headers, body: body);
  _checkUnauthorized(response);
  return response;
}

Future<real_http.Response> delete(Uri url, {Map<String, String>? headers, Object? body}) async {
  final response = await real_http.delete(url, headers: headers, body: body);
  _checkUnauthorized(response);
  return response;
}

void _checkUnauthorized(real_http.Response response) {
  if (response.statusCode == 401) {
    onUnauthorizedResponse?.call();
  }
}
