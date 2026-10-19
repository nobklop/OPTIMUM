import 'dart:math';
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
  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 90),
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!widget.reduced) animation.repeat();
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
    clock: animation,
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
              child: CustomPaint(painter: StarPainter(animation, pointer)),
            ),
          ),
          widget.child,
        ],
      ),
    ),
  );
}

class CosmicMotion extends InheritedWidget {
  final Animation<double> clock;
  const CosmicMotion({super.key, required this.clock, required super.child});
  static Animation<double>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CosmicMotion>()?.clock;
  @override
  bool updateShouldNotify(CosmicMotion oldWidget) => clock != oldWidget.clock;
}

class StarPainter extends CustomPainter {
  final Animation<double> animation;
  final ValueNotifier<Offset> pointer;
  late final List<Offset> stars = List.generate(
    136,
    (i) => Offset(Random(i * 17).nextDouble(), Random(i * 31 + 8).nextDouble()),
  );
  StarPainter(this.animation, this.pointer)
    : super(repaint: Listenable.merge([animation, pointer]));
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final phase = animation.value * pi * 2;
    // Elliptical shader clouds give depth without full-screen blur passes or textures.
    void nebula(
      Offset center,
      double width,
      double height,
      Color color,
      double opacity,
    ) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-.38 + sin(phase) * .08);
      canvas.scale(1, height / width);
      final rect = Rect.fromCircle(center: Offset.zero, radius: width);
      canvas.drawCircle(
        Offset.zero,
        width,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: opacity * .25),
              Colors.transparent,
            ],
            stops: const [0, .48, 1],
          ).createShader(rect),
      );
      canvas.restore();
    }

    nebula(
      Offset(
        size.width * (.77 + .06 * sin(phase)),
        size.height * (.29 + .05 * cos(phase)),
      ),
      size.width * .58,
      size.height * .39,
      const Color(0xFF77778F),
      .16,
    );
    nebula(
      Offset(
        size.width * (.38 + .05 * cos(phase)),
        size.height * (.77 + .04 * sin(phase * 2)),
      ),
      size.width * .48,
      size.height * .28,
      const Color(0xFF56566B),
      .12,
    );
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
  final Animation<double>? animation;
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
