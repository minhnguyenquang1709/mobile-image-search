import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:mobile_image_search/config/config.dart';
import 'package:mobile_image_search/utils/logger.dart';

class BpeTokenizer {
  static final int contextLength = Model.specs.contextLength;
  static final int startTokenId = 49406;
  static final int endTokenId = 49407;
  static final int padTokenId = 0;

  late final Map<String, int> _vocab;
  late final Map<String, int> _bpeRanks;
  bool _isInitialized = false;

  final Logger debugLogger = loggers[LoggerName.Tokenizer]!;

  static final BpeTokenizer _instance = BpeTokenizer._internal();
  factory BpeTokenizer() => _instance;
  BpeTokenizer._internal();

  /// read file vocab.json and merges.txt
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. initialize Vocabulary
      final vocabFile = File('${Model.tokenizerDir}/vocab.json');
      final mergesFile = File('${Model.tokenizerDir}/merges.txt');
      final vocabString = await vocabFile.readAsString();
      final Map<String, dynamic> vocabMap = json.decode(vocabString);
      _vocab = vocabMap.map((key, value) => MapEntry(key, value as int));

      // 2. Khởi tạo BPE Ranks (Luật gộp từ)
      final mergesString = await mergesFile.readAsString();
      final lines = mergesString.split('\n');

      _bpeRanks = {};
      int rank = 0;
      for (String line in lines) {
        line = line.trim();
        // Bỏ qua dòng trống hoặc dòng comment
        if (line.isEmpty || line.startsWith('#')) continue;

        _bpeRanks[line] = rank;
        rank++;
      }

      _isInitialized = true;
      debugLogger.printLog(
        "✅ Tokenizer initialized: ${_vocab.length} vocab, ${_bpeRanks.length} merges.",
      );
    } catch (e) {
      debugLogger.printLog("❌ Failed to initialize Tokenizer: $e");
      rethrow;
    }
  }

  /// Hàm chính (Public API): Chuyển Text thành Mảng 77 số nguyên
  List<int> tokenize(String text) {
    if (!_isInitialized) {
      throw Exception(
        "Tokenizer must be initialized before calling tokenize()",
      );
    }

    List<int> tokens = [];
    tokens.add(startTokenId);

    // 1. Tiền xử lý (Clean text & Split)
    // Chuyển thành chữ thường và loại bỏ khoảng trắng thừa
    final cleanText = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleanText.isEmpty) {
      return _padTokens(tokens); // Trả về mảng rỗng nếu user không nhập gì
    }

    final List<String> words = cleanText.split(' ');

    // 2. Xử lý BPE cho từng từ
    for (String word in words) {
      // Trích xuất các sub-words bằng thuật toán BPE
      final List<String> subWords = _applyBPE(word);

      // Tra từ điển lấy ID
      for (String subWord in subWords) {
        if (_vocab.containsKey(subWord)) {
          tokens.add(_vocab!);
        } else {
          // Bỏ qua ký tự không có trong từ điển (rất hiếm khi xảy ra với BPE)
          debugLogger.printLog("Warning: Unknown subword '$subWord'");
        }
      }

      // Ngắt sớm nếu đã chạm ngưỡng giới hạn (chừa 1 chỗ cho endToken)
      if (tokens.length >= contextLength - 1) break;
    }

    // 3. Cắt bớt nếu quá dài (Truncate)
    if (tokens.length > contextLength - 1) {
      tokens = tokens.sublist(0, contextLength - 1);
    }

    // 4. Thêm End Token
    tokens.add(endTokenId);

    // 5. Thêm Padding (Bù số 0)
    return _padTokens(tokens);
  }

  /// Thuật toán BPE Cốt lõi (Private)
  List<String> _applyBPE(String word) {
    // OpenCLIP luôn thêm </w> vào cuối mỗi từ để đánh dấu
    final String wordWithEnd = "$word</w>";

    // Tách từ thành các ký tự rời rạc (Ví dụ: "cat</w>" -> "c", "a", "t", "</w>")
    List<String> chars = [];
    for (int i = 0; i < wordWithEnd.length; i++) {
      if (wordWithEnd.startsWith("</w>", i)) {
        chars.add("</w>");
        i += 3; // Bỏ qua 3 ký tự tiếp theo
      } else {
        chars.add(wordWithEnd);
      }
    }

    // Vòng lặp gộp từ
    while (true) {
      if (chars.length < 2) break;

      int minRank = 999999; // Giả lập vô cùng
      int bestIdxToMerge = -1;
      String bestPair = "";

      // Tìm cặp ký tự liền kề có Rank ưu tiên cao nhất (số nhỏ nhất)
      for (int i = 0; i < chars.length - 1; i++) {
        final String pair = "${chars} ${chars}";

        if (_bpeRanks.containsKey(pair)) {
          final int rank = _bpeRanks!;
          if (rank < minRank) {
            minRank = rank;
            bestIdxToMerge = i;
            bestPair = pair;
          }
        }
      }

      // Nếu không tìm thấy cặp nào trong merges.txt nữa -> Thuật toán kết thúc
      if (bestIdxToMerge == -1) break;

      // Thực hiện Gộp (Merge)
      final List<String> newChars = [];
      for (int i = 0; i < chars.length; i++) {
        if (i == bestIdxToMerge) {
          // Gộp 2 phần tử lại (bỏ dấu cách ở giữa)
          newChars.add(chars + chars);
          i++; // Nhảy cóc qua phần tử tiếp theo vì đã bị gộp
        } else {
          newChars.add(chars);
        }
      }
      chars = newChars;
    }

    return chars;
  }

  /// Hàm phụ trợ thêm số 0 cho đủ chiều dài mảng
  List<int> _padTokens(List<int> tokens) {
    while (tokens.length < contextLength) {
      tokens.add(padTokenId);
    }
    return tokens;
  }
}
