import 'dart:async';

import 'package:boilerplate/domain/entity/menu/menu_response.dart';
import 'package:boilerplate/domain/repository/menu/menu_repository.dart';

class GetMenuUseCase {
  final MenuRepository _menuRepository;

  GetMenuUseCase(this._menuRepository);

  Future<MenuResponse> execute({String? groupName, String? pageName, required int userId}) {
    return _menuRepository.getMenu(groupName: groupName, pageName: pageName, userId: userId);
  }
}


