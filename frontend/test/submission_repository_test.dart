import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/features/courses/data/course_repository.dart';

class _MockHttpClientAdapter implements HttpClientAdapter {
  final Map<String, dynamic> Function(RequestOptions options) handler;

  _MockHttpClientAdapter(this.handler);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final response = handler(options);
    return ResponseBody.fromString(
      jsonEncode(response['data'] ?? {}),
      response['statusCode'] ?? 200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }
}

void main() {
  test('file submission carries the server-side auto-submit flag', () async {
    final dio = Dio()
      ..httpClientAdapter = _MockHttpClientAdapter((options) {
        expect(options.data, isA<FormData>());
        final form = options.data as FormData;
        expect(
          form.fields.any((field) =>
              field.key == 'auto_submitted' && field.value == 'true'),
          isTrue,
        );
        expect(form.files.single.key, 'file');
        return {'data': {'id': 1}};
      });

    final result = await CourseRepository(dio: dio).submitFile(
      4,
      9,
      [1, 2, 3],
      'answer.pdf',
      autoSubmitted: true,
    );

    expect(result['id'], 1);
  });
}
