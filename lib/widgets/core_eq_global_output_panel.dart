import 'dart:async';

import 'package:flutter/material.dart';

import '../engine/core_eq_android_audio.dart';

/// Controls Android's OEM global output effects when the device exposes them.
class CoreEqGlobalOutputPanel extends StatefulWidget {
  const CoreEqGlobalOutputPanel({super.key, required this.audio});

  final CoreEqAndroidAudio audio;

  @override
  State<CoreEqGlobalOutputPanel> createState() => _CoreEqGlobalOutputPanelState();
}

class _CoreEqGlobalOutputPanelState extends State<CoreEqGlobalOutputPanel> {
  static const _bg = Color(0xFF12161B);
  static const _line = Color(0xFF293139);
  static const _text = Color(0xFFF1F3F4);
  static const _muted = Color(0xFF89949D);
  static const _cyan = Color(0xFF7CE7DF);
  static const _amber = Color(0xFFFFBD72);
  static const _labels = ['31', '63', '125', '250', '500', '1k', '2k', '4k', '8k', '16k'];

  Map<Object?, Object?> _capabilities = const {};
  Map<Object?, Object?> _route = const {};
  final List<double> _gains = List<double>.filled(10, 0);
  double _bassStrength = 500;
  bool _loading = true;
  bool _busy = false;
  bool _eqEnabled = false;
  bool _bassEnabled = false;
  String? _error;
  StreamSubscription<Map<Object?, Object?>>? _routeSubscription;

  bool get _eqAvailable => _capabilities['equalizerAvailable'] == true;
  bool get _bassAvailable => _capabilities['bassBoostAvailable'] == true;
  List<Object?> get _outputs => (_route['outputs'] as List<Object?>?) ?? const [];

  @override
  void initState() {
    super.initState();
    _routeSubscription = widget.audio.audioRouteChanges.listen((route) {
      if (mounted) setState(() => _route = route);
    });
    _refresh();
  }

