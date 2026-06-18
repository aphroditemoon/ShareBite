import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // Android emulator: 10.0.2.2 | physical device: LAN IP | production: HTTPS API.
  static const String baseUrl =
      'https://foodwasteapp-production-6eaa.up.railway.app/api';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static String? _token;

  static Future<String?> getToken() async {
    _token ??= await _storage.read(key: 'auth_token');
    return _token;
  }

  static Future<void> saveToken(String token) async {
    _token = token;
    await _storage.write(key: 'auth_token', value: token);
  }

  static Future<void> clearToken() async {
    _token = null;
    await _storage.delete(key: 'auth_token');
  }

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static Map<String, dynamic> _handle(http.Response response) {
    Map<String, dynamic> body = {};

    try {
      if (response.body.trim().isNotEmpty) {
        body = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      }
    } catch (_) {
      throw ApiException('Invalid server response', response.statusCode);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {
        'success': body['success'] ?? true,
        'data': body['data'],
        'message': body['message'],
      };
    }

    throw ApiException(
      body['message']?.toString() ?? 'Request failed',
      response.statusCode,
    );
  }

  static String _fieldValue(dynamic value) {
    if (value is List || value is Map) return jsonEncode(value);
    return value.toString();
  }

  // ── AUTH ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password, {
    String? phone,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: await _headers(auth: false),
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
      }),
    );
    return _handle(response);
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: await _headers(auth: false),
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _handle(response);
  }

  static Future<Map<String, dynamic>> getMe() async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: await _headers(),
    );
    return _handle(response);
  }

  // ── LISTINGS ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getListings({
    double? lat,
    double? lng,
    double radius = 10000,
    String category = 'all',
    String? search,
    int page = 1,
    String sort = 'distance',
  }) async {
    final uri = Uri.parse('$baseUrl/listings').replace(queryParameters: {
      if (lat != null) 'lat': lat.toString(),
      if (lng != null) 'lng': lng.toString(),
      'radius': radius.toString(),
      if (category != 'all') 'category': category,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      'page': page.toString(),
      'limit': '50',
      'sort': sort,
    });

    final response = await http.get(uri, headers: await _headers());
    return _handle(response);
  }

  static Future<Map<String, dynamic>> getListing(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/listings/$id'),
      headers: await _headers(),
    );
    return _handle(response);
  }

  static Future<Map<String, dynamic>> createListing(
    Map<String, dynamic> data,
    List<File> images,
  ) async {
    final token = await getToken();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/listings'));

    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    data.forEach((key, value) {
      if (value != null) request.fields[key] = _fieldValue(value);
    });

    for (final image in images) {
      request.files.add(await http.MultipartFile.fromPath('images', image.path));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _handle(response);
  }

  static Future<Map<String, dynamic>> deleteListing(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/listings/$id'),
      headers: await _headers(),
    );
    return _handle(response);
  }

  // ── ML ────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getRecommendations({
    String? listingId,
    String? title,
    List<String>? tags,
    String? category,
    String? description,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ml/recommend'),
      headers: await _headers(),
      body: jsonEncode({
        'listingId': listingId,
        'title': title,
        'tags': tags,
        'category': category,
        'description': description,
      }),
    );
    return _handle(response);
  }

  // ── MAPS ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getNearbyListings(
    double lat,
    double lng, {
    double radius = 20000,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/maps/nearby?lat=$lat&lng=$lng&radius=$radius'),
      headers: await _headers(),
    );
    return _handle(response);
  }

  // ── MESSAGES ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getConversations() async {
    final response = await http.get(
      Uri.parse('$baseUrl/messages/conversations'),
      headers: await _headers(),
    );
    return _handle(response);
  }

  static Future<Map<String, dynamic>> getMessages(String conversationId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/messages/conversations/$conversationId'),
      headers: await _headers(),
    );
    return _handle(response);
  }

  static Future<Map<String, dynamic>> sendMessage(
    String recipientId,
    String content, {
    String? listingId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/messages'),
      headers: await _headers(),
      body: jsonEncode({
        'recipientId': recipientId,
        'content': content,
        'listingId': listingId,
      }),
    );
    return _handle(response);
  }

  // ── REQUESTS ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createRequest(
    String listingId, {
    String? message,
    int quantity = 1,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/requests'),
      headers: await _headers(),
      body: jsonEncode({
        'listingId': listingId,
        'message': message,
        'quantity': quantity,
      }),
    );
    return _handle(response);
  }

  static Future<Map<String, dynamic>> getMyRequests() async {
    final response = await http.get(
      Uri.parse('$baseUrl/requests/my'),
      headers: await _headers(),
    );
    return _handle(response);
  }

  // ── USER ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> data, {
    File? avatar,
  }) async {
    final token = await getToken();
    final request = http.MultipartRequest('PUT', Uri.parse('$baseUrl/users/profile'));

    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    data.forEach((key, value) {
      if (value != null) request.fields[key] = _fieldValue(value);
    });

    if (avatar != null) {
      request.files.add(await http.MultipartFile.fromPath('avatar', avatar.path));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _handle(response);
  }

  static Future<Map<String, dynamic>> getUser(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId'),
      headers: await _headers(auth: false),
    );
    return _handle(response);
  }

  static Future<Map<String, dynamic>> getUserListings(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/listings'),
      headers: await _headers(auth: false),
    );
    return _handle(response);
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
