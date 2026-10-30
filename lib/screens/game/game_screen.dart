import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flame/game.dart' hide Matrix4;
import 'package:provider/provider.dart';
import '../../widgets/unified_banner_ad.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';

import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../data/models/arrow.dart';
import '../../data/models/level.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/repositories/level_repository.dart';
import '../../ads/ad_manager.dart';
import '../../game/arrow_puzzle_game.dart';
import '../../game/game_state.dart';
import '../../widgets/lives_bar.dart';
import '../../widgets/wavy_progress_bar.dart';
import '../../widgets/app_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/audio_manager.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late LevelModel _level;
  late ArrowPuzzleGame _game;
  GameState? _gameState;
  late ConfettiController _confettiController;
  bool _showingGameOver = false;
  bool _showingComplete = false;
  bool _showingDeadlock = false;
  bool _inspectingDeadlock = false;
  int _lives = AppConstants.maxLives;
  int? _loadedLevelNum;
  bool _isLoadingLevel = false; // true while level is being generated async

  // Timer fields
  Timer? _levelTimer;
  int _timeRemaining = 0;
  int _totalTime = 0;
  bool _isTimeoutState = false;
  bool _isGamePaused = false;
  bool _isAppBackgrounded = false;
  String? _challengeDate;
  bool _isTournament = false;
  int _tournamentTimeLimit = 0;
  bool _hintBusy = false;

  late final TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 4));
    _transformationController = TransformationController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final levelNum = args?['level'] as int? ?? 1;
    _challengeDate = args?['challengeDate'] as String?;
    _isTournament = args?['mode'] == 'tournament';
    _tournamentTimeLimit = args?['timeLimit'] as int? ?? 0;
    if (_loadedLevelNum != levelNum) {
      _loadedLevelNum = levelNum;
      _loadLevelAsync(levelNum);
    }
  }

  Future<void> _loadLevelAsync(int levelNum) async {
    final levelRepo = context.read<LevelRepository>();

    // If level is already cached, load it instantly with no spinner.
    if (levelRepo.isCached(levelNum)) {
      _level = levelRepo.getLevel(levelNum);
      _initGame();
      // Pre-warm next levels off the UI thread
      levelRepo.preGenerateRangeAsync(levelNum + 1, 5);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showTutorialDialogIfNeeded(levelNum);
      });
      return;
    }

    // Level not cached — show loading overlay and generate in background isolate
    if (mounted) setState(() => _isLoadingLevel = true);

    try {
      final level = await levelRepo.getLevelAsync(levelNum);
      if (!mounted) return;
      _level = level;
      _initGame();
      setState(() => _isLoadingLevel = false);

      // Pre-warm next levels off the UI thread
      levelRepo.preGenerateRangeAsync(levelNum + 1, 5);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showTutorialDialogIfNeeded(levelNum);
      });
    } catch (_) {
      // Fallback: generate synchronously if async fails
      if (!mounted) return;
      _level = levelRepo.getLevel(levelNum);
      _initGame();
      if (mounted) setState(() => _isLoadingLevel = false);
    }
  }

  void _initGame() {
    _lives = AppConstants.maxLives;
    _showingGameOver = false;
    _showingDeadlock = false;
    _inspectingDeadlock = false;
    _transformationController.value = Matrix4.identity();
    _gameState?.removeListener(_onGameStateChanged);
    _gameState = GameState(
      level: _level,
      onLevelComplete: _onLevelComplete,
      onGameOver: _onGameOver,
      onLifeLost: _onLifeLost,
      onDeadlock: _onDeadlock,
    );
    _gameState!.addListener(_onGameStateChanged);

    _game = ArrowPuzzleGame(
      level: _level,
      gameState: _gameState!,
      onLevelComplete: _onLevelComplete,
      onGameOver: _onGameOver,
      onLifeLost: _onLifeLost,
    );

    _resetTimerForLevel();
  }

  void _onGameStateChanged() {
    if (!mounted) return;
    setState(() {
      _lives = _gameState!.lives;
    });
  }

  void _onLifeLost() {
    if (!mounted) return;
    setState(() => _lives = _gameState!.lives);
    AudioManager.instance.playLifeLost();
    if (context.read<ProgressRepository>().vibrationEnabled) {
      HapticFeedback.heavyImpact();
    }
  }

  void _onLevelComplete() {
    if (!mounted || _showingComplete) return;
    _levelTimer?.cancel();
    setState(() => _showingComplete = true);
    AudioManager.instance.playLevelComplete();
    if (context.read<ProgressRepository>().vibrationEnabled) {
      HapticFeedback.lightImpact();
    }

    final progress = context.read<ProgressRepository>();
    final adManager = context.read<AdManager>();
    final stars = ProgressRepository.calculateStars(
        _gameState!.livesLost, _level.totalArrows, _gameState!.movesUsed);
    final score =
        AppConstants.baseScore + (_lives * AppConstants.bonusPerRemainingLife);

    final result = LevelResult(
      levelNumber: _level.levelNumber,
      stars: stars,
      score: score,
      movesUsed: _gameState!.movesUsed,
      livesLost: _gameState!.livesLost,
      completed: true,
      completedAt: DateTime.now(),
    );
    final challengeDate = _challengeDate == null ? null : DateTime.tryParse(_challengeDate!);
    if (challengeDate != null) {
      progress.recordDailyChallenge(challengeDate, stars, score);
    } else if (_isTournament) {
      progress.recordTournamentBest(_level.levelNumber, _totalTime - _timeRemaining);
      progress.addCoins(score);
    } else {
      progress.recordLevelComplete(result);
      final levelType = AppConstants.levelTypeFor(_level.levelNumber);
      adManager.onLevelComplete(_level.levelNumber, levelType.isSpecial);
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _confettiController.play();
        if (context.read<ProgressRepository>().vibrationEnabled) {
          Future.forEach(List.generate(6, (i) => i * 150), (delay) async {
            await Future.delayed(Duration(milliseconds: delay == 0 ? 0 : 150));
            if (mounted && _showingComplete) {
              HapticFeedback.lightImpact();
            }
          });
        }
        _showLevelCompleteDialog(stars, score);
      }
    });
  }

  void _onGameOver() {
    if (!mounted || _showingGameOver) return;
    setState(() => _showingGameOver = true);
    if (context.read<ProgressRepository>().vibrationEnabled) {
      HapticFeedback.vibrate();
    }
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _showGameOverDialog();
    });
  }

  void _onDeadlock() {
    if (!mounted || _showingDeadlock || _showingGameOver || _showingComplete)
      return;
    _levelTimer?.cancel();
    setState(() {
      _showingDeadlock = true;
      _inspectingDeadlock = false;
    });
    if (context.read<ProgressRepository>().vibrationEnabled) {
      HapticFeedback.vibrate();
    }
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _showDeadlockDialog();
    });
  }

  Future<void> _showDeadlockDialog() async {
    _gameState?.setPaused(true);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeadlockDialog(
        level: _level,
        onRestart: () {
          Navigator.pop(context);
          _handleRestart(confirm: false);
        },
        onMenu: _handleMenu,
        onInspect: () {
          Navigator.pop(context);
          setState(() {
            _inspectingDeadlock = true;
          });
        },
      ),
    );
    if (mounted && _inspectingDeadlock) _pauseGame(false);
  }

  Future<void> _handleRestart({bool confirm = true}) async {
    if (confirm && (_gameState?.movesUsed ?? 0) > 0 && !_showingComplete && !_showingGameOver) {
      _pauseGame(true);
      final restart = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          title: Text('Start fresh?', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink)),
          content: Text('This board will reset and your three hearts will be restored.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep playing')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restart')),
          ],
        ),
      );
      if (!mounted) return;
      _pauseGame(false);
      if (restart != true) return;
    }
    final totalArrows = _level.arrows.length;
    final activeArrows =
        _gameState?.arrows.where((a) => a.state != ArrowState.sliding).length ??
            totalArrows;
    final clearedArrows = totalArrows - activeArrows;
    final progressVal =
        totalArrows > 0 ? (clearedArrows / totalArrows).clamp(0.0, 1.0) : 0.0;

    if (progressVal >= 0.8) {
      final adManager = context.read<AdManager>();
      await adManager.showInterstitial();
    }

    if (mounted) {
      setState(() {
        _showingGameOver = false;
        _showingComplete = false;
        _showingDeadlock = false;
        _inspectingDeadlock = false;
        _isGamePaused = false;
        _transformationController.value = Matrix4.identity();
        _game.resetLevel();
        _lives = AppConstants.maxLives;
        _resetTimerForLevel();
      });
    }
  }

  Future<void> _showSettingsDialog() async {
    _pauseGame(true);
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _GameSettingsDialog(
        onRestart: () {
          Navigator.pop(context);
          _handleRestart(confirm: false);
        },
      ),
    );
    if (mounted) _pauseGame(false);
  }

  void _pauseGame(bool paused) {
    setState(() => _isGamePaused = paused);
    _gameState?.setPaused(paused);
  }

  void _revealHint() {
    if (!mounted || _gameState == null) return;
    if (_game.showHint()) {
      showAppMessage(context, 'Follow the mint glow. This arrow has a clear exit.');
      if (context.read<ProgressRepository>().vibrationEnabled) HapticFeedback.selectionClick();
    } else {
      showAppMessage(context, 'No clear exit yet. Try restarting for a fresh board.');
    }
  }

  void _requestHint() {
    if (_hintBusy || _isGamePaused || _showingComplete || _showingGameOver) return;
    if (AppConstants.enableAdMob || AppConstants.enableUnityAds) {
      setState(() => _hintBusy = true);
      _pauseGame(true);
      context.read<AdManager>().showRewardedWithLoader(context,
        onRewarded: _revealHint,
        onDismissed: () {
          if (!mounted) return;
          setState(() => _hintBusy = false);
          _pauseGame(false);
        });
    } else {
      _revealHint();
    }
  }

  Future<void> _showHelp() async {
    _pauseGame(true);
    await showAppSheet(context, title: 'Make a little space', child: Column(children: [
      _helpRow(LucideIcons.mousePointer2, 'Tap an arrow', 'If its path is clear, it slides out. Clear every arrow to finish.'),
      _helpRow(LucideIcons.heart, 'Look before you tap', 'A blocked arrow costs one heart. You have three per board.'),
      _helpRow(LucideIcons.lightbulb, 'Need a nudge?', 'The hint button gives a legal arrow a mint glow. Hold an arrow to preview its path.'),
      _helpRow(LucideIcons.zoomIn, 'Get a closer look', 'Pinch to zoom, drag to pan, or use the zoom controls. Colored pairs leave together; gold dots redirect arrows.'),
      const SizedBox(height: 10),
      AppButton(label: 'Got it', onPressed: () => Navigator.pop(context)),
    ]));
    if (mounted) _pauseGame(false);
  }

  Widget _helpRow(IconData icon, String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: AppColors.primary, size: 25),
      const SizedBox(width: 15),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink)),
        const SizedBox(height: 4),
        Text(body, style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary)),
      ])),
    ]),
  );

  void _zoomBy(double factor) {
    final scale = (_transformationController.value.getMaxScaleOnAxis() * factor).clamp(0.8, 4.0);
    _transformationController.value = Matrix4.diagonal3Values(scale, scale, 1);
  }

  void _handleNextLevel() {
    Navigator.pop(context);
    _exitCompletedLevel();
  }

  /// Called after the completion dialog has already been dismissed.
  void _exitCompletedLevel() {
    if (_isTournament || _challengeDate != null) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacementNamed(context, '/game',
      arguments: {'level': _level.levelNumber + 1});
  }

  void _handleMenu() {
    Navigator.pop(context);
    if (_isTournament || _challengeDate != null) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/menu');
    }
  }

  void _handleDoubleCoins() {
    final adManager = context.read<AdManager>();
    Navigator.pop(context);
    bool rewarded = false;
    adManager.showRewardedWithLoader(
      context,
      onRewarded: () {
        rewarded = true;
        context.read<ProgressRepository>().addCoins(AppConstants.baseScore +
            (_lives * AppConstants.bonusPerRemainingLife));
        _exitCompletedLevel();
      },
      onDismissed: () {
        if (!rewarded) {
          _exitCompletedLevel();
        }
      },
    );
  }

  Future<void> _showLevelCompleteDialog(int stars, int score) async {
    _gameState?.setPaused(true);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Stack(
        children: [
          _LevelCompleteDialog(
            level: _level,
            stars: stars,
            score: score,
            onNextLevel: _handleNextLevel,
            onMenu: _handleMenu,
            onDoubleCoins: _handleDoubleCoins,
            onNextLevelLabel: _isTournament ? 'Back to Tournament' : _challengeDate != null ? 'Back to Calendar' : 'Next Level',
          ),
          // Top Center Explosive Confetti (Subtle)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.08,
              numberOfParticles: 10,
              maxBlastForce: 70,
              minBlastForce: 35,
              gravity: 0.18,
              shouldLoop: false,
              colors: const [
                Colors.red,
                Colors.blue,
                Colors.green,
                Colors.yellow,
                Colors.pink,
                Colors.purple,
                Colors.orange,
                Colors.teal,
                Colors.cyan,
              ],
            ),
          ),
          // Bottom Left Confetti (Subtle)
          Align(
            alignment: Alignment.bottomLeft,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: -pi / 4,
              emissionFrequency: 0.04,
              numberOfParticles: 4,
              maxBlastForce: 80,
              minBlastForce: 40,
              gravity: 0.15,
              shouldLoop: false,
              colors: const [
                Colors.red,
                Colors.blue,
                Colors.green,
                Colors.yellow,
                Colors.pink,
                Colors.purple,
                Colors.orange,
                Colors.teal,
                Colors.cyan,
              ],
            ),
          ),
          // Bottom Right Confetti (Subtle)
          Align(
            alignment: Alignment.bottomRight,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: -3 * pi / 4,
              emissionFrequency: 0.04,
              numberOfParticles: 4,
              maxBlastForce: 80,
              minBlastForce: 40,
              gravity: 0.15,
              shouldLoop: false,
              colors: const [
                Colors.red,
                Colors.blue,
                Colors.green,
                Colors.yellow,
                Colors.pink,
                Colors.purple,
                Colors.orange,
                Colors.teal,
                Colors.cyan,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showGameOverDialog() async {
    _gameState?.setPaused(true);
    final levelType = AppConstants.levelTypeFor(_level.levelNumber);
    final hasTimer = (levelType == LevelType.god && _level.levelNumber > 100) ||
        (levelType == LevelType.boss && _level.levelNumber > 200);

    int continueTime = 0;
    if (hasTimer && _gameState != null) {
      final remainingArrows =
          _gameState!.arrows.where((a) => a.state != ArrowState.sliding).length;
      continueTime =
          _calculateContinueDuration(_level.levelNumber, remainingArrows);
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GameOverDialog(
        level: _level,
        isTimeout: _isTimeoutState,
        continueTime: continueTime,
        onContinue: () {
          // Watch rewarded ad to restore 1 life or add extra time
          final adManager = context.read<AdManager>();
          Navigator.pop(context);
          bool rewarded = false;
          adManager.showRewardedWithLoader(
            context,
            onRewarded: () {
              rewarded = true;
              if (!mounted) return;
              setState(() {
                _showingGameOver = false;
                _pauseGame(false);
                if (_isTimeoutState) {
                  _timeRemaining = continueTime; // Add dynamic extra time
                  _isTimeoutState = false;
                  _gameState!.resumeFromTimeout();
                  _startLevelTimer();
                } else {
                  _gameState!.restoreLife();
                  _lives = _gameState!.lives;
                }
              });
            },
            onDismissed: () {
              if (!rewarded && mounted) {
                _showingGameOver = false;
                _showGameOverDialog(); // Re-open game over dialog so player can try again or restart
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Ad not completed. Try watching again or restart.',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    backgroundColor: const Color(0xFFC0392B),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          );
        },
        onRestart: () {
          Navigator.pop(context);
          _handleRestart(confirm: false);
        },
        onMenu: _handleMenu,
      ),
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _levelTimer?.cancel();
    _gameState?.removeListener(_onGameStateChanged);
    _gameState?.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _isAppBackgrounded = true;
    } else if (state == AppLifecycleState.resumed) {
      _isAppBackgrounded = false;
      // Auto-pause and show settings dialog if returned to an active timed level
      final levelType = AppConstants.levelTypeFor(_level.levelNumber);
      final hasTimer =
          (levelType == LevelType.god && _level.levelNumber > 100) ||
              (levelType == LevelType.boss && _level.levelNumber > 200);
      if (hasTimer &&
          !_showingComplete &&
          !_showingGameOver &&
          !_isLoadingLevel &&
          _isLevelReady &&
          !_isGamePaused) {
        _showSettingsDialog();
      }
    }
  }

  int _calculateLevelTimerDuration(int levelNum, int totalArrows) {
    final type = AppConstants.levelTypeFor(levelNum);
    if (type == LevelType.god && levelNum > 100) {
      final baseSeconds =
          (45.0 - (levelNum - 100) * (20.0 / 400.0)).clamp(25.0, 45.0);
      final secondsPerArrow =
          (2.5 - (levelNum - 100) * (1.0 / 400.0)).clamp(1.5, 2.5);
      return (baseSeconds + secondsPerArrow * totalArrows).round();
    } else if (type == LevelType.boss && levelNum > 200) {
      final baseSeconds =
          (40.0 - (levelNum - 200) * (20.0 / 300.0)).clamp(20.0, 40.0);
      final secondsPerArrow =
          (2.2 - (levelNum - 200) * (0.8 / 300.0)).clamp(1.4, 2.2);
      return (baseSeconds + secondsPerArrow * totalArrows).round();
    }
    return 0;
  }

  int _calculateContinueDuration(int levelNum, int remainingArrows) {
    final type = AppConstants.levelTypeFor(levelNum);
    if (type == LevelType.god) {
      final secondsPerArrow =
          (2.2 - (levelNum - 100) * (0.7 / 400.0)).clamp(1.5, 2.2);
      return (20.0 + secondsPerArrow * remainingArrows).round();
    } else if (type == LevelType.boss) {
      final secondsPerArrow =
          (2.0 - (levelNum - 200) * (0.6 / 300.0)).clamp(1.4, 2.0);
      return (15.0 + secondsPerArrow * remainingArrows).round();
    }
    return 45;
  }

  void _resetTimerForLevel() {
    _levelTimer?.cancel();
    _isTimeoutState = false;

    final progress = context.read<ProgressRepository>();
    if (progress.isDemoMode) {
      _totalTime = 0;
      _timeRemaining = 0;
      return;
    }

    final levelType = AppConstants.levelTypeFor(_level.levelNumber);
    final hasTimer = (levelType == LevelType.god && _level.levelNumber > 100) ||
        (levelType == LevelType.boss && _level.levelNumber > 200);

    if (hasTimer || _isTournament) {
      _totalTime = _isTournament ? _tournamentTimeLimit : _calculateLevelTimerDuration(
          _level.levelNumber, _level.arrows.length);
      _timeRemaining = _totalTime;
      _startLevelTimer();
    } else {
      _totalTime = 0;
      _timeRemaining = 0;
    }
  }

  void _startLevelTimer() {
    _levelTimer?.cancel();
    _levelTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Pause if game state is not active, completed, gameover, paused or backgrounded
      if (_showingComplete ||
          _showingGameOver ||
          _isLoadingLevel ||
          !_isLevelReady ||
          _isGamePaused ||
          _isAppBackgrounded) {
        return;
      }

      setState(() {
        if (_timeRemaining > 0) {
          _timeRemaining--;
          if (_timeRemaining == 0) {
            timer.cancel();
            _onTimeOut();
          }
        }
      });
    });
  }

  void _onTimeOut() {
    if (!mounted || _showingGameOver) return;
    setState(() {
      _isTimeoutState = true;
    });
    _gameState?.forceGameOver();
  }

  @override
  Widget build(BuildContext context) {
    // Show a premium loading screen while the level is being generated
    // in the background isolate — no freeze, no blank screen.
    if (_isLoadingLevel || !_isLevelReady) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final levelNum = args?['level'] as int? ?? 1;
    _challengeDate = args?['challengeDate'] as String?;
    _isTournament = args?['mode'] == 'tournament';
    _tournamentTimeLimit = args?['timeLimit'] as int? ?? 0;
      return _LevelLoadingScreen(levelNumber: levelNum);
    }

    final levelType = AppConstants.levelTypeFor(_level.levelNumber);

    // Calculate level progress
    final totalArrows = _level.arrows.length;
    final activeArrows =
        _gameState?.arrows.where((a) => a.state != ArrowState.sliding).length ??
            totalArrows;
    final clearedArrows = totalArrows - activeArrows;
    final progressVal =
        totalArrows > 0 ? (clearedArrows / totalArrows).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top Bar ─────────────────────────────────────────────────
              _TopBar(
                level: _level,
                levelType: levelType,
                lives: _lives,
                progress: progressVal,
                onBack: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacementNamed(context, '/menu');
                  }
                },
                onSettings: _showSettingsDialog,
                onRestart: _handleRestart,
                isChallenge: _challengeDate != null || _isTournament,
              ),

              if (_totalTime > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TimerDisplay(
                    timeRemaining: _timeRemaining,
                    totalTime: _totalTime,
                    levelType: levelType,
                  ),
                ),

              // ── Game Canvas ──────────────────────────────────────────────
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Measure the real screen area BEFORE entering InteractiveViewer.
                    // InteractiveViewer gives unbounded constraints to its children,
                    // so LayoutBuilder must be OUTSIDE to get finite values.
                    // Use the full available rect — Flame's _calcLayout already
                    // handles non-square grids by fitting activeCols × activeRows.
                    final boardW = constraints.maxWidth;
                    final boardH = constraints.maxHeight;
                    final fadeH = min(24.0, boardH * 0.04);
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Canvas — fills the Expanded bounds, clipped hard
                        Positioned.fill(
                          child: ClipRect(
                            child: InteractiveViewer(
                              transformationController:
                                  _transformationController,
                              minScale: 0.8,
                              maxScale: 4.0,
                              boundaryMargin: const EdgeInsets.all(180),
                              clipBehavior: Clip.none,
                              child: Center(
                                child: SizedBox(
                                  width: boardW,
                                  height: boardH,
                                  child: GameWidget(game: _game),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(bottom: 8, right: 14, child: Row(children: [
                          RoundIconButton(icon: LucideIcons.zoomOut, label: 'Zoom out', size: 38, iconSize: 18,
                            color: AppColors.surface, shadow: true, onPressed: () => _zoomBy(1 / 1.25)),
                          const SizedBox(width: 7),
                          RoundIconButton(icon: LucideIcons.maximize, label: 'Reset zoom', size: 38, iconSize: 18,
                            color: AppColors.surface, shadow: true, onPressed: () { _transformationController.value = Matrix4.identity(); }),
                          const SizedBox(width: 7),
                          RoundIconButton(icon: LucideIcons.zoomIn, label: 'Zoom in', size: 38, iconSize: 18,
                            color: AppColors.surface, shadow: true, onPressed: () => _zoomBy(1.25)),
                        ])),
                        // Top fade — fixed overlay, non-interactive
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Container(
                              height: fadeH,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColors.background,
                                    AppColors.background.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Bottom fade — fixed overlay, non-interactive
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Container(
                              height: fadeH,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    AppColors.background,
                                    AppColors.background.withValues(alpha: 0),
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
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  RoundIconButton(icon: LucideIcons.lightbulb, label: 'Highlight a solvable arrow',
                    size: 72, iconSize: 34, color: AppColors.surface, iconColor: AppColors.primary,
                    shadow: true, onPressed: _hintBusy ? null : _requestHint,
                    badge: (AppConstants.enableAdMob || AppConstants.enableUnityAds) ? Container(
                      padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(LucideIcons.play, color: Colors.white, size: 12)) : null),
                  const SizedBox(width: 24),
                  RoundIconButton(icon: LucideIcons.hash, label: 'How to play', size: 72, iconSize: 34,
                    color: AppColors.surface, iconColor: AppColors.primary, shadow: true, onPressed: _showHelp),
                ]),
              ),
              if (AppConstants.enableAdMob || AppConstants.enableUnityAds)
                const SizedBox(height: 50, child: UnifiedBannerAd(
                  admobUnitId: AppConstants.admobBannerUnitId,
                  unityPlacementId: AppConstants.unityBannerAdId,
                )),
            ],
          ),
        ),
      ),
      floatingActionButton: _inspectingDeadlock
          ? FloatingActionButton.extended(
              onPressed: () {
                AudioManager.instance.playClick();
                setState(() {
                  _inspectingDeadlock = false;
                });
                _showDeadlockDialog();
              },
              backgroundColor: AppColors.primary,
              icon: const Icon(LucideIcons.menu, color: Colors.white),
              label: Text(
                'Deadlock Options',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }

  bool get _isLevelReady => _gameState != null;

  void _showTutorialDialogIfNeeded(int levelNum) {
    if (levelNum == 1) {
      _showTutorialDialog(
        title: 'How to Play',
        description:
            'Arrows slide in the direction they point. Tap an arrow to make it escape the grid! Arrows cannot pass through other arrows, so plan their escape order carefully.',
        icon: LucideIcons.playCircle,
        iconColor: const Color(0xFF4CAF50),
        animationWidget: _buildNormalArrowAnimation(),
        stepText: '1/3',
      );
    } else if (levelNum == 2) {
      _showTutorialDialog(
        title: 'Color Paired Arrows',
        description:
            'Arrows with matching colors are paired together! Tap on either arrow in the pair, and both will slide out together simultaneously. Make sure both exit paths are clear!',
        icon: LucideIcons.coins,
        iconColor: const Color(0xFFFF2D55),
        animationWidget: _buildColorLockAnimation(),
        stepText: '2/3',
      );
    } else if (levelNum == 3) {
      _showTutorialDialog(
        title: 'Deflector Dots',
        description:
            'Gold deflector dots change the direction of exiting arrows! Trace the exit path through the deflector dots to make sure the arrow escapes successfully.',
        icon: LucideIcons.rotateCw,
        iconColor: const Color(0xFFFFAA00),
        animationWidget: _buildDeflectorAnimation(),
        stepText: '3/3',
      );
    }

    // Check for one-time 40x40 grid warning dialog
    final progressRepo = context.read<ProgressRepository>();
    if (_level.gridSize >= 40 && !progressRepo.hasSeen40x40Warning) {
      progressRepo.setHasSeen40x40Warning(true);
      _show40x40WarningDialog();
    }

    // If the arrows are very small, show a snackbar warning to zoom in/out (one-time only)
    if (_level.gridSize >= 25 && !progressRepo.hasSeenZoomHint) {
      progressRepo.setHasSeenZoomHint(true);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pinch to zoom in or out to see small arrows easily!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      });
    }
  }

  void _show40x40WarningDialog() {
    setState(() => _isGamePaused = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.surfaceLight),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 32,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentOrange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.alertTriangle,
                      color: AppColors.accentOrange, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  'Massive Grid Alert!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You are about to play a massive 40×40 level! On grids of this size, deadlocks (where all remaining arrows are blocked) are very common.\n\nBe extremely careful about your tap order. If you get stuck, look out for the Deadlock dialog to restart!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    AudioManager.instance.playClick();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Got It!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() => _isGamePaused = false);
      }
    });
  }

  void _showTutorialDialog({
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required Widget animationWidget,
    required String stepText,
  }) {
    setState(() => _isGamePaused = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: iconColor.withValues(alpha: 0.25), width: 2),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.15),
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tutorial Step Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: iconColor.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Text(
                    'TUTORIAL STEP $stepText',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: iconColor,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Pulsing Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                    begin: const Offset(0.92, 0.92),
                    end: const Offset(1.08, 1.08),
                    duration: 1000.ms,
                    curve: Curves.easeInOut),
                const SizedBox(height: 16),

                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                animationWidget,
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    AudioManager.instance.playClick();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Start Tutorial',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
              .animate()
              .scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1.0, 1.0),
                  duration: 320.ms,
                  curve: Curves.easeOutBack)
              .fade(duration: 250.ms),
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() => _isGamePaused = false);
      }
    });
  }

  Widget _buildNormalArrowAnimation() {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight, width: 1),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: Icon(Icons.arrow_forward_rounded,
                  color: AppColors.primary, size: 20),
            )
                .animate(onPlay: (c) => c.repeat())
                .scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1.03, 1.03),
                    duration: 800.ms,
                    curve: Curves.easeInOut)
                .slideX(begin: 0, end: 1.5, delay: 1000.ms, duration: 600.ms)
                .fadeOut(delay: 1000.ms, duration: 200.ms),
            Positioned(
              right: 80,
              bottom: 15,
              child: Icon(
                Icons.touch_app_rounded,
                color: AppColors.textPrimary.withValues(alpha: 0.8),
                size: 24,
              )
                  .animate(onPlay: (c) => c.repeat())
                  .hide()
                  .fadeIn(delay: 400.ms, duration: 200.ms)
                  .scale(
                      begin: const Offset(1.2, 1.2),
                      end: const Offset(0.9, 0.9),
                      delay: 400.ms,
                      duration: 400.ms,
                      curve: Curves.easeOutBack)
                  .fadeOut(delay: 800.ms, duration: 200.ms),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorLockAnimation() {
    // Color-pair tutorial: show two arrows in DIFFERENT colors so players
    // understand that "matching colors = paired". Arrow 1 exits upward
    // (coral/red), Arrow 2 exits rightward (cyan/teal) — both at the same time.
    final Color color1 = AppColors.getGroupColor(0); // group 0 pair color
    final Color color2 = AppColors.getGroupColor(1); // group 1 pair color
    return Container(
      height: 110,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight, width: 1),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Arrow 1 (color1, exits UP) ──────────────────────────────
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: color1.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color1, width: 2),
                      ),
                      child: Icon(Icons.arrow_upward_rounded,
                          color: color1, size: 20),
                    )
                        .animate(onPlay: (c) => c.repeat())
                        .scale(
                            begin: const Offset(0.9, 0.9),
                            end: const Offset(1.05, 1.05),
                            duration: 700.ms,
                            curve: Curves.easeInOut)
                        .slideY(
                            begin: 0,
                            end: -1.4,
                            delay: 900.ms,
                            duration: 550.ms)
                        .fadeOut(delay: 1000.ms, duration: 200.ms),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color1.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('PAIR',
                          style: TextStyle(
                              fontSize: 9,
                              color: color1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1)),
                    ),
                  ],
                ),

                const SizedBox(width: 36),

                // ── A small link indicator ───────────────────────────────────
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link_rounded,
                        color: Color(0xFF888888), size: 18),
                  ],
                ),

                const SizedBox(width: 36),

                // ── Arrow 2 (color2, exits RIGHT) ────────────────────────────
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: color2.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color2, width: 2),
                      ),
                      child: Icon(Icons.arrow_forward_rounded,
                          color: color2, size: 20),
                    )
                        .animate(onPlay: (c) => c.repeat())
                        .scale(
                            begin: const Offset(0.9, 0.9),
                            end: const Offset(1.05, 1.05),
                            duration: 700.ms,
                            curve: Curves.easeInOut)
                        .slideX(
                            begin: 0, end: 1.4, delay: 900.ms, duration: 550.ms)
                        .fadeOut(delay: 1000.ms, duration: 200.ms),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color2.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('PAIR',
                          style: TextStyle(
                              fontSize: 9,
                              color: color2,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1)),
                    ),
                  ],
                ),
              ],
            ),
            // Tap hint — appears briefly then fades
            Positioned(
              bottom: 10,
              child: Icon(
                Icons.touch_app_rounded,
                color: AppColors.textPrimary.withValues(alpha: 0.7),
                size: 22,
              )
                  .animate(onPlay: (c) => c.repeat())
                  .hide()
                  .fadeIn(delay: 300.ms, duration: 200.ms)
                  .scale(
                      begin: const Offset(1.2, 1.2),
                      end: const Offset(0.9, 0.9),
                      delay: 300.ms,
                      duration: 400.ms,
                      curve: Curves.easeOutBack)
                  .fadeOut(delay: 750.ms, duration: 200.ms),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeflectorAnimation() {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight, width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFFAA00),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFAA00).withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.arrow_upward_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.15, 1.15),
                  delay: 600.ms,
                  duration: 200.ms,
                  curve: Curves.easeOutBack)
              .then(duration: 200.ms)
              .scale(
                  begin: const Offset(1.15, 1.15),
                  end: const Offset(1, 1),
                  duration: 200.ms),
          Positioned(
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ).animate(onPlay: (c) => c.repeat()).custom(
                  duration: 1.2.seconds,
                  builder: (context, val, child) {
                    double dx = 0;
                    double dy = 0;
                    if (val < 0.5) {
                      dx = 60 * (1 - val * 2);
                      dy = 0;
                    } else {
                      dx = 0;
                      dy = -60 * ((val - 0.5) * 2);
                    }
                    return Transform.translate(
                      offset: Offset(dx, dy),
                      child: child,
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

// ── Timer Display ────────────────────────────────────────────────────────────

class _TimerDisplay extends StatelessWidget {
  final int timeRemaining;
  final int totalTime;
  final LevelType levelType;

  const _TimerDisplay({
    required this.timeRemaining,
    required this.totalTime,
    required this.levelType,
  });

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isLowTime = timeRemaining <= 15 || timeRemaining <= totalTime * 0.15;
    final progress = (timeRemaining / totalTime).clamp(0.0, 1.0);

    final color = isLowTime
        ? AppColors.heartRed // Vibrant red/orange warning
        : (levelType == LevelType.god
            ? AppColors.accent
            : AppColors.accentOrange);

    Widget content = Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLowTime ? AppColors.heartRed : AppColors.surfaceLight,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isLowTime ? 0.3 : 0.1),
            blurRadius: isLowTime ? 8 : 4,
            spreadRadius: isLowTime ? 1 : 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.hourglass,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                _formatTime(timeRemaining),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 3,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.surfaceLight.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ),
    );

    if (isLowTime) {
      content = content
          .animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          )
          .scaleXY(
              begin: 0.96,
              end: 1.04,
              duration: 400.ms,
              curve: Curves.easeInOut);
    }

    return content;
  }
}

