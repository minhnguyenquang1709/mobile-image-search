import 'dart:developer';
import 'dart:io';

class Logger {
  final String name;
  bool muted = false;

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

  void mute(String name) {
    final logger = Logger(name);
    logger.muted = true;
  }

  void unmute(String name) {
    final logger = Logger(name);
    logger.muted = false;
  }

  void printLog(String msg) {
    if (!muted) log('[Logger] $msg');
    print('[$name] $msg');
  }
}

final Map<String, Logger> loggers = {
  'AppRepository': Logger('AppRepository'),
  'PhotoGalleryService': Logger('PhotoGalleryService'),
  'VectorStoreService': Logger('VectorStoreService'),
  'AiInferenceService': Logger('AiInferenceService'),
  'IndexingQueueService': Logger('IndexingQueueService'),
};
