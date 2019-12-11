import 'package:flutter/material.dart';
import 'package:easy_chat_app/const.dart';
import 'package:photo_view/photo_view.dart';
import 'package:flutter/material.dart';
import 'package:string_scanner/string_scanner.dart';

class SyntaxHighlighterStyle {
  SyntaxHighlighterStyle(
      {this.baseStyle,
      this.numberStyle,
      this.commentStyle,
      this.keywordStyle,
      this.stringStyle,
      this.punctuationStyle,
      this.classStyle,
      this.constantStyle});

  static SyntaxHighlighterStyle lightThemeStyle() {
    return SyntaxHighlighterStyle(
        baseStyle: const TextStyle(color: Color(0xFF000000)),
        numberStyle: const TextStyle(color: Color(0xFF1565C0)),
        commentStyle: const TextStyle(color: Color(0xFF9E9E9E)),
        keywordStyle: const TextStyle(color: Color(0xFF9C27B0)),
        stringStyle: const TextStyle(color: Color(0xFF43A047)),
        punctuationStyle: const TextStyle(color: Color(0xFF000000)),
        classStyle: const TextStyle(color: Color(0xFF512DA8)),
        constantStyle: const TextStyle(color: Color(0xFF795548)));
  }

  static SyntaxHighlighterStyle darkThemeStyle() {
    return SyntaxHighlighterStyle(
        baseStyle: const TextStyle(color: Color(0xFFFFFFFF)),
        numberStyle: const TextStyle(color: Color(0xFF1565C0)),
        commentStyle: const TextStyle(color: Color(0xFF9E9E9E)),
        keywordStyle: const TextStyle(color: Color(0xFF80CBC4)),
        stringStyle: const TextStyle(color: Color(0xFF009688)),
        punctuationStyle: const TextStyle(color: Color(0xFFFFFFFF)),
        classStyle: const TextStyle(color: Color(0xFF009688)),
        constantStyle: const TextStyle(color: Color(0xFF795548)));
  }

  final TextStyle baseStyle;
  final TextStyle numberStyle;
  final TextStyle commentStyle;
  final TextStyle keywordStyle;
  final TextStyle stringStyle;
  final TextStyle punctuationStyle;
  final TextStyle classStyle;
  final TextStyle constantStyle;
}

abstract class Highlighter {
  // ignore: one_member_abstracts
  TextSpan format(String src);
}
class FullPhoto extends StatelessWidget {
  final String url;

  FullPhoto({Key key, @required this.url}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(
          'FULL PHOTO',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: new FullPhotoScreen(url: url),
    );
  }
}
// FullPhotoScreen Class
class FullPhotoScreen extends StatefulWidget {
  final String url;

  FullPhotoScreen({Key key, @required this.url}) : super(key: key);

  @override
  State createState() => new FullPhotoScreenState(url: url);
}

class FullPhotoScreenState extends State<FullPhotoScreen> {
  final String url;

  FullPhotoScreenState({Key key, @required this.url});

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(child: PhotoView(imageProvider: NetworkImage(url)));
  }
}
