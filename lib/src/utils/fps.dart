import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class FpsOverlay extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    throw UnimplementedError();
  }
}

class _FpsOverlayState extends State<FpsOverlay> {
  int _frameCount = 0;
  int _fps = 0;
  late final Ticker _ticker;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _ticker = Ticker((_) {});
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }
}
