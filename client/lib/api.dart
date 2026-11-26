import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );

  final http.Client _client;

  Future<Map<String, dynamic>?> currentUser() async {
    final response = await _client.get(_uri('/auth/me'));
    if (response.statusCode == 401) return null;
    return _decode(response);
  }

  Future<Map<String, dynamic>> login(String username, String password) =>
      _post('/auth/login', {'username': username, 'password': password});

  Future<void> logout() async {
    await _post('/auth/logout', const {});
  }

  Future<List<VocabularySet>> getSets() async {
    final data = _decode(await _client.get(_uri('/sets')));
    return (data['sets'] as List<dynamic>)
        .map((item) => VocabularySet.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<VocabularySet> createSet(String name) async => VocabularySet.fromJson(
        await _post('/sets', {'name': name}),
      );

  Future<void> renameSet(String setId, String name) async {
    final response = await _client.put(
      _uri('/sets/$setId'),
      headers: const {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({'name': name}),
    );
    _decode(response);
  }

  Future<List<Vocabulary>> getWords(String setId) async {
    final data = _decode(await _client.get(_uri('/sets/$setId/words')));
    return (data['words'] as List<dynamic>)
        .map((item) => Vocabulary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> addWord(String setId, String prompt, String answer) async {
    await _post('/sets/$setId/words', {'prompt': prompt, 'answer': answer});
  }

  Future<StudySession> getStudySession(String setId, String direction) async {
    final uri = _uri('/sets/$setId/study', queryParameters: {
      'method': 'fsrs',
      'direction': direction,
    });
    final data = _decode(await _client.get(uri));
    return StudySession.fromJson(data);
  }

  Future<int> reviewStudyCard(String setId, String vocabularyId, String direction, int rating) async {
    final data = await _post('/sets/$setId/study/reviews', {
      'method': 'fsrs',
      'direction': direction,
      'vocabularyId': vocabularyId,
      'rating': rating,
    });
    return data['intervalDays'] as int;
  }

  Future<LearningStatistics> getLearningStatistics(String setId, String direction) async {
    final uri = _uri('/sets/$setId/statistics', queryParameters: {
      'method': 'fsrs',
      'direction': direction,
    });
    return LearningStatistics.fromJson(_decode(await _client.get(uri)));
  }

  Future<ImportResult> importWords(String setId, List<ImportRow> rows) async {
    final data = await _post('/sets/$setId/imports', {
      'rows': rows.map((row) => {'prompt': row.prompt, 'answer': row.answer}).toList(),
    });
    return ImportResult(
      created: data['created'] as int,
      skippedDuplicates: data['skippedDuplicates'] as int,
    );
  }

  Uri _uri(String path, {Map<String, String>? queryParameters}) {
    final base = Uri.parse(_baseUrl);
    if (base.path.endsWith('.php')) {
      return base.replace(queryParameters: {
        ...base.queryParameters,
        'route': path,
        ...?queryParameters,
      });
    }
    final uri = Uri.parse('$_baseUrl$path');
    if (queryParameters == null) return uri;
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...queryParameters,
    });
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, Object?> body) async {
    final response = await _client.post(
      _uri(path),
      headers: const {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(data['error'] as String? ?? 'The request failed.', statusCode: response.statusCode);
    }
    return data;
  }
}

class VocabularySet {
  const VocabularySet({required this.id, required this.name, required this.wordCount});

  final String id;
  final String name;
  final int wordCount;

  factory VocabularySet.fromJson(Map<String, dynamic> json) => VocabularySet(
        id: json['id'] as String,
        name: json['name'] as String,
        wordCount: json['wordCount'] as int,
      );
}

class Vocabulary {
  const Vocabulary({required this.id, required this.prompt, required this.answer});

  final String id;
  final String prompt;
  final String answer;

  factory Vocabulary.fromJson(Map<String, dynamic> json) => Vocabulary(
        id: json['id'] as String,
        prompt: json['prompt'] as String,
        answer: json['answer'] as String,
      );
}

class StudySession {
  const StudySession({required this.cards, required this.stats});

  final List<StudyCard> cards;
  final StudyStats stats;

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
        cards: (json['cards'] as List<dynamic>)
            .map((item) => StudyCard.fromJson(item as Map<String, dynamic>))
            .toList(),
        stats: StudyStats.fromJson(json['stats'] as Map<String, dynamic>),
      );
}

class StudyCard {
  const StudyCard({required this.id, required this.front, required this.back});

  final String id;
  final String front;
  final String back;

  factory StudyCard.fromJson(Map<String, dynamic> json) => StudyCard(
        id: json['id'] as String,
        front: json['front'] as String,
        back: json['back'] as String,
      );
}

class StudyStats {
  const StudyStats({required this.total, required this.newCount, required this.dueCount, required this.reviewedCount, required this.repetitions, required this.lapses});

  final int total;
  final int newCount;
  final int dueCount;
  final int reviewedCount;
  final int repetitions;
  final int lapses;

  factory StudyStats.fromJson(Map<String, dynamic> json) => StudyStats(
        total: json['total'] as int,
        newCount: json['new_count'] as int,
        dueCount: json['due_count'] as int,
        reviewedCount: json['reviewed_count'] as int,
        repetitions: json['repetitions'] as int,
        lapses: json['lapses'] as int,
      );
}

class LearningStatistics {
  const LearningStatistics({required this.progress, required this.reviews, required this.dailyActivity});

  final LearningProgressStats progress;
  final ReviewStatistics reviews;
  final List<DailyReviewActivity> dailyActivity;

  factory LearningStatistics.fromJson(Map<String, dynamic> json) => LearningStatistics(
        progress: LearningProgressStats.fromJson(json['progress'] as Map<String, dynamic>),
        reviews: ReviewStatistics.fromJson(json['reviews'] as Map<String, dynamic>),
        dailyActivity: (json['dailyActivity'] as List<dynamic>)
            .map((item) => DailyReviewActivity.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}

class LearningProgressStats {
  const LearningProgressStats({required this.total, required this.newCount, required this.dueCount, required this.reviewedCount, required this.repetitions, required this.lapses});

  final int total;
  final int newCount;
  final int dueCount;
  final int reviewedCount;
  final int repetitions;
  final int lapses;

  factory LearningProgressStats.fromJson(Map<String, dynamic> json) => LearningProgressStats(
        total: json['total'] as int,
        newCount: json['new_count'] as int,
        dueCount: json['due_count'] as int,
        reviewedCount: json['reviewed_count'] as int,
        repetitions: json['repetitions'] as int,
        lapses: json['lapses'] as int,
      );
}

class ReviewStatistics {
  const ReviewStatistics({required this.total, required this.againCount, required this.hardCount, required this.goodCount, required this.easyCount, required this.firstReviewAt, required this.lastReviewAt});

  final int total;
  final int againCount;
  final int hardCount;
  final int goodCount;
  final int easyCount;
  final String? firstReviewAt;
  final String? lastReviewAt;

  factory ReviewStatistics.fromJson(Map<String, dynamic> json) => ReviewStatistics(
        total: json['total'] as int,
        againCount: json['again_count'] as int,
        hardCount: json['hard_count'] as int,
        goodCount: json['good_count'] as int,
        easyCount: json['easy_count'] as int,
        firstReviewAt: json['first_review_at'] as String?,
        lastReviewAt: json['last_review_at'] as String?,
      );
}

class DailyReviewActivity {
  const DailyReviewActivity({required this.day, required this.reviews, required this.againCount});

  final String day;
  final int reviews;
  final int againCount;

  factory DailyReviewActivity.fromJson(Map<String, dynamic> json) => DailyReviewActivity(
        day: json['day'] as String,
        reviews: json['reviews'] as int,
        againCount: json['againCount'] as int,
      );
}

class ImportRow {
  const ImportRow({required this.prompt, required this.answer});

  final String prompt;
  final String answer;
}

class ImportResult {
  const ImportResult({required this.created, required this.skippedDuplicates});

  final int created;
  final int skippedDuplicates;
}
