import 'dart:ui';

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
      final preferences = await _loadUserPreferences();
      final topics = preferences.topics;
      final tone = preferences.tone;
      
      debugPrint('PROV: Pulling topics from state: $topics, tone: $tone');
      
      final digestFuture = _apiService.fetchDailyDigest(
        topics: topics,
        tone: tone,
      );
      final discoveryFuture = _apiService.fetchDiscoveryNews(
        excludedTopics: topics,
        tone: tone,
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

  Future<({List<String> topics, String tone})> _loadUserPreferences() async {
    const defaultTopics = <String>['World News'];
    const defaultTone = 'analyst';
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return (topics: defaultTopics, tone: defaultTone);
    }

    try {
      final row = await Supabase.instance.client
          .from('user_preferences')
          .select('selected_topics, summary_tone')
          .eq('id', user.id)
          .maybeSingle();
      if (row == null) {
        return (topics: defaultTopics, tone: defaultTone);
      }
      
      final topicValues = row['selected_topics'];
      final rawTone = row['summary_tone'] as String?;
      
      final topics = (topicValues is List)
          ? topicValues
              .whereType<String>()
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false)
          : defaultTopics;
          
      // Validate tone against allowed values
      const allowedTones = ['executive', 'analyst', 'conversationalist', 'layman'];
      final tone = (rawTone != null && allowedTones.contains(rawTone.toLowerCase()))
          ? rawTone.toLowerCase()
          : defaultTone;

      return (topics: topics.isEmpty ? defaultTopics : topics, tone: tone);
    } catch (_) {
      return (topics: defaultTopics, tone: defaultTone);
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
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  article.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(source, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                Text(
                  article.summary,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                Row(
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: isSaved ? null : () {
                        _saveArticle(article);
                        Navigator.pop(context);
                      },
                      icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
                      label: Text(isSaved ? 'Saved' : 'Save'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: sourceUrl.isEmpty ? null : () => _openExternalUrl(sourceUrl),
                        child: const Text('Read Original'),
                      ),
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

  Widget _buildNarrativeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_digestArticles.isEmpty)
          const Text('No digest headlines yet.')
        else
          ..._digestArticles.map((Article article) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 12),
                  child: Icon(Icons.circle, size: 8, color: Theme.of(context).colorScheme.primary),
                ),
                Expanded(
                  child: Text(
                    article.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
          )),
      ],
    );
  }

  Widget _buildDiscoverySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 40),
        Text(
          'Discovery',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        if (_discoveryArticles.isEmpty)
          const Text('No discovery stories available right now.')
        else
          ..._discoveryArticles.map((Article article) => Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: GestureDetector(
              onTap: () => _showDiscoverySheet(article),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      article.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_outward, size: 16, color: Theme.of(context).colorScheme.primary),
                ],
              ),
            ),
          )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _digestArticles.isEmpty && _discoveryArticles.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadBriefingData,
          color: Theme.of(context).colorScheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AudioBriefingPlayer(
                  isLoading: _isLoading,
                  isSpeaking: _isSpeaking,
                  isPaused: _isPaused,
                  onTogglePlayback: _togglePlayback,
                ),
                _buildNarrativeSection(context),
                _buildDiscoverySection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AudioBriefingPlayer extends StatelessWidget {
  final bool isLoading;
  final bool isSpeaking;
  final bool isPaused;
  final VoidCallback onTogglePlayback;

  const AudioBriefingPlayer({
    super.key,
    required this.isLoading,
    required this.isSpeaking,
    required this.isPaused,
    required this.onTogglePlayback,
  });

  @override
  Widget build(BuildContext context) {
    final bool showPauseState = isSpeaking && !isPaused;
    return Column(
      children: <Widget>[
        const SizedBox(height: 32),
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              iconSize: 64,
              color: Theme.of(context).colorScheme.onPrimary,
              icon: Icon(showPauseState ? Icons.pause : Icons.play_arrow),
              onPressed: isLoading ? null : onTogglePlayback,
            ),
          ),
        ),
        const SizedBox(height: 24),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: isSpeaking ? 0.3 : 0.0,
            onChanged: (double value) {},
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('0:00', style: Theme.of(context).textTheme.bodySmall),
            Text('5:00', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(height: 32),
      ],
    );
  }
}
