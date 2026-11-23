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

  Future<List<Vocabulary>> getWords(int setId) async {
    final data = _decode(await _client.get(_uri('/sets/$setId/words')));
    return (data['words'] as List<dynamic>)
        .map((item) => Vocabulary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> addWord(int setId, String prompt, String answer) async {
    await _post('/sets/$setId/words', {'prompt': prompt, 'answer': answer});
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

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

  final int id;
  final String name;
  final int wordCount;

  factory VocabularySet.fromJson(Map<String, dynamic> json) => VocabularySet(
        id: json['id'] as int,
        name: json['name'] as String,
        wordCount: json['wordCount'] as int,
      );
}

class Vocabulary {
  const Vocabulary({required this.id, required this.prompt, required this.answer});

  final int id;
  final String prompt;
  final String answer;

  factory Vocabulary.fromJson(Map<String, dynamic> json) => Vocabulary(
        id: json['id'] as int,
        prompt: json['prompt'] as String,
        answer: json['answer'] as String,
      );
}
