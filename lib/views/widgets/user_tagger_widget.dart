import 'package:flutter/material.dart';
import 'package:user_tag_demo/models/user.dart';
import 'package:user_tag_demo/views/view_models/search_view_model.dart';
import 'package:user_tag_demo/views/widgets/loading_indicator.dart';

///Search view model
final _searchViewModel = SearchViewModel();

class UserTagger extends StatefulWidget {
  const UserTagger({
    Key? key,
    required this.controller,
    required this.onFormattedTextChanged,
    required this.builder,
    this.onCreate,
  }) : super(key: key);

  ///Child TextField's controller
  final TextEditingController controller;

  ///Callback to dispatch updated formatted text
  final void Function(String) onFormattedTextChanged;

  ///Returns callback that can be used to dismiss the overlay
  ///from parent widget.
  final void Function(VoidCallback)? onCreate;

  ///Widget builder.
  ///Returned widget must use the [GlobalKey] as it's key.
  final Widget Function(BuildContext, GlobalKey) builder;

  @override
  State<UserTagger> createState() => _UserTaggerState();
}

class _UserTaggerState extends State<UserTagger> {
  TextEditingController get controller => widget.controller;
  late final _containerKey = GlobalKey(
    debugLabel: "TextField Container Key",
  );
  late Offset _offset = Offset.zero;
  late double _width = 0;
  late bool _hideOverlay = true;
  OverlayEntry? _overlayEntry;

