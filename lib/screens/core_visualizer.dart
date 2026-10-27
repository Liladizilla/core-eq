import 'dart:math' as math;
import 'package:flutter/material.dart';

const bg = Color(0xFF080A0D);
const panel = Color(0xFF11161B);
const plate = Color(0xFF171E24);
const edge = Color(0xFF303B43);
const ink = Color(0xFFE8EEF1);
const muted = Color(0xFF78858D);
const cyan = Color(0xFF62E6E3);
const amber = Color(0xFFFFB45C);

class CoreVisualizerScreen extends StatefulWidget {
  const CoreVisualizerScreen({super.key});
  @override
  State<CoreVisualizerScreen> createState() => _CoreVisualizerScreenState();
}

class _CoreVisualizerScreenState extends State<CoreVisualizerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this, duration: const Duration(seconds: 12),
  )..repeat();
  int mode = 0;
  int selected = 1;
  bool bypass = false;
  double intensity = .64;

  static const modules = [
    ['IN', 'INPUT STAGE', 'TRIM / HEADROOM'],
    ['EQ', 'PARAMETRIC EQ', '10-BAND FILTER BANK'],
    ['DY', 'DYNAMIC EQ', 'FREQUENCY-DEPENDENT'],
    ['MB', 'MULTIBAND', '3-BAND DYNAMICS'],
    ['BS', 'BASS ENGINE', 'HARMONIC SYNTHESIS'],
    ['ST', 'STEREO FIELD', 'MID / SIDE WIDTH'],
    ['LM', 'TRUE-PEAK LIMITER', 'OUTPUT PROTECTION'],
  ];

  @override
  void dispose() { motion.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: bg,
    body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 720;
      return Column(children: [
        header(wide),
        Expanded(child: wide
          ? Row(children: [SizedBox(width: 58, child: rail()), Expanded(child: body(wide))])
          : body(wide)),
        bottomBar(wide),
      ]);
    })),
  );

  Widget header(bool wide) => Container(
    height: 65, padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 15),
    decoration: const BoxDecoration(color: panel, border: Border(bottom: BorderSide(color: edge))),
    child: Row(children: [
      Container(width: 34, height: 34, decoration: BoxDecoration(color: plate, border: Border.all(color: edge)),
        child: const Icon(Icons.graphic_eq, color: cyan, size: 19)),
      const SizedBox(width: 11),
      const Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CORE-EQ', style: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2.8, height: 1)),
        SizedBox(height: 5),
        Text('PERSONAL AUDIO PROCESSOR', style: TextStyle(color: muted, fontSize: 8, letterSpacing: 1.5)),
      ]),
      const Spacer(),
      if (wide) ...[chip('48 kHz', muted), const SizedBox(width: 7), chip('DSP LINK: OFFLINE', amber), const SizedBox(width: 12)],
      chip(bypass ? 'BYPASS' : 'VISUAL DEMO', bypass ? amber : cyan),
    ]),
  );

  Widget chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    decoration: BoxDecoration(color: plate, border: Border.all(color: edge)),
    child: Text(label, style: TextStyle(color: color, fontSize: 8, letterSpacing: .9, fontWeight: FontWeight.w800)),
  );

  Widget body(bool wide) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(wide ? 24 : 14, 16, wide ? 24 : 14, 16),
    child: wide
      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 6, child: visualDeck(true)),
          const SizedBox(width: 16),
          Expanded(flex: 5, child: controlDeck()),
        ])
      : Column(children: [visualDeck(false), const SizedBox(height: 14), controlDeck()]),
  );

  Widget visualDeck(bool wide) => Container(
    decoration: BoxDecoration(color: panel, border: Border.all(color: edge)),
    child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(13, 12, 13, 9), child: Row(children: [
        const Text('SPATIAL RESPONSE', style: TextStyle(color: ink, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.7)),
        const Spacer(),
        Text(mode == 0 ? 'FIELD / 360°' : 'SPECTRUM / FFT', style: const TextStyle(color: muted, fontSize: 8, letterSpacing: 1)),
      ])),
      SizedBox(height: wide ? 390 : 310, width: double.infinity,
        child: AnimatedBuilder(animation: motion, builder: (context, child) => CustomPaint(
          painter: OrbitalPainter(phase: motion.value * math.pi * 2, intensity: bypass ? .12 : intensity, spectrum: mode == 1),
        ))),
      const Divider(height: 1, color: edge),
      Padding(padding: const EdgeInsets.all(10), child: Row(children: [
        meter('INPUT', '-12.4', 'dBFS', cyan), const SizedBox(width: 7),
        meter('OUTPUT', '-9.8', 'dBFS', ink), const SizedBox(width: 7),
        meter('PEAK', '-1.0', 'dBTP', amber),
      ])),
    ]),
  );

  Widget meter(String label, String value, String unit, Color accent) => Expanded(child: Container(
    padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: plate, border: Border.all(color: edge)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: muted, fontSize: 8, letterSpacing: 1)),
      const SizedBox(height: 6),
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Flexible(child: FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(
          color: accent, fontSize: 17, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])))),
        const SizedBox(width: 3), Text(unit, style: const TextStyle(color: muted, fontSize: 7)),
      ]),
    ]),
  ));

  Widget controlDeck() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      const Text('PROCESSING CHAIN', style: TextStyle(color: ink, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.7)),
      const Spacer(), const Text('07 MODULES', style: TextStyle(color: muted, fontSize: 8, letterSpacing: 1)),
    ]),
    const SizedBox(height: 9),
    Container(decoration: BoxDecoration(color: panel, border: Border.all(color: edge)),
      child: Column(children: [for (var i = 0; i < modules.length; i++) moduleRow(i)])),
    const SizedBox(height: 12),
    Container(padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(color: panel, border: Border.all(color: edge)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 3, height: 27, color: cyan), const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(modules[selected][1], style: const TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text('STAGE ' + (selected + 1).toString().padLeft(2, '0') + ' / ' + modules[selected][2],
              style: const TextStyle(color: muted, fontSize: 7, letterSpacing: .6)),
          ])),
          TextButton(onPressed: () => setState(() => intensity = .64), child: const Text('RESET', style: TextStyle(color: muted, fontSize: 8))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Text('INTENSITY', style: TextStyle(color: muted, fontSize: 8, letterSpacing: 1)),
          Expanded(child: SliderTheme(data: SliderTheme.of(context).copyWith(
            activeTrackColor: cyan, inactiveTrackColor: edge, thumbColor: ink,
            overlayColor: cyan.withOpacity(.08), trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5)),
            child: Slider(value: intensity, min: 0, max: 1, onChanged: (v) => setState(() => intensity = v)))),
          SizedBox(width: 32, child: Text((intensity * 100).round().toString() + '%', textAlign: TextAlign.right,
            style: const TextStyle(color: cyan, fontSize: 9, fontFeatures: [FontFeature.tabularFigures()]))),
        ]),
        Row(children: [
          Expanded(child: modeButton(0, 'ORBITAL FIELD')), const SizedBox(width: 7),
          Expanded(child: modeButton(1, 'SPECTRUM')),
        ]),
      ])),
    const SizedBox(height: 10),
    Row(children: [Expanded(child: telemetry('ENGINE', 'NOT CONNECTED')), const SizedBox(width: 7), Expanded(child: telemetry('LATENCY', 'NOT MEASURED'))]),
  ]);

  Widget moduleRow(int i) {
    final item = modules[i];
    final active = i == selected;
    return InkWell(onTap: () => setState(() => selected = i), child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(color: active ? const Color(0xFF1B292D) : Colors.transparent, border: const Border(bottom: BorderSide(color: edge))),
      child: Row(children: [
        Container(width: 29, height: 28, alignment: Alignment.center, decoration: BoxDecoration(color: plate, border: Border.all(color: active ? cyan : edge)),
          child: Text(item[0], style: TextStyle(color: active ? cyan : muted, fontSize: 8, fontWeight: FontWeight.w800))),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item[1], style: TextStyle(color: active ? ink : const Color(0xFFB7C0C5), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .7)),
          const SizedBox(height: 3), Text(item[2], style: const TextStyle(color: muted, fontSize: 7, letterSpacing: .5)),
        ])),
        Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: bypass ? edge : (active ? cyan : const Color(0xFF53616A)))),
        const SizedBox(width: 7), Icon(Icons.chevron_right, size: 15, color: active ? cyan : muted),
      ]),
    ));
  }

  Widget modeButton(int value, String label) {
    final active = mode == value;
    return InkWell(onTap: () => setState(() => mode = value), child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10), alignment: Alignment.center,
      decoration: BoxDecoration(color: active ? const Color(0xFF183035) : plate, border: Border.all(color: active ? cyan : edge)),
      child: Text(label, style: TextStyle(color: active ? cyan : muted, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: .6)),
    ));
  }

  Widget telemetry(String label, String value) => Container(padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: panel, border: Border.all(color: edge)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: muted, fontSize: 7, letterSpacing: 1)),
      const SizedBox(height: 6), Text(value, style: const TextStyle(color: amber, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: .4)),
    ]));

  Widget rail() => Container(decoration: const BoxDecoration(color: panel, border: Border(right: BorderSide(color: edge))),
    child: Column(children: [
      const SizedBox(height: 14), railIcon(Icons.dashboard_outlined, true), railIcon(Icons.tune, false),
      railIcon(Icons.equalizer, false), railIcon(Icons.settings_outlined, false), const Spacer(),
      const RotatedBox(quarterTurns: 3, child: Padding(padding: EdgeInsets.only(bottom: 18),
        child: Text('CORE AUDIO / LAB', style: TextStyle(color: muted, fontSize: 7, letterSpacing: 1.5)))),
      const SizedBox(height: 18),
    ]));

  Widget railIcon(IconData icon, bool active) => Padding(padding: const EdgeInsets.only(bottom: 9),
    child: Container(width: 36, height: 36, decoration: BoxDecoration(color: active ? const Color(0xFF183035) : Colors.transparent, border: Border.all(color: active ? cyan : edge)),
      child: Icon(icon, size: 17, color: active ? cyan : muted)));

  Widget bottomBar(bool wide) => Container(
    padding: EdgeInsets.fromLTRB(wide ? 24 : 14, 9, wide ? 24 : 14, 10),
    decoration: const BoxDecoration(color: panel, border: Border(top: BorderSide(color: edge))),
    child: Row(children: [
      Expanded(child: InkWell(onTap: () => setState(() => bypass = !bypass), child: Container(height: 43,
        decoration: BoxDecoration(color: bypass ? const Color(0xFF352719) : const Color(0xFF173034), border: Border.all(color: bypass ? amber : cyan)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.power_settings_new, size: 17, color: bypass ? amber : cyan), const SizedBox(width: 8),
          Text(bypass ? 'PROCESSING BYPASSED' : 'MASTER BYPASS', style: TextStyle(color: bypass ? amber : cyan, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
        ])))),
      const SizedBox(width: 8),
      Container(width: 56, height: 43, alignment: Alignment.center, decoration: BoxDecoration(color: plate, border: Border.all(color: edge)),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('A/B', style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w800)),
          Text('SLOT', style: TextStyle(color: muted, fontSize: 6, letterSpacing: 1)),
        ])),
    ]),
  );
}

