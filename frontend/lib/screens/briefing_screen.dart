import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/article.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';

class BriefingScreen extends StatefulWidget {
  const BriefingScreen({super.key});

  @override
  State<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends State<BriefingScreen> {
  final ApiService _apiService = const ApiService();
  final FlutterTts _flutterTts = FlutterTts();

  final Set<String> _savedArticleKeys = <String>{};
  List<Article> _digestArticles = <Article>[];
  List<Article> _discoveryArticles = <Article>[];

  bool _isLoading = false;
  bool _isSpeaking = false;
  bool _isPaused = false;
  double? _configuredAudioSpeed;

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _loadSavedArticleKeys();
    _loadBriefingData();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initializeTts() async {
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSpeaking = true;
        _isPaused = false;
      });
    });
    _flutterTts.setPauseHandler(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPaused = true;
      });
    });
    _flutterTts.setCompletionHandler(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSpeaking = false;
        _isPaused = false;
      });
    });
    _flutterTts.setCancelHandler(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSpeaking = false;
        _isPaused = false;
      });
    });
    _flutterTts.setErrorHandler((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSpeaking = false;
        _isPaused = false;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final speedFactor = Provider.of<SettingsProvider>(context).audioSpeed;
    if (_configuredAudioSpeed == speedFactor) {
      return;
    }
    _configuredAudioSpeed = speedFactor;
    _flutterTts.setSpeechRate((0.45 * speedFactor).clamp(0.1, 1.0).toDouble());
  }

  Future<void> _loadBriefingData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final discoveryExclusions = await _loadDiscoveryExclusions();
      final digestFuture = _apiService.fetchDailyDigest(
        topics: const <String>['Tech', 'AI'],
        tone: 'Casual',
      );
      final discoveryFuture = _apiService.fetchDiscoveryNews(
        excludedTopics: discoveryExclusions,
      );
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        digestFuture,
        discoveryFuture,
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _digestArticles = results[0] as List<Article>;
        _discoveryArticles = results[1] as List<Article>;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load briefing: $error')),
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<String>> _loadDiscoveryExclusions() async {
    final defaults = <String>['Tech', 'AI'];
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return defaults;
    }

    try {
      final row = await Supabase.instance.client
          .from('user_preferences')
          .select('selected_topics')
          .eq('id', user.id)
          .maybeSingle();
      if (row == null) {
        return defaults;
      }
      final topicValues = row['selected_topics'];
      if (topicValues is! List) {
        return defaults;
      }
      final topics = topicValues
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      if (topics.isEmpty) {
        return defaults;
      }
      return topics;
    } catch (_) {
      return defaults;
    }
  }

  String _ttsText() {
    if (_digestArticles.isEmpty) {
      return '';
    }
    return _digestArticles
        .map(
          (article) =>
              '${article.title}. ${article.summary.replaceAll(RegExp(r'[-*•]\s*'), ' ').replaceAll('\n', ' ')}',
        )
        .join(' ');
  }

  Future<void> _togglePlayback() async {
    final narration = _ttsText().trim();
    if (narration.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No digest content available for audio.')),
      );
      return;
    }

    if (_isSpeaking && !_isPaused) {
      await _flutterTts.pause();
      if (!mounted) {
        return;
      }
      setState(() {
        _isPaused = true;
      });
      return;
    }

    await _flutterTts.stop();
    await _flutterTts.speak(narration);
    if (!mounted) {
      return;
    }
    setState(() {
      _isSpeaking = true;
      _isPaused = false;
    });
  }

  String _firstValidUrl(Article article) {
    for (final url in article.urls) {
      final trimmed = url.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }

  String _articleKey(Article article) {
    final firstUrl = _firstValidUrl(article);
    if (firstUrl.isNotEmpty) {
      return 'url:$firstUrl';
    }
    return 'title:${article.title.trim().toLowerCase()}';
  }

  List<String> _parseStringList(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? <String>[] : <String>[trimmed];
    }
    if (value is List) {
      return value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return <String>[];
  }

  String _parseFirstTitle(dynamic row) {
    if (row is! Map<String, dynamic>) {
      return '';
    }
    final title = (row['title'] as String? ?? '').trim();
    if (title.isNotEmpty) {
      return title.toLowerCase();
    }
    final titles = _parseStringList(row['titles']);
    if (titles.isNotEmpty) {
      return titles.first.toLowerCase();
    }
    return '';
  }

  Future<void> _loadSavedArticleKeys() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      final rows = await Supabase.instance.client
          .from('saved_summaries')
          .select('title,titles,urls')
          .eq('user_id', user.id);
      final keys = <String>{};
      if (rows is List) {
        for (final item in rows.whereType<Map<String, dynamic>>()) {
          final urls = _parseStringList(item['urls']);
          if (urls.isNotEmpty) {
            keys.add('url:${urls.first}');
            continue;
          }
          final title = _parseFirstTitle(item);
          if (title.isNotEmpty) {
            keys.add('title:$title');
          }
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _savedArticleKeys
          ..clear()
          ..addAll(keys);
      });
    } catch (_) {
      return;
    }
  }

  Future<String> _getOrCreateDefaultFolderId(String userId) async {
    final client = Supabase.instance.client;
    final existing = await client
        .from('folders')
        .select('id')
        .eq('user_id', userId)
        .order('created_at')
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      final folderId = (existing['id'] as String? ?? '').trim();
      if (folderId.isNotEmpty) {
        return folderId;
      }
    }

    final created = await client
        .from('folders')
        .insert(<String, dynamic>{
          'user_id': userId,
          'name': 'Saved',
        })
        .select('id')
        .single();
    final folderId = (created['id'] as String? ?? '').trim();
    if (folderId.isEmpty) {
      throw const FormatException('Failed to create a default folder.');
    }
    return folderId;
  }

  Future<void> _saveArticle(Article article) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save articles.')),
      );
      return;
    }

    final key = _articleKey(article);
    if (_savedArticleKeys.contains(key)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already saved.')),
      );
      return;
    }

    try {
      final folderId = await _getOrCreateDefaultFolderId(user.id);
      final payload = <String, dynamic>{
        'user_id': user.id,
        'folder_id': folderId,
        'summary': article.summary,
        'titles': <String>[article.title],
        'sources': article.sources,
        'urls': article.urls,
        'image_url': article.imageUrl,
      }..removeWhere((_, value) => value == null);

      await Supabase.instance.client.from('saved_summaries').insert(payload);
      if (!mounted) {
        return;
      }
      setState(() {
        _savedArticleKeys.add(key);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to bookmarks.')),
      );
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: ${error.message}')),
      );
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $error')),
      );
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid source URL')),
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open source URL')),
      );
    }
  }

  Future<void> _showDiscoverySheet(Article article) async {
    final isSaved = _savedArticleKeys.contains(_articleKey(article));
    final source = article.sources.isNotEmpty ? article.sources.first : 'Unknown source';
    final sourceUrl = _firstValidUrl(article);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  article.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(source),
                const SizedBox(height: 12),
                Text(article.summary),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: isSaved ? null : () => _saveArticle(article),
                      icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
                      tooltip: isSaved ? 'Saved' : 'Save',
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: sourceUrl.isEmpty ? null : () => _openExternalUrl(sourceUrl),
                      child: const Text('Read Original'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPodcastHeader(BuildContext context) {
    final bool showPauseState = _isSpeaking && !_isPaused;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.podcasts, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Daily Briefing Audio',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text('Listen to your digest summaries'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _isLoading ? null : _togglePlayback,
            icon: Icon(showPauseState ? Icons.pause : Icons.play_arrow),
            label: Text(showPauseState ? 'Pause' : 'Play'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _digestArticles.isEmpty && _discoveryArticles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadBriefingData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildPodcastHeader(context),
          const SizedBox(height: 20),
          Text(
            'Today\'s Headlines',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (_digestArticles.isEmpty)
            const Text('No digest headlines yet.')
          else
            ..._digestArticles.map(
              (article) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• ${article.title}'),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            'Discovery',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (_discoveryArticles.isEmpty)
            const Text('No discovery stories available right now.')
          else
            ..._discoveryArticles.map(
              (article) => Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _showDiscoverySheet(article),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),
                  child: Text(
                    article.title,
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
