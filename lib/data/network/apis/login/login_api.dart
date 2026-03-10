import 'dart:async';
import 'package:boilerplate/core/data/network/dio/dio_client.dart';
import 'package:boilerplate/data/network/constants/endpoints.dart';
import 'package:boilerplate/domain/entity/user/user.dart';
import 'package:dio/dio.dart';

/// User-friendly message when server is unreachable or returns unexpected data
/// (e.g. wrong base URL, 404, or non-JSON response).
const String _kServerConnectionError =
    'Could not connect to the server. Please check the server URL in Server Setup and try again.';

class LoginApi {
  final DioClient _dioClient;

  LoginApi(this._dioClient);

  Future<User> login(String email, String password) async {
    try {
      final res = await _dioClient.dio.post(
        Endpoints.login,
        data: {'email': email, 'password': password},
      );
      if (res.data is! Map<String, dynamic>) {
        throw Exception(_kServerConnectionError);
      }
      final data = res.data as Map<String, dynamic>;
      if (data['isSuccess'] == true) {
        return User.fromJson(data);
      } else {
        throw Exception(data['message'] ?? 'Login failed');
      }
    } on DioException catch (e) {
      String errorMessage;

      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final responseData = e.response!.data;

        if (statusCode == 401) {
          errorMessage =
              responseData is Map
                  ? (responseData['message'] ?? 'Invalid email or password. Please try again.')
                  : 'Invalid email or password. Please try again.';
        } else if (statusCode == 400) {
          errorMessage =
              responseData is Map
                  ? (responseData['message'] ?? 'Invalid request. Please check your input.')
                  : 'Invalid request. Please check your input.';
        } else if (statusCode == 404 || statusCode == 502 || statusCode == 503) {
          errorMessage = _kServerConnectionError;
        } else {
          errorMessage =
              responseData is Map
                  ? (responseData['message'] ?? 'Login failed. Please try again.')
                  : 'Login failed. Please try again.';
        }
      } else {
        // No response: connection refused, timeout, wrong host, SSL error, etc.
        errorMessage = _kServerConnectionError;
      }

      throw Exception(errorMessage);
    } on TypeError catch (_) {
      throw Exception(_kServerConnectionError);
    } on FormatException catch (_) {
      throw Exception(_kServerConnectionError);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(_kServerConnectionError);
    }
  }
}

