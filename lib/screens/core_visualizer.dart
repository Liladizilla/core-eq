import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../engine/core_eq_control_mapper.dart';
import '../engine/core_eq_android_audio.dart';
import '../widgets/core_eq_test_tone_panel.dart';

const _bg = Color(0xFF090B0E);
const _surface = Color(0xFF12161B);
const _raised = Color(0xFF1A2026);
const _line = Color(0xFF293139);
const _text = Color(0xFFF1F3F4);
const _muted = Color(0xFF89949D);
const _cyan = Color(0xFF7CE7DF);
const _amber = Color(0xFFFFBD72);

class CoreVisualizerScreen extends StatefulWidget {
  const CoreVisualizerScreen({super.key});
  @override
  State<CoreVisualizerScreen> createState() => _CoreVisualizerScreenState();
}

class _CoreVisualizerScreenState extends State<CoreVisualizerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this, duration: const Duration(seconds: 14),
  )..repeat();
  final CoreEqAndroidAudio _audio = CoreEqAndroidAudio();
  Timer? _statusTimer;
  bool _toneRunning = false;
  bool _statusReadRunning = false;
  double _peakLevel = 0;
  int _preset = 0;
  bool _bassBoost = false;
  bool _limiter = true;
  bool _bypass = false;
  bool _spatial = false;
  double _bass = 0;
  double _volume = 0;
  final List<double> _bands = List<double>.filled(10, 0);
  bool _nativeSyncRunning = false;
  bool _nativeSyncRequested = false;
  String? _nativeControlError;

  static const _presets = ['Flat', 'Bass', 'Vocal', 'Rock', 'Podcast'];
  static const _frequencies = ['32', '64', '125', '250', '500', '1k', '2k', '4k', '8k', '16k'];

  @override
  void initState() {
    super.initState();
    _statusTimer = Timer.periodic(
      const Duration(milliseconds: 160),
      (_) => _refreshAudioStatus(),
    );
  }

  Future<void> _refreshAudioStatus() async {
    if (_statusReadRunning) return;
    _statusReadRunning = true;
    try {
      final status = await _audio.readStatus();
      if (!mounted) return;
      final peak = status.running ? status.peakLevel : 0.0;
      if (_toneRunning != status.running || (_peakLevel - peak).abs() >= 0.015) {
        setState(() {
          _toneRunning = status.running;
          _peakLevel = peak;
        });
      }
    } catch (_) {
      // The platform channel may be unavailable on desktop or in widget tests.
      // Never leave a stale "active" signal visible after a failed status read.
      if (mounted && (_toneRunning || _peakLevel != 0)) {
        setState(() {
          _toneRunning = false;
          _peakLevel = 0;
        });
      }
    } finally {
      _statusReadRunning = false;
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  void _syncNativeSettings() {
    // Coalesce rapid slider/preset changes instead of queuing a complete stale
    // snapshot for every pointer event. While native writes are in flight,
    // remember only that another pass is needed; the next pass reads current
    // state after the previous pass finishes.
    _nativeSyncRequested = true;
    if (_nativeSyncRunning) return;
    _nativeSyncRunning = true;
    _runNativeSync();
  }

  Future<void> _runNativeSync() async {
    try {
      while (_nativeSyncRequested && mounted) {
        _nativeSyncRequested = false;
        final gains = List<double>.generate(_bands.length, (i) {
          final bassOffset = _bassBoost && i < 3 ? _bass : 0.0;
          return (_bands[i] + bassOffset).clamp(-12.0, 12.0).toDouble();
        });
        final outputGain = _volume;
        final bypassed = _bypass;
        final limiterEnabled = _limiter;
        try {
          for (var i = 0; i < gains.length; i++) {
            await _audio.setBandGain(i, gains[i]);
          }
          await _audio.setOutputGain(outputGain);
          await _audio.setBypassed(bypassed);
          await _audio.setLimiterEnabled(limiterEnabled);
          if (mounted && _nativeControlError != null) {
            setState(() => _nativeControlError = null);
          }
        } catch (error) {
          if (mounted) {
            setState(() => _nativeControlError =
                'Native DSP update failed. Stop the test tone, then retry. ($error)');
          }
          // Do not spin retrying a failed platform call. A later user action
          // or the visible RETRY button starts a fresh synchronization pass.
          _nativeSyncRequested = false;
        }
      }
    } finally {
      _nativeSyncRunning = false;
      // Cover a request that arrived as the previous pass was finishing.
      if (_nativeSyncRequested && mounted) _syncNativeSettings();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    body: SafeArea(child: Column(children: [
      _header(),
      Expanded(child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(wide ? 24 : 15, 18, wide ? 24 : 15, 22),
          child: wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 11, child: _visualPanel(wide)),
                const SizedBox(width: 18),
                Expanded(flex: 10, child: _controls()),
              ])
            : Column(children: [
                _visualPanel(wide),
                const SizedBox(height: 16),
                _controls(),
              ]),
        );
      })),
      _bottomBar(),
    ])),
  );

  Widget _header() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
    decoration: const BoxDecoration(
      color: _surface,
      border: Border(bottom: BorderSide(color: _line)),
    ),
    child: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: _raised, borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _line),
        ),
        child: const Icon(Icons.graphic_eq_rounded, color: _cyan, size: 23),
      ),
      const SizedBox(width: 12),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CORE-EQ', style: TextStyle(color: _text, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 2.1)),
        SizedBox(height: 3),
        Text('PERSONAL AUDIO', style: TextStyle(color: _muted, fontSize: 9, letterSpacing: 1.8)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: _bg, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: _toneRunning ? _cyan : _amber, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Text(_toneRunning ? 'TEST TONE ACTIVE' : 'AUDIO OFFLINE', style: TextStyle(color: _toneRunning ? _cyan : _muted, fontSize: 9, letterSpacing: .7, fontWeight: FontWeight.w700)),
        ]),
      ),
    ]),
  );

  Widget _panel({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) =>
    Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
      ),
      child: child,
    );

  Widget _sectionTitle(String title, {String? trailing}) => Row(children: [
    Expanded(child: Text(title, style: const TextStyle(color: _text, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .7))),
    if (trailing != null) Text(trailing, style: const TextStyle(color: _muted, fontSize: 9, letterSpacing: .6)),
  ]);

  Widget _visualPanel(bool wide) => _panel(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
    child: Column(children: [
      _sectionTitle('SPATIAL AUDIO FIELD', trailing: _spatial ? 'SPATIAL ON' : 'STEREO'),
      const SizedBox(height: 10),
      SizedBox(
        height: wide ? 400 : 300,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, _) => CustomPaint(
            painter: _FieldPainter(
              phase: _motion.value * math.pi * 2,
              intensity: _toneRunning && !_bypass ? 0.15 + _peakLevel * 1.5 : 0.0,
              spatial: _spatial,
              active: _toneRunning && !_bypass,
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(13)),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, color: _amber, size: 15),
          const SizedBox(width: 8),
          Expanded(child: Text(
            _toneRunning
                ? 'Generated test tone active. Field intensity follows the native DSP peak; microphone and system audio are not connected.'
                : 'No audio stream connected. Start the generated test tone to drive the field from native DSP measurements.',
            style: const TextStyle(color: _muted, fontSize: 10, height: 1.4),
          )),
        ]),
      ),
    ]),
  );

  Widget _controls() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('SOUND PROFILE', trailing: 'PRESETS'),
      const SizedBox(height: 14),
      Wrap(spacing: 7, runSpacing: 8, children: List.generate(_presets.length, (i) {
        final selected = _preset == i;
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () { setState(() {
            _preset = i;
            final curve = CoreEqControlMapper.presetGainsDb[_presets[i]]!;
            for (var j = 0; j < _bands.length; j++) {
              _bands[j] = curve[j];
            }
            _bass = 0;
            _bassBoost = false;
          });
          _syncNativeSettings();
        },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF203936) : _raised,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selected ? _cyan : _line),
            ),
            child: Text(_presets[i], style: TextStyle(
              color: selected ? _cyan : _muted, fontSize: 11, fontWeight: FontWeight.w700,
            )),
          ),
        );
      })),
    ])),
    const SizedBox(height: 12),
    _panel(child: Column(children: [
      Row(children: [
        const Expanded(child: Text('BASS BOOST', style: TextStyle(color: _text, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .5))),
        Switch.adaptive(value: _bassBoost, activeTrackColor: _cyan, onChanged: (v) {
          setState(() {
            _bassBoost = v;
            if (v && _bass == 0) _bass = 5;
            if (!v) _bass = 0;
          });
          _syncNativeSettings();
        }),
      ]),
      _sliderRow('Bass amount', _bass, -6, 12, (v) {
        setState(() => _bass = v);
        _syncNativeSettings();
      }, suffix: ' dB'),
      const Divider(color: _line, height: 22),
      Row(children: [
        const Expanded(child: Text('GRAPHIC EQUALIZER', style: TextStyle(color: _text, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .5))),
        TextButton(onPressed: () {
          setState(() {
            for (var i = 0; i < _bands.length; i++) { _bands[i] = 0; }
            _preset = 0;
          });
          _syncNativeSettings();
        }, child: const Text('RESET', style: TextStyle(color: _cyan, fontSize: 10))),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        height: 176,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: List.generate(10, (i) =>
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Column(children: [
              Expanded(child: RotatedBox(
                quarterTurns: 3,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2, activeTrackColor: _cyan, inactiveTrackColor: _line,
                    thumbColor: _text, overlayShape: SliderComponentShape.noOverlay,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  ),
                  child: Slider(value: _bands[i], min: -12, max: 12, onChanged: (v) { setState(() { _bands[i] = v; _preset = 0; }); _syncNativeSettings(); }),
                ),
              )),
              const SizedBox(height: 4),
              Text(_frequencies[i], style: const TextStyle(color: _muted, fontSize: 8)),
            ]),
          )),
        )),
      ),
      const SizedBox(height: 6),
      const Text('−12 dB                                      0                                      +12 dB', style: TextStyle(color: _muted, fontSize: 8)),
    ])),
    const SizedBox(height: 12),
    _panel(child: Column(children: [
      _toggleRow(Icons.shield_outlined, 'LIMITER', 'Limit generated-tone output peaks', _limiter, (v) { setState(() => _limiter = v); _syncNativeSettings(); }),
      const Divider(color: _line, height: 18),
      _toggleRow(Icons.spatial_audio_rounded, 'SPATIAL AUDIO', 'Wider stereo presentation', _spatial, (v) => setState(() => _spatial = v)),
      const Divider(color: _line, height: 18),
      _sliderRow('Output level', _volume, -24, 6, (v) { setState(() => _volume = v); _syncNativeSettings(); }, suffix: ' dB'),
    ])),
    const SizedBox(height: 12),
    if (_nativeControlError != null) ...[
      _panel(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.warning_amber_rounded, color: _amber, size: 18),
        const SizedBox(width: 9),
        Expanded(child: Text(_nativeControlError!, style: const TextStyle(color: _amber, fontSize: 10, height: 1.4))),
        TextButton(onPressed: _syncNativeSettings, child: const Text('RETRY', style: TextStyle(color: _cyan, fontSize: 10))),
      ])),
      const SizedBox(height: 12),
    ],
    _panel(child: Row(children: [
      const Icon(Icons.memory_rounded, color: _muted, size: 18),
      const SizedBox(width: 10),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PROCESSING ENGINE', style: TextStyle(color: _text, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .5)),
        SizedBox(height: 4),
        Text('10-band EQ, bass boost, output gain and bypass run through native DSP. The limiter processes the generated-tone PCM output; spatial audio remains UI-only. Microphone and system audio are not connected.', style: TextStyle(color: _muted, fontSize: 10, height: 1.4)),
      ])),
    ])),
    const SizedBox(height: 12),
    CoreEqTestTonePanel(audio: _audio),
  ]);

  Widget _sliderRow(String label, double value, double min, double max, ValueChanged<double> changed, {String suffix = ''}) =>
    Row(children: [
      SizedBox(width: 94, child: Text(label, style: const TextStyle(color: _muted, fontSize: 10))),
      Expanded(child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: _cyan, inactiveTrackColor: _line, thumbColor: _text,
          overlayShape: SliderComponentShape.noOverlay, trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
        ),
        child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: changed),
      )),
      SizedBox(width: 43, child: Text('${value.toStringAsFixed(0)}$suffix', textAlign: TextAlign.end, style: const TextStyle(color: _cyan, fontSize: 10, fontWeight: FontWeight.w700))),
    ]);

  Widget _toggleRow(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> changed) => Row(children: [
    Container(width: 37, height: 37, decoration: BoxDecoration(color: _raised, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: _cyan, size: 19)),
    const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: _text, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .5)),
      const SizedBox(height: 3),
      Text(subtitle, style: const TextStyle(color: _muted, fontSize: 9)),
    ])),
    Switch.adaptive(value: value, activeTrackColor: _cyan, onChanged: changed),
  ]);

  Widget _bottomBar() => Container(
    padding: const EdgeInsets.fromLTRB(15, 10, 15, 12),
    decoration: const BoxDecoration(color: _surface, border: Border(top: BorderSide(color: _line))),
    child: Row(children: [
      Expanded(child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: _bypass ? _amber : _cyan,
          side: BorderSide(color: _bypass ? _amber : _line),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: () { setState(() => _bypass = !_bypass); _syncNativeSettings(); },
        icon: Icon(_bypass ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded, size: 19),
        label: Text(_bypass ? 'BYPASS SELECTED' : 'BYPASS', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8)),
      )),
      const SizedBox(width: 10),
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: _muted, side: const BorderSide(color: _line),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 17),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: () {
          setState(() {
            _preset = 0; _bassBoost = false; _limiter = true; _spatial = false; _bypass = false; _bass = 0; _volume = 0;
            for (var i = 0; i < _bands.length; i++) { _bands[i] = 0; }
          });
          _syncNativeSettings();
        },
        child: const Text('RESET ALL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
      ),
    ]),
  );
}

