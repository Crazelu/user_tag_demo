import 'package:flutter/material.dart';
import 'package:user_tag_demo/models/post.dart';
import 'package:user_tag_demo/models/user.dart';

class HomeViewModel {
  final ValueNotifier<List<Post>> _posts = ValueNotifier(Post.posts);
  ValueNotifier<List<Post>> get posts => _posts;

  void addPost(String caption) {
    if (caption.isEmpty) return;

    final post = Post(
      caption: caption,
      poster: User.anon(),
      time: "now",
    );

    _posts.value.add(post);
    _posts.notifyListeners();
  }
}
