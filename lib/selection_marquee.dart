import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

enum SelectionMode { single, multiple, additive, range }

class SelectionConfig {
  final bool allowTouch;
  final double minDragDistance;
  final bool edgeAutoScroll;
  final double autoScrollSpeed;
  final double overlapThreshold;
  final double edgeZoneFraction;
  final double minAutoScrollFactor;
  final AutoScrollMode autoScrollMode;
  final Duration autoScrollAnimationDuration;
  final Curve autoScrollCurve;
  final SelectionDecoration? selectionDecoration;

  const SelectionConfig({
    this.allowTouch = true,
    this.minDragDistance = 6.0,
    this.edgeAutoScroll = true,
    this.autoScrollSpeed = 80.0,
    this.overlapThreshold = 0.0,
    this.edgeZoneFraction = 0.12,
    this.minAutoScrollFactor = 0.25,
    this.autoScrollMode = AutoScrollMode.jump,
    this.autoScrollAnimationDuration = const Duration(milliseconds: 120),
    this.autoScrollCurve = Curves.linear,
    this.selectionDecoration,
  });
}

enum AutoScrollMode { jump, animate }

enum SelectionBorderStyle { solid, dashed, dotted, marchingAnts }

class SelectionDecoration {
  final Color? fillColor;
  final Color? borderColor;
  final double borderWidth;
  final SelectionBorderStyle borderStyle;
  final double dashLength;
  final double gapLength;
  final Duration marchingSpeed;
  final double borderRadius;

  const SelectionDecoration({
    this.fillColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.borderStyle = SelectionBorderStyle.solid,
    this.dashLength = 6.0,
    this.gapLength = 4.0,
    this.marchingSpeed = const Duration(milliseconds: 800),
    this.borderRadius = 4.0,
  });
}

class SelectionController extends ChangeNotifier {
  Rect? selectionRect;
  bool isSelecting = false;

  final Set<String> _selectedIds = {};
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);

  final ValueNotifier<Set<String>> selectedListenable = ValueNotifier({});
  final StreamController<Set<String>> _selectedStreamController =
      StreamController<Set<String>>.broadcast();

  // registration for virtualized lists
  final Map<String, GlobalKey> _registeredKeys = {};
  final Map<String, Rect Function()> _rectProviders = {};

  Stream<Set<String>> get onSelectionChanged =>
      _selectedStreamController.stream;

  void _emitSelection() {
    final snapshot = Set<String>.from(_selectedIds);
    try {
      selectedListenable.value = snapshot;
    } catch (_) {}
    if (!_selectedStreamController.isClosed) {
      _selectedStreamController.add(snapshot);
    }
    notifyListeners();
  }

  // Basic selection API
  void select(String id) {
    _selectedIds.add(id);
    _emitSelection();
  }

  void deselect(String id) {
    _selectedIds.remove(id);
    _emitSelection();
  }

  void toggle(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    _emitSelection();
  }

  void setSelected(Set<String> ids) {
    _selectedIds
      ..clear()
      ..addAll(ids);
    _emitSelection();
  }

  void clear() {
    _selectedIds.clear();
    _emitSelection();
  }

  void selectAll({Iterable<String>? candidates}) {
    if (candidates != null) {
      _selectedIds
        ..clear()
        ..addAll(candidates);
    }
    _emitSelection();
  }

  // Selection lifecycle used by marquee widget
  void startSelection(Offset startPosition) {
    isSelecting = true;
    selectionRect = Rect.fromPoints(startPosition, startPosition);
    notifyListeners();
  }

  void updateSelection(Offset currentPosition, Offset startPosition) {
    selectionRect = Rect.fromPoints(startPosition, currentPosition);
    notifyListeners();
  }

  void endSelection() {
    isSelecting = false;
    selectionRect = null;
    notifyListeners();
  }

  // Registration API for virtual lists
  void registerItem(String id, GlobalKey key, {Rect Function()? rectProvider}) {
    _registeredKeys[id] = key;
    if (rectProvider != null) _rectProviders[id] = rectProvider;
  }

  void unregisterItem(String id) {
    _registeredKeys.remove(id);
    _rectProviders.remove(id);
  }

  Future<void> ensureItemVisible(
    String id, {
    ScrollController? scrollController,
  }) async {
    final key = _registeredKeys[id];
    final context = key?.currentContext;
    if (context == null) return;
    try {
      await Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      selectedListenable.dispose();
    } catch (_) {}
    try {
      _selectedStreamController.close();
    } catch (_) {}
    super.dispose();
  }
}

