import 'dart:async';

import 'package:boilerplate/domain/entity/menu/menu_response.dart';

abstract class MenuRepository {
  Future<MenuResponse> getMenu({String? groupName, String? pageName, required int userId});
}


