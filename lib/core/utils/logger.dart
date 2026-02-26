import 'dart:developer';

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

enum LoggerName {
  AppRepository,
  PhotoGalleryService,
  StoreService,
  AiInferenceService,
  IndexingQueueService,
  Tokenizer,
  GalleryRepository,
  GalleryDataSource,
  IndexingRepository,
}

final Map<LoggerName, Logger> loggers = {
  // application layer
  LoggerName.PhotoGalleryService: Logger('PhotoGalleryService'),
  LoggerName.StoreService: Logger('StoreService'),
  LoggerName.AiInferenceService: Logger('AiInferenceService'),
  LoggerName.IndexingQueueService: Logger('IndexingQueueService'),

  LoggerName.Tokenizer: Logger('Tokenizer'),

  // data layer
  LoggerName.GalleryRepository: Logger('GalleryRepository'),
  LoggerName.GalleryDataSource: Logger('GalleryDataSource'),
  LoggerName.IndexingRepository: Logger('IndexingRepository'),
};
