import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';

class AudioBriefingPlayer extends StatefulWidget {
  const AudioBriefingPlayer({
    required this.narrationText,
    super.key,
    this.title = 'Audio Briefing',
    this.subtitle = 'Listen to this story summary',
  });

  final String narrationText;
  final String title;
  final String subtitle;

  @override
  State<AudioBriefingPlayer> createState() => _AudioBriefingPlayerState();
}

class _AudioBriefingPlayerState extends State<AudioBriefingPlayer>
    with SingleTickerProviderStateMixin {
  final FlutterTts _flutterTts = FlutterTts();

  bool _isSpeaking = false;
  bool _isPaused = false;
  double? _configuredAudioSpeed;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _initializeTts();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _initializeTts() async {
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      if (!mounted) return;
      setState(() { _isSpeaking = true; _isPaused = false; });
    });
    _flutterTts.setPauseHandler(() {
      if (!mounted) return;
      setState(() => _isPaused = true);
    });
    _flutterTts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() { _isSpeaking = false; _isPaused = false; });
    });
    _flutterTts.setCancelHandler(() {
      if (!mounted) return;
      setState(() { _isSpeaking = false; _isPaused = false; });
    });
    _flutterTts.setErrorHandler((_) {
      if (!mounted) return;
      setState(() { _isSpeaking = false; _isPaused = false; });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final speed = Provider.of<SettingsProvider>(context).audioSpeed;
    if (_configuredAudioSpeed == speed) return;
    _configuredAudioSpeed = speed;
    _flutterTts.setSpeechRate((0.45 * speed).clamp(0.1, 1.0).toDouble());
  }

  Future<void> _togglePlayback() async {
    final narration = widget.narrationText.trim();
    if (narration.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No summary content available for audio.')),
      );
      return;
    }

    if (_isSpeaking && !_isPaused) {
      await _flutterTts.pause();
      if (!mounted) return;
      setState(() => _isPaused = true);
      return;
    }

    await _flutterTts.stop();
    await _flutterTts.speak(narration);
    if (!mounted) return;
    setState(() { _isSpeaking = true; _isPaused = false; });
  }

  @override
  Widget build(BuildContext context) {
    final showPause = _isSpeaking && !_isPaused;
    final cs        = Theme.of(context).colorScheme;
    final tt        = Theme.of(context).textTheme;
    final isDark    = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.07)
                : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.black.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              // Animated waveform icon
              ScaleTransition(
                scale: _isSpeaking && !_isPaused ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isSpeaking
                        ? (showPause ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded)
                        : Icons.headphones_rounded,
                    color: cs.primary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      widget.title,
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _isSpeaking
                          ? (showPause ? 'Playing…' : 'Paused')
                          : widget.subtitle,
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Play / Pause pill button
              GestureDetector(
                onTap: _togglePlayback,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: showPause ? cs.primary : cs.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        showPause ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 18,
                        color: showPause ? Colors.white : cs.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        showPause ? 'Pause' : 'Play',
                        style: tt.labelMedium?.copyWith(
                          color: showPause ? Colors.white : cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
