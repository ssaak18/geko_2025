import 'dart:convert';

import 'package:http/http.dart' as http;

class MockClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request) _handler;

  MockClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = await request.finalize().fold<List<int>>(<int>[], (a, b) => a..addAll(b));

    final response = await _handler(req);
    return http.StreamedResponse(
      Stream.fromIterable([response.bodyBytes]),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
    );
  }
}

class MockLocationService {
  final double lat;
  final double lng;

  MockLocationService(this.lat, this.lng);

  Future<Map<String, double>> getCurrentLocation() async {
    return {'latitude': lat, 'longitude': lng};
  }
}
