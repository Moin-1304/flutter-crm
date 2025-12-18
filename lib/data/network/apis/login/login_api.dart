import 'dart:async';
import 'package:boilerplate/core/data/network/dio/dio_client.dart';
import 'package:boilerplate/data/network/constants/endpoints.dart';
import 'package:boilerplate/domain/entity/user/user.dart';
import 'package:dio/dio.dart';


class LoginApi {
  final DioClient _dioClient;

  LoginApi(this._dioClient);

  Future<User> login(String email, String password) async {
    try {
      final res = await _dioClient.dio.post(
        Endpoints.login,
        data: {'email': email, 'password': password},
      );
      if (res.data['isSuccess'] == true) {
        return User.fromJson(res.data);
      } else {
        throw Exception(res.data['message'] ?? 'Login failed');
      }
    } on DioException catch (e) {
      // Handle DioException (401, 400, etc.)
      String errorMessage;
      
      if (e.response != null) {
        // Server responded with an error status code
        final statusCode = e.response!.statusCode;
        final responseData = e.response!.data;
        
        if (statusCode == 401) {
          // Unauthorized - Invalid credentials
          errorMessage = responseData?['message'] ?? 'Invalid email or password. Please try again.';
        } else if (statusCode == 400) {
          // Bad request
          errorMessage = responseData?['message'] ?? 'Invalid request. Please check your input.';
        } else {
          // Other error codes
          errorMessage = responseData?['message'] ?? 'Login failed. Please try again.';
        }
      } else {
        // No response from server
        errorMessage = 'Unable to connect to server. Please check your internet connection.';
      }
      
      throw Exception(errorMessage);
    } catch (e) {
      // Re-throw as Exception to maintain consistency
      if (e is Exception) {
        rethrow;
      }
      throw Exception(e.toString());
    }
  }
}

