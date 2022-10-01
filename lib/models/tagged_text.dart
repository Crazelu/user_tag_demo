import 'package:equatable/equatable.dart';

class TaggedText extends Equatable {
  final int startIndex;
  final int endIndex;
  final String text;

  const TaggedText({
    required this.startIndex,
    required this.endIndex,
    required this.text,
  });

  @override
  List<Object?> get props => [
        startIndex,
        endIndex,
        text,
      ];

  @override
  String toString() {
    return "TaggedText(startIndex: $startIndex, endIndex: $endIndex, text: $text)";
  }
}
