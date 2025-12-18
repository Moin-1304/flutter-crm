import 'dart:async';

import 'package:boilerplate/domain/entity/post/post_list.dart';

abstract class PostRepository {
  Future<PostList> getPosts();
}
