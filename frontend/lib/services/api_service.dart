import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/article.dart';
import '../models/market_snapshot_item.dart';
import '../models/sports_scoreboard.dart';
import 'platform_info_stub.dart'
    if (dart.library.io) 'platform_info_io.dart' as platform_info;

class ApiService {
  const ApiService();

  SupabaseClient get _supabase => Supabase.instance.client;

  String get _baseUrl {
    return 'https://anona-project.onrender.com';
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
    final id = _supabase.auth.currentUser?.id.trim();
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
    final requestBody = <String, dynamic>{
      if (userId != null) 'user_id': userId,
      'selected_topics': topics,
      'summary_tone': tone,
    };
    debugPrint('DEBUG: Frontend is requesting topics: ${requestBody['selected_topics']}');
    final response = await http.post(
      uri,
      headers: _authHeaders(extra: const {'Content-Type': 'application/json'}),
      body: jsonEncode(requestBody),
    );
    debugPrint('DEBUG Raw News Response: ${response.body}');

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

    try {
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
    } catch (e) {
      debugPrint('DEBUG JSON Parse Error: $e');
      rethrow;
    }
  }

  Future<String> fetchDeepDive(String url, {String? fallbackText}) async {
    final uri = Uri.parse('$_baseUrl/get-deep-dive').replace(
      queryParameters: <String, String>{
        'url': url,
        if (fallbackText != null && fallbackText.isNotEmpty) 'fallback_text': fallbackText,
      },
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
    String tone = 'analyst',
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

  Future<List<MarketSnapshotItem>> fetchMarketSnapshot() async {
    final userId = _currentUserId;
    final baseUri = Uri.parse('$_baseUrl/get-market-snapshot');
    final uri = userId == null
        ? baseUri
        : baseUri.replace(queryParameters: <String, String>{'user_id': userId});

    final response = await http.get(uri, headers: _authHeaders());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to fetch market snapshot '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException(
        'Invalid response format: expected market snapshot list.',
      );
    }

    return decoded
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException(
              'Invalid market item format: expected JSON object.',
            );
          }
          return MarketSnapshotItem.fromJson(item);
        })
        .toList(growable: false);
  }

  Future<SportsScoreboard> fetchSportsScoreboard() async {
    final userId = _currentUserId;
    final baseUri = Uri.parse('$_baseUrl/get-sports-scoreboard');
    final uri = userId == null
        ? baseUri
        : baseUri.replace(queryParameters: <String, String>{'user_id': userId});

    final response = await http.get(uri, headers: _authHeaders());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to fetch sports scoreboard '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Invalid response format: expected sports scoreboard object.',
      );
    }

    return SportsScoreboard.fromJson(decoded);
  }

  Future<void> deleteAccount() async {
    final uri = Uri.parse('$_baseUrl/delete-account');
    final response = await http.delete(uri, headers: _authHeaders());

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to delete account '
        '(${response.statusCode}): ${response.body}',
      );
    }
  }
}
