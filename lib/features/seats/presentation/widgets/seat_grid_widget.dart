import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import '../providers/seat_providers.dart';
import 'seat_tile.dart';
import 'seat_detail_sheet.dart';
import 'package:study_library/core/utils/error_formatter.dart';
import 'package:study_library/core/utils/seat_helper.dart';

class SeatGridWidget extends ConsumerStatefulWidget {
  final String libraryId;
  final String sectionId;
  final int rows;
  final int cols;
  final int? sectionColor;
  final bool showStatusLegend;

  const SeatGridWidget({
    super.key,
    required this.libraryId,
    required this.sectionId,
    required this.rows,
    required this.cols,
    this.sectionColor,
    this.showStatusLegend = false,
  });

  @override
  ConsumerState<SeatGridWidget> createState() => _SeatGridWidgetState();
}

class _SeatGridWidgetState extends ConsumerState<SeatGridWidget> {
  int _columns = 6;
  bool _hasInitializedColumns = false;
  double _pinchAccumulatedScale = 1.0;
  DateTime _lastWheelStepTime = DateTime.now();

  bool _isSlideMode = false;
  bool? _dragSelectMode; // true = selecting, false = deselecting
  final Set<String> _dragProcessedSeatIds = {};
  String _activeFilter = 'all'; // 'all', 'available', 'occupied', 'boys', 'girls'

  List<int> _getColumnTiers(double width) {
    final roomCols = widget.cols > 0 ? widget.cols : 10;
    if (width > 1200) {
      final list = <int>{20, 16, 12, roomCols, 8, 6, 4}.toList()..sort((a, b) => b.compareTo(a));
      return list;
    } else if (width > 800) {
      final list = <int>{16, 12, roomCols, 8, 6, 4}.toList()..sort((a, b) => b.compareTo(a));
      return list;
    } else if (width > 500) {
      final list = <int>{roomCols, 8, 6, 5, 4, 3}.toList()..sort((a, b) => b.compareTo(a));
      return list;
    } else {
      // Mobile phone screens (360px - 500px): Clean 4-tier column scale with comfortable 3-column default
      return const [5, 4, 3, 2];
    }
  }

  void _stepColumns(int direction, List<int> tiers) {
    // direction > 0: zoom in -> fewer columns (larger view)
    // direction < 0: zoom out -> more columns (compact fit)
    final currentIndex = tiers.indexOf(_columns);
    int nextIndex;
    if (currentIndex == -1) {
      nextIndex = tiers.indexWhere((t) => t <= _columns);
      if (nextIndex == -1) nextIndex = 0;
    } else {
      nextIndex = (currentIndex + direction).clamp(0, tiers.length - 1);
    }

    if (nextIndex != currentIndex) {
      _setColumns(tiers[nextIndex]);
    }
  }

  void _setColumns(int cols) {
    if (_columns == cols) return;
    HapticFeedback.selectionClick();
    setState(() {
      _columns = cols;
    });
  }

  void _handleDoubleTap(List<int> tiers) {
    final minColsTier = tiers.first; // max columns, most compact fit
    final middleTier = tiers[tiers.length ~/ 2];

    if (_columns == minColsTier) {
      _setColumns(middleTier);
    } else {
      _setColumns(minColsTier);
    }
  }

  void _handleDragStart(
    Offset localPosition,
    List<SeatModel> sortedSeats,
    int cols,
    double totalWidth,
    double childAspectRatio,
  ) {
    _dragProcessedSeatIds.clear();
    const double spacing = 8.0;
    final double itemWidth = (totalWidth - (cols - 1) * spacing) / cols;
    final double itemHeight = itemWidth / childAspectRatio;

    final int col = (localPosition.dx / (itemWidth + spacing)).floor();
    final int row = (localPosition.dy / (itemHeight + spacing)).floor();

    if (col >= 0 && col < cols && row >= 0) {
      final int index = row * cols + col;
      if (index >= 0 && index < sortedSeats.length) {
        final seat = sortedSeats[index];
        final isSelected = ref.read(selectedSeatsProvider).containsKey(seat.id);
        _dragSelectMode = !isSelected;
        _dragProcessedSeatIds.add(seat.id);
        HapticFeedback.selectionClick();

        if (_dragSelectMode == true) {
          ref.read(selectedSeatsProvider.notifier).selectMultiple({seat.id: widget.sectionId});
        } else {
          ref.read(selectedSeatsProvider.notifier).deselectMultiple([seat.id]);
        }
      }
    }
  }

