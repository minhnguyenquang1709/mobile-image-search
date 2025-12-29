import 'dart:developer';

class Logger {
  final String name;
  bool mute = false;

  // _cache is library-private, thanks to
  // the _ in front of its name.
  static final Map<String, Logger> _cache = <String, Logger>{};

  void muteLogger(String name) {
    final logger = Logger(name);
    logger.mute = true;
  }

  void unmuteLogger(String name) {
    final logger = Logger(name);
    logger.mute = false;
  }

  factory Logger(String name) {
    return _cache.putIfAbsent(name, () => Logger._internal(name));
  }

  factory Logger.fromJson(Map<String, Object> json) {
    return Logger(json['name'].toString());
  }

  Logger._internal(this.name);

  void printLog(String msg) {
    if (!mute) log(msg);
  }
}

final debugLogger = Logger('debug');