// ── Top Bar ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final LevelModel level;
  final LevelType levelType;
  final int lives;
  final double progress;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback onRestart;
  final bool isChallenge;

  const _TopBar({required this.level, required this.levelType, required this.lives,
    required this.progress, required this.onBack, required this.onSettings,
    required this.onRestart, this.isChallenge = false});

  @override
  Widget build(BuildContext context) {
    final difficulty = levelType.isSpecial ? levelType.label : Difficulty.forLevel(level.levelNumber).label;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
      child: Column(children: [
        SizedBox(height: 78, child: Row(children: [
          RoundIconButton(icon: LucideIcons.arrowLeft, label: 'Back', onPressed: onBack),
          const SizedBox(width: 12),
          RoundIconButton(icon: LucideIcons.rotateCcw, label: 'Restart level', onPressed: onRestart),
          Expanded(child: Semantics(label: 'Level ${level.levelNumber}, $difficulty', child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(difficulty, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: AppColors.difficultyColor(level.levelNumber))),
              const SizedBox(height: 5),
              LivesBar(lives: lives, maxLives: AppConstants.maxLives),
            ],
          ))),
          RoundIconButton(icon: LucideIcons.pause, label: 'Pause game', size: 42, iconSize: 20,
            color: Colors.transparent, iconColor: AppColors.textMuted, onPressed: onSettings),
        ])),
        const SizedBox(height: 12),
        WavyProgressBar(progress: progress, width: double.infinity, height: 8),
      ]),
    );
  }
}