  ///Retrieves rendering information necessary to determine where
  ///the overlay is positioned on the screen.
  void _computeSize() {
    try {
      final renderBox =
          _containerKey.currentContext!.findRenderObject() as RenderBox;
      _width = renderBox.size.width;
      _offset = renderBox.localToGlobal(Offset.zero);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  ///Hides overlay if [val] is true.
  ///Otherwise, this computes size, creates and inserts and OverlayEntry.
  void _shouldHideOverlay(bool val) {
    try {
      if (_hideOverlay == val) return;
      setState(() {
        _hideOverlay = val;
        if (_hideOverlay) {
          _overlayEntry?.remove();
          _overlayEntry = null;
        } else {
          _computeSize();
          _overlayEntry = _createOverlay();
          Overlay.of(context)!.insert(_overlayEntry!);
        }
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  ///Creates an overlay to show search result
  OverlayEntry _createOverlay() {
    return OverlayEntry(
      builder: (_) => Positioned(
        left: _offset.dx,
        width: _width,
        height: 380,
        top: _offset.dy - 390,
        child: _UserListView(
          tagUser: _tagUser,
          onClose: () => _shouldHideOverlay(true),
        ),
      ),
    );
  }

  ///Table of tagged user names and their ids
  late final Map<String, String> _taggedUsers = {};

  ///Formatted text where tagged user names are replaced in this format:
  ///```dart
  ///"@Lucky Ebere"
  ///```
  ///becomes
  ///
  ///```dart
  ///"@6zo22531b866ce0016f9e5tt#Lucky Ebere#"
  ///```
  ///assuming that `Lucky Ebere`'s id is `6zo22531b866ce0016f9e5tt`
  String get _formattedText {
    String text = controller.text;

    for (var name in _taggedUsers.keys) {
      if (text.contains(name)) {
        final userName = name.replaceAll("@", "");
        text = text.replaceAll(name, "@${_taggedUsers[name]}#$userName#");
      }
    }
    return text;
  }

  ///Whether to not execute the [_tagListener] logic
  bool _defer = false;

  ///Current tagged user selected in TextField
  String _selectedTag = "";

  ///Executes user search with [query]
  void _search(String query) {
    if (query.isEmpty) return;

    _shouldHideOverlay(false);
    _searchViewModel.search(query.trim());
  }

  ///Adds [name] and [id] to [_taggedUsers] and
  ///updates content of TextField with [name]
  void _tagUser(String name, String id) {
    _shouldSearch = false;
    _shouldHideOverlay(true);

    name = "@${name.trim()}";
    id = id.trim();

    if (_taggedUsers[name] != null) {
      //user has already been tagged
      //show error
      return;
    }

    final text = controller.text;
    late final position = controller.selection.base.offset - 1;
    int index = 0;
    if (position != text.length - 1) {
      index = text.substring(0, position).lastIndexOf("@");
    } else {
      index = text.lastIndexOf("@");
    }
    if (index >= 0) {
      final tag = text.substring(index, position + 1);
      _defer = true;
      _taggedUsers[name] = id;
      final newText = text.replaceAll(tag, name);
      _lastCachedText = newText;
      controller.text = newText;
      _defer = true;

      int offset = newText.indexOf(name) + name.length + 1;
      if (offset > newText.length) offset -= 1;

      controller.selection = TextSelection.fromPosition(
        TextPosition(
          offset: offset,
        ),
      );

      widget.onFormattedTextChanged(_formattedText);
    }
  }

  ///Highlights a tagged user from [_taggedUsers] when keyboard action attempts to remove them
  ///to prompt the user.
  ///
  ///Highlighted user when [_removeEditedTags] is triggered is removed from
  ///the TextField.
  ///
  ///Does nothing when there is no tagged user or when there's no attempt
  ///to remove a tagged user from the TextField.
  ///
  ///Returns `true` if a tagged user is either selected or removed
  ///(if they were previously selected).
  ///Otherwise, returns `false`.
  bool _removeEditedTags() {
    try {
      final text = controller.text;
      if (text.isEmpty) {
        _taggedUsers.clear();
        _lastCachedText = text;
        return false;
      }
      final position = controller.selection.base.offset - 1;
      if (text[position] == "@") {
        _shouldSearch = true;
        return false;
      }

      for (var tag in _taggedUsers.keys) {
        if (!text.contains(tag)) {
          if (_isTagSelected) {
            _removeSelection();
            return true;
          } else {
            if (_backtrackAndSelect(tag)) return true;
          }
        }
      }
    } catch (e, trace) {
      debugPrint("FROM _removeEditedTags: $e");
      debugPrint("FROM _removeEditedTags: $trace");
    }
    _lastCachedText = controller.text;
    _defer = false;
    return false;
  }

  ///Back tracks from current cursor position to find and select
  ///a tagged user, if any.
  ///
  ///Returns `true` if a tagged user is found and selected.
  ///Otherwise, returns `false`.
  bool _backtrackAndSelect(String tag) {
    String text = controller.text;
    if (!text.contains("@")) return false;

    final length = controller.selection.base.offset;
    _defer = true;
    controller.text = _lastCachedText;
    text = _lastCachedText;
    _defer = true;
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: length),
    );

    late String temp = "";

    for (int i = length; i >= 0; i--) {
      if (i == length && text[i] == "@") return false;

      temp = text[i] + temp;
      if (text[i] == "@" && temp.length > 1 && temp == tag) {
        _selectedTag = tag;
        _isTagSelected = true;
        _startOffset = i;
        _endOffset = length + 1;
        _defer = true;
        controller.selection = TextSelection(
          baseOffset: _startOffset!,
          extentOffset: _endOffset!,
        );
        return true;
      }
    }

    return false;
  }

  ///Updates offsets after [_selectedTag] set in [_backtrackAndSelect]
  ///has been removed.
  void _removeSelection() {
    _taggedUsers.remove(_selectedTag);
    _selectedTag = "";
    _lastCachedText = controller.text;
    _startOffset = null;
    _endOffset = null;
    _isTagSelected = false;
    widget.onFormattedTextChanged(_formattedText);
  }

  ///Whether a tagged user is selected in the TextField
  bool _isTagSelected = false;

  ///Start offset for selection in the TextField
  int? _startOffset;

  ///End offset for selection in the TextField
  int? _endOffset;

  ///Text from the TextField in it's previous state before a new update
  ///(new text input from keyboard or deletion).
  ///
  ///This is necessary to compare and see if changes have occured and to restore
  ///the text field content when user attempts to remove a tagged user
  ///so the tagged user can be selected and with further action, be removed.
  String _lastCachedText = "";

  ///Whether to initiate a user search
  bool _shouldSearch = false;

  ///Regex to match allowed search characters.
  ///Non-conforming characters terminate the search context.
  late final _regExp = RegExp(r'^[a-zA-Z-]*$');

  ///This is triggered when deleting text from TextField that isn't
  ///a tagged user. Useful for continuing search without having to
  ///type `@` first.
  ///
  ///E.g, if you typed
  ///```dart
  ///@lucky|
  ///```
  ///the search context is activated and `lucky` is sent as the search query.
  ///
  ///But if you continue with a terminating character like so:
  ///```dart
  ///@lucky |
  ///```
  ///the search context is exited and the overlay is dismissed.
  ///
  ///However, if the text is edited to bring the cursor back to
  ///
  ///```dart
  ///@luck|
  ///```
  ///the search context is entered again and the text after the `@` is
  ///sent as the search query.
  ///
  ///Returns `false` when a search query is found from back tracking.
  ///Otherwise, returns `true`.
  bool _backtrackAndSearch() {
    String text = controller.text;
    if (!text.contains("@")) return true;

    final length = controller.selection.base.offset - 1;

    late String temp = "";

    for (int i = length; i >= 0; i--) {
      if (i == length && text[i] == "@") return true;

      if (!_regExp.hasMatch(text[i]) && text[i] != "@") return true;

      temp = text[i] + temp;
      if (text[i] == "@" && temp.length > 1) {
        _shouldSearch = true;
        _isTagSelected = false;
        _extractAndSearch(controller.text, length);
        return false;
      }
    }

    _lastCachedText = controller.text;
    return true;
  }

  ///Shifts cursor to end of tagged user name
  ///when an attempt to edit one is made.
  ///
  ///This shift of the cursor allows the next backbutton press from the
  ///same position to trigger the selection (and removal on next press)
  ///of the tagged user.
  void _shiftCursorForTaggedUser() {
    String text = controller.text;
    if (!text.contains("@")) return;

    final length = controller.selection.base.offset - 1;

    late String temp = "";

    for (int i = length; i >= 0; i--) {
      if (i == length && text[i] == "@") {
        temp = "@";
        break;
      }

      temp = text[i] + temp;
      if (text[i] == "@" && temp.length > 1) break;
    }

    if (temp.isEmpty) return;
    for (var user in _taggedUsers.keys) {
      if (user.contains(temp)) {
        final names = user.split(" ");
        if (names.length != 2) return;

        int offset = length +
            names.last.length +
            (names.first.length - temp.length + 1) +
            1;

        if (offset > text.length) {
          offset = text.length;
        }

        if (text.substring(length + 1, offset).trim().contains(names.last)) {
          _defer = true;
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: offset),
          );
          return;
        }
      }
    }
  }

  ///Listener attached to [controller] to listen for change in
  ///search context and tagged user selection.
  ///
  ///Triggers search:
  ///Starts the search context when last entered character is `@`.
  ///
  ///Ends Search:
  ///Exits search context and hides overlay when a terminating character
  ///not matched by [_regExp] is entered.
  void _tagListener() {
    if (_defer) {
      _defer = false;
      return;
    }

    final text = controller.text;

    if (text.isEmpty && _selectedTag.isNotEmpty) {
      _removeSelection();
    }

    //When a previously selected tag is unselected without removing
    //reset tag selection values
    if (_startOffset != null &&
        controller.selection.base.offset != _startOffset) {
      _selectedTag = "";
      _startOffset = null;
      _endOffset = null;
      _isTagSelected = false;
    }

    late final position = controller.selection.base.offset - 1;

    if (_shouldSearch && position != text.length - 1 && text.contains("@")) {
      _extractAndSearch(text, position);
      return;
    }

    if (_lastCachedText == text) {
      _shiftCursorForTaggedUser();
      widget.onFormattedTextChanged(_formattedText);
      return;
    }

    if (_lastCachedText.trim().length > text.trim().length) {
      if (_removeEditedTags()) {
        _shouldHideOverlay(true);
        widget.onFormattedTextChanged(_formattedText);
        return;
      }
      _shiftCursorForTaggedUser();
      final hideOverlay = _backtrackAndSearch();
      if (hideOverlay) _shouldHideOverlay(true);
      widget.onFormattedTextChanged(_formattedText);
      return;
    }
    _lastCachedText = text;

    if (text[position] == "@") {
      _shouldSearch = true;
      widget.onFormattedTextChanged(_formattedText);
      return;
    }

    if (!_regExp.hasMatch(text[position])) {
      _shouldSearch = false;
    }

    if (_shouldSearch) {
      _extractAndSearch(text, position);
    } else {
      _shouldHideOverlay(true);
    }
    widget.onFormattedTextChanged(_formattedText);
  }

  ///Extract text appended to the last `@` symbol found in [text]
  ///or the substring of [text] up until [position] if [position] is not null
  ///and performs a user search.
  void _extractAndSearch(String text, int endOffset) {
    try {
      int index = text.substring(0, endOffset).lastIndexOf("@");

      if (index < 0) return;

      final userName = text.substring(
        index + 1,
        endOffset + 1,
      );
      if (userName.isNotEmpty) _search(userName);
    } catch (e, trace) {
      debugPrint("$trace");
    }
  }

  @override
  void initState() {
    super.initState();
    controller.addListener(_tagListener);
  }

  @override
  void dispose() {
    controller.removeListener(_tagListener);
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.onCreate?.call(() {
      _shouldHideOverlay(true);
    });
    return widget.builder(context, _containerKey);
  }
}

class _UserListView extends StatelessWidget {
  final Function(String, String) tagUser;
  final VoidCallback onClose;
  const _UserListView({
    Key? key,
    required this.tagUser,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.2),
            offset: const Offset(0, -5),
            blurRadius: 10,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: ValueListenableBuilder<bool>(
            valueListenable: _searchViewModel.loading,
            builder: (_, loading, __) {
              return ValueListenableBuilder<List<User>>(
                  valueListenable: _searchViewModel.users,
                  builder: (_, users, __) {
                    if (loading && users.isEmpty) {
                      return const Center(
                        child: LoadingWidget(),
                      );
                    }
                    return Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            onPressed: onClose,
                            icon: const Icon(Icons.close),
                          ),
                        ),
                        if (users.isEmpty)
                          const Center(child: Text("No user found"))
                        else
                          Expanded(
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: users.length,
                              itemBuilder: (_, index) {
                                final user = users[index];
                                return ListTile(
                                  leading: Container(
                                    height: 50,
                                    width: 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      image: DecorationImage(
                                        image: NetworkImage(user.avatar),
                                      ),
                                    ),
                                  ),
                                  title: Text(user.fullName),
                                  subtitle: Text("@${user.userName}"),
                                  onTap: () {
                                    tagUser(user.userName, user.id);
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  });
            }),
      ),
    );
  }
}
