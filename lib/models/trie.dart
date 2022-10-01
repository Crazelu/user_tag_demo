import 'package:user_tag_demo/models/tagged_text.dart';

class _TrieNode {
  final Map<String, _TrieNode> children;
  late bool endOfWord;
  int? startIndex;
  int? endIndex;

  _TrieNode({
    this.endOfWord = false,
  }) : children = {};
}

class Trie {
  late _TrieNode _root;

  Trie() : _root = _TrieNode();

  void insertAll(Iterable<TaggedText> tags) {
    for (var tag in tags) {
      insert(tag);
    }
  }

  ///Inserts tag into trie
  void insert(TaggedText tag) {
    int length = tag.text.length;
    _TrieNode node = _root;
    for (int i = 0; i < length; i++) {
      final char = tag.text[i];
      if (node.children[char] == null) {
        final newNode = _TrieNode(endOfWord: i == length - 1);
        node.children[char] = newNode;
        node = newNode;
      } else {
        node = node.children[char]!;
      }
    }
    node.endOfWord = true;
    node.startIndex = tag.startIndex;
    node.endIndex = tag.endIndex;
  }

  ///If a [TaggedText] is a substring of [word],
  ///[TaggedText] is returned. Otherwise, `null` is returned.
  TaggedText? search(String word) {
    int length = word.length;
    _TrieNode node = _root;
    int lastIndex = 0;

    TaggedText? tag;

    for (int i = 0; i < length; i++) {
      if (node.endOfWord) {
        tag = TaggedText(
          startIndex: node.startIndex!,
          endIndex: node.endIndex!,
          text: word.substring(0, lastIndex + 1),
        );
      }

      final char = word[i];
      if (node.children[char] == null) {
        break;
      }
      lastIndex = i;
      node = node.children[char]!;
    }
    if (node.endOfWord) {
      return TaggedText(
        startIndex: node.startIndex!,
        endIndex: node.endIndex!,
        text: word.substring(0, lastIndex + 1),
      );
    }
    return tag;
  }

  void clear() {
    _root = _TrieNode();
  }
}
