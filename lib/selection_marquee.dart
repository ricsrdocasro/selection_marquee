import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// Defines the behavior of the selection when dragging or clicking.
enum SelectionMode {
  /// Clears previous selection and selects the new item(s).
  single,

  /// Toggles the selection of the item(s).
  multiple,

  /// Adds the new item(s) to the existing selection.
  additive,

  /// Selects a range of items from the anchor to the current item.
  range
}

/// Configuration for the [SelectionMarquee] widget.
class SelectionConfig {
  /// Whether to allow touch input to initiate selection drag.
  final bool allowTouch;

  /// The minimum distance the pointer must move before a drag is considered started.
  final double minDragDistance;

  /// Whether to enable auto-scrolling when dragging near the edges of the scrollable area.
  final bool edgeAutoScroll;

  /// The maximum speed of auto-scrolling in pixels per second.
  final double autoScrollSpeed;

  /// Optional threshold for item overlap to be considered selected (0.0 to 1.0).
  /// Currently logic uses strict overlap or contact.
  final double overlapThreshold;

  /// The fraction of the scrollable area's height/width that triggers auto-scrolling.
  final double edgeZoneFraction;

  /// The minimum speed factor for auto-scrolling (0.0 to 1.0).
  final double minAutoScrollFactor;

  /// The mode of auto-scrolling: [AutoScrollMode.jump] or [AutoScrollMode.animate].
  final AutoScrollMode autoScrollMode;

  /// The duration of the animation step when using [AutoScrollMode.animate].
  final Duration autoScrollAnimationDuration;

  /// The curve of the auto-scroll animation.
  final Curve autoScrollCurve;

  /// Custom decoration for the selection marquee box.
  final SelectionDecoration? selectionDecoration;

  /// Creates a [SelectionConfig] with customizable parameters.
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

/// Defines how the scrollable area reacts during auto-scrolling.
enum AutoScrollMode {
  /// Jumps the scroll position immediately. smoother for high-frequency updates.
  jump,

  /// Animates to the new position.
  animate
}

/// Defines the visual style of the selection box border.
enum SelectionBorderStyle {
  /// A solid line border.
  solid,

  /// A dashed line border.
  dashed,

  /// A dotted line border.
  dotted,

  /// A "Marching Ants" animated border effect.
  marchingAnts
}

/// Defines the visual decoration of the selection marquee box.
class SelectionDecoration {
  /// The fill color of the selection box.
  final Color? fillColor;

  /// The border color of the selection box.
  final Color? borderColor;

  /// The width of the border.
  final double borderWidth;

  /// The style of the border (solid, dashed, etc.).
  final SelectionBorderStyle borderStyle;

  /// The length of the dashes (for dashed/marching ants styles).
  final double dashLength;

  /// The length of the gaps between dashes.
  final double gapLength;

  /// The speed of the marching ants animation.
  final Duration marchingSpeed;

  /// The border radius of the selection box.
  final double borderRadius;

  /// Creates a [SelectionDecoration] configuration.
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

/// Defines the type of selection action being performed during a drag.
enum SelectionDragType {
  /// Replaces the current selection with the new one.
  replace,

  /// Adds items to the current selection.
  additive,

  /// Inverts the selection state of items under the marquee.
  invert
}

/// Manages the state of the selection, including selected items and the marquee geometry.
class SelectionController extends ChangeNotifier {
  /// The current rectangle of the selection marquee in global coordinates.
  Rect? selectionRect;

  /// Whether a selection drag operation is currently in progress.
  bool isSelecting = false;

  /// The type of the current drag operation (e.g. replace, additive).
  SelectionDragType dragType = SelectionDragType.replace;

  final Set<String> _selectedIds = {};

  /// The set of currently selected item IDs.
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);

  // NEW: internal registry of all items currently in the list
  final Set<String> _registeredIds = {};

  // Track the last "touched" item for Range Selection (Shift+Click)
  String? _lastAnchorId;

  /// Optional callback to retrieve all selectable IDs.
  /// Required for 'Select All' (Ctrl+A) to work correctly in virtualized lists (ListView/GridView)
  /// where items are dynamically created/destroyed.
  ValueGetter<Iterable<String>>? allItemsGetter;

