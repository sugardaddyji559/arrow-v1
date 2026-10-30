import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;

import '../models/level.dart';
import '../../core/constants.dart';
import '../../core/audio_manager.dart';

class ProgressRepository extends ChangeNotifier {
  final SharedPreferences? _prefs;
  final DateTime Function() _clock;
  DateTime get _now => _clock();

  // ── State fields ────────────────────────────────────────────────────────────
  int _lives = AppConstants.maxLives;
  int _currentLevel = 1;
  int _highestUnlockedLevel = 1;
  int _totalScore = 0;
  int _coins = 0;

  // Streak
  int _streakDays = 0;
  DateTime? _lastPlayedDate;

  // Level results
  final Map<int, LevelResult> _levelResults = {};
  final Map<String, int> _dailyChallengeStars = {};
  final Map<int, int> _tournamentBestSeconds = {};
  bool _collectionSeen = true;

  // Settings
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  double _musicVolume = 0.6;
  bool _vibrationEnabled = true;
  ThemeMode _themeMode = ThemeMode.system;

  // 40x40 warning state
  bool _hasSeen40x40Warning = false;

  // Zoom hint state
  bool _hasSeenZoomHint = false;

  // Demo Mode
  bool _isDemoMode = false;

  // ── Getters ──────────────────────────────────────────────────────────────────
  bool get isDemoMode => _isDemoMode;
  int get lives => _isDemoMode ? 999 : _lives;
  int get maxLives => AppConstants.maxLives;
  int get currentLevel => _currentLevel;
  int get highestUnlockedLevel => _isDemoMode ? 500 : _highestUnlockedLevel;
  int get totalScore => _totalScore;
  int get coins => _coins;
  int get streakDays => _streakDays;
  DateTime? get lastPlayedDate => _lastPlayedDate;
  bool get hasLives => _isDemoMode ? true : _lives > 0;
  bool get livesAreFull => _isDemoMode ? true : _lives >= AppConstants.maxLives;

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;
  double get musicVolume => _musicVolume;
  int get completedLevelCount => _levelResults.values.where((r) => r.completed).length;
  int get totalStars => _levelResults.values.fold(0, (sum, r) => sum + r.stars);
  int get perfectLevelCount => _levelResults.values.where((r) => r.stars == 3).length;
  bool get hasNewCollection => !_collectionSeen;
  Map<String, int> get dailyChallengeStars => Map.unmodifiable(_dailyChallengeStars);
  Map<int, int> get tournamentBestSeconds => Map.unmodifiable(_tournamentBestSeconds);

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Stable across devices and sessions; challenges do not advance the campaign.
  static int dailyChallengeLevel(DateTime date) =>
      ((date.year * 372 + date.month * 31 + date.day) * 73 + 19) % 500 + 1;

  bool isDailyChallengeComplete(DateTime date) => _dailyChallengeStars.containsKey(dateKey(date));
  int completedChallengesInMonth(DateTime month) => _dailyChallengeStars.keys.where((key) {
    final d = DateTime.tryParse(key);
    return d != null && d.year == month.year && d.month == month.month;
  }).length;

  Future<void> markCollectionSeen() async {
    if (_collectionSeen) return;
    _collectionSeen = true;
    await _prefs?.setBool('collectionSeen', true);
    notifyListeners();
  }

  Future<bool> recordDailyChallenge(DateTime date, int stars, int score) async {
    final key = dateKey(date);
    if (_dailyChallengeStars.containsKey(key)) return false;
    _dailyChallengeStars[key] = stars.clamp(1, 3);
    _coins += score;
    _totalScore += score;
    _collectionSeen = false;
    await _save();
    notifyListeners();
    return true;
  }

  Future<bool> recordTournamentBest(int level, int seconds) async {
    final best = _tournamentBestSeconds[level];
    if (best != null && best <= seconds) return false;
    _tournamentBestSeconds[level] = math.max(1, seconds);
    if (best == null) _coins += 50;
    await _save();
    notifyListeners();
    return true;
  }
  bool get vibrationEnabled => _vibrationEnabled;
  ThemeMode get themeMode => _themeMode;
  bool get hasSeen40x40Warning => _hasSeen40x40Warning;
  bool get hasSeenZoomHint => _hasSeenZoomHint;

  int getStarsForLevel(int level) => _levelResults[level]?.stars ?? 0;

  bool isLevelUnlocked(int level) {
    if (_isDemoMode) return true;
    return level <= _highestUnlockedLevel;
  }

  void toggleDemoMode() {
    _isDemoMode = !_isDemoMode;
    notifyListeners();
  }

  bool isLevelCompleted(int level) => _levelResults.containsKey(level);

