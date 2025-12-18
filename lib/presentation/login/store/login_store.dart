// lib/stores/user/user_store.dart
import 'package:flutter/material.dart';
import 'package:boilerplate/domain/entity/user/user.dart';
import '../../../domain/usecase/login/login_usecase.dart';
import '../../../data/sharedpref/shared_preference_helper.dart';
import '../../../data/sharedpref/constants/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserStore extends ChangeNotifier {
  final LoginUseCase _loginUseCase;
  final LogoutUseCase _logoutUseCase;
  final GetUserUseCase _getUserUseCase;

  bool isLoggedIn = false;
  bool success = false;
  bool isLoading = false;
  User? currentUser;
  String? errorMessage;

  // Getter for login status
  bool get isUserLoggedIn => isLoggedIn;

  UserStore(this._loginUseCase, this._logoutUseCase, this._getUserUseCase) {
    _init();
  }

  Future<void> _init() async {
    // First check if the user explicitly logged out
    final prefs = await SharedPreferences.getInstance();
    final isLoggedInFlag = prefs.getBool(Preferences.is_logged_in) ?? false;
    
    if (isLoggedInFlag) {
      // User should be logged in, try to get saved user
      currentUser = await _getUserUseCase.execute();
      isLoggedIn = currentUser != null;
    } else {
      // User explicitly logged out, clear any saved user data
      currentUser = null;
      isLoggedIn = false;
    }
    notifyListeners();
  }

  Future<User?> login(String email, String password) async {
    try {
      // reset previous error state before a new attempt
      errorMessage = null;
      isLoading = true;
      notifyListeners();

      final user = await _loginUseCase.execute(email, password);

      if (user != null && user.isSuccess) {
        currentUser = user;
        success = true;
        isLoggedIn = true;
        // ensure error message does not linger after success
        errorMessage = null;
      } else {
        success = false;
        isLoggedIn = false;
        // Set error message when login fails
        if (user == null) {
          errorMessage = 'Invalid email or password';
        } else if (!user.isSuccess) {
          errorMessage = 'Login failed. Please check your credentials';
        }
      }
      notifyListeners();
      return user;
    } catch (e) {
      success = false;
      isLoggedIn = false;
      // Clean up the error message - remove "Exception: " prefix if present
      String errorMsg = e.toString();
      if (errorMsg.startsWith('Exception: ')) {
        errorMsg = errorMsg.substring('Exception: '.length);
      }
      errorMessage = errorMsg;
      notifyListeners();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _logoutUseCase.execute();
    isLoggedIn = false;
    success = false;
    currentUser = null;
    errorMessage = null;
    notifyListeners();
  }
}
