import 'package:flutter/material.dart';
import 'package:boilerplate/data/network/apis/menu/menu_api.dart';
import 'package:boilerplate/di/service_locator.dart';

class MenuStore extends ChangeNotifier {
  final MenuApi _menuApi = getIt<MenuApi>();
  
  bool isLoading = false;
  dynamic menuData;
  String? errorMessage;

  Future<void> getMenu({String? groupName, String? pageName, required int userId}) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      print('=== MENU API CALL ===');
      print('Group Name: $groupName');
      print('Page Name: $pageName');
      print('User ID: $userId');
      print('===================');

      menuData = await _menuApi.getMenu(
        groupName: groupName,
        pageName: pageName,
        userId: userId,
      );

      print('=== MENU API RESPONSE ===');
      print('Menu Data: $menuData');
      print('========================');

      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      print('=== MENU API ERROR ===');
      print('Error: $e');
      print('=====================');
      notifyListeners();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }
}
