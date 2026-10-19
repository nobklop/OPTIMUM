import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const ink = Color(0xFF050507);
const panel = Color(0xFF101014);
const muted = Color(0xFF92929C);
const paper = Color(0xFFF5F5F7);

class Cosmos extends StatefulWidget {
  final bool reduced;
  final Widget child;
  const Cosmos({super.key, required this.reduced, required this.child});
  @override
  State<Cosmos> createState() => _CosmosState();
}

class _CosmosState extends State<Cosmos>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _active = true;
  final pointer = ValueNotifier<Offset>(Offset.zero);
  final frameClock = ValueNotifier<double>(0);
  int _frame = -1;
  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 90),
  );
  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _active = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    animation.addListener(() {
      final frame = (animation.value * 90 * 30).floor();
      if (frame != _frame) {
        _frame = frame;
        frameClock.value = animation.value;
      }
    });
    if (!widget.reduced && _active) animation.repeat();
  }

  @override
  void didUpdateWidget(Cosmos oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduced) {
      animation.stop();
      pointer.value = Offset.zero;
    } else if (_active && !animation.isAnimating) {
      animation.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    animation.dispose();
    pointer.dispose();
    frameClock.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active && !widget.reduced) {
      animation.repeat();
    } else {
      animation.stop();
    }
  }

  @override
  Widget build(BuildContext context) => CosmicMotion(
    clock: frameClock,
    child: MouseRegion(
      onHover: (event) {
        if (widget.reduced) return;
        final size = context.size;
        if (size != null) {
          pointer.value = Offset(
            event.localPosition.dx / size.width - .5,
            event.localPosition.dy / size.height - .5,
          );
        }
      },
      onExit: (_) => pointer.value = Offset.zero,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: StarPainter(frameClock, pointer)),
            ),
          ),
          widget.child,
        ],
      ),
    ),
  );
}

class CosmicMotion extends InheritedWidget {
  final ValueListenable<double> clock;
  const CosmicMotion({super.key, required this.clock, required super.child});
  static ValueListenable<double>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CosmicMotion>()?.clock;
  @override
  bool updateShouldNotify(CosmicMotion oldWidget) => clock != oldWidget.clock;
}

