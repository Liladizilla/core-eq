import 'dart:ui';
import 'package:flutter/material.dart';

const bg = Color(0xFF07090C);
const panel = Color(0xFF10151A);
const raised = Color(0xFF151C22);
const line = Color(0xFF28343C);
const cyan = Color(0xFF00E5FF);
const amber = Color(0xFFFFB300);
const pink = Color(0xFFFF2D95);
const muted = Color(0xFF82919A);
const ink = Color(0xFFE8F0F3);

class CoreDeckScreen extends StatefulWidget {
  const CoreDeckScreen({super.key});
  @override
  State<CoreDeckScreen> createState() => _CoreDeckScreenState();
}

class _CoreDeckScreenState extends State<CoreDeckScreen> {
  bool bypass = false;
  int slot = 0;
  int selected = 1;
  String preset = 'NEUTRAL REFERENCE';
  double macro = 0;
  final gains = <double>[0, 2.5, -1.5, 1.2, .5, -.8, 1.8, 0, -1, .3];
  static const names = ['INPUT', 'PRE-EQ', 'DYN EQ', 'MBC', 'POST-EQ', 'BASS', 'WIDTH', 'LIMITER', 'OUTPUT'];
  static const details = ['Trim / gain', '10-band parametric', 'Frequency selective', 'Multiband dynamics', 'Tone shaping', 'Harmonic synthesis', 'Mid / side field', 'True peak ceiling', 'Level / balance'];
  static const frequencyLabels = ['60', '120', '250', '500', '1k', '2k', '4k', '8k', '12k', '16k'];
  static const codes = ['IN', 'EQ', 'DY', 'MB', 'EQ', 'BS', 'ST', 'LM', 'OUT'];
  static const colors = [cyan, cyan, pink, pink, cyan, amber, cyan, amber, cyan];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: bg,
    body: SafeArea(child: LayoutBuilder(builder: (context, size) {
      final wide = size.maxWidth >= 720;
      return Column(children: [
        header(wide),
        Expanded(child: wide
          ? Row(children: [SizedBox(width: 52, child: meters(true)), Expanded(child: mainDeck(true)), SizedBox(width: 45, child: analysisRail())])
          : Column(children: [Expanded(child: mainDeck(false)), SizedBox(height: 40, child: meters(false))])),
        dock(wide),
      ]);
    })),
  );

  Widget header(bool wide) => Container(
    padding: EdgeInsets.fromLTRB(wide ? 24 : 15, 13, wide ? 24 : 15, 12),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: line))),
    child: Row(children: [
      Container(width: 34, height: 34, decoration: BoxDecoration(color: cyan.withValues(alpha: .07), border: Border.all(color: cyan.withValues(alpha: .7))), child: const Icon(Icons.multitrack_audio, color: cyan, size: 19)),
      const SizedBox(width: 10),
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CORE-EQ', style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 2.4)),
        SizedBox(height: 2),
        Text('AUDIO PROCESSING SYSTEM', style: TextStyle(color: muted, fontSize: 8, letterSpacing: 1.5)),
      ]),
      const Spacer(),
      if (wide) ...[status('48 kHz', muted), const SizedBox(width: 7), status('ANDROID / DEMO', amber), const SizedBox(width: 10)],
      Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7), decoration: BoxDecoration(color: (bypass ? amber : cyan).withValues(alpha: .07), border: Border.all(color: (bypass ? amber : cyan).withValues(alpha: .6))), child: Row(children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: bypass ? amber : cyan)),
        const SizedBox(width: 7),
        Text(bypass ? 'BYPASS' : 'UI PREVIEW', style: TextStyle(color: bypass ? amber : cyan, fontSize: 9, letterSpacing: 1.1, fontWeight: FontWeight.bold)),
      ])),
    ]),
  );

  Widget status(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(border: Border.all(color: line)), child: Text(text, style: TextStyle(color: color, fontSize: 8, letterSpacing: .9)));

  Widget mainDeck(bool wide) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(wide ? 20 : 13, 15, wide ? 20 : 13, 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Text('SIGNAL PATH', style: TextStyle(color: muted, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)), const Spacer(), const Text('9 MODULES', style: TextStyle(color: muted, fontSize: 9, letterSpacing: 1.2))]),
      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: panel, border: Border.all(color: line)), child: Column(children: [
        for (int i = 0; i < names.length; i++) ...[
          if (i > 0) SizedBox(height: 13, child: Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(left: 22), child: Container(width: 1, height: 13, color: bypass ? line : cyan.withValues(alpha: .5))))),
          moduleNode(i),
        ],
      ])),
      const SizedBox(height: 16),
      editor(wide),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: telemetry('PROCESSING', bypass ? 'BYPASSED' : 'UI PREVIEW', bypass ? amber : cyan)),
        const SizedBox(width: 7),
        Expanded(child: telemetry('LATENCY', 'NOT MEASURED', muted)),
        const SizedBox(width: 7),
        Expanded(child: telemetry('DSP LOAD', 'NOT CONNECTED', muted)),
      ]),
    ]),
  );

  Widget moduleNode(int i) {
    final active = selected == i;
    final c = colors[i];
    return InkWell(onTap: () => setState(() => selected = i), child: AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(color: active ? c.withValues(alpha: .08) : raised, border: Border.all(color: active ? c.withValues(alpha: .8) : line, width: active ? 1.2 : 1)),
      child: Row(children: [
        Container(width: 27, height: 27, decoration: BoxDecoration(border: Border.all(color: bypass ? line : c.withValues(alpha: .7))), child: Center(child: Text(codes[i], style: TextStyle(color: bypass ? muted : c, fontSize: 8, fontWeight: FontWeight.bold)))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(names[i], style: TextStyle(color: bypass ? muted : ink, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
          const SizedBox(height: 2),
          Text(details[i], style: const TextStyle(color: muted, fontSize: 9)),
        ])),
        if (i == 2 || i == 3) Container(width: 3, height: 18, color: pink.withValues(alpha: bypass ? .2 : .8)),
        const SizedBox(width: 8),
        Text(active ? 'EDIT' : (bypass ? 'OFF' : 'ON'), style: TextStyle(color: active ? c : muted, fontSize: 8, letterSpacing: 1)),
        Icon(Icons.chevron_right, color: active ? c : muted, size: 15),
      ]),
    ));
  }

  Widget editor(bool wide) {
    final c = colors[selected];
    return Container(decoration: BoxDecoration(color: panel, border: Border.all(color: line)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(13, 12, 10, 9), child: Row(children: [
        Container(width: 3, height: 25, color: c),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(names[selected], style: const TextStyle(color: ink, fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 12)),
          const SizedBox(height: 3),
          Text('MODULE ' + (selected + 1).toString().padLeft(2, '0') + ' / ' + details[selected].toUpperCase(), style: const TextStyle(color: muted, fontSize: 8, letterSpacing: .7)),
        ])),
        TextButton(onPressed: () => setState(() { for (int i=0;i<gains.length;i++) { gains[i]=0; } }), child: const Text('FLAT', style: TextStyle(color: muted, fontSize: 9, letterSpacing: 1))),
      ])),
      SizedBox(height: wide ? 185 : 165, child: Padding(padding: const EdgeInsets.fromLTRB(9, 0, 9, 8), child: CustomPaint(painter: EqCurvePainter(gains: List.of(gains), bypassed: bypass), child: const SizedBox.expand()))),
      const Divider(height: 1, color: line),
      Padding(padding: const EdgeInsets.fromLTRB(12, 11, 12, 12), child: Column(children: [
        Row(children: [
          readout('FREQUENCY', frequencyLabels[selected] + ' Hz'),
          const SizedBox(width: 7),
          readout('GAIN', gains[selected].toStringAsFixed(1) + ' dB'),
          const SizedBox(width: 7),
          readout('Q', '1.00'),
        ]),
        const SizedBox(height: 9),
        Row(children: [
          const Text('MACRO', style: TextStyle(color: muted, fontSize: 9, letterSpacing: 1.2)),
          Expanded(child: SliderTheme(data: SliderTheme.of(context).copyWith(activeTrackColor: c, inactiveTrackColor: line, thumbColor: c, overlayColor: c.withValues(alpha: .12), trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5)), child: Slider(value: macro, min: -1, max: 1, onChanged: (v) => setState(() { macro = v; gains[selected] = v * 6; })))),
          SizedBox(width: 39, child: Text((macro * 100).round().toString() + '%', textAlign: TextAlign.right, style: TextStyle(color: c, fontSize: 10, fontFeatures: const [FontFeature.tabularFigures()]))),
        ]),
      ])),
    ]));
  }

  Widget readout(String label, String value) => Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), decoration: BoxDecoration(color: raised, border: Border.all(color: line)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: muted, fontSize: 8, letterSpacing: .8)),
    const SizedBox(height: 5),
    FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]))),
  ])));

  Widget telemetry(String label, String value, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10), decoration: BoxDecoration(color: panel, border: Border.all(color: line)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: muted, fontSize: 8, letterSpacing: .8)),
    const SizedBox(height: 6),
    FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: .6))),
  ]));

  Widget meters(bool vertical) {
    const values = [.36,.62,.51,.77,.43,.58,.31,.68,.47,.25,.55,.39];
    Color bar(double v) => v > .72 ? amber : cyan.withValues(alpha: bypass ? .12 : .2 + v * .8);
    if (vertical) return Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Column(children: [
      const Text('IN', style: TextStyle(color: muted, fontSize: 8)),
      const SizedBox(height: 8),
      Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: values.map((v) => Container(margin: const EdgeInsets.only(bottom: 3), width: 17, height: 8, color: bar(v))).toList())),
      const SizedBox(height: 12),
      const Text('OUT', style: TextStyle(color: muted, fontSize: 8)),
      const SizedBox(height: 8),
      Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: values.reversed.map((v) => Container(margin: const EdgeInsets.only(bottom: 3), width: 17, height: 8, color: bar(v))).toList())),
    ]));
    return Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), decoration: const BoxDecoration(border: Border(top: BorderSide(color: line))), child: Row(children: [
      const Text('IN', style: TextStyle(color: muted, fontSize: 8, letterSpacing: 1)),
      const SizedBox(width: 8),
      Expanded(child: Row(children: values.map((v) => Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 1), height: 7, color: bar(v))).toList())),
      const SizedBox(width: 8),
      const Text('OUT', style: TextStyle(color: muted, fontSize: 8, letterSpacing: 1)),
    ]));
  }

  Widget analysisRail() => Center(child: RotatedBox(quarterTurns: 1, child: TextButton.icon(onPressed: () => setState(() => selected = 1), icon: const Icon(Icons.show_chart, size: 14), label: const Text('SPECTRUM', style: TextStyle(fontSize: 9, letterSpacing: 1)), style: TextButton.styleFrom(foregroundColor: cyan))));

  Widget dock(bool wide) => Container(padding: EdgeInsets.fromLTRB(wide ? 24 : 13, 9, wide ? 24 : 13, 11), decoration: const BoxDecoration(color: panel, border: Border(top: BorderSide(color: line))), child: Row(children: [
    Expanded(child: InkWell(onTap: () => setState(() => bypass = !bypass), child: Container(height: 47, decoration: BoxDecoration(color: (bypass ? amber : cyan).withValues(alpha: .09), border: Border.all(color: bypass ? amber : cyan.withValues(alpha: .7))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(bypass ? Icons.power_settings_new : Icons.graphic_eq, color: bypass ? amber : cyan, size: 17),
      const SizedBox(width: 7),
      Text(bypass ? 'BYPASSED' : 'BYPASS', style: TextStyle(color: bypass ? amber : cyan, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
    ]))),
    const SizedBox(width: 7),
    InkWell(onTap: () => setState(() => slot = 1 - slot), child: Container(width: 49, height: 47, decoration: BoxDecoration(border: Border.all(color: cyan.withValues(alpha: .6)), color: cyan.withValues(alpha: .06)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(slot == 0 ? 'A' : 'B', style: const TextStyle(color: cyan, fontSize: 16, fontWeight: FontWeight.w800)),
      const Text('SLOT', style: TextStyle(color: muted, fontSize: 7, letterSpacing: 1)),
    ]))),
    const SizedBox(width: 7),
    Expanded(flex: 2, child: InkWell(onTap: showPresets, child: Container(height: 47, padding: const EdgeInsets.symmetric(horizontal: 9), decoration: BoxDecoration(border: Border.all(color: line)), child: Row(children: [
      const Icon(Icons.tune, color: muted, size: 16),
      const SizedBox(width: 7),
      Expanded(child: Text(preset, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ink, fontSize: 8, letterSpacing: .6))),
      const Icon(Icons.expand_more, color: muted, size: 16),
    ])))),
  ]));

  void showPresets() {
    const choices = ['NEUTRAL REFERENCE', 'HARMAN TARGET', 'PODCAST CLARITY', 'CAR CABIN', 'LATE NIGHT', 'BASSHEAD SAFE'];
    showModalBottomSheet<void>(context: context, backgroundColor: panel, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: line)), builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(18), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('RECALL PRESET', style: TextStyle(color: ink, fontWeight: FontWeight.w800, letterSpacing: 2)),
      const SizedBox(height: 10),
      for (final p in choices) ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(p, style: TextStyle(color: p == preset ? cyan : ink, fontSize: 11, letterSpacing: .8)), trailing: p == preset ? const Icon(Icons.check, color: cyan, size: 16) : null, onTap: () {
        setState(() {
          preset = p;
          for (int i=0;i<gains.length;i++) { gains[i]=0; }
          if (p == 'HARMAN TARGET') { gains[1]=2; gains[2]=1.5; gains[7]=-1; }
          if (p == 'PODCAST CLARITY') { gains[1]=-1; gains[4]=2.5; gains[6]=1.5; }
          if (p == 'CAR CABIN') { gains[0]=2; gains[1]=1.5; gains[7]=-1; }
          if (p == 'LATE NIGHT') { gains[0]=-2; gains[8]=-1.5; }
          if (p == 'BASSHEAD SAFE') { gains[0]=3; gains[1]=2; gains[9]=-1; }
          macro = 0;
        });
        Navigator.pop(ctx);
      }),
    ]))));
  }
}

