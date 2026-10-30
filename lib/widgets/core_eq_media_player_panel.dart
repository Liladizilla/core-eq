import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../engine/core_eq_android_audio.dart';

/// Local-file playback through Media3 and the native CORE-EQ DSP on Android.
class CoreEqMediaPlayerPanel extends StatefulWidget {
  const CoreEqMediaPlayerPanel({super.key});

  @override
  State<CoreEqMediaPlayerPanel> createState() => _CoreEqMediaPlayerPanelState();
}

class _CoreEqMediaPlayerPanelState extends State<CoreEqMediaPlayerPanel> {
  final CoreEqAndroidAudio _audio = CoreEqAndroidAudio();
  CoreEqMediaStatus _status = const CoreEqMediaStatus(
    isPlaying: false, playWhenReady: false, state: 'idle',
    positionMs: 0, durationMs: null, mediaUri: null,
  );
  Timer? _poller;
  bool _busy = false;
  String? _error;
  String? _fileName;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poller = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_status.playWhenReady && mounted) _refresh();
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<CoreEqMediaStatus> Function() action) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final status = await action();
      if (mounted) setState(() => _status = status);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    try {
      final status = await _audio.readMediaStatus();
      if (mounted) setState(() => _status = status);
    } catch (_) {
      // Native playback is Android-only; don't spam the UI during platform probing.
    }
  }

  Future<void> _pickAndPlay() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.audio, allowMultiple: false, withData: false,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final path = file.path;
      if (path == null || path.isEmpty) {
        throw StateError('Android did not provide a readable path for this audio file.');
      }
      final status = await _audio.playMedia(Uri.file(path).toString());
      if (mounted) {
        setState(() { _status = status; _fileName = file.name; });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _time(int milliseconds) {
    final seconds = (milliseconds / 1000).floor();
    final minutes = seconds ~/ 60;
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF7CE7DF);
    const muted = Color(0xFF9AA5AE);
    const line = Color(0xFF293139);
    if (defaultTargetPlatform != TargetPlatform.android) return const SizedBox.shrink();

    final duration = _status.durationMs;
    final maxPosition = duration != null && duration > 0 ? duration.toDouble() : 1.0;
    final position = _status.positionMs.toDouble().clamp(0.0, maxPosition);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12161B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.graphic_eq_rounded, color: cyan, size: 19),
            SizedBox(width: 9),
            Expanded(child: Text('LOCAL PLAYBACK / DSP PATH', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .7))),
          ]),
          const SizedBox(height: 8),
          const Text('Play a local audio file through the native equalizer. This does not process Spotify or other apps.', style: TextStyle(color: muted, fontSize: 10, height: 1.45)),
          const SizedBox(height: 14),
          Row(children: [
            const Icon(Icons.audio_file_outlined, color: muted, size: 20),
            const SizedBox(width: 9),
            Expanded(child: Text(_fileName ?? 'No track selected', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12))),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _busy ? null : _pickAndPlay,
              style: OutlinedButton.styleFrom(foregroundColor: cyan, side: const BorderSide(color: line)),
              child: const Text('CHOOSE FILE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 8),
          Slider(
            value: position,
            min: 0,
            max: maxPosition,
            onChanged: duration == null || duration <= 0 || _busy
                ? null
                : (value) => setState(() => _status = CoreEqMediaStatus(
                      isPlaying: _status.isPlaying,
                      playWhenReady: _status.playWhenReady,
                      state: _status.state,
                      positionMs: value.round(),
                      durationMs: _status.durationMs,
                      mediaUri: _status.mediaUri,
                      inputPeakLevel: _status.inputPeakLevel,
                      outputPeakLevel: _status.outputPeakLevel,
                      processedFrames: _status.processedFrames,
                      sampleRateHz: _status.sampleRateHz,
                      channels: _status.channels,
                    )),
            onChangeEnd: duration == null || duration <= 0
                ? null
                : (value) => _run(() => _audio.seekMedia(Duration(milliseconds: value.round()))),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_time(_status.positionMs), style: const TextStyle(color: muted, fontSize: 10)),
            Text(duration == null ? _status.state.toUpperCase() : _time(duration), style: const TextStyle(color: muted, fontSize: 10)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: _busy || _status.mediaUri == null
                  ? null
                  : () => _run(() => _status.isPlaying ? _audio.pauseMedia() : _audio.resumeMedia()),
              icon: Icon(_status.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 17),
              label: Text(_status.isPlaying ? 'PAUSE' : 'PLAY', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(foregroundColor: cyan, side: const BorderSide(color: line)),
            )),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _busy || _status.mediaUri == null ? null : () => _run(_audio.stopMedia),
              style: OutlinedButton.styleFrom(foregroundColor: muted, side: const BorderSide(color: line)),
              child: const Text('STOP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Color(0xFFFFBD72), fontSize: 10, height: 1.4)),
          ],
          const SizedBox(height: 8),
          Text('ENGINE: MEDIA3 / NATIVE C++  •  STATE: ${_status.state.toUpperCase()}', style: const TextStyle(color: muted, fontSize: 8, letterSpacing: .4)),
          const SizedBox(height: 7),
          Row(children: [
            Expanded(child: Text('IN ${(_status.inputPeakLevel * 100).toStringAsFixed(1)}%', style: const TextStyle(color: muted, fontSize: 9, fontFeatures: [FontFeature.tabularFigures()]))),
            Expanded(child: Text('DSP OUT ${(_status.outputPeakLevel * 100).toStringAsFixed(1)}%', style: TextStyle(color: _status.outputPeakLevel > 1.0 ? const Color(0xFFFFBD72) : cyan, fontSize: 9, fontFeatures: const [FontFeature.tabularFigures()]))),
            Text(_status.sampleRateHz > 0 ? '${_status.sampleRateHz ~/ 1000}k / ${_status.channels}ch' : 'DSP idle', style: const TextStyle(color: muted, fontSize: 9)),
          ]),
          if (_status.processedFrames > 0 && _status.outputPeakLevel > 1.0) ...[
            const SizedBox(height: 5),
            const Text('OUTPUT CLIPPING: reduce EQ boost or lower output gain.', style: TextStyle(color: Color(0xFFFFBD72), fontSize: 9)),
          ],
        ],
      ),
    );
  }
}
