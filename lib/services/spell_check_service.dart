import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:spell_check_on_client/spell_check_on_client.dart';

/// A custom [SpellCheckService] that uses local word-list dictionaries
/// (French, English) loaded from app assets.
///
/// Activated in every text field via:
/// ```dart
/// spellCheckConfiguration: SpellCheckConfiguration(
///   spellCheckService: AppSpellCheckService(),
/// ),
/// ```
class AppSpellCheckService extends SpellCheckService {
  static final AppSpellCheckService _instance =
      AppSpellCheckService._internal();

  factory AppSpellCheckService() => _instance;

  AppSpellCheckService._internal();

  final Map<String, SpellCheck> _checkers = {};
  bool _initialized = false;
  bool _initializing = false;

  /// Call once at startup (in [main]) to load dictionaries in the background.
  Future<void> init() async {
    if (_initialized || _initializing) return;
    _initializing = true;

    try {
      // Folder name uses double 'n' — matches the actual asset directory.
      const base = 'assets/spell_check_dictionnary';

      final frContent = await rootBundle.loadString('$base/fr_words.txt');
      _checkers['fr'] = SpellCheck.fromWordsContent(
        frContent,
        letters: 'abcdefghijklmnopqrstuvwxyzàâæçéèêëîïôœùûüÿ'.split(''),
      );

      final enContent = await rootBundle.loadString('$base/en_words.txt');
      _checkers['en'] = SpellCheck.fromWordsContent(
        enContent,
        letters: 'abcdefghijklmnopqrstuvwxyz'.split(''),
      );

      // Arabic dictionary is 96 MB — skipped to avoid OOM.
      // Uncomment only on high-memory desktop targets:
      // final arContent = await rootBundle.loadString('$base/ar_words.txt');
      // _checkers['ar'] = SpellCheck.fromWordsContent(
      //   arContent,
      //   letters: 'ابتةثجحخدذرزسشصضطظعغفقكلمنهويأإآؤئء'.split(''),
      // );

      _initialized = true;
      debugPrint('SpellCheck: loaded fr + en dictionaries');
    } catch (e) {
      debugPrint('SpellCheck: init error – $e');
    } finally {
      _initializing = false;
    }
  }

  // ── SpellCheckService interface ──────────────────────────────────────────

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) async {
    if (!_initialized) return null;

    // Pick by locale; fall back to French then English.
    final checker =
        _checkers[locale.languageCode] ?? _checkers['fr'] ?? _checkers['en'];
    if (checker == null) return null;

    final spans = <SuggestionSpan>[];

    // Match Latin words (≥ 3 chars) only.
    final wordRegex = RegExp(r'\b[a-zA-Zàâæçéèêëîïôœùûüÿ]{3,}\b');

    for (final match in wordRegex.allMatches(text)) {
      final word = match.group(0)!.toLowerCase();

      if (!checker.isCorrect(word)) {
        final suggestions = checker.didYouMeanAny(word, maxWords: 5);
        spans.add(
          SuggestionSpan(
            TextRange(start: match.start, end: match.end),
            suggestions,
          ),
        );
      }
    }

    return spans;
  }
}
