// copied from https://github.com/treeplate/isd_treeclient/blob/master/lib/ui-core.dart

import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

class ZoomCurve extends Curve {
  const ZoomCurve(this.zoomFactor);

  final double zoomFactor;

  @override
  double transformInternal(double t) {
    if (zoomFactor == 1) return t;
    return (pow(zoomFactor, t) - 1) / (zoomFactor - 1);
  }
}

class ZoomController extends ChangeNotifier {
  static const Curve panCurve = Curves.linear;

  double _zoom;
  late double _oldZoom = _zoom;
  double get realZoom => _zoom;
  double? _zoomMidpoint;
  bool panThenZoom = false;
  double get zoom {
    if (_zoomMidpoint == null && !panThenZoom) {
      return ZoomCurve(_zoom / _oldZoom).transform(_animation.value) *
              (_zoom - _oldZoom) +
          _oldZoom;
    }
    if (panThenZoom) {
      if (_animation.value <= 1 / 2) {
        return _oldZoom;
      } else {
        return ZoomCurve(_zoom / _oldZoom).transform(_animation.value * 2 - 1) *
                (_zoom - _oldZoom) +
            _oldZoom;
      }
    }
    if (_animation.value <= 1 / 3) {
      return ZoomCurve(_zoomMidpoint! / _oldZoom)
                  .transform(_animation.value * 3) *
              (_zoomMidpoint! - _oldZoom) +
          _oldZoom;
    }
    if (_animation.value <= 2 / 3) {
      return _zoomMidpoint!;
    }
    return ZoomCurve(_zoom / _zoomMidpoint!)
                .transform(_animation.value * 3 - 2) *
            (_zoom - _zoomMidpoint!) +
        _zoomMidpoint!;
  }

  Offset _screenCenter;
  late Offset _oldScreenCenter = _screenCenter;
  Offset get realScreenCenter => _screenCenter;
  Offset get screenCenter {
    if (_zoomMidpoint == null && !panThenZoom) {
      return (_screenCenter - _oldScreenCenter) *
              panCurve.transform(_animation.value) +
          _oldScreenCenter;
    }
    if (_animation.value <= 1 / 3 && !panThenZoom) {
      return _oldScreenCenter;
    }
    if (panThenZoom && _animation.value <= 1 / 2) {
      return (_screenCenter - _oldScreenCenter) *
              panCurve.transform(_animation.value * 2) +
          _oldScreenCenter;
    }
    if (!panThenZoom && _animation.value <= 2 / 3) {
      return (_screenCenter - _oldScreenCenter) *
              panCurve.transform(_animation.value * 3 - 1) +
          _oldScreenCenter;
    }
    return _screenCenter;
  }

  late final AnimationController _animation;

  void animateTo(double newZoom, Offset newScreenCenter) {
    _oldZoom = zoom;
    _oldScreenCenter = screenCenter;
    _zoom = newZoom;
    _screenCenter = newScreenCenter;
    double maxZoomThatHasGoalOnScreen =
        1 /
        (max(
              (newScreenCenter.dx - _oldScreenCenter.dx).abs(),
              (newScreenCenter.dy - _oldScreenCenter.dy).abs(),
            ) *
            2);
    if (maxZoomThatHasGoalOnScreen < _oldZoom) {
      _zoomMidpoint = maxZoomThatHasGoalOnScreen;
      panThenZoom = false;
    } else if (maxZoomThatHasGoalOnScreen < _zoom) {
      _zoomMidpoint = null;
      panThenZoom = true;
    } else {
      _zoomMidpoint = null;
      panThenZoom = false;
    }
    _animation.reset();
    _animation.animateTo(1);
  }

  void modifyAnimation({double? zoom, Offset? screenCenter}) {
    _zoom = zoom ?? _zoom;
    _screenCenter = screenCenter ?? _screenCenter;
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  ZoomController({
    this._zoom = 1,
    this._screenCenter = const Offset(.5, .5),
    required TickerProvider vsync,
  }) {
    _animation = AnimationController(
      vsync: vsync,
      duration: Duration(seconds: 3),
      value: 1,
    );
    _animation.addListener(notifyListeners);
  }
}

class ZoomableCustomPaint extends StatefulWidget {
  const ZoomableCustomPaint({
    super.key,
    required this.painter,
    required this.controller,
    this.onTap,
  });
  final CustomPainter painter;
  final ZoomController controller;
  final void Function(Offset)? onTap;