class OrbitalPainter extends CustomPainter {
  const OrbitalPainter({required this.phase, required this.intensity, required this.spectrum});
  final double phase;
  final double intensity;
  final bool spectrum;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * .5, size.height * .49);
    final r = math.min(size.width * .35, size.height * .36);
    final grid = Paint()..style = PaintingStyle.stroke..strokeWidth = .7..color = edge;
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(c, r * (1.14 + i * .14), grid..color = edge.withOpacity(i == 0 ? .8 : .3));
    }
    for (var i = 0; i < 72; i++) {
      final a = i * math.pi * 2 / 72;
      final inner = r * (1.18 + (i % 6 == 0 ? .08 : 0));
      final outer = r * (i % 6 == 0 ? 1.31 : 1.22);
      canvas.drawLine(c + Offset(math.cos(a) * inner, math.sin(a) * inner), c + Offset(math.cos(a) * outer, math.sin(a) * outer),
        Paint()..color = muted.withOpacity(i % 6 == 0 ? .65 : .22)..strokeWidth = i % 6 == 0 ? 1.2 : .6);
    }
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF0B1115));
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.1..color = cyan.withOpacity(.55));
    for (var lat = -5; lat <= 5; lat++) {
      final y = lat / 6.4;
      final w = r * math.sqrt(math.max(0, 1 - y * y));
      canvas.drawOval(Rect.fromCenter(center: c + Offset(0, y * r), width: w * 2, height: math.max(3, r * (.18 + (1 - y.abs()) * .1))),
        grid..color = cyan.withOpacity(lat == 0 ? .4 : .17));
    }
    for (var lon = 0; lon < 8; lon++) {
      final squeeze = math.cos(phase * .22 + lon * math.pi / 8);
      final path = Path();
      for (var j = 0; j <= 64; j++) {
        final t = j / 64 * math.pi * 2;
        final p = Offset(c.dx + math.sin(t) * r * squeeze, c.dy + math.cos(t) * r);
        if (j == 0) { path.moveTo(p.dx, p.dy); } else { path.lineTo(p.dx, p.dy); }
      }
      canvas.drawPath(path, grid..color = cyan.withOpacity(.16));
    }
    // Deliberately labeled demo motion until live PCM data is connected.
    final count = spectrum ? 96 : 68;
    for (var i = 0; i < count; i++) {
      final a = i * math.pi * 2 / count + phase * .14;
      final wave = .5 + .5 * math.sin(i * .61 + phase * 1.8) * math.cos(i * .19 - phase * .72);
      final envelope = .28 + .72 * math.pow(wave, 1.4).toDouble();
      final h = (spectrum ? 5 + envelope * 29 : 4 + envelope * 22) * intensity;
      final base = r * (spectrum ? .75 : .82);
      final front = math.cos(a - phase * .25) > -.1;
      final p1 = c + Offset(math.cos(a) * base, math.sin(a) * base * .76);
      final p2 = c + Offset(math.cos(a) * (base + h), math.sin(a) * (base + h) * .76);
      final accent = wave > .77 ? amber : cyan;
      canvas.drawLine(p1, p2, Paint()..color = (front ? accent : muted).withOpacity(front ? .9 : .2)
        ..strokeWidth = spectrum ? 2.2 : 2.8..strokeCap = StrokeCap.square);
      if (front && i % 4 == 0) canvas.drawCircle(p2, 1.5, Paint()..color = accent.withOpacity(.9));
    }
    canvas.drawCircle(c, r * .09, Paint()..color = const Color(0xFF13272B));
    canvas.drawCircle(c, r * .09, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = cyan.withOpacity(.6));
    canvas.drawLine(c - const Offset(7, 0), c + const Offset(7, 0), Paint()..color = ink.withOpacity(.6)..strokeWidth = .8);
    canvas.drawLine(c - const Offset(0, 7), c + const Offset(0, 7), Paint()..color = ink.withOpacity(.6)..strokeWidth = .8);
    const style = TextStyle(color: muted, fontSize: 7, letterSpacing: 1);
    label(canvas, 'LOW', Offset(c.dx - r * 1.35, c.dy + r * .85), style);
    label(canvas, 'MID', Offset(c.dx - 9, c.dy - r * 1.35), style);
    label(canvas, 'HIGH', Offset(c.dx + r * 1.02, c.dy + r * .85), style);
    label(canvas, 'CORE-EQ / SPATIAL FIELD', const Offset(12, 12), style);
    label(canvas, 'ANIMATION: DEMO SIGNAL', Offset(12, size.height - 17), style);
  }

  void label(Canvas canvas, String text, Offset position, TextStyle style) {
    final p = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    p.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant OrbitalPainter old) =>
    old.phase != phase || old.intensity != intensity || old.spectrum != spectrum;
}