class StarPainter extends CustomPainter {
  final ValueListenable<double> animation;
  final ValueNotifier<Offset> pointer;
  late final List<Offset> stars = List.generate(
    184,
    (i) => Offset(Random(i * 17).nextDouble(), Random(i * 31 + 8).nextDouble()),
  );
  StarPainter(this.animation, this.pointer)
    : super(repaint: Listenable.merge([animation, pointer]));
  static ui.Image cloud(Color color, double opacity) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(128, 128);
    canvas.drawCircle(
      center,
      128,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * .25),
            Colors.transparent,
          ],
          stops: const [0, .48, 1],
        ).createShader(const Rect.fromLTWH(0, 0, 256, 256)),
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(256, 256);
    picture.dispose();
    return image;
  }

  static final ui.Image _cloudA = cloud(const Color(0xFF85859B), .20);
  static final ui.Image _cloudB = cloud(const Color(0xFF67677F), .16);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final phase = animation.value * pi * 2;
    // Elliptical shader clouds give depth without full-screen blur passes or textures.
    void nebula(Offset center, double width, double height, ui.Image image) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-.38 + sin(phase) * .08);
      canvas.scale(1, height / width);
      final rect = Rect.fromCircle(center: Offset.zero, radius: width);
      canvas.drawImageRect(
        image,
        const Rect.fromLTWH(0, 0, 256, 256),
        rect,
        Paint()..filterQuality = FilterQuality.low,
      );
      canvas.restore();
    }

    // Separate banks of haze leave dark gaps across the whole field.
    const banks = [
      (.12, .18, .27, .22),
      (.52, .12, .24, .19),
      (.88, .38, .23, .31),
      (.29, .72, .27, .26),
      (.70, .88, .26, .22),
    ];
    for (var i = 0; i < banks.length; i++) {
      final bank = banks[i];
      nebula(
        Offset(
          size.width * (bank.$1 + .025 * sin(phase + i * 1.7)),
          size.height * (bank.$2 + .035 * cos(phase * (i % 2 + 1) + i)),
        ),
        size.width * bank.$3,
        size.height * bank.$4,
        i.isEven ? _cloudA : _cloudB,
      );
    }
    // A distant orbital arc moves below the stars; all colors remain nearly neutral.
    canvas.save();
    canvas.translate(size.width * .8, size.height * .55);
    canvas.rotate(-.4 + sin(phase) * .06);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.width * .9,
        height: size.height * .42,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..color = paper.withValues(alpha: .045),
    );
    canvas.restore();
    for (var i = 0; i < stars.length; i++) {
      final depth = i % 3 + 1;
      final x =
          ((stars[i].dx + .035 * depth * sin(phase + stars[i].dy * pi * 2)) %
                  1) *
              size.width +
          pointer.value.dx * depth * 5;
      final y =
          stars[i].dy * size.height +
          sin(phase + i) * depth * 3 +
          pointer.value.dy * depth * 4;
      final edgeFade = min(
        1.0,
        min(x / 24, (size.width - x) / 24),
      ).clamp(0.0, 1.0);
      final alpha =
          edgeFade *
          (.14 + (i % 5) * .05) *
          (.7 + .3 * sin(phase * (3 + i % 4) + i));
      paint.color = paper.withValues(alpha: alpha);
      final center = Offset(x, y);
      canvas.drawCircle(center, i % 9 == 0 ? 1.35 : .65, paint);
      if (i % 19 == 0) {
        canvas.drawCircle(
          center,
          4.5,
          Paint()
            ..shader = RadialGradient(
              colors: [
                paper.withValues(alpha: alpha * .4),
                Colors.transparent,
              ],
            ).createShader(Rect.fromCircle(center: center, radius: 4.5)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(StarPainter oldDelegate) =>
      oldDelegate.animation != animation || oldDelegate.pointer != pointer;
}

/// Fine decoration spans the wide hero card, independently of the large planet.
class HeroSky extends StatelessWidget {
  const HeroSky({super.key});
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: HeroSkyPainter(CosmicMotion.of(context))),
  );
}

class HeroSkyPainter extends CustomPainter {
  final ValueListenable<double>? animation;
  HeroSkyPainter(this.animation) : super(repaint: animation);
  static final _points = List.generate(
    62,
    (i) => Offset(
      .30 + Random(i * 41 + 19).nextDouble() * .70,
      Random(i * 23 + 7).nextDouble(),
    ),
  );
  @override
  void paint(Canvas canvas, Size size) {
    final phase = (animation?.value ?? 0) * pi * 2;
    final scale = (size.width / 1000).clamp(.4, 1.5);
    canvas.drawImageRect(
      StarPainter._cloudB,
      const Rect.fromLTWH(0, 0, 256, 256),
      Rect.fromCenter(
        center: Offset(size.width * .57, size.height * .45),
        width: size.width * .5,
        height: size.height * 1.2,
      ),
      Paint()..filterQuality = FilterQuality.low,
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .6
      ..color = paper.withValues(alpha: .085);
    canvas.save();
    canvas.translate(size.width * .77, size.height * .58);
    canvas.rotate(-.31 + sin(phase) * .035);
    for (var i = 0; i < 2; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.width * (.66 + i * .08),
          height: size.height * (1.06 + i * .12),
        ),
        line,
      );
    }
    canvas.restore();
    for (var i = 0; i < _points.length; i++) {
      final point = _points[i];
      final x = point.dx * size.width + sin(phase + i) * 3 * scale;
      final y = point.dy * size.height + cos(phase * 2 + i) * 2;
      // Preserve the quiet area behind the copy and buttons.
      final fade = ((point.dx - .30) / .27).clamp(0.0, 1.0);
      final alpha =
          fade * (.14 + .15 * (.5 + .5 * sin(phase * (i % 3 + 1) + i)));
      final center = Offset(x, y);
      canvas.drawCircle(
        center,
        i % 11 == 0 ? 1.2 : .55,
        Paint()..color = paper.withValues(alpha: alpha),
      );
      if (i % 17 == 0) {
        final glint = Paint()
          ..strokeWidth = .55
          ..color = paper.withValues(alpha: alpha * .6);
        canvas.drawLine(
          center - const Offset(3, 0),
          center + const Offset(3, 0),
          glint,
        );
        canvas.drawLine(
          center - const Offset(0, 3),
          center + const Offset(0, 3),
          glint,
        );
      }
    }
    const constellation = [
      Offset(.47, .24),
      Offset(.51, .19),
      Offset(.55, .28),
      Offset(.58, .23),
    ];
    final drift = Offset(sin(phase) * 3, cos(phase) * 2);
    for (var i = 0; i < constellation.length; i++) {
      final point =
          Offset(
            constellation[i].dx * size.width,
            constellation[i].dy * size.height,
          ) +
          drift;
      canvas.drawCircle(
        point,
        1.15,
        Paint()..color = paper.withValues(alpha: .36),
      );
      if (i > 0) {
        final previous =
            Offset(
              constellation[i - 1].dx * size.width,
              constellation[i - 1].dy * size.height,
            ) +
            drift;
        canvas.drawLine(
          previous,
          point,
          Paint()
            ..strokeWidth = .55
            ..color = paper.withValues(alpha: .10),
        );
      }
    }
    for (var i = 0; i < 2; i++) {
      final center = Offset(
        size.width * (.58 + i * .12) + sin(phase + i) * 6,
        size.height * (.73 - i * .39) + cos(phase + i) * 4,
      );
      final radius = (i == 0 ? 5.0 : 3.0) * scale;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-.5, -.6),
            radius: 1.5,
            colors: [Color(0xFF8B8B9D), Color(0xFF2D2D3D), Color(0xFF101018)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(HeroSkyPainter oldDelegate) =>
      oldDelegate.animation != animation;
}

class OrbitArt extends StatelessWidget {
  final int variant;
  final double size;
  final bool animated;
  const OrbitArt({
    super.key,
    this.variant = 0,
    this.size = 180,
    this.animated = false,
  });
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: OrbitPainter(
          variant,
          animated ? CosmicMotion.of(context) : null,
        ),
      ),
    ),
  );
}