  /// A [ValueNotifier] that notifies listeners of the current set of selected IDs.
  final ValueNotifier<Set<String>> selectedListenable = ValueNotifier({});
  final StreamController<Set<String>> _selectedStreamController =
      StreamController<Set<String>>.broadcast();

  // registration for virtualized lists
  final Map<String, GlobalKey> _registeredKeys = {};
  final Map<String, Rect Function()> _rectProviders = {};

  /// A stream that emits the set of selected IDs whenever the selection changes.
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

  /// Adds a single item to the selection.
  void select(String id) {
    if (_selectedIds.add(id)) {
      _lastAnchorId = id;
      _emitSelection();
    }
  }

  /// Removes a single item from the selection.
  void deselect(String id) {
    if (_selectedIds.remove(id)) {
      if (_lastAnchorId == id) _lastAnchorId = null;
      _emitSelection();
    }
  }

  /// Toggles the selection state of a single item.
  void toggle(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
      if (_lastAnchorId == id) _lastAnchorId = null;
    } else {
      _selectedIds.add(id);
      _lastAnchorId = id;
    }
    _emitSelection();
  }

  /// Handle Tap interactions (Click, Ctrl+Click, Shift+Click)
  void itemClicked(String id, {bool isShift = false, bool isCtrl = false}) {
    if (isShift &&
        _lastAnchorId != null &&
        _registeredIds.contains(_lastAnchorId)) {
      // Range Select
      _selectRange(_lastAnchorId!, id, isCtrl);
    } else if (isCtrl) {
      // Toggle
      toggle(id);
    } else {
      // Single Select (Replace)
      _selectedIds.clear();
      select(id);
    }
  }

  void _selectRange(String startId, String endId, bool preserveExisting) {
    // 1. Sort all registered items visually to determine order
    final sortedItems = _sortRegisteredItems();

    // 2. Find indices
    final startIndex = sortedItems.indexOf(startId);
    final endIndex = sortedItems.indexOf(endId);

    if (startIndex == -1 || endIndex == -1) {
      // Fallback if anchor or target not found (e.g. scrolled away)
      select(endId);
      return;
    }

    final lower = math.min(startIndex, endIndex);
    final upper = math.max(startIndex, endIndex);

    final rangeIds = sortedItems.sublist(lower, upper + 1);

    if (!preserveExisting) {
      _selectedIds.clear();
    }
    _selectedIds.addAll(rangeIds);

    // The new anchor is usually the one clicked last (endId)
    _lastAnchorId =
        startId; // Keep the original anchor? Standard behavior varies.
    // Windows Explorer: Anchor stays at the 'start' of the shift-click chain.
    // But let's set it to startId (the persistent anchor).

    _emitSelection();
  }

  List<String> _sortRegisteredItems() {
    // Collect all registered items with their Rects
    final items = <_ItemPos>[];

    for (final id in _registeredIds) {
      // Try getting rect from provider or key
      Rect? rect;
      if (_rectProviders.containsKey(id)) {
        rect = _rectProviders[id]!();
      } else if (_registeredKeys.containsKey(id)) {
        final key = _registeredKeys[id]!;
        final ctx = key.currentContext;
        if (ctx != null) {
          final box = ctx.findRenderObject() as RenderBox?;
          if (box != null && box.attached) {
            final offset = box.localToGlobal(Offset.zero); // Global coords
            rect = offset & box.size;
          }
        }
      }

      if (rect != null) {
        items.add(_ItemPos(id, rect));
      }
    }

    // Sort: Top-to-bottom, then Left-to-right
    items.sort((a, b) {
      final dy = a.rect.top - b.rect.top;
      if (dy.abs() > 0.5)
        return dy.sign.toInt(); // Tolerance for grid alignment
      return (a.rect.left - b.rect.left).sign.toInt();
    });

    return items.map((e) => e.id).toList();
  }

  /// Sets the selection to exactly the provided set of IDs.
  void setSelected(Set<String> ids) {
    _selectedIds
      ..clear()
      ..addAll(ids);
    _emitSelection();
  }

  /// Clears the current selection.
  void clear() {
    if (_selectedIds.isNotEmpty) {
      _selectedIds.clear();
      _emitSelection();
    }
  }

  /// Registers an item so it can be included in 'Select All'.
  /// (Called automatically by SelectableItem)
  void register(String id) {
    _registeredIds.add(id);
  }

  /// Unregisters an item when it is disposed.
  void unregister(String id) {
    _registeredIds.remove(id);
  }

