// lib/data/repository/user_repository.dart
import 'package:boilerplate/data/network/apis/login/login_api.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:boilerplate/domain/entity/user/user.dart';

class UserRepository {
  final LoginApi _loginApi;
  final SharedPreferenceHelper _sharedPrefHelper;

  UserRepository(this._loginApi, this._sharedPrefHelper);

  Future<User?> login(String email, String password) async {
    final user = await _loginApi.login(email, password);
    if (user.isSuccess) {
      await _sharedPrefHelper.saveIsLoggedIn(true);
      await _sharedPrefHelper.saveUser(user);
    }
    return user;
  }

  Future<void> logout() async {
    await _sharedPrefHelper.saveIsLoggedIn(false);
    await _sharedPrefHelper.clearUser();
  }

  Future<User?> getSavedUser() async {
    return _sharedPrefHelper.getUser();
  }

  Future<bool> isLoggedIn() async {
    return _sharedPrefHelper.isLoggedIn;
  }
}
