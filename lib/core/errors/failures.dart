import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

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
            return const ServerFailure('Requested item not found.', code: '404');
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

    final errString = exception.toString();
    if (errString.contains('network') ||
        errString.contains('SocketException') ||
        errString.contains('Failed host lookup')) {
      return const NetworkFailure(
        'No internet connection. Please verify your connection.',
      );
    }

    return UnexpectedFailure(
      errString.replaceFirst(RegExp(r'^[A-Za-z]+Exception:\s*'), ''),
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

class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message, {super.code});
}
