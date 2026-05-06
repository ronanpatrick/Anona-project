import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/onboarding_state.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const List<String> _sportsTeamSuggestions = <String>[
    'Arsenal',
    'Chelsea',
    'Lakers',
    'Warriors',
    'Yankees',
    'Red Sox',
  ];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _sportsTeamController = TextEditingController();

  List<String> _selectedTopics = <String>[];
  List<String> _selectedSportsTeams = <String>[];
  SummaryTone _summaryTone = SummaryTone.professional;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _sportsTeamController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        Supabase.instance.client
            .from('profiles')
            .select('name,full_name,username')
            .eq('id', user.id)
            .maybeSingle(),
        Supabase.instance.client
            .from('user_preferences')
            .select('selected_topics,summary_tone,sports_teams')
            .eq('id', user.id)
            .maybeSingle(),
      ]);

      final profileRow = results[0] as Map<String, dynamic>?;
      final preferencesRow = results[1] as Map<String, dynamic>?;

      _nameController.text = ((profileRow?['name'] as String?) ??
              (profileRow?['full_name'] as String?) ??
              '')
          .trim();
      _usernameController.text = ((profileRow?['username'] as String?) ?? '').trim();
      _selectedTopics = _parseStringList(preferencesRow?['selected_topics']);
      _selectedSportsTeams = _parseStringList(preferencesRow?['sports_teams']);
      _summaryTone = SummaryTone.fromDbValue(preferencesRow?['summary_tone'] as String?);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $error')),
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

  List<String> _parseStringList(dynamic value) {
    if (value is! List) {
      return <String>[];
    }
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  void _toggleTopic(String topic) {
    setState(() {
      if (_selectedTopics.contains(topic)) {
        _selectedTopics.remove(topic);
      } else {
        _selectedTopics.add(topic);
      }
    });
  }

  void _toggleSportsTeam(String team) {
    setState(() {
      if (_selectedSportsTeams.contains(team)) {
        _selectedSportsTeams.remove(team);
      } else {
        _selectedSportsTeams.add(team);
      }
    });
  }

  void _addCustomSportsTeam() {
    final team = _sportsTeamController.text.trim();
    if (team.isEmpty) {
      return;
    }
    if (_selectedSportsTeams.contains(team)) {
      _sportsTeamController.clear();
      return;
    }
    setState(() {
      _selectedSportsTeams.add(team);
      _sportsTeamController.clear();
    });
  }

  Future<void> _saveChanges() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await Future.wait<dynamic>(<Future<dynamic>>[
        Supabase.instance.client.from('profiles').upsert(
          <String, dynamic>{
            'id': user.id,
            'name': _nameController.text.trim(),
            'username': _usernameController.text.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'id',
        ),
        Supabase.instance.client.from('user_preferences').upsert(
          <String, dynamic>{
            'id': user.id,
            'selected_topics': _selectedTopics,
            'summary_tone': _summaryTone.dbValue,
            'sports_teams': _selectedSportsTeams,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'id',
        ),
      ]);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save changes: $error')),
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Text('User Details', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Edit Personalization',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text('Topics', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: onboardingTopics
                      .map(
                        (topic) => FilterChip(
                          label: Text(topic),
                          selected: _selectedTopics.contains(topic),
                          onSelected: (_) => _toggleTopic(topic),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 16),
                Text('Summary Tone', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<SummaryTone>(
                  segments: SummaryTone.values
                      .map(
                        (tone) => ButtonSegment<SummaryTone>(
                          value: tone,
                          label: Text(tone.label),
                        ),
                      )
                      .toList(growable: false),
                  selected: <SummaryTone>{_summaryTone},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _summaryTone = selection.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Text('Sports Teams', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _sportsTeamSuggestions
                      .map(
                        (team) => FilterChip(
                          label: Text(team),
                          selected: _selectedSportsTeams.contains(team),
                          onSelected: (_) => _toggleSportsTeam(team),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _sportsTeamController,
                        decoration: const InputDecoration(
                          labelText: 'Add custom team',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _addCustomSportsTeam,
                      icon: const Icon(Icons.add),
                      tooltip: 'Add team',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedSportsTeams
                      .map(
                        (team) => Chip(
                          label: Text(team),
                          onDeleted: () => _toggleSportsTeam(team),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  child: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                ),
              ],
            ),
    );
  }
}
