import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/article.dart';
import 'platform_info_stub.dart'
    if (dart.library.io) 'platform_info_io.dart' as platform_info;

class ApiService {
  const ApiService();

  SupabaseClient get _supabase => Supabase.instance.client;

  String get _baseUrl {
    if (platform_info.isAndroid) {
      return 'http://10.0.2.2:8000';
    }

    if (kIsWeb || platform_info.isIOS) {
      return 'http://127.0.0.1:8000';
    }

    return 'http://127.0.0.1:8000';
  }

  Map<String, String> _authHeaders({Map<String, String>? extra}) {
    final headers = <String, String>{...?extra};
    final token = _supabase.auth.currentSession?.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  String? get _currentUserId {
    final id = _supabase.auth.currentUser?.id?.trim();
    if (id == null || id.isEmpty) {
      return null;
    }
    return id;
  }

  Future<List<Article>> fetchDailyDigest({
    required List<String> topics,
    required String tone,
  }) async {
    final uri = Uri.parse('$_baseUrl/get-daily-digest');
    final userId = _currentUserId;
    final response = await http.post(
      uri,
      headers: _authHeaders(extra: const {'Content-Type': 'application/json'}),
      body: jsonEncode(<String, dynamic>{
        if (userId != null) 'user_id': userId,
        'topics': topics,
        'tone': tone,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to fetch daily digest '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Invalid response format: expected a JSON object.',
      );
    }

    final articlesJson = decoded['articles'];
    if (articlesJson is! List) {
      throw const FormatException(
        'Invalid response format: expected "articles" array.',
      );
    }

    return articlesJson
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException(
              'Invalid article format: expected JSON object.',
            );
          }
          return Article.fromJson(item);
        })
        .toList(growable: false);
  }

  Future<String> fetchDeepDive(String url) async {
    final uri = Uri.parse('$_baseUrl/get-deep-dive').replace(
      queryParameters: <String, String>{'url': url},
    );
    final response = await http.get(uri, headers: _authHeaders());

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to fetch deep dive '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Invalid response format: expected a JSON object.',
      );
    }

    final analysis = decoded['analysis'];
    if (analysis is! String || analysis.trim().isEmpty) {
      throw const FormatException(
        'Invalid response format: expected non-empty "analysis".',
      );
    }
    return analysis;
  }

  Future<List<Article>> fetchDiscoveryNews({
    required List<String> excludedTopics,
    String tone = 'Professional',
    int limit = 5,
  }) async {
    final queryParams = <String, List<String>>{
      'tone': <String>[tone],
      'limit': <String>[limit.toString()],
      'country': <String>['us'],
    };
    final normalizedExcluded = excludedTopics
        .map((topic) => topic.trim())
        .where((topic) => topic.isNotEmpty)
        .toList(growable: false);
    if (normalizedExcluded.isNotEmpty) {
      queryParams['excluded_topics'] = normalizedExcluded;
    }

    final uri = Uri.parse('$_baseUrl/get-discovery-news').replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: _authHeaders());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to fetch discovery news '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    final rawArticles = switch (decoded) {
      List<dynamic> list => list,
      Map<String, dynamic> map when map['articles'] is List => map['articles'] as List<dynamic>,
      _ => throw const FormatException('Invalid response format for discovery news.'),
    };

    return rawArticles
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException(
              'Invalid discovery article format: expected JSON object.',
            );
          }
          return Article.fromJson(item);
        })
        .toList(growable: false);
  }
}