  /// Selects all known items.
  ///
  /// If [candidates] is provided, only those items are selected.
  /// Otherwise, it uses [allItemsGetter] if available, or falls back to currently registered items.
  void selectAll({Iterable<String>? candidates}) {
    if (candidates != null) {
      _selectedIds
        ..clear()
        ..addAll(candidates);
      _emitSelection();
    } else if (allItemsGetter != null) {
      _selectedIds
        ..clear()
        ..addAll(allItemsGetter!());
      _emitSelection();
    } else if (_registeredIds.isNotEmpty) {
      _selectedIds
        ..clear()
        ..addAll(_registeredIds);
      _emitSelection();
    }
  }

  // Selection lifecycle used by marquee widget
  Set<String> _dragBaseSelection = {};

  /// Starts a selection drag operation.
  void startSelection(Offset startPosition,
      {Set<String>? initialSelection,
      SelectionDragType type = SelectionDragType.replace}) {
    isSelecting = true;
    dragType = type;
    _dragBaseSelection =
        initialSelection != null ? Set.from(initialSelection) : {};
    selectionRect = Rect.fromPoints(startPosition, startPosition);
    notifyListeners();
  }

  /// Updates the selection rectangle during a drag operation.
  void updateSelection(Offset currentPosition, Offset startPosition) {
    selectionRect = Rect.fromPoints(startPosition, currentPosition);
    notifyListeners();
  }

  /// Ends the selection drag operation.
  void endSelection() {
    isSelecting = false;
    selectionRect = null;
    notifyListeners();
  }

  // Registration API for virtual lists

  /// Registers a virtual item with its key and optional rect provider.
  void registerItem(String id, GlobalKey key, {Rect Function()? rectProvider}) {
    _registeredKeys[id] = key;
    if (rectProvider != null) _rectProviders[id] = rectProvider;
  }

  /// Unregisters a virtual item.
  void unregisterItem(String id) {
    _registeredKeys.remove(id);
    _rectProviders.remove(id);
  }

  /// Attempts to scroll the view to ensure the specified item is visible.
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

/// A widget that provides drag-to-select functionality (marquee selection) for its child.
class SelectionMarquee extends StatefulWidget {
  /// The child widget (usually a scrollable view like ListView or GridView).
  final Widget child;

  /// The controller that manages selection state.
  final SelectionController controller;

  /// A GlobalKey attached to the Stack that contains the selection box.
  /// This is used to determine the geometry of the selection area.
  final GlobalKey marqueeKey;

  /// Configuration options for the selection behavior and appearance.
  final SelectionConfig config;

  /// The ScrollController of the child scrollable view.
  /// Required for auto-scrolling to work.
  final ScrollController? scrollController;

  /// Whether to enable keyboard modifiers (Ctrl, Shift) for selection.
  ///
  /// * Ctrl + Drag: Invert selection.
  /// * Shift + Drag: Add to selection.
  /// * Default is true.
  final bool enableKeyboardDrag;

  /// Whether to enable keyboard shortcuts (Ctrl+A, Esc).
  ///
  /// * Ctrl + A: Select All.
  /// * Esc: Clear selection.
  /// * Default is true.
  final bool enableShortcuts;

  /// Creates a [SelectionMarquee].
  const SelectionMarquee({
    super.key,
    required this.child,
    required this.controller,
    required this.marqueeKey,
    this.config = const SelectionConfig(),
    this.scrollController,
    this.enableKeyboardDrag = true,
    this.enableShortcuts = true,
  });

