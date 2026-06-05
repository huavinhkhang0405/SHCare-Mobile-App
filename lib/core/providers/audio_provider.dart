import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

enum AudioProfile { defaultPlaylist, stressRelief, sleepAid }

class AudioProvider extends ChangeNotifier with WidgetsBindingObserver {
  final AudioPlayer _bgmPlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;

  late final Future<void> _bgmReady;
  bool _isPluginAvailable = true;
  bool _wasPlayingBeforePause = false;

  bool _isBgmMuted = false;
  bool get isBgmMuted => _isBgmMuted;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  AudioProfile _currentProfile = AudioProfile.defaultPlaylist;
  AudioProfile get currentProfile => _currentProfile;

  String get currentProfileLabel {
    switch (_currentProfile) {
      case AudioProfile.stressRelief:
        return 'Giam cang thang (Mua + Piano cham)';
      case AudioProfile.sleepAid:
        return 'Ngu sau (Brown noise / 432Hz)';
      case AudioProfile.defaultPlaylist:
        return 'Playlist thuong ngay';
    }
  }

  static const double _defaultVolume = 0.2;
  static const List<String> _defaultTracks = [
    'assets/Audio/bg_music1.mp3',
    'assets/Audio/bg_music2.mp3',
    'assets/Audio/bg_music3.mp3',
  ];
  static const List<String> _stressTracks = [
    'assets/Audio/rain_piano_slow_1.mp3',
    'assets/Audio/rain_piano_slow_2.mp3',
  ];
  static const List<String> _sleepTracks = [
    'assets/Audio/brown_noise.mp3',
    'assets/Audio/solfeggio_432hz.mp3',
  ];

  AudioProvider() {
    WidgetsBinding.instance.addObserver(this);
    _playerStateSub = _bgmPlayer.playerStateStream.listen((state) {
      if (_isPlaying == state.playing) {
        return;
      }
      _isPlaying = state.playing;
      notifyListeners();
    });
    _bgmReady = _initializeBgm();
  }

  Future<void> _initializeBgm() async {
    try {
      await _setupAudioSession();
      await _loadProfileSource(
        AudioProfile.defaultPlaylist,
        fallbackToDefault: false,
      );
    } on MissingPluginException catch (e) {
      _isPluginAvailable = false;
      debugPrint('just_audio chưa được attach vào engine: $e');
    } catch (e) {
      debugPrint('Lỗi khởi tạo BGM: $e');
    }
  }

  // Hàm bật nhạc nền (Gọi khi vào app)
  Future<void> startBgm() async {
    await playMusic();
  }

  Future<void> applyMoodPlaylist(int moodIndex) async {
    // moodIndex >= 3 tương ứng trạng thái căng thẳng / mệt mỏi.
    if (moodIndex >= 3) {
      await _switchProfile(AudioProfile.stressRelief);
      return;
    }
    await _switchProfile(AudioProfile.defaultPlaylist);
  }

  Future<void> activateSleepPlaylist() async {
    await _switchProfile(AudioProfile.sleepAid);
  }

  Future<void> activateDefaultPlaylist() async {
    await _switchProfile(AudioProfile.defaultPlaylist);
  }

