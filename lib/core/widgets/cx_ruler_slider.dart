import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';

/// A premium, highly tactile horizontal ruler slider.
///
/// Users can slide left/right to adjust values (e.g. height or weight).
/// Tick marks scroll smoothly and snap to the nearest unit, firing a haptic
/// selection tick on every increment.
class CxRulerSlider extends StatefulWidget {
  const CxRulerSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    this.step = 1.0,
    this.majorInterval = 10,
    this.minorInterval = 1,
    this.unitLabel = '',
  })  : assert(min < max),
        assert(value >= min && value <= max);

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final double step;
  final int majorInterval;
  final int minorInterval;
  final String unitLabel;

  @override
  State<CxRulerSlider> createState() => _RqRulerSliderState();
}

class _RqRulerSliderState extends State<CxRulerSlider> {
  late ScrollController _scrollController;
  final double _itemWidth = 10.0; // Width of each tick mark interval
  bool _isUserScrolling = false;
  int _lastHapticValue = -1;

  @override
  void initState() {
    super.initState();
    final initialOffset = (widget.value - widget.min) / widget.step * _itemWidth;
    _scrollController = ScrollController(initialScrollOffset: initialOffset);
  }

  @override
  void didUpdateWidget(covariant CxRulerSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the value was changed externally (and not by user scroll), animate to it
    if (!_isUserScrolling && oldWidget.value != widget.value) {
      final targetOffset = (widget.value - widget.min) / widget.step * _itemWidth;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(targetOffset);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _isUserScrolling = true;
    } else if (notification is ScrollUpdateNotification) {
      final offset = _scrollController.offset;
      final rawValue = widget.min + (offset / _itemWidth) * widget.step;
      final clampedValue = rawValue.clamp(widget.min, widget.max);

      // Round to nearest step
      final stepsCount = ((clampedValue - widget.min) / widget.step).round();
      final steppedValue = widget.min + stepsCount * widget.step;

      if (steppedValue != widget.value) {
        // Fire haptic feedback on every tick change
        final hapticKey = steppedValue.round();
        if (hapticKey != _lastHapticValue) {
          HapticFeedback.selectionClick();
          _lastHapticValue = hapticKey;
        }
        widget.onChanged(steppedValue);
      }
    } else if (notification is ScrollEndNotification) {
      _isUserScrolling = false;
      _snapToNearest();
    }
  }

  void _snapToNearest() {
    final offset = _scrollController.offset;
    final stepsCount = (offset / _itemWidth).round();
    final targetOffset = stepsCount * _itemWidth;

    Future.delayed(Duration.zero, () {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final totalSteps = ((widget.max - widget.min) / widget.step).round() + 1;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _onScrollNotification(notification);
        return true;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sidePadding = constraints.maxWidth / 2;

          return SizedBox(
            height: 110,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // 1. The Scrollable Ruler Scale
                ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: sidePadding),
                  itemCount: totalSteps,
                  itemBuilder: (context, index) {
                    final currentValue = widget.min + index * widget.step;
                    final isMajor = index % widget.majorInterval == 0;
                    final isMinor = index % widget.minorInterval == 0;

                    if (!isMajor && !isMinor) {
                      return SizedBox(width: _itemWidth);
                    }

                    return SizedBox(
                      width: _itemWidth,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          // Tick Mark Line
                          Container(
                            width: isMajor ? 2.2 : 1.2,
                            height: isMajor ? 32 : 18,
                            decoration: BoxDecoration(
                              color: isMajor
                                  ? c.textPrimary.withOpacity(0.7)
                                  : c.textTertiary.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Major Tick Labels
                          if (isMajor)
                            Text(
                              currentValue.toStringAsFixed(0),
                              style: CxType.caption.copyWith(
                                color: c.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),

                // 2. Center Pointer Indicator (Ember)
                IgnorePointer(
                  child: Container(
                    width: 3,
                    height: 50,
                    decoration: BoxDecoration(
                      color: c.ember,
                      borderRadius: BorderRadius.circular(1.5),
                      boxShadow: [
                        BoxShadow(
                          color: c.ember.withOpacity(0.4),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
