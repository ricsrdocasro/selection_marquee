import 'package:flutter/material.dart';
import 'package:selection_marquee/selection_marquee.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Selection Marquee Example',
      theme: ThemeData(useMaterial3: true),
      home: const ExampleHome(),
    );
  }
}

class ExampleHome extends StatefulWidget {
  const ExampleHome({super.key});

  @override
  State<ExampleHome> createState() => _ExampleHomeState();
}

class _ExampleHomeState extends State<ExampleHome> {
  final SelectionController _controller = SelectionController();
  final GlobalKey _marqueeKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  // layout
  bool _isGrid = true;

  // runtime tuning values for auto-scroll
  double _edgeZoneFraction = 0.12;
  double _autoScrollSpeed = 600.0;
  double _minAutoScrollFactor = 0.25;
  bool _edgeAutoScrollEnabled = true;
  bool _shortcutsEnabled = true;
  AutoScrollMode _autoScrollMode = AutoScrollMode.jump;
  Curve _autoScrollCurve = Curves.linear;

  // selection decoration options
  SelectionBorderStyle _selectionBorderStyle =
      SelectionBorderStyle.marchingAnts;
  double _selectionBorderWidth = 1.0;
  double _selectionDashLength = 8.0;
  double _selectionGapLength = 4.0;
  int _selectionMarchMs = 800;
  double _selectionBorderRadius = 4.0;

  final Map<String, Curve> _curveOptions = {
    'linear': Curves.linear,
    'easeIn': Curves.easeIn,
    'easeOut': Curves.easeOut,
    'easeInOut': Curves.easeInOut,
    'fastOutSlowIn': Curves.fastOutSlowIn,
  };

  // sidebar + indicator
  bool _sidebarOpen = false;
  double _currentVelocity = 0.0; // px/s, positive = down

  final List<String> items = List.generate(50, (i) => 'Item ${i + 1}');