  ProgressRepository([this._prefs, DateTime Function()? clock]) : _clock = clock ?? DateTime.now {
    _load();
  }


  // ── Load / Save ──────────────────────────────────────────────────────────────

  void _load() {
    if (_prefs == null) return;
    try {
      _lives = _prefs!.getInt('lives') ?? AppConstants.maxLives;
      _currentLevel = _prefs!.getInt('currentLevel') ?? 1;
      _highestUnlockedLevel = _prefs!.getInt('highestUnlockedLevel') ?? 1;
      _totalScore = _prefs!.getInt('totalScore') ?? 0;
      _coins = _prefs!.getInt('coins') ?? 0;
      _streakDays = _prefs!.getInt('streakDays') ?? 0;

      _soundEnabled = _prefs!.getBool('soundEnabled') ?? true;
      _musicEnabled = _prefs!.getBool('musicEnabled') ?? true;
      _musicVolume = (_prefs!.getDouble('musicVolume') ?? 0.6).clamp(0.0, 1.0).toDouble();
      _collectionSeen = _prefs!.getBool('collectionSeen') ?? true;
      final dailyJson = _prefs!.getString('dailyChallengeStars');
      if (dailyJson != null) {
        (jsonDecode(dailyJson) as Map<String, dynamic>).forEach((key, value) {
          if (DateTime.tryParse(key) != null) _dailyChallengeStars[key] = (value as int).clamp(1, 3);
        });
      }
      final tournamentJson = _prefs!.getString('tournamentBestSeconds');
      if (tournamentJson != null) {
        (jsonDecode(tournamentJson) as Map<String, dynamic>).forEach((key, value) {
          final level = int.tryParse(key);
          if (level != null) _tournamentBestSeconds[level] = value as int;
        });
      }
      _vibrationEnabled = _prefs!.getBool('vibrationEnabled') ?? true;
      _hasSeen40x40Warning = _prefs!.getBool('hasSeen40x40Warning') ?? false;
      _hasSeenZoomHint = _prefs!.getBool('hasSeenZoomHint') ?? false;

      final themeStr = _prefs!.getString('themeMode') ?? 'system';
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == themeStr,
        orElse: () => ThemeMode.system,
      );

      // Synchronize to AudioManager
      AudioManager.instance.setSoundEnabled(_soundEnabled);
      AudioManager.instance.setMusicVolume(_musicVolume);
      AudioManager.instance.setMusicEnabled(_musicEnabled);

      final lastPlayedStr = _prefs!.getString('lastPlayedDate');
      if (lastPlayedStr != null) {
        _lastPlayedDate = DateTime.tryParse(lastPlayedStr);
      }

      final resultsJson = _prefs!.getString('levelResults');
      if (resultsJson != null) {
        final Map<String, dynamic> map = jsonDecode(resultsJson);
        for (final entry in map.entries) {
          final level = int.tryParse(entry.key);
          if (level != null) {
            _levelResults[level] =
                LevelResult.fromJson(entry.value as Map<String, dynamic>);
          }
        }
      }

      // Check streak
      _updateStreak();
    } catch (e) {
      debugPrint('Error loading progress from SharedPreferences: $e');
    }
  }

  Future<void> _save() async {
    if (_prefs == null) return;
    try {
      await Future.wait([
        _prefs!.setInt('lives', _lives),
        _prefs!.setInt('currentLevel', _currentLevel),
        _prefs!.setInt('highestUnlockedLevel', _highestUnlockedLevel),
        _prefs!.setInt('totalScore', _totalScore),
        _prefs!.setInt('coins', _coins),
        _prefs!.setInt('streakDays', _streakDays),
        _prefs!.setBool('soundEnabled', _soundEnabled),
        _prefs!.setBool('musicEnabled', _musicEnabled),
        _prefs!.setBool('vibrationEnabled', _vibrationEnabled),
        _prefs!.setDouble('musicVolume', _musicVolume),
        _prefs!.setString('themeMode', _themeMode.name),
        _prefs!.setBool('collectionSeen', _collectionSeen),
        _prefs!.setString('dailyChallengeStars', jsonEncode(_dailyChallengeStars)),
        _prefs!.setString('tournamentBestSeconds', jsonEncode(_tournamentBestSeconds.map((k, v) => MapEntry(k.toString(), v)))),
        if (_lastPlayedDate != null)
          _prefs!.setString('lastPlayedDate', _lastPlayedDate!.toIso8601String()),
      ]);
    } catch (e) {
      debugPrint('Error saving progress: $e');
    }

    // Save level results
    if (_prefs != null) {
      final Map<String, dynamic> resultsMap = {};
      for (final entry in _levelResults.entries) {
        resultsMap[entry.key.toString()] = entry.value.toJson();
      }
      await _prefs?.setString('levelResults', jsonEncode(resultsMap));
    }
  }

  // ── Lives — restored only via rewarded ad or level restart ─────────────────

  /// Called by GameState when player makes a wrong move.
  /// NOTE: Lives are NOT decremented from here — GameState manages lives
  /// during gameplay. This method is for external persistence (e.g. continue).
  Future<void> restoreLives({int amount = AppConstants.maxLives}) async {
    _lives = (_lives + amount).clamp(0, AppConstants.maxLives);
    await _save();
    notifyListeners();
  }

  /// Reset lives to full — called when player restarts a level.
  Future<void> resetLivesToFull() async {
    _lives = AppConstants.maxLives;
    await _save();
    notifyListeners();
  }

  // ── Streak ───────────────────────────────────────────────────────────────────

  void _updateStreak() {
    if (_lastPlayedDate == null) return;
    final now = _now;
    final today = DateTime(now.year, now.month, now.day);
    final lastPlayed = DateTime(
      _lastPlayedDate!.year,
      _lastPlayedDate!.month,
      _lastPlayedDate!.day,
    );
    final diff = today.difference(lastPlayed).inDays;
    if (diff > 1) {
      // Streak broken
      _streakDays = 0;
      _save();
    }
  }

  Future<void> recordDailyPlay() async {
    final now = _now;
    final today = DateTime(now.year, now.month, now.day);

    if (_lastPlayedDate != null) {
      final lastPlayed = DateTime(
        _lastPlayedDate!.year,
        _lastPlayedDate!.month,
        _lastPlayedDate!.day,
      );
      final diff = today.difference(lastPlayed).inDays;
      if (diff == 0) return; // Already recorded today
      if (diff == 1) {
        _streakDays++; // Consecutive day
      } else {
        _streakDays = 1; // Restart streak
      }
    } else {
      _streakDays = 1;
    }

    _lastPlayedDate = now;
    await _save();
    notifyListeners();
  }

  Future<void> protectStreak() async {
    // Called after watching a rewarded ad on streak break
    _lastPlayedDate = _now;
    await _save();
    notifyListeners();
  }

  // ── Level Progress ────────────────────────────────────────────────────────────

  Future<void> recordLevelComplete(LevelResult result) async {
    final existing = _levelResults[result.levelNumber];
    if (existing == null || result.stars > existing.stars) {
      _levelResults[result.levelNumber] = result;
    }
    _totalScore += result.score;
    _coins += result.score;
    _collectionSeen = false;
    _currentLevel = result.levelNumber + 1;
    if (_currentLevel > _highestUnlockedLevel) {
      _highestUnlockedLevel = _currentLevel;
    }
    await _save();
    notifyListeners();
  }

  Future<void> setCurrentLevel(int level) async {
    _currentLevel = level;
    await _save();
    notifyListeners();
  }

  Future<void> addCoins(int amount) async {
    _coins += amount;
    await _save();
    notifyListeners();
  }

  // ── Settings Setters ─────────────────────────────────────────────────────────

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    AudioManager.instance.setSoundEnabled(value);
    await _prefs?.setBool('soundEnabled', value);
    notifyListeners();
  }

  Future<void> setMusicEnabled(bool value) async {
    _musicEnabled = value;
    AudioManager.instance.setMusicEnabled(value);
    await _prefs?.setBool('musicEnabled', value);
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    await _prefs?.setBool('vibrationEnabled', value);
    notifyListeners();
  }

  Future<void> setMusicVolume(double value) async {
    _musicVolume = value.clamp(0.0, 1.0).toDouble();
    AudioManager.instance.setMusicVolume(_musicVolume);
    await _prefs?.setDouble('musicVolume', _musicVolume);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    _themeMode = value;
    await _prefs?.setString('themeMode', value.name);
    notifyListeners();
  }

  Future<void> setHasSeen40x40Warning(bool value) async {
    _hasSeen40x40Warning = value;
    await _prefs?.setBool('hasSeen40x40Warning', value);
    notifyListeners();
  }

  Future<void> setHasSeenZoomHint(bool value) async {
    _hasSeenZoomHint = value;
    await _prefs?.setBool('hasSeenZoomHint', value);
    notifyListeners();
  }

  // ── Star rating calculator ────────────────────────────────────────────────────
  static int calculateStars(int livesLost, int totalArrows, int movesUsed) {
    if (livesLost == 0) return 3;
    if (livesLost == 1) return 2;
    return 1;
  }
}
