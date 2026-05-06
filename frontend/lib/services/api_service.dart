import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/article.dart';
import 'platform_info_stub.dart'
    if (dart.library.io) 'platform_info_io.dart' as platform_info;

class ApiService {
  const ApiService();

  String get _baseUrl {
    if (platform_info.isAndroid) {
      return 'http://10.0.2.2:8000';
    }

    if (kIsWeb || platform_info.isIOS) {
      return 'http://127.0.0.1:8000';
    }

    return 'http://127.0.0.1:8000';
  }

  Future<List<Article>> fetchDailyDigest({
    required List<String> topics,
    required String tone,
  }) async {
    final uri = Uri.parse('$_baseUrl/get-daily-digest');
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(<String, dynamic>{
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
    final response = await http.get(uri);

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
}