class EqCurvePainter extends CustomPainter {
  final List<double> gains;
  final bool bypassed;
  const EqCurvePainter({required this.gains, required this.bypassed});

  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0, right = 7.0, top = 12.0, bottom = 22.0;
    final r = Rect.fromLTRB(left, top, size.width-right, size.height-bottom);
    final grid = Paint()..color = line..strokeWidth = 1;
    final text = TextPainter(textDirection: TextDirection.ltr);
    for (int i=0;i<=4;i++) {
      final y = r.top + r.height*i/4;
      canvas.drawLine(Offset(r.left,y), Offset(r.right,y), grid);
      final db = 12-i*6;
      text.text = TextSpan(text: (db>0?'+':'')+db.toString(), style: const TextStyle(color: muted, fontSize: 8));
      text.layout(); text.paint(canvas, Offset(0,y-5));
    }
    const labels = ['20','50','100','500','1k','5k','10k','20k'];
    for (int i=0;i<labels.length;i++) {
      final x = r.left+r.width*i/(labels.length-1);
      canvas.drawLine(Offset(x,r.top), Offset(x,r.bottom), grid);
      text.text = TextSpan(text: labels[i], style: const TextStyle(color: muted,fontSize:8));
      text.layout(); text.paint(canvas, Offset(x-text.width/2,r.bottom+6));
    }
    final zero = r.top+r.height/2;
    canvas.drawLine(Offset(r.left,zero), Offset(r.right,zero), Paint()..color=muted.withValues(alpha:.45)..strokeWidth=1.2);
    final points=<Offset>[];
    for (int i=0;i<140;i++) {
      final x=r.left+r.width*i/139;
      final pos=i/139*(gains.length-1);
      final ix=pos.floor().clamp(0,gains.length-2);
      final t=pos-ix;
      final g=gains[ix]*(1-t)+gains[ix+1]*t;
      points.add(Offset(x,(zero-g/24*r.height*2).clamp(r.top,r.bottom)));
    }
    final path=Path()..moveTo(points.first.dx,points.first.dy);
    for (final p in points.skip(1)) { path.lineTo(p.dx,p.dy); }
    final c=bypassed?muted:cyan;
    final fill=Path.from(path)..lineTo(r.right,zero)..lineTo(r.left,zero)..close();
    canvas.drawPath(fill,Paint()..color=c.withValues(alpha:.07));
    canvas.drawPath(path,Paint()..color=c.withValues(alpha:.18)..strokeWidth=5..style=PaintingStyle.stroke..maskFilter=const MaskFilter.blur(BlurStyle.normal,4));
    canvas.drawPath(path,Paint()..color=c..strokeWidth=1.8..style=PaintingStyle.stroke);
    for (int i=0;i<gains.length;i++) {
      final x=r.left+r.width*i/(gains.length-1);
      final y=(zero-gains[i]/24*r.height*2).clamp(r.top,r.bottom);
      canvas.drawCircle(Offset(x,y),4,Paint()..color=bg);
      canvas.drawCircle(Offset(x,y),3,Paint()..color=c);
    }
  }
  @override
  bool shouldRepaint(covariant EqCurvePainter old) => old.bypassed != bypassed || old.gains.toString() != gains.toString();
}
