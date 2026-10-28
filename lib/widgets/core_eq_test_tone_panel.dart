import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine/core_eq_android_audio.dart';

const _panelBg = Color(0xFF12161B);
const _panelLine = Color(0xFF293139);
const _panelText = Color(0xFFF1F3F4);
const _panelMuted = Color(0xFF89949D);
const _panelCyan = Color(0xFF7CE7DF);
const _panelAmber = Color(0xFFFFBD72);

/// Visible control for the Android generated test tone only.
class CoreEqTestTonePanel extends StatefulWidget {
  const CoreEqTestTonePanel({super.key});

  @override
  State<CoreEqTestTonePanel> createState() => _CoreEqTestTonePanelState();
}

class _CoreEqTestTonePanelState extends State<CoreEqTestTonePanel> {
  final CoreEqAndroidAudio _audio = CoreEqAndroidAudio();
  bool _running = false;
  bool _busy = false;
  String? _error;

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final status = _running
          ? await _audio.stop()
          : await _audio.startTestTone();
      if (!mounted) return;
      setState(() {
        _running = status.running;
        _error = status.error;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = error is PlatformException
            ? (error.message ?? error.code)
            : 'Android audio is unavailable on this platform.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    // Best-effort shutdown if the widget is removed while playback is active.
    if (_running) {
      _audio.stop().catchError((Object _) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _panelBg,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _panelLine),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('ANDROID AUDIO TEST', style: TextStyle(
        color: _panelText, fontSize: 12, fontWeight: FontWeight.w800,
        letterSpacing: .7,
      )),
      const SizedBox(height: 7),
      Text(
        _running
            ? 'Generated 440 Hz tone is playing through the native DSP.'
            : 'Play a generated 440 Hz tone through the native DSP and Android output.',
        style: const TextStyle(color: _panelMuted, fontSize: 10, height: 1.5),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _busy || !defaultTargetPlatformIsAndroid ? null : _toggle,
          icon: _busy
              ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(_running ? Icons.stop_circle_outlined : Icons.play_circle_outline),
          label: Text(_busy ? 'PLEASE WAIT' : _running ? 'STOP TEST TONE' : 'START TEST TONE'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _running ? _panelAmber : _panelCyan,
            side: const BorderSide(color: _panelLine),
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
      ),
      if (!defaultTargetPlatformIsAndroid) ...[
        const SizedBox(height: 8),
        const Text('Android only. No audio is started on this platform.',
          style: TextStyle(color: _panelMuted, fontSize: 10)),
      ],
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text('Audio error: $_error',
          style: const TextStyle(color: _panelAmber, fontSize: 10, height: 1.4)),
      ],
      const SizedBox(height: 8),
      const Text(
        'Test tone only. This does not capture microphone audio or process other apps.',
        style: TextStyle(color: _panelMuted, fontSize: 9, height: 1.45),
      ),
    ]),
  );
}

bool get defaultTargetPlatformIsAndroid =>
    defaultTargetPlatform == TargetPlatform.android;