  @override
  void dispose() {
    _routeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final values = await Future.wait([
        widget.audio.readGlobalEffectCapabilities(),
        widget.audio.readAudioRouteStatus(),
      ]);
      if (!mounted) return;
      setState(() {
        _capabilities = values[0];
        _route = values[1];
        _eqEnabled = values[0]['equalizerEnabled'] == true;
        _bassEnabled = values[0]['bassBoostEnabled'] == true;
        final levels = values[0]['coreBandLevelsDb'];
        if (levels is List && levels.length == _gains.length) {
          for (var i = 0; i < _gains.length; i++) {
            final levelMb = levels[i];
            if (levelMb is num) _gains[i] = (levelMb.toDouble() / 100).clamp(-12, 12).toDouble();
          }
        }
        final strength = values[0]['bassStrength'];
        if (strength is num) _bassStrength = strength.toDouble().clamp(0, 1000).toDouble();
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not query Android global effects: $error';
      });
    }
  }

  Future<void> _command(Future<Map<Object?, Object?>> Function() action) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final result = await action();
      if (!mounted) return;
      setState(() {
        _capabilities = {..._capabilities, ...result};
        _eqEnabled = result['equalizerEnabled'] == true;
        _bassEnabled = result['bassBoostEnabled'] == true;
        final levels = result['coreBandLevelsDb'];
        if (levels is List && levels.length == _gains.length) {
          for (var i = 0; i < _gains.length; i++) {
            final levelMb = levels[i];
            if (levelMb is num) _gains[i] = (levelMb.toDouble() / 100).clamp(-12, 12);
          }
        }
        final strength = result['bassStrength'];
        if (strength is num) _bassStrength = strength.toDouble().clamp(0, 1000);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _routeLabel() {
    if (_outputs.isEmpty) return 'NO OUTPUT DEVICE REPORTED';
    final names = _outputs.map((item) {
      if (item is! Map) return 'UNKNOWN';
      final type = item['type']?.toString() ?? 'other';
      return switch (type) {
        'bluetooth_a2dp' || 'bluetooth_sco' || 'bluetooth_le_headset' => 'BLUETOOTH',
        'wired_headphones' || 'wired_headset' => 'WIRED HEADPHONES',
        'usb_audio' => 'USB AUDIO',
        'built_in_speaker' => 'PHONE SPEAKER',
        'earpiece' => 'EARPIECE',
        'hdmi' => 'HDMI',
        _ => type.toUpperCase(),
      };
    }).toSet().toList();
    return names.join(' / ');
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _bg,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.headphones_rounded, color: _cyan, size: 19),
        const SizedBox(width: 9),
        const Expanded(child: Text('ANDROID OUTPUT EFFECTS', style: TextStyle(
          color: _text, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .7,
        ))),
        IconButton(
          tooltip: 'Refresh device capabilities',
          onPressed: _busy ? null : _refresh,
          icon: const Icon(Icons.refresh, color: _muted, size: 18),
        ),
      ]),
      const SizedBox(height: 5),
      Text(_routeLabel(), style: const TextStyle(
        color: _cyan, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: .7,
      )),
      const SizedBox(height: 8),
      Text(
        _loading
            ? 'Checking whether this Android device exposes global output effects…'
            : _eqAvailable || _bassAvailable
                ? 'This device exposes at least one OEM global output effect. External-app routing remains device and headphone dependent.'
                : 'This device has not exposed a usable global output equalizer or bass effect. App-owned DSP cannot modify Spotify or other apps.',
        style: const TextStyle(color: _muted, fontSize: 10, height: 1.45),
      ),
      if (_loading) const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: LinearProgressIndicator(minHeight: 2, color: _cyan, backgroundColor: _line),
      ),
      const SizedBox(height: 12),
      _switchRow(
        'GLOBAL EQUALIZER',
        'Android output-mix Equalizer, session 0',
        _eqEnabled,
        _eqAvailable && !_busy,
        (value) => _command(() => widget.audio.setGlobalEffectsEnabled(value)),
      ),
      const Divider(color: _line, height: 18),
      _switchRow(
        'GLOBAL BASS BOOST',
        'OEM BassBoost effect, session 0',
        _bassEnabled,
        _bassAvailable && !_busy,
        (value) => _command(() => widget.audio.setGlobalBassBoostEnabled(value)),
      ),
      if (_bassAvailable) ...[
        const SizedBox(height: 7),
        Row(children: [
          const Expanded(child: Text('BASS STRENGTH', style: TextStyle(color: _muted, fontSize: 9, letterSpacing: .7))),
          Text(_bassStrength.round().toString(), style: const TextStyle(color: _cyan, fontSize: 10)),
        ]),
        Slider(
          value: _bassStrength,
          min: 0,
          max: 1000,
          divisions: 100,
          activeColor: _cyan,
          inactiveColor: _line,
          onChanged: _busy ? null : (value) => setState(() => _bassStrength = value),
          onChangeEnd: _busy ? null : (value) => _command(
            () => widget.audio.setGlobalBassBoostStrength(value.round()),
          ),
        ),
      ],
      const Divider(color: _line, height: 20),
      Row(children: [
        const Expanded(child: Text('10-BAND OUTPUT EQ', style: TextStyle(
          color: _text, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .5,
        ))),
        Text(_eqAvailable ? 'DEVICE BANDS: ${_capabilities['bandCount'] ?? 0}' : 'UNAVAILABLE',
          style: const TextStyle(color: _muted, fontSize: 8)),
      ]),
      const SizedBox(height: 8),
      for (var band = 0; band < _gains.length; band++)
        Row(children: [
          SizedBox(width: 38, child: Text(_labels[band], style: const TextStyle(
            color: _muted, fontSize: 9, fontFeatures: [FontFeature.tabularFigures()],
          ))),
          Expanded(child: Slider(
            value: _gains[band],
            min: -12,
            max: 12,
            divisions: 48,
            activeColor: _cyan,
            inactiveColor: _line,
            onChanged: !_eqEnabled || _busy ? null : (value) {
              setState(() => _gains[band] = value);
            },
            onChangeEnd: !_eqEnabled || _busy ? null : (value) {
              _command(() => widget.audio.setGlobalBandGain(band, value));
            },
          )),
          SizedBox(width: 43, child: Text(
            '${_gains[band] >= 0 ? '+' : ''}${_gains[band].toStringAsFixed(1)}',
            textAlign: TextAlign.end,
            style: const TextStyle(color: _text, fontSize: 9, fontFeatures: [FontFeature.tabularFigures()]),
          )),
        ]),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, style: const TextStyle(color: _amber, fontSize: 10, height: 1.4)),
      ],
      const SizedBox(height: 7),
      const Text(
        'Session 0 support is not guaranteed by Android. The sliders map to the nearest bands exposed by the phone. Verify the effect with an external music app and the actual headphone route.',
        style: TextStyle(color: _muted, fontSize: 9, height: 1.45),
      ),
    ]),
  );

  Widget _switchRow(
    String title,
    String subtitle,
    bool value,
    bool enabled,
    ValueChanged<bool> changed,
  ) => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: _text, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .5)),
      const SizedBox(height: 3),
      Text(subtitle, style: const TextStyle(color: _muted, fontSize: 9)),
    ])),
    Switch.adaptive(value: value, onChanged: enabled ? changed : null, activeTrackColor: _cyan),
  ]);
}