class _FieldPainter extends CustomPainter {
  const _FieldPainter({required this.phase, required this.intensity, required this.spatial, required this.active});
  final double phase;
  final double intensity;
  final bool spatial;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .5, size.height * .48);
    final radius = math.min(size.width * .34, size.height * .33);
    final grid = Paint()..style = PaintingStyle.stroke..strokeWidth = .7..color = _line;
    // A restrained technical field while the real audio-analysis feed is not yet connected.
    for (var i = 0; i < 5; i++) {
      canvas.drawOval(Rect.fromCenter(center: center, width: radius * (1.2 + i * .22), height: radius * (1.2 + i * .22) * (spatial ? .64 : .84)), grid..color = _line.withValues(alpha: .7 - i * .1));
    }
    final globe = Paint()..shader = const RadialGradient(
      colors: [Color(0xFF243C3D), Color(0xFF111A20), Color(0xFF0A0E12)],
      stops: [0, .48, 1],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, globe);
    canvas.drawCircle(center, radius, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.1..color = _cyan.withValues(alpha: .65));
    for (var lat = -5; lat <= 5; lat++) {
      final y = lat / 6.4;
      final width = radius * math.sqrt(math.max(0, 1 - y * y));
      canvas.drawOval(Rect.fromCenter(center: center + Offset(0, y * radius), width: width * 2, height: math.max(2, radius * (.15 + (1 - y.abs()) * .1))), grid..color = _cyan.withValues(alpha: .14));
    }
    for (var lon = 0; lon < 10; lon++) {
      final squeeze = math.cos(phase * .18 + lon * math.pi / 10);
      final path = Path();
      for (var j = 0; j <= 80; j++) {
        final t = j / 80 * math.pi * 2;
        final point = Offset(center.dx + math.sin(t) * radius * squeeze, center.dy + math.cos(t) * radius);
        if (j == 0) { path.moveTo(point.dx, point.dy); } else { path.lineTo(point.dx, point.dy); }
      }
      canvas.drawPath(path, grid..color = _cyan.withValues(alpha: .13));
    }
    for (var i = 0; i < 100; i++) {
      final angle = i * math.pi * 2 / 100 + phase * .1;
      final wave = .5 + .5 * math.sin(i * .43 + phase * 1.4) * math.cos(i * .17 - phase * .6);
      final height = (4 + wave * 27) * intensity;
      final inner = radius * 1.08;
      final outer = inner + height;
      final a = center + Offset(math.cos(angle) * inner, math.sin(angle) * inner * .8);
      final b = center + Offset(math.cos(angle) * outer, math.sin(angle) * outer * .8);
      final front = math.cos(angle - phase * .15) > -.15;
      canvas.drawLine(a, b, Paint()
        ..color = (wave > .82 ? _amber : _cyan).withValues(alpha: front ? .85 : .16)
        ..strokeWidth = spatial ? 2.5 : 1.7
        ..strokeCap = StrokeCap.round);
    }
    final label = TextPainter(
      text: const TextSpan(text: 'CORE / FIELD', style: TextStyle(color: _muted, fontSize: 9, letterSpacing: 1.4)),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, const Offset(3, 2));
    final status = TextPainter(
      text: TextSpan(text: active ? 'NATIVE DSP / SIGNAL' : 'AWAITING AUDIO INPUT', style: const TextStyle(color: _muted, fontSize: 8, letterSpacing: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    status.paint(canvas, Offset(3, size.height - 14));
  }

  @override
  bool shouldRepaint(covariant _FieldPainter old) =>
      old.phase != phase || old.intensity != intensity || old.spatial != spatial || old.active != active;
}
