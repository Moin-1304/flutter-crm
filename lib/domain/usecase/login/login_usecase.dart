// lib/domain/usecase/user/login_usecase.dart
import 'package:boilerplate/domain/entity/user/user.dart';
import '../../repository/user/user_repository.dart';

class LoginUseCase {
  final UserRepository _userRepository;

  LoginUseCase(this._userRepository);

  Future<User?> execute(String email, String password) {
    return _userRepository.login(email, password);
  }
}


class LogoutUseCase {
  final UserRepository _userRepository;

  LogoutUseCase(this._userRepository);

  Future<void> execute() {
    return _userRepository.logout();
  }
}



class GetUserUseCase {
  final UserRepository _userRepository;

  GetUserUseCase(this._userRepository);

  Future<User?> execute() {
    return _userRepository.getSavedUser();
  }
}