  @override
  State<SelectionMarquee> createState() => _SelectionMarqueeState();
}

class _SelectionMarqueeState extends State<SelectionMarquee>
    with SingleTickerProviderStateMixin {
  Offset? _startPos;
  double _dragStartScrollOffset = 0.0;
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

  // Helper to calculate the REAL rectangle relative to the content
  Rect _getSelectionRect() {
    if (_startPos == null || _currentPointerLocal == null) return Rect.zero;

    // SCROLL FIX: Calculate how much we have scrolled since dragging started
    double currentScroll = (widget.scrollController?.hasClients ?? false)
        ? widget.scrollController!.offset
        : 0.0;

    double scrollDelta = currentScroll - _dragStartScrollOffset;

    // Adjust the visual start point to "stick" to the content
    Offset adjustedStart = _startPos! - Offset(0, scrollDelta);

    return Rect.fromPoints(adjustedStart, _currentPointerLocal!);
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

    Widget content = Listener(
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
          _currentPointerLocal = details.localPosition;
          _dragStarted = false;

          // SCROLL FIX: Capture Scroll Offset
          if (widget.scrollController?.hasClients ?? false) {
            _dragStartScrollOffset = widget.scrollController!.offset;
          } else {
            _dragStartScrollOffset = 0.0;
          }

          // KEYBOARD MODIFIERS
          bool shouldClear = true;
          Set<String>? initialSelection;
          SelectionDragType dragType = SelectionDragType.replace;

          if (widget.enableKeyboardDrag) {
            final keys = HardwareKeyboard.instance.logicalKeysPressed;
            final isCtrl = keys.contains(LogicalKeyboardKey.controlLeft) ||
                keys.contains(LogicalKeyboardKey.controlRight) ||
                keys.contains(LogicalKeyboardKey.metaLeft) ||
                keys.contains(LogicalKeyboardKey.metaRight);

            final isShift = keys.contains(LogicalKeyboardKey.shiftLeft) ||
                keys.contains(LogicalKeyboardKey.shiftRight);

            // Logic:
            // Ctrl + Drag = Invert (Toggle) what is under the marquee
            // Shift + Drag = Additive (Accumulate) - standard desktop behavior for marquee

            if (isCtrl) {
              shouldClear = false;
              initialSelection = widget.controller.selectedIds;
              dragType = SelectionDragType.invert;
            } else if (isShift) {
              shouldClear = false;
              initialSelection = widget.controller.selectedIds;
              dragType = SelectionDragType.additive;
            }
          }

          if (shouldClear) {
            widget.controller.clear();
          }
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

            // RE-CALCULATE initial selection here because the clear() might have happened above
            Set<String>? finalInitial;
            SelectionDragType finalType = SelectionDragType.replace;

            if (widget.enableKeyboardDrag) {
              final keys = HardwareKeyboard.instance.logicalKeysPressed;
              final isCtrl = keys.contains(LogicalKeyboardKey.controlLeft) ||
                  keys.contains(LogicalKeyboardKey.controlRight) ||
                  keys.contains(LogicalKeyboardKey.metaLeft) ||
                  keys.contains(LogicalKeyboardKey.metaRight);
              final isShift = keys.contains(LogicalKeyboardKey.shiftLeft) ||
                  keys.contains(LogicalKeyboardKey.shiftRight);

              if (isCtrl) {
                finalInitial = widget.controller.selectedIds;
                finalType = SelectionDragType.invert;
              } else if (isShift) {
                finalInitial = widget.controller.selectedIds;
                finalType = SelectionDragType.additive;
              }
            }

            widget.controller.startSelection(_startPos!,
                initialSelection: finalInitial, type: finalType);
          }

          if (_dragStarted) {
            final rect = _getSelectionRect();
            widget.controller.updateSelection(
              rect.bottomRight,
              rect.topLeft,
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
                      radius: widget.config.selectionDecoration?.borderRadius ??
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

    // Shortcuts Wrapper
    if (widget.enableShortcuts) {
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyA, control: true): () =>
              widget.controller.selectAll(),
          const SingleActivator(LogicalKeyboardKey.keyA, meta: true): () =>
              widget.controller.selectAll(),
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              widget.controller.clear(),
        },
        child: Focus(
          autofocus: true,
          child: content,
        ),
      );
    }

    return content;
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
        final rect = _getSelectionRect();
        widget.controller.updateSelection(rect.bottomRight, rect.topLeft);
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

/// A wrapper widget that marks an item as selectable within a [SelectionMarquee].
///
/// Automatically registers itself with the [SelectionController].
class SelectableItem extends StatefulWidget {
  /// The unique identifier for this item.
  final String id;

  /// The child widget to display.
  final Widget child;

  /// The controller managing the selection.
  final SelectionController controller;

  /// The marquee's key, used for coordinate space calculations.
  final GlobalKey marqueeKey;

  /// Optional border radius for the default selection decoration.
  final BorderRadius? borderRadius;

  /// Optional provider for the item's global rectangle.
  /// If not provided, it is calculated from the widget's render object.
  final Rect Function()? rectProvider;

  /// A builder function to customize the appearance when selected.
  final Widget Function(BuildContext, Widget, bool)? selectedBuilder;

  /// Custom decoration to apply when selected (overrides default).
  final Decoration? selectionDecoration;

  /// Whether to register the item with the controller on build.
  /// Default is true.
  final bool registerOnBuild;

  /// Callback for long press gestures.
  final VoidCallback? onLongPress;

  /// Callback for right-click context menu events.
  ///
  /// If provided, right-clicking the item will trigger this callback.
  /// The item will be selected (if not already) before the callback is invoked.
  final void Function(Offset globalPosition)? onContextMenu;

  /// Creates a [SelectableItem].
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
    this.onLongPress,
    this.onContextMenu,
  });

