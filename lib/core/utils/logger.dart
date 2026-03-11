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

class LoggerName {
  static const String appRepository = "AppRepository";
  static const String photoGalleryService = "PhotoGalleryService";
  static const String storeService = "StoreService";
  static const String aiInferenceService = "AiInferenceService";
  static const String indexingQueueService = "IndexingQueueService";
  static const String tokenizer = "Tokenizer";
  static const String galleryRepository = "GalleryRepository";
  static const String galleryDataSource = "GalleryDataSource";
  static const String indexingRepository = "IndexingRepository";
  static const String galleryController = "GalleryController";
}

final Map<String, Logger> loggers = {
  // Application layer
  LoggerName.photoGalleryService: Logger(LoggerName.photoGalleryService),
  LoggerName.storeService: Logger(LoggerName.storeService),
  LoggerName.aiInferenceService: Logger(LoggerName.aiInferenceService),
  LoggerName.indexingQueueService: Logger(LoggerName.indexingQueueService),

  LoggerName.tokenizer: Logger(LoggerName.tokenizer),

  // Data layer
  LoggerName.galleryRepository: Logger(LoggerName.galleryRepository),
  LoggerName.galleryDataSource: Logger(LoggerName.galleryDataSource),
  LoggerName.indexingRepository: Logger(LoggerName.indexingRepository),

  // Presentation layer
  LoggerName.galleryController: Logger(LoggerName.galleryController),
};
