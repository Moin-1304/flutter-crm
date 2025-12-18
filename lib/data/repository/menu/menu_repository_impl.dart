import 'dart:async';

import 'package:boilerplate/data/network/apis/menu/menu_api.dart';
import 'package:boilerplate/domain/entity/menu/menu_response.dart';
import 'package:boilerplate/domain/repository/menu/menu_repository.dart';

class MenuRepositoryImpl extends MenuRepository {
  final MenuApi _menuApi;

  MenuRepositoryImpl(this._menuApi);

  @override
  Future<MenuResponse> getMenu({String? groupName, String? pageName, required int userId}) async {
    final data = await _menuApi.getMenu(groupName: groupName, pageName: pageName, userId: userId);
    if (data is Map<String, dynamic>) {
      return MenuResponse.fromJson(data);
    }
    return MenuResponse.fromJson({'data': data});
  }
}