class OrbitPainter extends CustomPainter {
  final int variant;
  final ValueListenable<double>? animation;
  OrbitPainter(this.variant, [this.animation]) : super(repaint: animation);
  @override
  void paint(Canvas canvas, Size size) {
    final phase = (animation?.value ?? 0) * pi * 2;
    final center = Offset(
      size.width / 2,
      size.height / 2 + sin(phase * 2) * size.height * .018,
    );
    final radius = size.shortestSide * .24;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFB9B8CD).withValues(alpha: .15),
          const Color(0xFF343245).withValues(alpha: .05),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * .5));
    canvas.drawCircle(center, size.width * .5, glow);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.35 - variant * .23 + sin(phase) * .12);
    for (var i = 0; i < 4; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * (3.3 + i * .18),
          height: radius * (.85 + i * .12),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == 1 ? 1.2 : .5
          ..color = paper.withValues(alpha: i == 1 ? .6 : .14),
      );
    }
    canvas.restore();
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.65, -.7),
          radius: 1.7,
          colors: [
            Color(0xFFCACAD4),
            Color(0xFF666674),
            Color(0xFF1F1F29),
            Color(0xFF08080C),
          ],
          stops: [0, .19, .55, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.5,
      1.8,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = paper.withValues(alpha: .6),
    );
    final angle = -.55 + phase * 2;
    final dot =
        center + Offset(cos(angle) * radius * 1.85, sin(angle) * radius * .8);
    canvas.drawCircle(
      dot,
      8,
      Paint()
        ..shader = RadialGradient(
          colors: [paper.withValues(alpha: .3), Colors.transparent],
        ).createShader(Rect.fromCircle(center: dot, radius: 8)),
    );
    canvas.drawCircle(dot, 2, Paint()..color = paper);
  }

  @override
  bool shouldRepaint(OrbitPainter oldDelegate) =>
      oldDelegate.variant != variant || oldDelegate.animation != animation;
}

class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });
  @override
  Widget build(BuildContext context) => Material(
    color: panel.withValues(alpha: .9),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: Colors.white.withValues(alpha: .065)),
    ),
    child: Padding(padding: padding, child: child),
  );
}
