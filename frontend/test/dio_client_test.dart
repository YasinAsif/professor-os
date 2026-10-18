import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/core/network/api_constants.dart';
import 'package:professor_os/core/network/dio_client.dart';

void main() {
  test('refresh policy retries an ordinary unauthorized request once', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/courses'),
      response: Response(
        requestOptions: RequestOptions(path: '/courses'),
        statusCode: 401,
      ),
    );

    expect(shouldAttemptTokenRefresh(error), isTrue);
  });

  test('refresh policy does not recurse on a retried or refresh request', () {
    final retried = DioException(
      requestOptions: RequestOptions(
        path: '/courses',
        extra: {'auth_retry': true},
      ),
      response: Response(
        requestOptions: RequestOptions(path: '/courses'),
        statusCode: 401,
      ),
    );
    final refresh = DioException(
      requestOptions: RequestOptions(path: ApiConstants.refresh),
      response: Response(
        requestOptions: RequestOptions(path: ApiConstants.refresh),
        statusCode: 401,
      ),
    );

    expect(shouldAttemptTokenRefresh(retried), isFalse);
    expect(shouldAttemptTokenRefresh(refresh), isFalse);
  });
}
