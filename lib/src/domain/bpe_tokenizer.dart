import 'dart:convert';
import 'dart:io';
import 'package:mobile_image_search/src/core/constants/config_constant.dart';

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
    required String vocabExtractedPath,
    required String mergesExtractedPath,
  }) async {
    if (_isInitialized) return;

    try {
      // vocabulary
      final vocabFile = File(vocabExtractedPath);
      final mergesFile = File(mergesExtractedPath);
      // final vocabString = await rootBundle.loadString(
      //   '${Model.tokenizerDir}/vocab.json',
      // );
      final vocabString = await vocabFile.readAsString();
      final Map<String, dynamic> vocabMap = json.decode(vocabString);
      _vocab = vocabMap.map((key, value) => MapEntry(key, value as int));

      // BPE ranks
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

  List<int> tokenizeText(String text) {
    if (!_isInitialized) {
      throw Exception(
        "Tokenizer must be initialized before calling tokenize()",
      );
    }

    List<int> tokens = [];
    tokens.add(startTokenId);

    // preprocess
    final cleanText = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleanText.isEmpty) {
      return _padTokens(tokens);
    }

    final List<String> words = cleanText.split(' ');

    // process each word
    for (String word in words) {
      // extract sub-words using BPE
      final List<String> subWords = applyBPE(word);

      // get ID
      for (String subWord in subWords) {
        if (_vocab.containsKey(subWord)) {
          tokens.add(_vocab[subWord]!);
        } else {}
      }

      if (tokens.length >= contextLength - 1) break;
    }

    // truncate
    if (tokens.length > contextLength - 1) {
      tokens = tokens.sublist(0, contextLength - 1);
    }

    // add end token
    tokens.add(endTokenId);

    // padding
    return _padTokens(tokens);
  }

  /// check subword in vocabulary
  bool isInVocab(String subWord) => _vocab.containsKey(subWord);

  List<String> applyBPE(String word) {
    final String wordWithEnd = "$word</w>";

    List<String> chars = [];
    for (int i = 0; i < wordWithEnd.length; i++) {
      if (wordWithEnd.startsWith("</w>", i)) {
        chars[i - 1] = '${chars[i - 1]}</w>';
        i += 4; // skip </w>
      } else {
        chars.add(wordWithEnd[i]);
      }
    }

    // merge loop
    while (true) {
      if (chars.length < 2) break;

      int minRank = 999999;
      int bestIdxToMerge = -1;

      // find best pair to merge base on BPE ranks
      for (int i = 0; i < chars.length - 1; i++) {
        final String pair = "${chars[i]} ${chars[i + 1]}";

        if (_bpeRanks.containsKey(pair)) {
          final int rank = _bpeRanks[pair]!;
          if (rank < minRank) {
            minRank = rank;
            bestIdxToMerge = i;
          }
        }
      }

      // end when no more pairs to merge
      if (bestIdxToMerge == -1) break;

      // merge
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