  void _handleDragUpdate(
    Offset localPosition,
    List<SeatModel> sortedSeats,
    int cols,
    double totalWidth,
    double childAspectRatio,
  ) {
    if (_dragSelectMode == null) return;
    const double spacing = 8.0;
    final double itemWidth = (totalWidth - (cols - 1) * spacing) / cols;
    final double itemHeight = itemWidth / childAspectRatio;

    final int col = (localPosition.dx / (itemWidth + spacing)).floor();
    final int row = (localPosition.dy / (itemHeight + spacing)).floor();

    if (col >= 0 && col < cols && row >= 0) {
      final int index = row * cols + col;
      if (index >= 0 && index < sortedSeats.length) {
        final seat = sortedSeats[index];
        if (!_dragProcessedSeatIds.contains(seat.id)) {
          _dragProcessedSeatIds.add(seat.id);
          HapticFeedback.selectionClick();
          if (_dragSelectMode == true) {
            ref.read(selectedSeatsProvider.notifier).selectMultiple({seat.id: widget.sectionId});
          } else {
            ref.read(selectedSeatsProvider.notifier).deselectMultiple([seat.id]);
          }
        }
      }
    }
  }

  void _handleDragEnd() {
    _dragSelectMode = null;
    _dragProcessedSeatIds.clear();
  }

