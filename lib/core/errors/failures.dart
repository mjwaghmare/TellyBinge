import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_core/firebase_core.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  List<Object?> get props => [message, code];

  @override
  String toString() => message;

  /// Utility to convert any caught exception or error into a clean domain Failure.
  factory Failure.fromException(Object exception) {
    if (exception is Failure) {
      return exception;
    }

    if (exception is SocketException || exception is TimeoutException) {
      return const NetworkFailure(
        'Unable to connect. Please check your internet connection and try again.',
      );
    }

    if (exception is DioException) {
      switch (exception.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return const NetworkFailure(
            'Connection timed out. Please check your network and try again.',
          );
        case DioExceptionType.badResponse:
          final statusCode = exception.response?.statusCode;
          if (statusCode == 404) {
            return const ServerFailure(
              'Requested item not found.',
              code: '404',
            );
          }
          if (statusCode == 429) {
            return const ServerFailure(
              'Too many requests. Please wait a moment and try again.',
              code: '429',
            );
          }
          return ServerFailure(
            'Server responded with error (${statusCode ?? 'unknown'}).',
            code: statusCode?.toString(),
          );
        case DioExceptionType.cancel:
          return const UnexpectedFailure('Request was cancelled.');
        default:
          return UnexpectedFailure(
            exception.message ?? 'An unexpected network error occurred.',
          );
      }
    }

    if (exception is FirebaseException) {
      final code = exception.code;
      if (code == 'network-request-failed' || code == 'unavailable') {
        return NetworkFailure(
          'Network connection error. Please check your internet and try again.',
          code: code,
        );
      }
      if (code == 'permission-denied') {
        return AuthFailure(
          'You do not have permission to perform this action.',
          code: code,
        );
      }
      if (code == 'user-not-found' ||
          code == 'wrong-password' ||
          code == 'invalid-credential') {
        return AuthFailure(
          'Invalid email or password. Please try again.',
          code: code,
        );
      }
      if (code == 'user-disabled') {
        return AuthFailure('This account has been disabled.', code: code);
      }
      return UnexpectedFailure(
        exception.message ?? 'A database error occurred. Please try again.',
        code: code,
      );
    }

    final errString = exception.toString();
    if (errString.contains('network') ||
        errString.contains('SocketException') ||
        errString.contains('Failed host lookup')) {
      return const NetworkFailure(
        'No internet connection. Please verify your connection.',
      );
    }

    return UnexpectedFailure(
      errString.replaceFirst(RegExp(r'^(?:[A-Za-z]*Exception|Error):\s*'), ''),
    );
  }
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.code});
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code});
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code});
}

class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.code});
}

class WriteFailure extends Failure {
  const WriteFailure(super.message, {super.code});
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message, {super.code});
}

/// Generic typed Result object representing either a Success or a Failure.
sealed class Result<T> extends Equatable {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is FailureResult<T>;

  T? get dataOrNull => switch (this) {
    Success(:final data) => data,
    _ => null,
  };

  Failure? get failureOrNull => switch (this) {
    FailureResult(:final failure) => failure,
    _ => null,
  };

  static Result<T> success<T>(T data) => Success<T>(data);
  static Result<T> failure<T>(Failure failure) => FailureResult<T>(failure);
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);

  @override
  List<Object?> get props => [data];
}

class FailureResult<T> extends Result<T> {
  final Failure failure;
  const FailureResult(this.failure);

  @override
  List<Object?> get props => [failure];
}
