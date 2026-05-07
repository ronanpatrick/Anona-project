import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  final ApiService _apiService = const ApiService();
  final SupabaseClient _client = Supabase.instance.client;

  final List<_SavedFolderSection> _sections = <_SavedFolderSection>[];
  RealtimeChannel? _savedChannel;

  bool _isLoading = false;
  bool _isDeepDiveLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedSummaries();
    _subscribeToSavedChanges();
  }

  @override
  void dispose() {
    final channel = _savedChannel;
    if (channel != null) {
      _client.removeChannel(channel);
    }
    super.dispose();
  }

  void _subscribeToSavedChanges() {
    final user = _client.auth.currentUser;
    if (user == null) {
      return;
    }

    _savedChannel = _client
        .channel('saved-summaries-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'saved_summaries',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (_) => _loadSavedSummaries(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'folders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (_) => _loadSavedSummaries(),
        )
        .subscribe();
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

  String _parseTitle(Map<String, dynamic> row) {
    final direct = (row['title'] as String? ?? '').trim();
    if (direct.isNotEmpty) {
      return direct;
    }
    final titles = _parseStringList(row['titles']);
    if (titles.isNotEmpty) {
      return titles.first;
    }
    return 'Saved summary';
  }

  String? _parseImageUrl(Map<String, dynamic> row) {
    final imageUrl = (row['image_url'] as String? ?? '').trim();
    if (imageUrl.isNotEmpty) {
      return imageUrl;
    }
    final fallback = (row['imageUrl'] as String? ?? '').trim();
    return fallback.isEmpty ? null : fallback;
  }

  String _folderNameForId(Map<String, String> folderMap, String folderId) {
    final trimmedId = folderId.trim();
    if (trimmedId.isEmpty) {
      return 'Uncategorized';
    }
    final name = (folderMap[trimmedId] ?? '').trim();
    return name.isEmpty ? 'Uncategorized' : name;
  }

  Future<void> _loadSavedSummaries() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sections.clear();
        _errorMessage = 'Sign in to view saved summaries.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final foldersResponse = await _client
          .from('folders')
          .select('id,name')
          .eq('user_id', user.id)
          .order('name');
      final savedResponse = await _client
          .from('saved_summaries')
          .select('id,folder_id,title,titles,summary,sources,urls,image_url,created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final folderMap = <String, String>{};
      for (final row in foldersResponse.whereType<Map<String, dynamic>>()) {
        final id = (row['id'] as String? ?? '').trim();
        final name = (row['name'] as String? ?? '').trim();
        if (id.isNotEmpty) {
          folderMap[id] = name.isEmpty ? 'Untitled folder' : name;
        }
      }
    
      final byFolder = <String, List<_SavedSummaryItem>>{};
      for (final row in savedResponse.whereType<Map<String, dynamic>>()) {
        final folderId = (row['folder_id'] as String? ?? '').trim();
        final folderName = _folderNameForId(folderMap, folderId);
        final item = _SavedSummaryItem(
          id: (row['id'] as String? ?? '').trim(),
          title: _parseTitle(row),
          summary: (row['summary'] as String? ?? '').trim(),
          sources: _parseStringList(row['sources']),
          urls: _parseStringList(row['urls']),
          imageUrl: _parseImageUrl(row),
          folderId: folderId,
        );
        byFolder.putIfAbsent(folderName, () => <_SavedSummaryItem>[]).add(item);
      }
    
      final sections = byFolder.entries
          .map(
            (entry) => _SavedFolderSection(
              folderName: entry.key,
              items: entry.value,
            ),
          )
          .toList(growable: false);
      sections.sort(
        (a, b) => a.folderName.toLowerCase().compareTo(b.folderName.toLowerCase()),
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _sections
          ..clear()
          ..addAll(sections);
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load saved summaries: ${error.message}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load saved summaries: $error';
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

  Future<void> _showReadOriginalSheet(_SavedSummaryItem item) async {
    if (item.urls.isEmpty) {
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
            children: item.urls
                .asMap()
                .entries
                .map(
                  (entry) => ListTile(
                    leading: const Icon(Icons.open_in_new),
                    title: Text('Source ${entry.key + 1}'),
                    subtitle: Text(entry.value),
                    onTap: () async {
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

  String _firstValidUrl(_SavedSummaryItem item) {
    for (final url in item.urls) {
      final trimmed = url.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }

  Future<void> _showDeepDive(_SavedSummaryItem item) async {
    final url = _firstValidUrl(item);
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No article URL available for Deep Dive')),
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
      if (!mounted) {
        return;
      }
      setState(() {
        _isDeepDiveLoading = false;
      });
    }
  }

  Widget _buildImage(String? imageUrl) {
    final normalized = imageUrl?.trim() ?? '';
    final parsed = Uri.tryParse(normalized);
    final hasValidImage =
        normalized.isNotEmpty && parsed != null && parsed.hasScheme && parsed.host.isNotEmpty;
    if (!hasValidImage) {
      return Container(
        height: 120,
        width: 120,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          Icons.image_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Image.network(
      normalized,
      height: 120,
      width: 120,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: 120,
        width: 120,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Future<void> _openSavedSummary(_SavedSummaryItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        final mediaQuery = MediaQuery.of(context);
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: mediaQuery.viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(item.summary),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: item.sources
                      .map((source) => Chip(label: Text(source)))
                      .toList(growable: false),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: () => _showDeepDive(item),
                      child: const Text('Deep Dive'),
                    ),
                    TextButton(
                      onPressed: () => _showReadOriginalSheet(item),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.bookmark_add_outlined,
              size: 90,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No saved articles yet',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Tap the bookmark icon on any Home card to save summaries here by folder.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (_sections.isEmpty) {
      body = _buildEmptyState();
    } else {
      body = RefreshIndicator(
        onRefresh: _loadSavedSummaries,
        child: ListView.builder(
          itemCount: _sections.length,
          itemBuilder: (BuildContext context, int sectionIndex) {
            final section = _sections[sectionIndex];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Text(
                    section.folderName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...section.items.map(
                  (item) => Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: InkWell(
                      onTap: () => _openSavedSummary(item),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _buildImage(item.imageUrl),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.summary,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return Stack(
      children: <Widget>[
        Positioned.fill(child: body),
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

class _SavedFolderSection {
  const _SavedFolderSection({
    required this.folderName,
    required this.items,
  });

  final String folderName;
  final List<_SavedSummaryItem> items;
}

class _SavedSummaryItem {
  const _SavedSummaryItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.sources,
    required this.urls,
    required this.imageUrl,
    required this.folderId,
  });

  final String id;
  final String title;
  final String summary;
  final List<String> sources;
  final List<String> urls;
  final String? imageUrl;
  final String folderId;
}
