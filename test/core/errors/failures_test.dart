import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/errors/failures.dart';

void main() {
  group('Failure.fromException', () {
    test('returns the same failure if input is already a Failure', () {
      const failure = NetworkFailure('Test failure');
      expect(Failure.fromException(failure), equals(failure));
    });

    test('maps SocketException to NetworkFailure', () {
      final failure = Failure.fromException(
        const SocketException('Failed host lookup'),
      );
      expect(failure, isA<NetworkFailure>());
      expect(failure.message, contains('internet connection'));
    });

    test('maps TimeoutException to NetworkFailure', () {
      final failure = Failure.fromException(
        TimeoutException('Connection timed out'),
      );
      expect(failure, isA<NetworkFailure>());
      expect(failure.message, contains('internet connection'));
    });

    test('maps DioException connection error to NetworkFailure', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );
      final failure = Failure.fromException(dioException);
      expect(failure, isA<NetworkFailure>());
      expect(failure.message, contains('timed out'));
    });

    test('maps DioException 404 badResponse to ServerFailure', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 404,
        ),
      );
      final failure = Failure.fromException(dioException);
      expect(failure, isA<ServerFailure>());
      expect(failure.code, equals('404'));
      expect(failure.message, equals('Requested item not found.'));
    });

    test('maps DioException 429 badResponse to ServerFailure', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 429,
        ),
      );
      final failure = Failure.fromException(dioException);
      expect(failure, isA<ServerFailure>());
      expect(failure.code, equals('429'));
      expect(failure.message, contains('Too many requests'));
    });

    test('maps FirebaseException network-request-failed to NetworkFailure', () {
      final firebaseException = FirebaseException(
        plugin: 'firestore',
        code: 'network-request-failed',
      );
      final failure = Failure.fromException(firebaseException);
      expect(failure, isA<NetworkFailure>());
      expect(failure.code, equals('network-request-failed'));
    });

    test('maps FirebaseException permission-denied to AuthFailure', () {
      final firebaseException = FirebaseException(
        plugin: 'firestore',
        code: 'permission-denied',
      );
      final failure = Failure.fromException(firebaseException);
      expect(failure, isA<AuthFailure>());
      expect(failure.code, equals('permission-denied'));
    });

    test('maps FirebaseException invalid-credential to AuthFailure', () {
      final firebaseException = FirebaseException(
        plugin: 'firebase_auth',
        code: 'invalid-credential',
      );
      final failure = Failure.fromException(firebaseException);
      expect(failure, isA<AuthFailure>());
      expect(failure.message, contains('Invalid email or password'));
    });

    test('strips Exception prefix from generic exceptions', () {
      final failure = Failure.fromException(
        Exception('Something went wrong'),
      );
      expect(failure, isA<UnexpectedFailure>());
      expect(failure.message, equals('Something went wrong'));
    });
  });

  group('Result', () {
    test('Success holds data and returns null for failure', () {
      const result = Success<int>(42);
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.dataOrNull, equals(42));
      expect(result.failureOrNull, isNull);
    });

    test('FailureResult holds failure and returns null for data', () {
      const failure = UnexpectedFailure('Boom');
      const result = FailureResult<int>(failure);
      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.dataOrNull, isNull);
      expect(result.failureOrNull, equals(failure));
    });
  });
}
