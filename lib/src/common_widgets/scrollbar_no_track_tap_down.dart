import 'package:flutter/widgets.dart';

class InteractiveThumbScrollbar extends RawScrollbar {
  const InteractiveThumbScrollbar({
    super.key,
    required super.child,
    super.controller,
    super.thumbVisibility,
    super.shape,
    super.radius,
    super.thickness,
    super.thumbColor,
    super.minThumbLength,
    super.minOverscrollLength,
    super.trackVisibility,
    super.trackRadius,
    super.trackColor,
    super.trackBorderColor,
    super.fadeDuration,
    super.timeToFade,
    super.pressDuration = Duration.zero,
    super.notificationPredicate,
    super.interactive,
    super.scrollbarOrientation,
    super.mainAxisMargin = 0.0,
    super.crossAxisMargin = 0.0,
    super.padding,
  });

  @override
  RawScrollbarState<RawScrollbar> createState() =>
      _InteractiveThumbScrollbarState();
}

class _InteractiveThumbScrollbarState
    extends RawScrollbarState<InteractiveThumbScrollbar> {
  @override
  // ignore: must_call_super
  void handleTrackTapDown(TapDownDetails details) {
    return;
  }
}