  @override
  State<ZoomableCustomPaint> createState() => _ZoomableCustomPaintState();
}

class _ZoomableCustomPaintState extends State<ZoomableCustomPaint> {
  double lastRelativeScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          onPointerSignal: (details) {
            if (details is PointerScrollEvent) {
              setState(() {
                if (details.scrollDelta.dy > 0) {
                  handleZoom(1 / 1.5);
                } else {
                  handleZoom(1.5);
                }
              });
            }
          },
          child: Center(
            child: GestureDetector(
              onScaleStart: (details) {
                lastRelativeScale = 1.0;
              },
              onScaleUpdate: (details) {
                setState(() {
                  if (details.pointerCount > 1 && details.scale == 1) {
                    // to work around trackpad two-finger scroll being interpreted as a pan instead of a scale
                    handleZoom(details.focalPointDelta.dy < 0 ? 1 / 1.5 : 1.5);
                  } else {
                    handlePan(details.focalPointDelta, constraints);
                    double scaleMultiplicativeDelta =
                        details.scale / lastRelativeScale;
                    handleZoom(scaleMultiplicativeDelta);
                    lastRelativeScale = details.scale;
                  }
                });
              },
              onTapUp: (TapUpDetails details) {
                Offset topLeft = Offset(
                  widget.controller.screenCenter.dx - .5,
                  widget.controller.screenCenter.dy - .5,
                );
                Offset preZoom =
                    details.localPosition / constraints.biggest.shortestSide;
                Offset postZoom =
                    (preZoom - Offset(.5, .5)) / widget.controller.zoom +
                    Offset(.5, .5) +
                    topLeft;
                if (widget.onTap != null) {
                  widget.onTap!(postZoom);
                }
              },
              supportedDevices: {.mouse, .stylus, .invertedStylus, .touch},
              child: ClipRect(
                child: SizedBox(
                  width: constraints.biggest.shortestSide,
                  height: constraints.biggest.shortestSide,
                  child: CustomPaint(
                    size: Size.square(constraints.biggest.shortestSide),
                    painter: widget.painter,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void handleZoom(double scaleMultiplicativeDelta) {
    if (widget.controller.realZoom >= 1 / scaleMultiplicativeDelta) {
      widget.controller.modifyAnimation(
        zoom: widget.controller.realZoom * scaleMultiplicativeDelta,
      );
    }
  }

  void handlePan(Offset delta, BoxConstraints constraints) {
    setState(() {
      Offset newScreenCenter =
          widget.controller.realScreenCenter -
          (delta / constraints.biggest.shortestSide) /
              widget.controller.realZoom;
      widget.controller.modifyAnimation(
        screenCenter: Offset(
          newScreenCenter.dx.clamp(0, 1),
          newScreenCenter.dy.clamp(0, 1),
        ),
      );
    });
  }
}

Offset calculateScreenPosition(
  Offset basePosition,
  Offset screenCenter,
  double zoom,
  Size screenSize,
) {
  Offset topLeft = Offset(screenCenter.dx - .5, screenCenter.dy - .5);
  Offset noZoomPos = (basePosition - topLeft);
  Offset afterZoomPos =
      (((noZoomPos - Offset(.5, .5)) * zoom) + Offset(.5, .5));
  return afterZoomPos.scale(screenSize.width, screenSize.height);
}

final List<Paint> starCategories = [
  // multiply strokeWidth by size of unit square
  Paint() // NEUTRON_STAR
    ..color = Color(0xff00ccff)
    ..strokeWidth = 0.001,
  Paint() // RED_STAR
    ..color = Color(0xDFFF0000)
    ..strokeWidth = 0.005,
  Paint() // ORANGE_STAR
    ..color = Color(0xCFFF9900)
    ..strokeWidth = 0.005,
  Paint() // BLUE_STAR
    ..color = Color(0xff00ccff)
    ..strokeWidth = 0.005,
  Paint() // YOUNG_STAR
    ..color = Color(0xBFdddddd)
    ..strokeWidth = 0.003,
  Paint() // WHITE_DWARF
    ..color = Color(0xAFFFFFFF)
    ..strokeWidth = 0.001,
  Paint() // BLACK_HOLE
    ..color = Color(0xFF111111)
    ..strokeWidth = 0.01,
  Paint() // HYPERGIANT
    ..color = Color(0xffff2200)
    ..strokeWidth = 0.01,
  Paint() // NEBULA
    ..color = Color(0xff9900ff)
    ..strokeWidth = 0.005,
  Paint() // UNSTABLE
    ..color = Color(0xffffff00)
    ..strokeWidth = 0.005,
];