// ── Level Complete Dialog ─────────────────────────────────────────────────────

class _LevelCompleteDialog extends StatelessWidget {
  final LevelModel level;
  final int stars;
  final int score;
  final VoidCallback onNextLevel;
  final VoidCallback onMenu;
  final VoidCallback onDoubleCoins;
  final String onNextLevelLabel;

  const _LevelCompleteDialog({
    required this.level,
    required this.stars,
    required this.score,
    required this.onNextLevel,
    required this.onMenu,
    required this.onDoubleCoins,
    this.onNextLevelLabel = 'Next Level',
  });

  bool get _showAds =>
      AppConstants.enableAdMob ||
      AppConstants.enableUnityAds ||
      AppConstants.enableAppLovin;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.surfaceLight),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 32),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.partyPopper,
              color: AppColors.primary,
              size: 52,
            ).animate().scale(
                begin: const Offset(0, 0),
                end: const Offset(1, 1),
                duration: 400.ms,
                curve: Curves.elasticOut),
            const SizedBox(height: 12),
            Text('Level Complete!',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),

            // Stars
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  3,
                  (i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          i < stars
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: i < stars
                              ? AppColors.starYellow
                              : AppColors.surfaceLight,
                          size: 38,
                        ),
                      )
                          .animate(delay: Duration(milliseconds: 200 + i * 150))
                          .scale(
                              begin: const Offset(0, 0),
                              end: const Offset(1, 1),
                              curve: Curves.elasticOut)),
            ),
            const SizedBox(height: 20),

            // Score
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.accentGold.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.coins,
                    color: Color(0xFFE2B93C),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text('+$score',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentGold)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Next Level button or Game Completed message
            if (level.levelNumber == 500) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.accentGold.withValues(alpha: 0.4),
                      width: 1.5),
                ),
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.trophy,
                      color: AppColors.accentGold,
                      size: 32,
                    ).animate(onPlay: (c) => c.repeat()).scale(
                        begin: const Offset(0.9, 0.9),
                        end: const Offset(1.1, 1.1),
                        duration: 1.seconds,
                        curve: Curves.easeInOut),
                    const SizedBox(height: 10),
                    Text(
                      'You Finished the Game!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.accentGold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Congratulations! You\'ve solved all 500 challenges. Stay tuned for more levels coming soon!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              _DialogButton(
                label: onNextLevelLabel,
                icon: Icons.play_arrow_rounded,
                gradient: AppColors.primaryGradient,
                onTap: onNextLevel,
              ),
              const SizedBox(height: 10),
            ],

            // Double coins (rewarded ad)
            if (_showAds) ...[
              _DialogButton(
                label: 'Double Coins',
                icon: LucideIcons.clapperboard,
                gradient: AppColors.secondaryGradient,
                textColor: AppColors.textPrimary,
                iconColor: AppColors.textPrimary,
                onTap: onDoubleCoins,
              ),
              const SizedBox(height: 10),
            ],

            TextButton(
              onPressed: () {
                AudioManager.instance.playClick();
                onMenu();
              },
              child: Text('Back to Menu',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Game Over Dialog ──────────────────────────────────────────────────────────

class _GameOverDialog extends StatelessWidget {
  final LevelModel level;
  final bool isTimeout;
  final int continueTime;
  final VoidCallback onContinue;
  final VoidCallback onRestart;
  final VoidCallback onMenu;

  const _GameOverDialog({
    required this.level,
    this.isTimeout = false,
    this.continueTime = 0,
    required this.onContinue,
    required this.onRestart,
    required this.onMenu,
  });

  bool get _showAds =>
      AppConstants.enableAdMob ||
      AppConstants.enableUnityAds ||
      AppConstants.enableAppLovin;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.surfaceLight),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 32),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTimeout ? LucideIcons.hourglass : LucideIcons.heartOff,
              color: AppColors.accent,
              size: 52,
            ).animate().shake(duration: 500.ms),
            const SizedBox(height: 12),
            Text(isTimeout ? 'Out of Time!' : 'Out of Lives!',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            // Continue with ad
            if (_showAds) ...[
              Text(
                  isTimeout
                      ? 'Watch an ad to get +$continueTime seconds and continue'
                      : 'Watch an ad to get 1 more life and continue',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 28),
              _DialogButton(
                label: isTimeout
                    ? 'Get +$continueTime Seconds & Continue'
                    : 'Get 1 More Life & Continue',
                icon: LucideIcons.clapperboard,
                gradient: AppColors.successGradient,
                onTap: onContinue,
              ),
              const SizedBox(height: 10),
            ],

            // Restart (all lives back)
            _DialogButton(
              label: 'Restart Level',
              icon: Icons.refresh_rounded,
              gradient: AppColors.secondaryGradient,
              textColor: AppColors.textPrimary,
              iconColor: AppColors.textPrimary,
              onTap: onRestart,
            ),
            const SizedBox(height: 10),

            TextButton(
              onPressed: () {
                AudioManager.instance.playClick();
                onMenu();
              },
              child: Text('Main Menu',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Deadlock Dialog ───────────────────────────────────────────────────────────

class _DeadlockDialog extends StatelessWidget {
  final LevelModel level;
  final VoidCallback onRestart;
  final VoidCallback onMenu;
  final VoidCallback onInspect;

  const _DeadlockDialog({
    required this.level,
    required this.onRestart,
    required this.onMenu,
    required this.onInspect,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.surfaceLight),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 32,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.alertTriangle,
              color: AppColors.accentOrange,
              size: 52,
            ).animate().shake(duration: 600.ms),
            const SizedBox(height: 12),
            Text(
              'Deadlock Reached!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'All remaining arrows are blocked. This can happen if they are cleared in the wrong sequence.\n\n💡 Hint: Try to trace the paths and see which arrows must escape first to clear the way for others!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),

            // Restart Level
            _DialogButton(
              label: 'Restart Level',
              icon: Icons.refresh_rounded,
              gradient: AppColors.primaryGradient,
              onTap: onRestart,
            ),
            const SizedBox(height: 10),

            // Inspect Board
            _DialogButton(
              label: 'Inspect Board',
              icon: LucideIcons.eye,
              gradient: AppColors.secondaryGradient,
              textColor: AppColors.textPrimary,
              iconColor: AppColors.textPrimary,
              onTap: onInspect,
            ),
            const SizedBox(height: 10),

            TextButton(
              onPressed: () {
                AudioManager.instance.playClick();
                onMenu();
              },
              child: Text(
                'Back to Menu',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;
  final Color textColor;
  final Color iconColor;

  const _DialogButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
    this.textColor = Colors.white,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioManager.instance.playClick();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textColor)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameSettingsDialog extends StatelessWidget {
  final VoidCallback onRestart;

  const _GameSettingsDialog({required this.onRestart});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressRepository>();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.surfaceLight),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 32,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Take a breather',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // Sound Toggle
            _DialogSettingsTile(
              icon: LucideIcons.volume2,
              label: 'Sound Effects',
              value: progress.soundEnabled,
              onChanged: (val) => progress.setSoundEnabled(val),
            ),

            // Music Toggle
            _DialogSettingsTile(
              icon: LucideIcons.music,
              label: 'Background Music',
              value: progress.musicEnabled,
              onChanged: (val) => progress.setMusicEnabled(val),
            ),

            // Vibration Toggle
            _DialogSettingsTile(
              icon: LucideIcons.vibrate,
              label: 'Vibration',
              value: progress.vibrationEnabled,
              onChanged: (val) => progress.setVibrationEnabled(val),
            ),

            const SizedBox(height: 16),
            Divider(color: AppColors.surfaceLight, height: 1),
            const SizedBox(height: 20),

            // Restart Button
            _DialogButton(
              label: 'Restart Level',
              icon: LucideIcons.rotateCcw,
              gradient: AppColors.primaryGradient,
              onTap: onRestart,
            ),
            const SizedBox(height: 10),

            // Close / Resume Button
            TextButton(
              onPressed: () {
                AudioManager.instance.playClick();
                Navigator.pop(context);
              },
              child: Text(
                'Resume Game',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogSettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _DialogSettingsTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Switch(
            value: value,
            onChanged: (val) {
              AudioManager.instance.playClick();
              onChanged(val);
            },
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

// ── Level loading ────────────────────────────────────────────────────────────
const _normalLoadingMessages = ['Finding a little room to think…'];

class _LevelLoadingScreen extends StatelessWidget {
  final int levelNumber;
  const _LevelLoadingScreen({required this.levelNumber});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const ArrowWordmark(size: 46),
      const SizedBox(height: 28),
      Text('Level $levelNumber', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.ink)),
      const SizedBox(height: 12),
      Text(_normalLoadingMessages.first, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
      const SizedBox(height: 28),
      SizedBox(width: 25, height: 25, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary)),
    ])),
  );
}
