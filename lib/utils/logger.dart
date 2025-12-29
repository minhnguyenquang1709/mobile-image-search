import 'dart:developer';
import 'dart:io';

class Logger {
  final String name;
  bool mute = false;

  // _cache is library-private, thanks to
  // the _ in front of its name.
  static final Map<String, Logger> _cache = <String, Logger>{};

  factory Logger(String name) {
    final logger = _cache.putIfAbsent(name, () => Logger._internal(name));
    return logger;
  }

  factory Logger.fromJson(Map<String, Object> json) {
    return Logger(json['name'].toString());
  }

  Logger._internal(this.name);

  void muteLogger(String name) {
    final logger = Logger(name);
    logger.mute = true;
  }

  void unmuteLogger(String name) {
    final logger = Logger(name);
    logger.mute = false;
  }

  void printLog(String msg) {
    if (!mute) log('[Logger] $msg');
    print('[$name] $msg');
  }
}

final debugLogger = Logger('DebugLogger');