  Future<void> fadeOutAndPause() async {
    if (!_isPluginAvailable) {
      return;
    }

    try {
      await _bgmReady;
      final currentVolume = _bgmPlayer.volume;

      for (var i = 10; i >= 0; i--) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await _bgmPlayer.setVolume(currentVolume * (i / 10));
      }

      await _bgmPlayer.pause();
      await _bgmPlayer.setVolume(_isBgmMuted ? 0 : currentVolume);
    } on MissingPluginException catch (e) {
      _isPluginAvailable = false;
      debugPrint('Không thể fade out vì thiếu plugin just_audio: $e');
    } catch (e) {
      debugPrint('Lỗi khi fade out nhạc nền: $e');
    }
  }

  List<String> _tracksForProfile(AudioProfile profile) {
    switch (profile) {
      case AudioProfile.stressRelief:
        return _stressTracks;
      case AudioProfile.sleepAid:
        return _sleepTracks;
      case AudioProfile.defaultPlaylist:
        return _defaultTracks;
    }
  }

  Future<void> _loadProfileSource(
    AudioProfile profile, {
    bool fallbackToDefault = true,
  }) async {
    final tracks = _tracksForProfile(profile);

    try {
      final sources = tracks
          .map((assetPath) => AudioSource.asset(assetPath, tag: assetPath))
          .toList();

      await _bgmPlayer.setAudioSources(
        sources,
        initialIndex: 0,
        initialPosition: Duration.zero,
      );
      await _bgmPlayer.setLoopMode(LoopMode.all);
      await _bgmPlayer.setVolume(_isBgmMuted ? 0 : _defaultVolume);
      _currentProfile = profile;
      notifyListeners();
    } on PlayerException catch (e) {
      if (fallbackToDefault && profile != AudioProfile.defaultPlaylist) {
        debugPrint(
          'Playlist $profile chua co file hop le, fallback ve playlist mac dinh: $e',
        );
        await _loadProfileSource(
          AudioProfile.defaultPlaylist,
          fallbackToDefault: false,
        );
        return;
      }
      rethrow;
    }
  }

  Future<void> _switchProfile(
    AudioProfile profile, {
    bool autoPlay = true,
  }) async {
    if (!_isPluginAvailable) {
      return;
    }

    try {
      await _bgmReady;
      final wasPlaying = _bgmPlayer.playing;
      await _loadProfileSource(profile);

      if ((autoPlay || wasPlaying) && !_bgmPlayer.playing) {
        await _bgmPlayer.play();
      }
    } on MissingPluginException catch (e) {
      _isPluginAvailable = false;
      debugPrint('Khong the chuyen playlist vi thieu plugin just_audio: $e');
    } catch (e) {
      debugPrint('Khong the chuyen profile am thanh: $e');
    }
  }

  Future<void> _setupAudioSession() async {
    if (!_isPluginAvailable) {
      return;
    }

    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      await _interruptionSub?.cancel();
      _interruptionSub = session.interruptionEventStream.listen((event) {
        if (event.begin) {
          unawaited(pauseMusic());
          return;
        }
        if (!_isBgmMuted) {
          unawaited(playMusic());
        }
      });
    } on MissingPluginException catch (e) {
      _isPluginAvailable = false;
      debugPrint('audio_session chưa sẵn sàng: $e');
    } catch (e) {
      debugPrint('Lỗi cấu hình audio session: $e');
    }
  }

  Future<void> playMusic() async {
    if (!_isPluginAvailable) {
      return;
    }

    try {
      await _bgmReady;
      await _bgmPlayer.setVolume(_isBgmMuted ? 0 : _defaultVolume);
      if (!_bgmPlayer.playing) {
        await _bgmPlayer.play();
      }
    } on MissingPluginException catch (e) {
      _isPluginAvailable = false;
      debugPrint('just_audio bị mất plugin sau restart: $e');
    } catch (e) {
      debugPrint('Không thể phát BGM: $e');
    }
  }

  Future<void> pauseMusic() async {
    if (!_isPluginAvailable) {
      return;
    }

    try {
      await _bgmReady;
      if (_bgmPlayer.playing) {
        await _bgmPlayer.pause();
      }
    } on MissingPluginException catch (e) {
      _isPluginAvailable = false;
      debugPrint('Không thể pause vì thiếu plugin just_audio: $e');
    } catch (e) {
      debugPrint('Không thể tạm dừng BGM: $e');
    }
  }

  // Hàm bật/tắt tiếng (Toggle Mute) cho người dùng
  Future<void> toggleMute() async {
    _isBgmMuted = !_isBgmMuted;
    if (_isPluginAvailable) {
      try {
        await _bgmReady;
        await _bgmPlayer.setVolume(_isBgmMuted ? 0 : _defaultVolume);
      } catch (e) {
        debugPrint('Không thể cập nhật âm lượng: $e');
      }
    }
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasPlayingBeforePause = _bgmPlayer.playing;
      if (_wasPlayingBeforePause) {
        unawaited(pauseMusic());
      }
      return;
    }

    if (state == AppLifecycleState.resumed && _wasPlayingBeforePause) {
      _wasPlayingBeforePause = false;
      if (!_isBgmMuted) {
        unawaited(playMusic());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_playerStateSub?.cancel());
    unawaited(_interruptionSub?.cancel());
    unawaited(
      _bgmPlayer.dispose().catchError((Object e) {
        debugPrint('Không thể dispose BGM player: $e');
      }),
    );

    super.dispose();
  }
}