class SelectionMarquee extends StatefulWidget {
  final Widget child;
  final SelectionController controller;
  final GlobalKey marqueeKey;
  final SelectionConfig config;
  final ScrollController? scrollController;

  const SelectionMarquee({
    super.key,
    required this.child,
    required this.controller,
    required this.marqueeKey,
    this.config = const SelectionConfig(),
    this.scrollController,
  });

  @override
  State<SelectionMarquee> createState() => _SelectionMarqueeState();
}

class _SelectionMarqueeState extends State<SelectionMarquee>
    with SingleTickerProviderStateMixin {
  Offset? _startPos;
  bool _isMouse = false;
  bool _dragStarted = false;
  Offset? _currentPointerLocal;
  Timer? _autoScrollTimer;
  double _lastAutoTick = 0;
  AnimationController? _marchingController;
  double _marchPhase = 0.0;

  @override
  void initState() {
    super.initState();
    _marchingController = AnimationController(vsync: this);
    _marchingController!.addListener(() {
      setState(() {
        _marchPhase = _marchingController!.value;
      });
    });
  }

  @override
  void dispose() {
    try {
      _marchingController?.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selDec = widget.config.selectionDecoration;
    if (selDec != null &&
        selDec.borderStyle == SelectionBorderStyle.marchingAnts) {
      _marchingController?.duration = selDec.marchingSpeed;
      if (!(_marchingController?.isAnimating ?? false)) {
        _marchingController?.repeat();
      }
    } else {
      if ((_marchingController?.isAnimating ?? false)) {
        _marchingController?.stop();
      }
      _marchingController?.value = 0.0;
    }
    return Listener(
      onPointerDown: (event) {
        _isMouse = event.kind == PointerDeviceKind.mouse;
      },
      onPointerMove: (event) {
        // track pointer globally and convert to marquee-local coordinates
        final renderBox =
            widget.marqueeKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final local = renderBox.globalToLocal(event.position);
          _currentPointerLocal = local;
          if (_dragStarted) _maybeStartAutoScroll(local);
        }
      },
      onPointerUp: (event) {
        _currentPointerLocal = null;
        _stopAutoScroll();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (details) {
          _startPos = details.localPosition;
          _dragStarted = false;
        },
        onPanUpdate: (details) {
          if (_startPos == null) return;
          _currentPointerLocal = details.localPosition;
          final distance = (details.localPosition - _startPos!).distance;
          final allowTouch = widget.config.allowTouch || _isMouse;
          if (!_dragStarted &&
              distance >= widget.config.minDragDistance &&
              allowTouch) {
            _dragStarted = true;
            widget.controller.startSelection(_startPos!);
          }

          if (_dragStarted) {
            widget.controller.updateSelection(
              details.localPosition,
              _startPos!,
            );
            _maybeStartAutoScroll(details.localPosition);
          }
        },
        onPanEnd: (details) {
          if (_dragStarted) {
            widget.controller.endSelection();
          }
          _startPos = null;
          _currentPointerLocal = null;
          _dragStarted = false;
          _stopAutoScroll();
        },
        child: Stack(
          key: widget.marqueeKey,
          children: [
            widget.child,
            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                if (widget.controller.selectionRect == null) {
                  return const SizedBox();
                }
                return Positioned.fromRect(
                  rect: widget.controller.selectionRect!,
                  child: CustomPaint(
                    painter: _SelectionRectPainter(
                      decoration: widget.config.selectionDecoration,
                      themeFill: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.15),
                      themeBorder: Theme.of(context).colorScheme.primary,
                      // radius handled by decoration if provided
                      // fall back to 4.0 if not provided
                      radius:
                          widget.config.selectionDecoration?.borderRadius ??
                          4.0,
                      phase: _marchPhase,
                      repaint: _marchingController,
                    ),
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _maybeStartAutoScroll(Offset localPointer) {
    if (!widget.config.edgeAutoScroll) return;
    final sc = widget.scrollController;
    if (sc == null || !(sc.hasClients)) return;

    final renderBox =
        widget.marqueeKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    final topZone = size.height * 0.12;
    final bottomZone = size.height * 0.12;

    // If pointer not in either edge zone, stop auto-scroll
    final inTop = localPointer.dy <= topZone;
    final inBottom = localPointer.dy >= size.height - bottomZone;
    if (!inTop && !inBottom) {
      _stopAutoScroll();
      return;
    }

    // start timer if not already running
    if (_autoScrollTimer != null && _autoScrollTimer!.isActive) return;

    _lastAutoTick = DateTime.now().millisecondsSinceEpoch / 1000.0;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final dt = now - _lastAutoTick;
      _lastAutoTick = now;

      final rb =
          widget.marqueeKey.currentContext?.findRenderObject() as RenderBox?;
      if (rb == null) return;
      final s = rb.size;
      final tp = _currentPointerLocal;
      if (tp == null) return;

      // determine direction and normalized proximity (0..1)
      int dir = 0;
      double proximity = 0.0;
      final zone = s.height * widget.config.edgeZoneFraction;
      if (tp.dy <= zone) {
        dir = -1;
        proximity = (zone - tp.dy) / zone; // 0..1
      } else if (tp.dy >= s.height - zone) {
        dir = 1;
        proximity = (tp.dy - (s.height - zone)) / zone; // 0..1
      }

      if (dir == 0) return;

      // map proximity to speed factor: keep a minimum fraction so it never stalls
      final minFactor = widget.config.minAutoScrollFactor;
      final factor = (minFactor + (1 - minFactor) * proximity).clamp(0.0, 1.0);
      final maxSpeed =
          widget.config.autoScrollSpeed; // pixels per second (configured max)
      final speed = maxSpeed * factor;
      final delta = speed * dt * dir;

      final pos = sc.position.pixels + delta;
      final clamped = pos.clamp(
        sc.position.minScrollExtent,
        sc.position.maxScrollExtent,
      );
      try {
        if (widget.config.autoScrollMode == AutoScrollMode.jump) {
          sc.jumpTo(clamped);
        } else {
          // animate by a small step proportional to configured animation duration
          final animDt =
              widget.config.autoScrollAnimationDuration.inMilliseconds / 1000.0;
          final animDelta = speed * animDt * dir;
          final animTarget = (sc.position.pixels + animDelta).clamp(
            sc.position.minScrollExtent,
            sc.position.maxScrollExtent,
          );
          sc.animateTo(
            animTarget,
            duration: widget.config.autoScrollAnimationDuration,
            curve: Curves.linear,
          );
        }
      } catch (_) {}

      // update selection while autoscrolling
      if (_currentPointerLocal != null &&
          _startPos != null &&
          widget.controller.isSelecting) {
        widget.controller.updateSelection(_currentPointerLocal!, _startPos!);
      }
    });
  }

  void _stopAutoScroll() {
    try {
      _autoScrollTimer?.cancel();
    } catch (_) {}
    _autoScrollTimer = null;
  }
}

class SelectableItem extends StatefulWidget {
  final String id;
  final Widget child;
  final SelectionController controller;
  final GlobalKey marqueeKey;
  final BorderRadius? borderRadius;
  final Rect Function()? rectProvider;
  final Widget Function(BuildContext, Widget, bool)? selectedBuilder;
  final Decoration? selectionDecoration;
  final bool registerOnBuild;

  const SelectableItem({
    super.key,
    required this.id,
    required this.child,
    required this.controller,
    required this.marqueeKey,
    this.borderRadius,
    this.rectProvider,
    this.selectedBuilder,
    this.selectionDecoration,
    this.registerOnBuild = true,
  });

  @override
  State<SelectableItem> createState() => _SelectableItemState();
}

class _SelectableItemState extends State<SelectableItem> {
  final GlobalKey _itemKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onSelectionChange);
    if (widget.registerOnBuild) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.registerItem(
          widget.id,
          _itemKey,
          rectProvider: widget.rectProvider,
        );
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSelectionChange);
    widget.controller.unregisterItem(widget.id);
    super.dispose();
  }

  void _onSelectionChange() {
    if (!widget.controller.isSelecting ||
        widget.controller.selectionRect == null) {
      return;
    }

    final marqueeRenderBox =
        widget.marqueeKey.currentContext?.findRenderObject() as RenderBox?;

    final itemRect = widget.rectProvider != null
        ? widget.rectProvider!()
        : (() {
            final renderBox =
                _itemKey.currentContext?.findRenderObject() as RenderBox?;
            if (renderBox == null ||
                marqueeRenderBox == null ||
                !renderBox.attached) {
              return null;
            }
            final offset = renderBox.localToGlobal(
              Offset.zero,
              ancestor: marqueeRenderBox,
            );
            return offset & renderBox.size;
          })();

    if (itemRect == null) return;

    final overlap = widget.controller.selectionRect!.overlaps(itemRect);
    if (overlap) {
      if (!widget.controller.selectedIds.contains(widget.id)) {
        widget.controller.select(widget.id);
      }
    } else {
      if (widget.controller.selectedIds.contains(widget.id)) {
        widget.controller.deselect(widget.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final selected = widget.controller.selectedIds.contains(widget.id);
        Widget child = KeyedSubtree(key: _itemKey, child: widget.child);

        if (widget.selectedBuilder != null) {
          return widget.selectedBuilder!(context, child, selected);
        }

        final decoration =
            widget.selectionDecoration ??
            BoxDecoration(
              color: selected
                  ? Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: widget.borderRadius,
            );

        return Container(decoration: decoration, child: child);
      },
    );
  }
}

class _SelectionRectPainter extends CustomPainter {
  final SelectionDecoration? decoration;
  final Color themeFill;
  final Color themeBorder;
  final double radius;
  final double phase; // 0..1

  _SelectionRectPainter({
    required this.decoration,
    required this.themeFill,
    required this.themeBorder,
    required this.radius,
    required this.phase,
    super.repaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final fill = decoration?.fillColor ?? themeFill;
    if (fill != Colors.transparent) {
      final fillPaint = Paint()..color = fill;
      final r = decoration?.borderRadius ?? radius;
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));
      canvas.drawRRect(rrect, fillPaint);
    }

    final borderColor = decoration?.borderColor ?? themeBorder;
    final borderWidth = decoration?.borderWidth ?? 1.0;
    final style = decoration?.borderStyle ?? SelectionBorderStyle.solid;

    final rrect = RRect.fromRectAndRadius(
      rect.deflate(borderWidth / 2),
      Radius.circular(decoration?.borderRadius ?? radius),
    );
    final path = Path()..addRRect(rrect);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..color = borderColor
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    if (style == SelectionBorderStyle.solid) {
      canvas.drawPath(path, paint);
      return;
    }

    // Special handling for "actual dots" if dotted style
    if (style == SelectionBorderStyle.dotted) {
      final gap = decoration?.gapLength ?? 4.0;
      final diameter = borderWidth * 1.5; // Dots are 50% larger than the line width
      final period = diameter + gap;
      final offset = period * phase;

      paint
        ..style = PaintingStyle.fill
        ..strokeWidth = 0; // ensure fill paint doesn't use stroke width

      for (final metric in path.computeMetrics()) {
        double distance = -(offset % period);
        while (distance < metric.length) {
          if (distance >= 0) {
            final tangent = metric.getTangentForOffset(distance);
            if (tangent != null) {
              canvas.drawCircle(tangent.position, diameter / 2, paint);
            }
          }
          distance += period;
        }
      }
      return;
    }

    // Dashed / Marching Ants logic
    final dashLen = decoration?.dashLength ?? 6.0;
    final gapLen = decoration?.gapLength ?? 4.0;
    final phaseOffset = (dashLen + gapLen) * phase;

    for (final metric in path.computeMetrics()) {
      double distance = -phaseOffset;
      while (distance < metric.length) {
        final start = math.max(0.0, distance);
        final end = math.min(metric.length, distance + dashLen);
        if (end > start) {
          final extract = metric.extractPath(start, end);
          canvas.drawPath(extract, paint);
        }
        distance += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionRectPainter oldDelegate) {
    return oldDelegate.decoration != decoration ||
        oldDelegate.phase != phase ||
        oldDelegate.themeBorder != themeBorder;
  }
}