  @override
  State<SelectableItem> createState() => _SelectableItemState();
}

class _SelectableItemState extends State<SelectableItem> {
  final GlobalKey _itemKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.controller.register(widget.id);
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
  void didUpdateWidget(SelectableItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      widget.controller.unregister(oldWidget.id);
      widget.controller.register(widget.id);

      // Handle existing registration update
      widget.controller.unregisterItem(oldWidget.id);
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
  }

  @override
  void dispose() {
    widget.controller.unregister(widget.id);
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
    final wasAlreadySelected =
        widget.controller._dragBaseSelection.contains(widget.id);

    // Apply logic based on Drag Type
    if (widget.controller.dragType == SelectionDragType.replace) {
      if (overlap) {
        if (!widget.controller.selectedIds.contains(widget.id)) {
          widget.controller.select(widget.id);
        }
      } else {
        if (widget.controller.selectedIds.contains(widget.id)) {
          widget.controller.deselect(widget.id);
        }
      }
    } else if (widget.controller.dragType == SelectionDragType.additive) {
      // Additive (Shift): If overlapping OR was selected -> Select
      if (overlap || wasAlreadySelected) {
        if (!widget.controller.selectedIds.contains(widget.id)) {
          widget.controller.select(widget.id);
        }
      } else {
        // If not overlapping AND not wasSelected -> Deselect (revert to unselected)
        if (widget.controller.selectedIds.contains(widget.id)) {
          widget.controller.deselect(widget.id);
        }
      }
    } else if (widget.controller.dragType == SelectionDragType.invert) {
      // Invert (Ctrl):
      // If overlapping: Flip state (Selected -> Unselected, Unselected -> Selected)
      // If not overlapping: Restore base state

      final shouldBeSelected =
          overlap ? !wasAlreadySelected : wasAlreadySelected;

      if (shouldBeSelected) {
        if (!widget.controller.selectedIds.contains(widget.id)) {
          widget.controller.select(widget.id);
        }
      } else {
        if (widget.controller.selectedIds.contains(widget.id)) {
          widget.controller.deselect(widget.id);
        }
      }
    }
  }

  void _handleTap() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final isCtrl = keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);
    final isShift = keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);

    widget.controller.itemClicked(widget.id, isShift: isShift, isCtrl: isCtrl);
  }

  void _handleRightClick(TapUpDetails details) {
    if (widget.onContextMenu == null) return;

    // Desktop Behavior:
    // If item is NOT in selection -> Select it (and deselect others)
    // If item IS in selection -> Keep selection as is

    if (!widget.controller.selectedIds.contains(widget.id)) {
      widget.controller.itemClicked(widget.id); // Standard click (replace)
    }

    widget.onContextMenu!(details.globalPosition);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final selected = widget.controller.selectedIds.contains(widget.id);
        Widget child = KeyedSubtree(key: _itemKey, child: widget.child);

        if (widget.selectedBuilder != null) {
          child = widget.selectedBuilder!(context, child, selected);
        } else {
          final decoration = widget.selectionDecoration ??
              BoxDecoration(
                color: selected
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: widget.borderRadius,
              );
          child = Container(decoration: decoration, child: child);
        }

        // Wrap with GestureDetector to handle clicks
        return GestureDetector(
          onTap: _handleTap,
          onLongPress: widget.onLongPress,
          onSecondaryTapUp: _handleRightClick,
          behavior: HitTestBehavior.translucent,
          child: child,
        );
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
      final diameter =
          borderWidth * 1.5; // Dots are 50% larger than the line width
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

class _ItemPos {
  final String id;
  final Rect rect;
  _ItemPos(this.id, this.rect);
}
