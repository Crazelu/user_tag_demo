import 'package:flutter/material.dart';
import 'package:user_tag_demo/models/post.dart';
import 'package:user_tag_demo/views/view_models/home_view_model.dart';
import 'package:user_tag_demo/views/widgets/comment_text_field.dart';
import 'package:user_tag_demo/views/widgets/post_widget.dart';
import 'package:user_tag_demo/views/widgets/user_tagger_widget.dart';

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final homeViewModel = HomeViewModel();
  late final _controller = TextEditingController();
  late final _focusNode = FocusNode();

  String _formattedText = "";
  VoidCallback? _dismissOverlay;

  void _focusListener() {
    if (!_focusNode.hasFocus) {
      _dismissOverlay?.call();
    }
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_focusListener);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_focusListener);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var insets = MediaQuery.of(context).viewInsets;
    return GestureDetector(
      onTap: () {
        _dismissOverlay?.call();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.redAccent,
          title: const Text("The Squad"),
        ),
        bottomNavigationBar: UserTagger(
            onCreate: (onClose) {
              _dismissOverlay = onClose;
            },
            onFormattedTextChanged: (formattedText) {
              _formattedText = formattedText;
            },
            controller: _controller,
            builder: (context, containerKey) {
              return CommentTextField(
                focusNode: _focusNode,
                containerKey: containerKey,
                insets: insets,
                controller: _controller,
                onSend: () {
                  FocusScope.of(context).unfocus();
                  homeViewModel.addPost(_formattedText);
                  _controller.clear();
                },
              );
            }),
        body: ValueListenableBuilder<List<Post>>(
            valueListenable: homeViewModel.posts,
            builder: (_, posts, __) {
              return ListView.builder(
                itemCount: posts.length,
                itemBuilder: (_, index) {
                  return PostWidget(post: posts[index]);
                },
              );
            }),
      ),
    );
  }
}
