import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/neuro_theme_provider.dart';
import '../models/neuro_profile.dart';
import '../services/firebase_service.dart';

class FocusTimerScreen extends StatefulWidget {
  const FocusTimerScreen({super.key});

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen> {
  // Timer States
  int _focusDuration = 25 * 60; // Default 25 min
  final int _breakDuration = 5 * 60;  // 5 min
  
  late int _secondsRemaining;
  bool _isFocusMode = true; // true = Focus, false = Break
  bool _isRunning = false;
  bool _isNoiseEnabled = false;
  Timer? _timer;
  
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _secondsRemaining = _focusDuration;
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _switchMode();
          }
        });
      });
    }
    setState(() => _isRunning = !_isRunning);
  }

  void _switchMode() {
    // Log the completed focus session to Firebase before switching
    if (_isFocusMode) {
      _logSession();
    }
    setState(() {
      _isFocusMode = !_isFocusMode;
      _secondsRemaining = _isFocusMode ? _focusDuration : _breakDuration;
      _isRunning = false;
    });
    _timer?.cancel();
  }

  /// Log completed focus session to Firebase
  Future<void> _logSession() async {
    final userId = FirebaseService.currentUserId;
    if (userId == null) return;

    final focusMinutes = _focusDuration ~/ 60;
    try {
      await FirebaseService.logStudySession(
        userId: userId,
        durationMinutes: focusMinutes,
        topic: 'Focus Session',
      );
      debugPrint('Study session logged: ${focusMinutes}min');
    } catch (e) {
      debugPrint('Failed to log session: $e');
    }
  }

  void _skipToZero() {
    setState(() {
      _secondsRemaining = 0;
    });
  }

  void _setFocusDuration(int minutes) {
    setState(() {
      _focusDuration = minutes * 60;
      if (_isFocusMode) {
        _secondsRemaining = _focusDuration;
        _isRunning = false;
        _timer?.cancel();
      }
    });
  }

  Future<void> _toggleAudio() async {
    if (_isNoiseEnabled) {
      await _audioPlayer.pause();
      setState(() => _isNoiseEnabled = false);
    } else {
      setState(() => _isNoiseEnabled = true);
      // Play a relaxing rain sound from Google's public action sounds repository
      await _audioPlayer.play(UrlSource('https://actions.google.com/sounds/v1/weather/rain_on_roof.ogg'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<NeuroThemeProvider>(context).activeProfile;
    final stateColor = _isFocusMode ? profile.accentColor : const Color(0xFF4CAF50);

    return Scaffold(
      backgroundColor: profile.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: profile.textColor),
        title: Text(
          _isFocusMode ? 'Focus Time' : 'Sensory Break',
          style: TextStyle(
            fontFamily: profile.fontFamily,
            color: profile.textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (_isFocusMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      double tempVal = (_focusDuration ~/ 60).toDouble();
                      return StatefulBuilder(
                        builder: (context, setDialogState) {
                          return AlertDialog(
                            backgroundColor: profile.cardColor,
                            title: Text('Set Focus Time', style: TextStyle(color: profile.textColor, fontFamily: profile.fontFamily)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${tempVal.toInt()} minutes',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: profile.accentColor,
                                    fontFamily: profile.fontFamily,
                                  ),
                                ),
                                Slider(
                                  value: tempVal,
                                  min: 1,
                                  max: 120,
                                  divisions: 119,
                                  activeColor: profile.accentColor,
                                  onChanged: (val) {
                                    setDialogState(() => tempVal = val);
                                  },
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Cancel', style: TextStyle(color: profile.textColor.withValues(alpha: 0.5))),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: profile.accentColor),
                                onPressed: () {
                                  _setFocusDuration(tempVal.toInt());
                                  Navigator.pop(context);
                                },
                                child: const Text('Set Timer', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
                child: Row(
                  children: [
                    Text(
                      '${_focusDuration ~/ 60} min',
                      style: TextStyle(
                        color: profile.textColor,
                        fontFamily: profile.fontFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.edit_rounded, color: profile.textColor, size: 16),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _isFocusMode
                    ? _buildFocusRing(profile, stateColor)
                    : _buildBreathingCircle(profile, stateColor),
              ),
            ),
            _buildControls(profile, stateColor),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusRing(NeuroProfile profile, Color color) {
    final isAdhd = profile.profileType == NeuroProfileType.adhd;
    double progress = 1 - (_secondsRemaining / _focusDuration);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 250,
              height: 250,
              child: CircularProgressIndicator(
                value: 1.0,
                strokeWidth: isAdhd ? 12 : 20,
                color: profile.cardColor,
              ),
            ),
            SizedBox(
              width: 250,
              height: 250,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: isAdhd ? 12 : 20,
                strokeCap: isAdhd ? StrokeCap.round : StrokeCap.butt,
                color: color,
              ),
            ),
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: profile.cardColor.withValues(alpha: 0.5),
                boxShadow: isAdhd
                    ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 30)]
                    : [],
              ),
              child: isAdhd
                  ? Center(
                      child: Text(
                        '${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: profile.textColor,
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(Icons.waves_rounded, size: 64, color: color.withValues(alpha: 0.5)),
                    ),
            ),
          ],
        ).animate(target: _isRunning ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05)),
        
        const SizedBox(height: 32),
        if (!isAdhd)
          Text(
            'Time is flowing softly...',
            style: TextStyle(
              fontFamily: profile.fontFamily,
              color: profile.textColor.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
      ],
    );
  }

  Widget _buildBreathingCircle(NeuroProfile profile, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')} remaining',
          style: TextStyle(
            fontFamily: profile.fontFamily,
            fontSize: 18,
            color: profile.textColor.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 40),
        Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 4),
          ),
          child: Center(
            child: Text(
              'Breathe',
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: profile.textColor,
              ),
            ),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.3, 1.3),
          duration: 4000.ms,
          curve: Curves.easeInOutSine,
        ),
        const SizedBox(height: 60),
        Text(
          'Inhale deeply, exhale completely.',
          style: TextStyle(
            fontFamily: profile.fontFamily,
            color: profile.textColor.withValues(alpha: 0.7),
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildControls(NeuroProfile profile, Color color) {
    return Column(
      children: [
        // Skip text for testing/convenience
        TextButton(
          onPressed: _isFocusMode ? _skipToZero : _switchMode,
          child: Text(
            _isFocusMode ? 'Debug: Skip to break' : 'End Break Early', 
            style: TextStyle(
              color: _isFocusMode ? profile.textColor.withValues(alpha: 0.3) : color,
              fontWeight: _isFocusMode ? FontWeight.normal : FontWeight.bold,
            )
          ),
        ),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _switchMode,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: profile.cardColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.skip_next_rounded, color: profile.textColor.withValues(alpha: 0.5)),
              ),
            ),
            const SizedBox(width: 24),
            GestureDetector(
              onTap: _toggleTimer,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Icon(
                  _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(width: 24),
            GestureDetector(
              onTap: _toggleAudio,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isNoiseEnabled ? color.withValues(alpha: 0.2) : profile.cardColor,
                  shape: BoxShape.circle,
                  border: _isNoiseEnabled ? Border.all(color: color.withValues(alpha: 0.5)) : null,
                ),
                child: Icon(
                  Icons.headphones_rounded,
                  color: _isNoiseEnabled ? color : profile.textColor.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

