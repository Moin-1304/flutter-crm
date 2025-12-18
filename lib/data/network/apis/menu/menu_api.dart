import 'dart:async';

import 'package:boilerplate/core/data/network/dio/dio_client.dart';
import 'package:boilerplate/data/network/constants/endpoints.dart';

class MenuApi {
  final DioClient _dioClient;

  MenuApi(this._dioClient);

  Future<dynamic> getMenu({String? groupName, String? pageName, required int userId}) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.menuGet,
        data: {
          'GroupName': groupName,
          'PageName': pageName,
          'UserId': userId,
        },
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }
}


