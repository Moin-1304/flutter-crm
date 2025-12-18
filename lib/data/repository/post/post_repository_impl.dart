import 'dart:async';

import 'package:boilerplate/data/network/apis/posts/post_api.dart';
import 'package:boilerplate/domain/entity/post/post_list.dart';
import 'package:boilerplate/domain/repository/post/post_repository.dart';

class PostRepositoryImpl extends PostRepository {
  // api objects
  final PostApi _postApi;

  // constructor
  PostRepositoryImpl(this._postApi);

  // Post: ---------------------------------------------------------------------
  @override
  Future<PostList> getPosts() async {
    return await _postApi.getPosts().catchError((error) => throw error);
  }
}
