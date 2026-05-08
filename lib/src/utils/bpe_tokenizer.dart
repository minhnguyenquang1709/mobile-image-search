import 'dart:convert';
import 'dart:io';
import 'package:mobile_image_search/src/constants/config_constant.dart';

class BpeTokenizer {
  static final int contextLength = Model.specs.contextLength;
  static final int startTokenId = 49406;
  static final int endTokenId = 49407;
  static final int padTokenId = 0;

  late final Map<String, int> _vocab;
  late final Map<String, int> _bpeRanks;
  bool _isInitialized = false;

  static final BpeTokenizer _instance = BpeTokenizer._internal();
  factory BpeTokenizer() => _instance;
  BpeTokenizer._internal();

  /// read file vocab.json and merges.txt
  Future<void> init({
    String? vocabExtractedPath,
    String? mergesExtractedPath,
  }) async {
    if (_isInitialized) return;

    try {
      // 1. initialize Vocabulary
      final vocabFile = File(
        vocabExtractedPath ?? '${Model.tokenizerDir}/vocab.json',
      );
      final mergesFile = File(
        mergesExtractedPath ?? '${Model.tokenizerDir}/merges.txt',
      );
      // final vocabString = await rootBundle.loadString(
      //   '${Model.tokenizerDir}/vocab.json',
      // );
      final vocabString = await vocabFile.readAsString();
      final Map<String, dynamic> vocabMap = json.decode(vocabString);
      _vocab = vocabMap.map((key, value) => MapEntry(key, value as int));

      // 2. initialize BPE Ranks
      // final mergesString = await rootBundle.loadString(
      //   '${Model.tokenizerDir}/merges.txt',
      // );
      final mergesString = await mergesFile.readAsString();
      final lines = mergesString.split('\n');

      _bpeRanks = {};
      int rank = 0;
      for (String line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('#')) continue;

        _bpeRanks[line] = rank;
        rank++;
      }

      _isInitialized = true;

      for (int i = 0; i < 5; i++) {}
    } catch (e) {
      rethrow;
    }
  }

  List<int> tokenize(String text) {
    if (!_isInitialized) {
      throw Exception(
        "Tokenizer must be initialized before calling tokenize()",
      );
    }

    List<int> tokens = [];
    tokens.add(startTokenId);

    // 1. preprocess
    final cleanText = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleanText.isEmpty) {
      return _padTokens(tokens);
    }

    final List<String> words = cleanText.split(' ');

    // 2. process each word
    for (String word in words) {
      // extract sub-words using BPE
      final List<String> subWords = _applyBPE(word);

      // get ID
      for (String subWord in subWords) {
        if (_vocab.containsKey(subWord)) {
          tokens.add(_vocab[subWord]!);
        } else {}
      }

      if (tokens.length >= contextLength - 1) break;
    }

    // 3. Truncate
    if (tokens.length > contextLength - 1) {
      tokens = tokens.sublist(0, contextLength - 1);
    }

    // 4. End Token
    tokens.add(endTokenId);

    // 5. Padding
    return _padTokens(tokens);
  }

  /// BPE algo implementation
  List<String> _applyBPE(String word) {
    final String wordWithEnd = "$word</w>";

    List<String> chars = [];
    // separate into array of chars, with ${lastChar}</w> as single character
    for (int i = 0; i < wordWithEnd.length; i++) {
      if (wordWithEnd.startsWith("</w>", i)) {
        // chars.add("</w>");
        chars[i - 1] = '${chars[i - 1]}</w>';
        i += 4; // skip </w>. example: "dog" -> ["d", "o", "g</w>"]
      } else {
        chars.add(wordWithEnd[i]);
      }
    }

    // merge loop
    while (true) {
      if (chars.length < 2) break; // stop condition

      int minRank = 999999;
      int bestIdxToMerge = -1;
      String bestPair = "";

      // find best pair to merge base on BPE ranks
      for (int i = 0; i < chars.length - 1; i++) {
        final String pair = "${chars[i]} ${chars[i + 1]}";

        if (_bpeRanks.containsKey(pair)) {
          final int rank = _bpeRanks[pair]!;
          if (rank < minRank) {
            minRank = rank;
            bestIdxToMerge = i;
            bestPair = pair;
          }
        }
      }

      // end when no more pairs to merge
      if (bestIdxToMerge == -1) break;

      // Merge
      final List<String> newChars = [];
      for (int i = 0; i < chars.length; i++) {
        if (i == bestIdxToMerge) {
          newChars.add(chars[i] + chars[i + 1]);
          i++;
        } else {
          newChars.add(chars[i]);
        }
      }
      chars = newChars;
    }

    return chars;
  }

  List<int> _padTokens(List<int> tokens) {
    while (tokens.length < contextLength) {
      tokens.add(padTokenId);
    }
    return tokens;
  }

  String decode(List<int> tokenIds) {
    if (!_isInitialized) {
      return "<error>";
    }
    String result = "";
    for (int id in tokenIds) {
      if (_vocab.containsValue(id)) {
        String token = _vocab.keys.firstWhere((k) => _vocab[k] == id);
        result += token;
      } else {}
    }

    return result;
  }
}
