import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/article.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = const ApiService();

  List<Article> _articles = <Article>[];
  final Set<String> _savedArticleKeys = <String>{};
  bool _isLoading = false;
  bool _isDeepDiveLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedArticleKeys();
  }

  Future<void> _fetchDailyDigest() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final articles = await _apiService.fetchDailyDigest(
        topics: const ['Tech', 'AI'],
        tone: 'Casual',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _articles = articles;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load digest: $error'),
        ),
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

  Future<void> _showReadOriginalSheet(Article article) async {
    final entries = <MapEntry<String, String>>[];
    final itemCount = article.sources.length > article.urls.length
        ? article.sources.length
        : article.urls.length;

    for (var index = 0; index < itemCount; index++) {
      final url = index < article.urls.length ? article.urls[index].trim() : '';
      final source = index < article.sources.length
          ? article.sources[index].trim()
          : '';
      entries.add(
        MapEntry<String, String>(
          source.isEmpty ? 'Publisher ${index + 1}' : source,
          url,
        ),
      );
    }

    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No sources available')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: entries
                .map(
                  (entry) => ListTile(
                    leading: const Icon(Icons.open_in_new),
                    title: Text(entry.key),
                    subtitle: Text(
                      entry.value.isEmpty ? 'No URL available' : entry.value,
                    ),
                    onTap: entry.value.isEmpty
                        ? null
                        : () async {
                            Navigator.of(context).pop();
                            await _openExternalUrl(entry.value);
                          },
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );
  }

  Future<void> _showDeepDive(Article article) async {
    final url = _firstValidUrl(article);
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No article URL available')),
      );
      return;
    }

    setState(() {
      _isDeepDiveLoading = true;
    });

    try {
      final analysis = await _apiService.fetchDeepDive(url);
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Comprehensive Read'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: SelectableText(analysis),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load deep dive: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeepDiveLoading = false;
        });
      }
    }
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

  String _sourceSubtitle(Article article) {
    final normalizedSources = article.sources
        .map((source) => source.trim())
        .where((source) => source.isNotEmpty)
        .toList(growable: false);
    if (normalizedSources.isEmpty) {
      return 'Unknown source';
    }

    final primarySource = normalizedSources.first;
    final otherCount = normalizedSources.length - 1;
    if (otherCount <= 0) {
      return primarySource;
    }
    final otherLabel = otherCount == 1 ? 'other' : 'others';
    return '$primarySource and $otherCount $otherLabel';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Already saved.')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved to bookmarks.')));
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

  Widget _buildArticleImage(Article article) {
    final imageUrl = article.imageUrl?.trim() ?? '';
    final imageUri = Uri.tryParse(imageUrl);
    final hasValidImage =
        imageUrl.isNotEmpty && imageUri != null && imageUri.hasScheme && imageUri.host.isNotEmpty;

    if (!hasValidImage) {
      return Container(
        height: 180,
        width: double.infinity,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    return SizedBox(
      height: 180,
      width: double.infinity,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_articles.isEmpty) {
      body = const Center(child: Text('Tap the button to get your news.'));
    } else {
      body = ListView.builder(
        itemCount: _articles.length,
        itemBuilder: (BuildContext context, int index) {
          final article = _articles[index];
          final isSaved = _savedArticleKeys.contains(_articleKey(article));
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildArticleImage(article),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        article.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(_sourceSubtitle(article)),
                      const SizedBox(height: 8),
                      Text(article.summary),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          TextButton(
                            onPressed: () => _showDeepDive(article),
                            child: const Text('Deep Dive'),
                          ),
                          TextButton(
                            onPressed: () => _showReadOriginalSheet(article),
                            child: const Text('Read Original'),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => _saveArticle(article),
                            icon: Icon(
                              isSaved ? Icons.bookmark : Icons.bookmark_border,
                            ),
                            tooltip: isSaved ? 'Saved' : 'Save',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return Stack(
      children: <Widget>[
        Positioned.fill(child: body),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: _isLoading ? null : _fetchDailyDigest,
            child: const Icon(Icons.refresh),
          ),
        ),
        if (_isDeepDiveLoading)
          const Positioned.fill(
            child: Stack(
              children: <Widget>[
                ModalBarrier(dismissible: false, color: Color(0x55000000)),
                Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
      ],
    );
  }
}