  @override
  void initState() {
    super.initState();
    _controller.allItemsGetter = () => items;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildCard(String id) {
    return SelectableItem(
      id: id,
      controller: _controller,
      marqueeKey: _marqueeKey,
      borderRadius: BorderRadius.circular(12),
      onLongPress: () => _controller.toggle(id),
      onContextMenu: (position) {
        showMenu(
          context: context,
          position: RelativeRect.fromLTRB(
            position.dx,
            position.dy,
            position.dx,
            position.dy,
          ),
          items: [
            PopupMenuItem(
              value: 'info',
              child: Text('Selected: ${_controller.selectedIds.length} items'),
            ),
            const PopupMenuItem(value: 'clear', child: Text('Clear Selection')),
          ],
        ).then((value) {
          if (value == 'clear') {
            _controller.clear();
          }
        });
      },
      selectedBuilder: (context, child, selected) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      selectionDecoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: Colors.blueAccent, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(child: Text(id)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selection Marquee Example'),
        actions: [
          IconButton(
            icon: Icon(_sidebarOpen ? Icons.chevron_right : Icons.chevron_left),
            tooltip: 'Toggle Sidebar',
            onPressed: () => setState(() => _sidebarOpen = !_sidebarOpen),
          ),
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: 'Select All',
            onPressed: () => _controller.selectAll(candidates: items),
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Clear',
            onPressed: () => _controller.clear(),
          ),
          IconButton(
            icon: Icon(_isGrid ? Icons.list : Icons.grid_view),
            onPressed: () => setState(() => _isGrid = !_isGrid),
          ),
        ],
      ),
      body: Row(
        children: [
          // main content
          Expanded(
            child: Listener(
              onPointerMove: (event) {
                // compute a local estimated velocity for the sidebar display only
                final rb = _marqueeKey.currentContext?.findRenderObject()
                    as RenderBox?;
                if (rb == null) return;
                final local = rb.globalToLocal(event.position);
                final s = rb.size;
                final zone = s.height * _edgeZoneFraction;
                double velocity = 0.0;
                if (local.dy <= zone) {
                  final proximity = (zone - local.dy) / zone;
                  final factor = (_minAutoScrollFactor +
                          (1 - _minAutoScrollFactor) * proximity)
                      .clamp(0.0, 1.0);
                  velocity = -_autoScrollSpeed * factor; // negative => up
                } else if (local.dy >= s.height - zone) {
                  final proximity = (local.dy - (s.height - zone)) / zone;
                  final factor = (_minAutoScrollFactor +
                          (1 - _minAutoScrollFactor) * proximity)
                      .clamp(0.0, 1.0);
                  velocity = _autoScrollSpeed * factor; // positive => down
                }
                setState(() => _currentVelocity = velocity);
              },
              onPointerUp: (_) => setState(() => _currentVelocity = 0.0),
              child: SelectionMarquee(
                controller: _controller,
                marqueeKey: _marqueeKey,
                scrollController: _scrollController,
                enableShortcuts: _shortcutsEnabled,
                config: SelectionConfig(
                  edgeAutoScroll: _edgeAutoScrollEnabled,
                  autoScrollSpeed: _autoScrollSpeed,
                  edgeZoneFraction: _edgeZoneFraction,
                  minAutoScrollFactor: _minAutoScrollFactor,
                  autoScrollMode: _autoScrollMode,
                  selectionDecoration: SelectionDecoration(
                    borderStyle: _selectionBorderStyle,
                    borderWidth: _selectionBorderWidth,
                    borderRadius: _selectionBorderRadius,
                    dashLength: _selectionDashLength,
                    gapLength: _selectionGapLength,
                    marchingSpeed: Duration(milliseconds: _selectionMarchMs),
                  ),
                  autoScrollCurve: _autoScrollCurve,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Tip: drag with mouse or long-press and drag on touch devices. Tap items to toggle selection.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('Edge Auto-Scroll'),
                                    const Spacer(),
                                    Switch(
                                      value: _edgeAutoScrollEnabled,
                                      onChanged: (v) => setState(
                                        () => _edgeAutoScrollEnabled = v,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Text(
                                        'Keyboard Shortcuts (Ctrl+A, Esc)'),
                                    const Spacer(),
                                    Switch(
                                      value: _shortcutsEnabled,
                                      onChanged: (v) => setState(
                                        () => _shortcutsEnabled = v,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Auto-scroll mode: ${_autoScrollMode.name}',
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButton<AutoScrollMode>(
                                        value: _autoScrollMode,
                                        items: AutoScrollMode.values
                                            .map(
                                              (m) => DropdownMenuItem(
                                                value: m,
                                                child: Text(m.name),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (v) => setState(
                                          () => _autoScrollMode =
                                              v ?? AutoScrollMode.jump,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Edge zone fraction: ${_edgeZoneFraction.toStringAsFixed(2)}',
                                ),
                                Slider(
                                  min: 0.05,
                                  max: 0.5,
                                  divisions: 45,
                                  value: _edgeZoneFraction,
                                  onChanged: (v) =>
                                      setState(() => _edgeZoneFraction = v),
                                ),
                                Text(
                                  'Max auto-scroll speed: ${_autoScrollSpeed.toStringAsFixed(0)} px/s',
                                ),
                                Slider(
                                  min: 50,
                                  max: 2000,
                                  divisions: 39,
                                  value: _autoScrollSpeed,
                                  onChanged: (v) =>
                                      setState(() => _autoScrollSpeed = v),
                                ),
                                Text(
                                  'Min auto-scroll factor: ${_minAutoScrollFactor.toStringAsFixed(2)}',
                                ),
                                Slider(
                                  min: 0.0,
                                  max: 1.0,
                                  divisions: 100,
                                  value: _minAutoScrollFactor,
                                  onChanged: (v) =>
                                      setState(() => _minAutoScrollFactor = v),
                                ),
                                const SizedBox(height: 8),
                                const Text('Auto-scroll curve:'),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButton<String>(
                                        value: _curveOptions.keys.firstWhere(
                                          (k) =>
                                              _curveOptions[k] ==
                                              _autoScrollCurve,
                                          orElse: () => 'linear',
                                        ),
                                        items: _curveOptions.keys
                                            .map(
                                              (k) => DropdownMenuItem(
                                                value: k,
                                                child: Text(k),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (v) => setState(() {
                                          if (v != null) {
                                            _autoScrollCurve =
                                                _curveOptions[v]!;
                                          }
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text('Selection border style:'),
                                Row(
                                  children: [
                                    Expanded(
                                      child:
                                          DropdownButton<SelectionBorderStyle>(
                                        value: _selectionBorderStyle,
                                        items: SelectionBorderStyle.values
                                            .map(
                                              (s) => DropdownMenuItem(
                                                value: s,
                                                child: Text(s.name),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (v) => setState(
                                          () => _selectionBorderStyle =
                                              v ?? SelectionBorderStyle.solid,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Border radius: ${_selectionBorderRadius.toStringAsFixed(1)}',
                                ),
                                Slider(
                                  min: 0.0,
                                  max: 24.0,
                                  divisions: 24,
                                  value: _selectionBorderRadius,
                                  onChanged: (v) => setState(
                                    () => _selectionBorderRadius = v,
                                  ),
                                ),
                                Text(
                                  'Border width: ${_selectionBorderWidth.toStringAsFixed(1)}',
                                ),
                                Slider(
                                  min: 0.5,
                                  max: 6.0,
                                  divisions: 11,
                                  value: _selectionBorderWidth,
                                  onChanged: (v) =>
                                      setState(() => _selectionBorderWidth = v),
                                ),
                                Text(
                                  'Dash length: ${_selectionDashLength.toStringAsFixed(1)}',
                                ),
                                Slider(
                                  min: 2.0,
                                  max: 32.0,
                                  divisions: 15,
                                  value: _selectionDashLength,
                                  onChanged: (v) =>
                                      setState(() => _selectionDashLength = v),
                                ),
                                Text(
                                  'Gap length: ${_selectionGapLength.toStringAsFixed(1)}',
                                ),
                                Slider(
                                  min: 0.0,
                                  max: 24.0,
                                  divisions: 12,
                                  value: _selectionGapLength,
                                  onChanged: (v) =>
                                      setState(() => _selectionGapLength = v),
                                ),
                                Text('Marching speed: $_selectionMarchMs ms'),
                                Slider(
                                  min: 100,
                                  max: 2000,
                                  divisions: 19,
                                  value: _selectionMarchMs.toDouble(),
                                  onChanged: (v) => setState(
                                    () => _selectionMarchMs = v.toInt(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      _isGrid
                          ? SliverPadding(
                              padding: const EdgeInsets.all(8.0),
                              sliver: SliverGrid.count(
                                crossAxisCount: 4,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                children:
                                    items.map((e) => _buildCard(e)).toList(),
                              ),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6.0,
                                  ),
                                  child: _buildCard(items[index]),
                                ),
                                childCount: items.length,
                              ),
                            ),
                                                                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                            
                                                      // sidebar
                                                      AnimatedContainer(
                                                        duration: const Duration(milliseconds: 200),
                                                        width: _sidebarOpen ? 240 : 0,
                                                        child: _sidebarOpen
                                                            ? Container(
                                                                color: Theme.of(
                                                                  context,
                                                                ).colorScheme.surfaceContainerHighest,
                                                                child: Padding(
                                                                  padding: const EdgeInsets.all(12.0),
                                                                  child: Column(
                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                    children: [
                                                                      Row(
                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                        children: [
                                                                          const Text('Auto-scroll'),
                                                                          IconButton(
                                                                            icon: const Icon(Icons.close),
                                                                            onPressed: () =>
                                                                                setState(() => _sidebarOpen = false),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                      const SizedBox(height: 8),
                                                                      Text(
                                                                        'Velocity: ${_currentVelocity.toStringAsFixed(1)} px/s',
                                                                      ),
                                                                      const SizedBox(height: 8),
                                                                      LinearProgressIndicator(
                                                                        value:
                                                                            (_currentVelocity.abs() /
                                                                                    (_autoScrollSpeed == 0
                                                                                        ? 1
                                                                                        : _autoScrollSpeed))
                                                                                .clamp(0.0, 1.0),
                                                                      ),
                                                                      const SizedBox(height: 12),
                                                                      Text(
                                                                        'Direction: ${_currentVelocity < 0
                                                                            ? 'Up'
                                                                            : _currentVelocity > 0
                                                                            ? 'Down'
                                                                            : 'None'}',
                                                                      ),
                                                                      const SizedBox(height: 12),
                                                                      Text(
                                                                        'Edge zone: ${_edgeZoneFraction.toStringAsFixed(2)}',
                                                                      ),
                                                                      Text(
                                                                        'Max speed: ${_autoScrollSpeed.toStringAsFixed(0)}',
                                                                      ),
                                                                      Text(
                                                                        'Min factor: ${_minAutoScrollFactor.toStringAsFixed(2)}',
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              )
                                                            : null,
                                                      ),        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              ValueListenableBuilder<Set<String>>(
                valueListenable: _controller.selectedListenable,
                builder: (context, set, _) => Text('Selected: ${set.length}'),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Reveal first selected',
                icon: const Icon(Icons.visibility),
                onPressed: () {
                  final first = _controller.selectedIds.isNotEmpty
                      ? _controller.selectedIds.first
                      : null;
                  if (first != null) {
                    _controller.ensureItemVisible(
                      first,
                      scrollController: _scrollController,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