  @override
  Widget build(BuildContext context) {
    final seatsAsync = ref.watch(seatsProvider(widget.sectionId));
    final selectedSeats = ref.watch(selectedSeatsProvider);
    final studentsAsync = ref.watch(studentsStreamProvider);
    final studentList = studentsAsync.value ?? <StudentModel>[];
    final Map<String, StudentModel> studentMap = {
      for (final s in studentList) s.id: s,
    };

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasSelection = selectedSeats.isNotEmpty;

    final seats = seatsAsync.value ?? [];
    final sectionSeats = seats.where((s) => !s.id.startsWith('missing_')).toList();
    final allSelected = sectionSeats.isNotEmpty && sectionSeats.every((s) => selectedSeats.containsKey(s.id));

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final tiers = _getColumnTiers(width);

        if (!_hasInitializedColumns) {
          _hasInitializedColumns = true;
          // Set comfortable default: physical room layout on tablet/desktop, comfortable fit on mobile
          if (width >= 650 && widget.cols > 0) {
            _columns = widget.cols; // Always match physical room columns (e.g. 10 for Cozy Hall) on desktop/tablet!
          } else if (width < 440) {
            _columns = 3;
          } else if (width <= 650) {
            _columns = 4;
          } else {
            _columns = widget.cols > 0 ? widget.cols : tiers[tiers.length ~/ 2];
          }
        } else {
          // Clamp columns if device rotated or screen resized
          if (_columns > tiers.first) _columns = tiers.first;
          if (_columns < tiers.last) _columns = tiers.last;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showStatusLegend) ...[
              // Legend with matching tile backgrounds and borders
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildLegendItem(
                    isDark ? const Color(0xFF1B382B) : const Color(0xFFE8F5E9),
                    isDark ? const Color(0xFF2E7D32) : const Color(0xFF81C784),
                    'Available',
                  ),
                  _buildLegendItem(
                    isDark ? const Color(0xFF3E1D24) : const Color(0xFFFFEBEE),
                    isDark ? const Color(0xFFC62828) : const Color(0xFFEF9A9A),
                    'Occupied',
                  ),
                  _buildLegendItem(
                    isDark ? const Color(0xFF3E3218) : const Color(0xFFFFF8E1),
                    isDark ? const Color(0xFFF57F17) : const Color(0xFFFFD54F),
                    'Reserved',
                  ),
                  _buildLegendItem(
                    isDark ? const Color(0xFF2B2B2B) : const Color(0xFFEEEEEE),
                    isDark ? const Color(0xFF616161) : const Color(0xFFBDBDBD),
                    'Maintenance',
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            // Quick Filter Chips Bar (Live dynamic counts)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFilterChip(
                    'all',
                    'All Desks',
                    sectionSeats.length,
                    Theme.of(context).colorScheme.primary,
                    Icons.apps_rounded,
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    'available',
                    'Vacant',
                    sectionSeats.where((s) => s.status == SeatStatus.available).length,
                    const Color(0xFF10B981),
                    Icons.event_seat_rounded,
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    'occupied',
                    'Occupied',
                    sectionSeats.where((s) => s.status == SeatStatus.occupied).length,
                    const Color(0xFFEF4444),
                    Icons.person_rounded,
                  ),
                  if (sectionSeats.any((s) => s.genderRestriction == GenderRestriction.male)) ...[
                    const SizedBox(width: 6),
                    _buildFilterChip(
                      'boys',
                      'Boys',
                      sectionSeats.where((s) => s.genderRestriction == GenderRestriction.male).length,
                      const Color(0xFF1976D2),
                      Icons.male_rounded,
                    ),
                  ],
                  if (sectionSeats.any((s) => s.genderRestriction == GenderRestriction.female)) ...[
                    const SizedBox(width: 6),
                    _buildFilterChip(
                      'girls',
                      'Girls',
                      sectionSeats.where((s) => s.genderRestriction == GenderRestriction.female).length,
                      const Color(0xFFE91E63),
                      Icons.female_rounded,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Interactive Actions Toolbar (Slide-to-Select, Select All, Room View, Web/Mobile Zoom Actions)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (_isSlideMode || hasSelection)
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                      : (isDark ? Colors.white12 : Colors.black12),
                ),
              ),
              child: Row(
                children: [
                  // 1. Slide Mode Action
                  InkWell(
                    onTap: () {
                      setState(() => _isSlideMode = !_isSlideMode);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: _isSlideMode
                            ? Theme.of(context).colorScheme.primary
                            : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isSlideMode ? Icons.swipe_rounded : Icons.touch_app_rounded,
                            size: 15,
                            color: _isSlideMode
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isSlideMode
                                ? 'Slide: ON'
                                : (width < 380 ? 'Slide' : '🖐️ Slide to Select'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _isSlideMode
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // 2. Select All / Clear Action
                  if (sectionSeats.isNotEmpty)
                    InkWell(
                      onTap: () {
                        if (allSelected) {
                          ref.read(selectedSeatsProvider.notifier).deselectMultiple(sectionSeats.map((s) => s.id));
                        } else {
                          final map = {for (final s in sectionSeats) s.id: widget.sectionId};
                          ref.read(selectedSeatsProvider.notifier).selectMultiple(map);
                          setState(() => _isSlideMode = true);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: allSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                              size: 14,
                              color: allSelected
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              allSelected
                                  ? 'Clear'
                                  : (width < 380 ? 'All' : 'Select All'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: allSelected
                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const Spacer(),

                  // 3. High-Visibility Laptop & Mobile Zoom Controls (Zoom Out / Fit / Zoom In)
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Zoom Out / Fit more seats
                        Tooltip(
                          message: 'Zoom Out / Fit more seats (Press "-" key or Ctrl + Scroll Down)',
                          child: InkWell(
                            onTap: () => _stepColumns(-1, tiers),
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: width < 380 ? 7 : 10, vertical: 6),
                              child: Icon(
                                Icons.zoom_out_rounded,
                                size: 18,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 18,
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                        // Reset / Auto-fit
                        Tooltip(
                          message: 'Reset zoom / Fit to screen (Press "0" key)',
                          child: InkWell(
                            onTap: () => _setColumns(tiers[tiers.length ~/ 2]),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: width < 380 ? 6 : 8, vertical: 6),
                              child: Icon(
                                Icons.fit_screen_rounded,
                                size: 16,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 18,
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                        // Zoom In / Enlarge seats
                        Tooltip(
                          message: 'Zoom In / Enlarge seats (Press "+" key or Ctrl + Scroll Up)',
                          child: InkWell(
                            onTap: () => _stepColumns(1, tiers),
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: width < 380 ? 7 : 10, vertical: 6),
                              child: Icon(
                                Icons.zoom_in_rounded,
                                size: 18,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (hasSelection) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 17),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      tooltip: 'Clear selection',
                      onPressed: () {
                        ref.read(selectedSeatsProvider.notifier).clear();
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),

            seatsAsync.when(
              data: (seats) {
                if (seats.isEmpty) {
                  return const Center(child: Text('No seats initialized.'));
                }

                final sortedSeats = [...seats]..sort(SeatHelper.compareSeats);

                final double childAspectRatio = _columns <= 2 ? 1.35 : (_columns <= 3 ? 1.15 : (_columns <= 5 ? 1.05 : 0.98));

                return Focus(
                  autofocus: true,
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent) {
                      if (event.logicalKey == LogicalKeyboardKey.equal ||
                          event.logicalKey == LogicalKeyboardKey.add ||
                          event.logicalKey == LogicalKeyboardKey.numpadAdd) {
                        _stepColumns(1, tiers);
                        return KeyEventResult.handled;
                      } else if (event.logicalKey == LogicalKeyboardKey.minus ||
                          event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
                        _stepColumns(-1, tiers);
                        return KeyEventResult.handled;
                      } else if (event.logicalKey == LogicalKeyboardKey.digit0 ||
                          event.logicalKey == LogicalKeyboardKey.numpad0) {
                        _setColumns(tiers[tiers.length ~/ 2]);
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Listener(
                    // Web & Desktop Mouse-Wheel Zoom (Ctrl / Alt + Scroll Wheel)
                    onPointerSignal: (pointerSignal) {
                      if (pointerSignal is PointerScrollEvent) {
                        final isCtrl = HardwareKeyboard.instance.isControlPressed ||
                            HardwareKeyboard.instance.isMetaPressed ||
                            HardwareKeyboard.instance.isAltPressed;
                        if (isCtrl) {
                          final now = DateTime.now();
                          if (now.difference(_lastWheelStepTime).inMilliseconds > 160) {
                            _lastWheelStepTime = now;
                            if (pointerSignal.scrollDelta.dy < 0) {
                              _stepColumns(1, tiers); // Zoom in / enlarge
                            } else if (pointerSignal.scrollDelta.dy > 0) {
                              _stepColumns(-1, tiers); // Zoom out / fit
                            }
                          }
                        }
                      }
                    },
                    // Laptop Trackpad Pinch Gesture (MacBook, Windows Touchpad)
                    onPointerPanZoomUpdate: (event) {
                      final now = DateTime.now();
                      if (now.difference(_lastWheelStepTime).inMilliseconds > 220) {
                        if (event.scale > 1.2) {
                          _lastWheelStepTime = now;
                          _stepColumns(1, tiers);
                        } else if (event.scale < 0.8) {
                          _lastWheelStepTime = now;
                          _stepColumns(-1, tiers);
                        }
                      }
                    },
                    child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: () => _handleDoubleTap(tiers),
                    // Touchscreen two-finger pinch gesture
                    onScaleStart: (_isSlideMode || hasSelection)
                        ? null
                        : (details) {
                            _pinchAccumulatedScale = 1.0;
                          },
                    onScaleUpdate: (_isSlideMode || hasSelection)
                        ? null
                        : (details) {
                            if (details.pointerCount >= 2) {
                              _pinchAccumulatedScale = details.scale;
                              if (_pinchAccumulatedScale > 1.35) {
                                _stepColumns(1, tiers);
                                _pinchAccumulatedScale = 1.0;
                              } else if (_pinchAccumulatedScale < 0.72) {
                                _stepColumns(-1, tiers);
                                _pinchAccumulatedScale = 1.0;
                              }
                            }
                          },
                    // Slide-to-Select gestures (works on both Web mouse drag and Mobile touch drag)
                    onPanStart: (_isSlideMode || hasSelection)
                        ? (details) => _handleDragStart(
                              details.localPosition,
                              sortedSeats,
                              _columns,
                              width,
                              childAspectRatio,
                            )
                        : null,
                    onPanUpdate: (_isSlideMode || hasSelection)
                        ? (details) => _handleDragUpdate(
                              details.localPosition,
                              sortedSeats,
                              _columns,
                              width,
                              childAspectRatio,
                            )
                        : null,
                    onPanEnd: (_isSlideMode || hasSelection) ? (_) => _handleDragEnd() : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top Spatial Orientation Banner (Entrance & Front Reception)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.door_front_door_outlined, size: 14, color: Theme.of(context).colorScheme.primary),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        width < 420 ? 'Main Entrance' : 'Front Reception & Main Entrance',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.wifi_rounded, size: 13, color: Color(0xFF10B981)),
                                  const SizedBox(width: 4),
                                  Text(
                                    width < 420 ? 'Wi-Fi Zone' : 'High-Speed Wi-Fi Zone',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Interactive Desk Grid
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: GridView.builder(
                            key: ValueKey<int>(_columns),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _columns,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: childAspectRatio,
                            ),
                            itemCount: sortedSeats.length,
                            itemBuilder: (context, index) {
                              final seat = sortedSeats[index];
                              final isSelected = selectedSeats.containsKey(seat.id);
                              final student = seat.studentId != null ? studentMap[seat.studentId] : null;

                              bool isDimmed = false;
                              if (_activeFilter == 'available') {
                                isDimmed = seat.status != SeatStatus.available;
                              } else if (_activeFilter == 'occupied') {
                                isDimmed = seat.status != SeatStatus.occupied;
                              } else if (_activeFilter == 'boys') {
                                isDimmed = seat.genderRestriction != GenderRestriction.male;
                              } else if (_activeFilter == 'girls') {
                                isDimmed = seat.genderRestriction != GenderRestriction.female;
                              }

                              return RepaintBoundary(
                                key: ValueKey(seat.id),
                                child: SeatTile(
                                  seat: seat,
                                  isSelected: isSelected,
                                  isDimmed: isDimmed,
                                  columns: _columns,
                                  student: student,
                                  studentName: student?.name,
                                  shiftName: (student?.customFields['shift'] as String?) ??
                                      (student?.planId != null ? 'Active Plan' : null),
                                  sectionColor: widget.sectionColor != null ? Color(widget.sectionColor!) : null,
                                  onTap: () {
                                    if (_isSlideMode || selectedSeats.isNotEmpty) {
                                      ref
                                          .read(selectedSeatsProvider.notifier)
                                          .toggleSelection(seat.id, widget.sectionId);
                                    } else {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        builder: (context) => SeatDetailSheet(
                                          seat: seat,
                                          sectionId: widget.sectionId,
                                        ),
                                      );
                                    }
                                  },
                                  onLongPress: () {
                                    setState(() => _isSlideMode = true);
                                    ref
                                        .read(selectedSeatsProvider.notifier)
                                        .toggleSelection(seat.id, widget.sectionId);
                                  },
                                ),
                              );
                            },
                          ),
                        ),

                        // Bottom Spatial Orientation Banner (Silent Zone & Restrooms)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.volume_off_rounded, size: 14, color: Color(0xFF0D9488)),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        width < 420 ? 'Silent Zone' : 'Deep Silent Reading Zone',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.water_drop_outlined, size: 13, color: Color(0xFF3B82F6)),
                                  const SizedBox(width: 4),
                                  Text(
                                    width < 420 ? 'Washrooms' : 'Water & Restrooms ➔',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    AppErrorFormatter.toUserFriendly(err, actionContext: 'seat'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(
    String key,
    String label,
    int count,
    Color activeColor,
    IconData icon,
  ) {
    final isSelected = _activeFilter == key;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        setState(() {
          _activeFilter = isSelected ? 'all' : key;
        });
        HapticFeedback.selectionClick();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.18)
              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? activeColor : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 4),
            Text(
              '$label ($count)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color bgColor, Color borderColor, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor, width: 1.2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
