import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:easy_chat_app/const.dart';
import 'package:easy_chat_app/map.dart';
import 'package:easy_chat_app/fullPhoto.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

class Chat extends StatelessWidget {
  final String peerId;
  final String peerAvatar;
  final String peerNickName;

  Chat(
      {Key key,
      @required this.peerId,
      @required this.peerAvatar,
      @required this.peerNickName})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(
          peerNickName,
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: new ChatScreen(
        peerId: peerId,
        peerAvatar: peerAvatar,
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String peerId;
  final String peerAvatar;

  ChatScreen({Key key, @required this.peerId, @required this.peerAvatar})
      : super(key: key);

  @override
  State createState() =>
      new ChatScreenState(peerId: peerId, peerAvatar: peerAvatar);
}

class ChatScreenState extends State<ChatScreen> {
  ChatScreenState({Key key, @required this.peerId, @required this.peerAvatar});

  String peerId;
  String peerAvatar;
  String id;

  var listMessage;
  String groupChatId;
  SharedPreferences prefs;

  File imageFile;
  bool isLoading;
  bool isShowSticker; // 表情包是否出现
  String imageUrl;

  final TextEditingController textEditingController =
      new TextEditingController();
  final ScrollController listScrollController = new ScrollController();
  final FocusNode focusNode = new FocusNode();

  @override
  void initState() {
    super.initState();
    focusNode.addListener(onFocusChange);

    groupChatId = '';

    isLoading = false;
    isShowSticker = false;
    imageUrl = '';

    readLocal();
  }

  void onFocusChange() {
    if (focusNode.hasFocus) {
      // 当键盘出现时，隐藏表情包
      setState(() {
        isShowSticker = false;
      });
    }
  }

  // 更新 users->user->chattingWith
  readLocal() async {
    prefs = await SharedPreferences.getInstance();
    id = prefs.getString('id') ?? '';
    if (id.hashCode <= peerId.hashCode) {
      groupChatId = '$id-$peerId';
    } else {
      groupChatId = '$peerId-$id';
    }

    Firestore.instance
        .collection('users')
        .document(id)
        .updateData({'chattingWith': peerId});

    setState(() {});
  }

  // 从相册获取图片并上传
  Future getImage() async {
    imageFile = await ImagePicker.pickImage(source: ImageSource.gallery);

    if (imageFile != null) {
      setState(() {
        isLoading = true;
      });
      uploadFile();
    }
  }

  void getSticker() {
    // Hide keyboard when sticker appear
    focusNode.unfocus();
    setState(() {
      isShowSticker = !isShowSticker;
    });
  }

  Future uploadFile() async {
    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    StorageReference reference = FirebaseStorage.instance.ref().child(fileName);
    StorageUploadTask uploadTask = reference.putFile(imageFile);
    StorageTaskSnapshot storageTaskSnapshot = await uploadTask.onComplete;
    storageTaskSnapshot.ref.getDownloadURL().then((downloadUrl) {
      imageUrl = downloadUrl;
      setState(() {
        isLoading = false;
        onSendMessage(imageUrl, 1);
      });
    }, onError: (err) {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(msg: '这不是图片文件');
    });
  }

  // 发送消息
  // type: 0 = text, 1 = image, 2 = sticker  type=3 position
  void onSendMessage(String content, int type) {
    if (content.trim() != '') {
      textEditingController.clear();

      // 写入聊天数据
      // massages -> groupId(document) -> groupId(collection) -> massage
      var documentReference = Firestore.instance
          .collection('messages')
          .document(groupChatId)
          .collection(groupChatId)
          .document(DateTime.now().millisecondsSinceEpoch.toString());

      Firestore.instance.runTransaction((transaction) async {
        await transaction.set(
          documentReference,
          {
            'idFrom': id,
            'idTo': peerId,
            'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
            'content': content,
            'type': type
          },
        );
      });
      listScrollController.animateTo(0.0,
          duration: Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      Fluttertoast.showToast(msg: '请输入消息');
    }
  }

  Widget buildItem(int index, DocumentSnapshot document) {


    // 显示自己的消息
    Container showRightMassage(int type, String msg) {
      // type 0
      Container textContainer = new Container(
        child: Text(
          msg,
          style: TextStyle(color: primaryColor),
        ),
        padding: EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 10.0),
        width: 200.0,
        decoration: BoxDecoration(
            color: greyColor2, borderRadius: BorderRadius.circular(8.0)),
        margin: EdgeInsets.only(
            bottom: isLastMessageRight(index) ? 20.0 : 10.0, right: 10.0),
      );

      // type 1
      Container imageContainer = new Container(
        child: FlatButton(
          child: Material(
            child: CachedNetworkImage(
              placeholder: (context, url) => Container(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                ),
                width: 200.0,
                height: 200.0,
                padding: EdgeInsets.all(70.0),
                decoration: BoxDecoration(
                  color: greyColor2,
                  borderRadius: BorderRadius.all(
                    Radius.circular(8.0),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Material(
                child: Image.asset(
                  'images/img_not_available.jpeg',
                  width: 200.0,
                  height: 200.0,
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.all(
                  Radius.circular(8.0),
                ),
                clipBehavior: Clip.hardEdge,
              ),
              imageUrl: document['content'],
              width: 200.0,
              height: 200.0,
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            clipBehavior: Clip.hardEdge,
          ),
          onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => FullPhoto(url: document['content'])));
          },
          padding: EdgeInsets.all(0),
        ),
        margin: EdgeInsets.only(
            bottom: isLastMessageRight(index) ? 20.0 : 10.0, right: 10.0),
      );
//      type 2
      Container stickerContainer = new Container(
        child: new Image.asset(
          'images/${document['content']}.gif',
          width: 100.0,
          height: 100.0,
          fit: BoxFit.cover,
        ),
        margin: EdgeInsets.only(
            bottom: isLastMessageRight(index) ? 20.0 : 10.0, right: 10.0),
      );
      // 跳转map页
      void _gotoMapPage() {
        print(msg);
        UserPosition position =UserPosition.fromJson(jsonDecode(msg));
        print(position.toString());
        Navigator.push(
          context,
          new MaterialPageRoute(builder: (context) => MapPage(position: UserPosition.fromJson(jsonDecode(msg)),)
          ));
      }
      //type 3
      Container mapContainer = new Container(
        padding: EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 10.0),
        width: 200.0,
        decoration: BoxDecoration(
            color: greyColor2,
            borderRadius: BorderRadius.circular(8.0)),
        margin: EdgeInsets.only(
            bottom: isLastMessageRight(index) ? 20.0 : 10.0,
            right: 10.0),

        child: new GestureDetector(
          onTap: _gotoMapPage,
          child: Row(
            children: <Widget>[

              Container(
                child: new Image.asset(
                  'images/position.png',
                  width: 60.0,
                  height: 60.0,
//                  fit: BoxFit.cover,
                ),
                margin: EdgeInsets.only(left: 6.0),
              ),
              Container(
                child:  new Text('你的位置',
                    style: new TextStyle(
                      color: primaryColor,
                      fontSize: 16,
//                       fontWeight: FontWeight.w600
                    )),
                margin:new EdgeInsets.symmetric(horizontal: 11.0),
              )
            ],
          ),
        ),
      );

      Container result;
      switch (type) {
        case 0:
          result = textContainer;
          break;
        case 1:
          result = imageContainer;
          break;
        case 2:
          result = stickerContainer;
          break;
        case 3:
          result = mapContainer;
          break;
        default:
          result = new Container();
      }
      return result;
    }

    // 显示对方消息
    Container showLeftMassage(int type, String msg) {
      Container textContainer = new Container(
        child: Text(
          document['content'],
          style: TextStyle(color: Colors.white),
        ),
        padding: EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 10.0),
        width: 200.0,
        decoration: BoxDecoration(
            color: primaryColor, borderRadius: BorderRadius.circular(8.0)),
        margin: EdgeInsets.only(left: 10.0),
      );
      Container imageContainer = new Container(
        child: FlatButton(
          child: Material(
            child: CachedNetworkImage(
              placeholder: (context, url) => Container(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                ),
                width: 200.0,
                height: 200.0,
                padding: EdgeInsets.all(70.0),
                decoration: BoxDecoration(
                  color: greyColor2,
                  borderRadius: BorderRadius.all(
                    Radius.circular(8.0),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Material(
                child: Image.asset(
                  'images/img_not_available.jpeg',
                  width: 200.0,
                  height: 200.0,
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.all(
                  Radius.circular(8.0),
                ),
                clipBehavior: Clip.hardEdge,
              ),
              imageUrl: document['content'],
              width: 200.0,
              height: 200.0,
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            clipBehavior: Clip.hardEdge,
          ),
          onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => FullPhoto(url: document['content'])));
          },
          padding: EdgeInsets.all(0),
        ),
        margin: EdgeInsets.only(left: 10.0),
      );

      Container stickerContainer = new Container(
        child: new Image.asset(
          'images/${document['content']}.gif',
          width: 100.0,
          height: 100.0,
          fit: BoxFit.cover,
        ),
        margin: EdgeInsets.only(
            bottom: isLastMessageRight(index) ? 20.0 : 10.0, right: 10.0),
      );
      void _gotoMapPage() {
        print(msg);
        UserPosition position = UserPosition.fromJson(jsonDecode(msg));
        print(position.toString());
        Navigator.push(
          context,
          // 需要修改
          new MaterialPageRoute(builder: (context) => MapPage(position: UserPosition.fromJson(jsonDecode(msg)))),
        );
      }
      Container mapContainer = new Container(
        padding: EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 10.0),
        width: 200.0,
        decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(8.0)),
        margin: EdgeInsets.only(left: 10.0),

        child: new GestureDetector(
          onTap: _gotoMapPage,
          child: Row(
            children: <Widget>[

              Container(
                child: new Image.asset(
                  'images/position.png',
                  width: 60.0,
                  height: 60.0,
//                  fit: BoxFit.cover,
                ),
                margin: EdgeInsets.only(left: 6.0),
              ),
             Container(
               child:  new Text('对方的位置',
                   style: new TextStyle(
                       color: Colors.white,
                       fontSize: 16,
//                       fontWeight: FontWeight.w600
                   )),
               margin:new EdgeInsets.symmetric(horizontal: 11.0),
             )
            ],
          ),
        ),
      );
      Container result;
      switch (type) {
        case 0:
          result = textContainer;
          break;
        case 1:
          result = imageContainer;
          break;
        case 2:
          result = stickerContainer;
          break;
        case 3:
          result = mapContainer;
          break;
        default:
          result = new Container();
      }
      return result;
    }

    if (document['idFrom'] == id) {
      // Right (my message)
      return Row(
        children: <Widget>[
          showRightMassage(document['type'], document['content'])
        ],
        mainAxisAlignment: MainAxisAlignment.end,
      );
    } else {
      // Left (peer message)
      return Container(
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                // show the peerAvatar（对方头像）
                isLastMessageLeft(index)
                    ? Material(
                        child: CachedNetworkImage(
                          placeholder: (context, url) => Container(
                            child: CircularProgressIndicator(
                              strokeWidth: 1.0,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(themeColor),
                            ),
                            width: 35.0,
                            height: 35.0,
                            padding: EdgeInsets.all(10.0),
                          ),
                          imageUrl: peerAvatar,
                          width: 35.0,
                          height: 35.0,
                          fit: BoxFit.cover,
                        ),
                        borderRadius: BorderRadius.all(
                          Radius.circular(18.0),
                        ),
                        clipBehavior: Clip.hardEdge,
                      )
                    : Container(width: 35.0),

                showLeftMassage(document['type'], document['content'])
              ],
            ),

            // Time
            isLastMessageLeft(index)
                ? Container(
                    child: Text(
                      DateFormat('dd MMM kk:mm').format(
                          DateTime.fromMillisecondsSinceEpoch(
                              int.parse(document['timestamp']))),
                      style: TextStyle(
                          color: greyColor,
                          fontSize: 12.0,
                          fontStyle: FontStyle.italic),
                    ),
                    margin: EdgeInsets.only(left: 50.0, top: 5.0, bottom: 5.0),
                  )
                : Container()
          ],
          crossAxisAlignment: CrossAxisAlignment.start,
        ),
        margin: EdgeInsets.only(bottom: 10.0),
      );
    }
  }

  // 在屏幕上，对方为最后一条消息
  // 最后一条消息，下面为输入框或自己消息，空格加大
  bool isLastMessageLeft(int index) {
    if ((index > 0 &&
            listMessage != null &&
            listMessage[index - 1]['idFrom'] == id) ||
        index == 0) {
      return true;
    } else {
      return false;
    }
  }

  // 在屏幕上，我方为最后一条消息
  bool isLastMessageRight(int index) {
    if ((index > 0 &&
            listMessage != null &&
            listMessage[index - 1]['idFrom'] != id) ||
        index == 0) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> onBackPress() {
    if (isShowSticker) {
      setState(() {
        isShowSticker = false;
      });
    } else {
      Firestore.instance
          .collection('users')
          .document(id)
          .updateData({'chattingWith': null});
      Navigator.pop(context);
    }

    return Future.value(false);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              // List of messages
              buildListMessage(),

              // Sticker
              (isShowSticker ? buildSticker() : Container()),

              // Input content
              buildInput(),
            ],
          ),

          // Loading
          buildLoading()
        ],
      ),
      onWillPop: onBackPress,
    );
  }

  Widget buildSticker() {
    return Container(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              FlatButton(
                onPressed: () => onSendMessage('mimi1', 2),
                child: new Image.asset(
                  'images/mimi1.gif',
                  width: 50.0,
                  height: 50.0,
                  fit: BoxFit.cover,
                ),
              ),
              FlatButton(
                onPressed: () => onSendMessage('mimi2', 2),
                child: new Image.asset(
                  'images/mimi2.gif',
                  width: 50.0,
                  height: 50.0,
                  fit: BoxFit.cover,
                ),
              ),
              FlatButton(
                onPressed: () => onSendMessage('mimi3', 2),
                child: new Image.asset(
                  'images/mimi3.gif',
                  width: 50.0,
                  height: 50.0,
                  fit: BoxFit.cover,
                ),
              )
            ],
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          ),
          Row(
            children: <Widget>[
              FlatButton(
                onPressed: () => onSendMessage('mimi4', 2),
                child: new Image.asset(
                  'images/mimi4.gif',
                  width: 50.0,
                  height: 50.0,
                  fit: BoxFit.cover,
                ),
              ),
              FlatButton(
                onPressed: () => onSendMessage('mimi5', 2),
                child: new Image.asset(
                  'images/mimi5.gif',
                  width: 50.0,
                  height: 50.0,
                  fit: BoxFit.cover,
                ),
              ),
              FlatButton(
                onPressed: () => onSendMessage('mimi6', 2),
                child: new Image.asset(
                  'images/mimi6.gif',
                  width: 50.0,
                  height: 50.0,
                  fit: BoxFit.cover,
                ),
              )
            ],
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          ),
          Row(
            children: <Widget>[
              FlatButton(
                onPressed: () => onSendMessage('mimi7', 2),
                child: new Image.asset(
                  'images/mimi7.gif',
                  width: 50.0,
                  height: 50.0,
                  fit: BoxFit.cover,
                ),
              ),
              FlatButton(
                onPressed: () => onSendMessage('mimi8', 2),
                child: new Image.asset(
                  'images/mimi8.gif',
                  width: 50.0,
                  height: 50.0,
                  fit: BoxFit.cover,
                ),
              ),
              FlatButton(
                onPressed: () => onSendMessage('mimi9', 2),
                child: new Image.asset(
                  'images/mimi9.gif',
                  width: 50.0,
                  height: 50.0,
                  fit: BoxFit.cover,
                ),
              )
            ],
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          )
        ],
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      ),
      decoration: new BoxDecoration(
          border:
              new Border(top: new BorderSide(color: greyColor2, width: 0.5)),
          color: Colors.white),
      padding: EdgeInsets.all(5.0),
      height: 180.0,
    );
  }

  Widget buildLoading() {
    return Positioned(
      child: isLoading
          ? Container(
              child: Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(themeColor)),
              ),
              color: Colors.white.withOpacity(0.8),
            )
          : Container(),
    );
  }

  // 异步发送位置数据
  _getPosition() {
    Future<Position> p = Geolocator().getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
   p.then((v){
     onSendMessage( jsonEncode(new UserPosition(latitude: v.latitude,longitude: v.longitude)), 3);
   });
  }

  Widget buildInput() {
    return Container(
      child: Row(
        children: <Widget>[
          // Button send image
          Material(
            child: new Container(
              margin: new EdgeInsets.symmetric(horizontal: 0.0),
              child: new IconButton(
                icon: new Icon(Icons.image),
                onPressed: getImage,
                color: primaryColor,
              ),
            ),
            color: Colors.white,
          ),
          Material(
            child: new Container(
              margin: new EdgeInsets.symmetric(horizontal: 0.0),
              child: new IconButton(
                icon: new Icon(Icons.face),
                onPressed: getSticker,
                color: primaryColor,
              ),
            ),
            color: Colors.white,
          ),
          Material(
            child: new Container(
              margin: new EdgeInsets.symmetric(horizontal: 0.0),
              child: new IconButton(
                icon: new Icon(Icons.add_location),
                color: primaryColor,
                onPressed: _getPosition,
              ),
            ),
            color: Colors.white,
          ),
          // Edit text
          Flexible(
            child: Container(
              child: TextField(
                style: TextStyle(color: primaryColor, fontSize: 15.0),
                controller: textEditingController,
                decoration: InputDecoration.collapsed(
                  hintText: '输入消息...',
                  hintStyle: TextStyle(color: greyColor),
                ),
                focusNode: focusNode,
              ),
            ),
          ),

          // Button send message
          Material(
            child: new Container(
              margin: new EdgeInsets.symmetric(horizontal: 8.0),
              child: new IconButton(
                icon: new Icon(Icons.send),
                onPressed: () => onSendMessage(textEditingController.text, 0),
                color: primaryColor,
              ),
            ),
            color: Colors.white,
          ),
        ],
      ),
      width: double.infinity,
      height: 50.0,
      decoration: new BoxDecoration(
          border:
              new Border(top: new BorderSide(color: greyColor2, width: 0.5)),
          color: Colors.white),
    );
  }

  Widget buildListMessage() {
    return Flexible(
      child: groupChatId == ''
          ? Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(themeColor)))
          : StreamBuilder(
              stream: Firestore.instance
                  .collection('messages')
                  .document(groupChatId)
                  .collection(groupChatId)
                  .orderBy('timestamp', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                      child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(themeColor)));
                } else {
                  listMessage = snapshot.data.documents;
                  return ListView.builder(
                    padding: EdgeInsets.all(10.0),
                    itemBuilder: (context, index) =>
                        buildItem(index, snapshot.data.documents[index]),
                    itemCount: snapshot.data.documents.length,
                    reverse: true,
                    controller: listScrollController,
                  );
                }
              },
            ),
    );
  }
}

//rubbish
// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Wrapper over the analysis server providing a simplified API and automatic
/// handling of reliability.
library atom.analysis_server;

import 'dart:async';

import 'package:analysis_server_lib/analysis_server_lib.dart';
import 'package:atom/atom.dart';
import 'package:atom/node/fs.dart';
import 'package:atom/node/notification.dart';
import 'package:atom/node/package.dart';
import 'package:atom/node/process.dart';
import 'package:atom/node/workspace.dart';
import 'package:atom/utils/disposable.dart';
import 'package:atom/utils/string_utils.dart';
import 'package:logging/logging.dart';

import 'dartino/dartino.dart' show dartino;
import 'jobs.dart';
import 'plugin.dart' show pluginVersion;
import 'projects.dart';
import 'sdk.dart';
import 'state.dart';

export 'package:analysis_server_lib/analysis_server_lib.dart'
    show
        FormatResult,
        HoverInformation,
        HoverResult,
        RequestError,
        AvailableRefactoringsResult,
        RefactoringResult,
        RefactoringOptions,
        SourceEdit,
        SourceFileEdit,
        AnalysisOutline,
        Outline,
        AddContentOverlay,
        ChangeContentOverlay,
        RemoveContentOverlay,
        AnalysisErrors,
        AnalysisFlushResults;

export 'jobs.dart' show Job;

final Logger _logger = new Logger('analysis-server');

class AtomAnalysisServer implements Disposable {
  static bool get startWithDiagnostics =>
      atom.config.getBoolValue('${pluginId}.debugAnalysisServer');
  static bool get useChecked =>
      atom.config.getBoolValue('${pluginId}.analysisServerUseChecked');

  static final int DIAGNOSTICS_PORT = 23072;

  static String get diagnosticsUrl => 'http://localhost:${DIAGNOSTICS_PORT}';

  StreamSubscriptions subs = new StreamSubscriptions();
  Disposables disposables = new Disposables();

  StreamController<bool> _serverActiveController =
      new StreamController.broadcast();
  StreamController<bool> _serverBusyController =
      new StreamController.broadcast();
  StreamController<String> _onSendController = new StreamController.broadcast();
  StreamController<String> _onReceiveController =
      new StreamController.broadcast();
  StreamController<AnalysisNavigation> _onNavigatonController =
      new StreamController.broadcast();
  StreamController<AnalysisOutline> _onOutlineController =
      new StreamController.broadcast();

  _AnalysisServerWrapper _server;
  _AnalyzingJob _job;

  MethodSend _willSend;

  List<DartProject> knownRoots = [];

  AtomAnalysisServer() {
    Timer.run(_setup);

    bool firstNotification = true;

    onActive.listen((value) {
      if (firstNotification) {
        firstNotification = false;
        return;
      }

      if (value) {
        atom.notifications.addInfo('Dart analysis server starting up.');
      } else {
        if (projectManager.projects.isEmpty) {
          atom.notifications.addInfo(
              'Dart analysis server shutting down (no Dart projects open).');
        } else {
          atom.notifications.addInfo('Dart analysis server shutting down.');
        }
      }
    });
  }

  Stream<bool> get onActive => _serverActiveController.stream;
  Stream<bool> get onBusy => _serverBusyController.stream;

  Stream<String> get onSend => _onSendController.stream;
  Stream<String> get onReceive => _onReceiveController.stream;

  Stream<AnalysisNavigation> get onNavigaton => _onNavigatonController.stream;
  Stream<AnalysisOutline> get onOutline => _onOutlineController.stream;

  Stream<AnalysisErrors> get onAnalysisErrors =>
      analysisServer._server.analysis.onErrors;
  Stream<AnalysisFlushResults> get onAnalysisFlushResults =>
      analysisServer._server.analysis.onFlushResults;

  AnalysisServer get server => _server;

  set willSend(void fn(String methodName)) {
    _willSend = fn;
    if (_server != null) {
      _server.willSend = _willSend;
    }
  }

  void _setup() {
    subs.add(projectManager.onProjectsChanged.listen(_reconcileRoots));
    subs.add(sdkManager.onSdkChange.listen(_handleSdkChange));

    editorManager.dartProjectEditors.onActiveEditorChanged
        .listen(_focusedEditorChanged);

    knownRoots.clear();
    knownRoots.addAll(projectManager.projects);

    _checkTrigger();

    var trim =
        (String str) => str.length > 260 ? str.substring(0, 260) + '…' : str;

    onSend.listen((String message) {
      if (_logger.isLoggable(Level.FINER)) {
        _logger.finer('--> ${trim(message)}');
      }
    });

    onReceive.listen((String message) {
      if (message.startsWith('Observatory listening')) {
        message = message.trim();
        if (AtomAnalysisServer.startWithDiagnostics) {
          message +=
              '\nAnalysis server diagnostics on ${AtomAnalysisServer.diagnosticsUrl}';
        }
        atom.notifications
            .addInfo('Analysis server', detail: message, dismissable: true);
      }

      if (message.startsWith('Observatory no longer listening')) {
        atom.notifications.addInfo('Analysis server',
            detail: message.trim(), dismissable: true);
      }

      if (_logger.isLoggable(Level.FINER)) {
        _logger.finer('<-- ${trim(message)}');
      }
    });
  }

  /// Returns whether the analysis server is active and running.
  bool get isActive => _server != null && _server.isRunning;

  bool get isBusy => _server != null && _server.analyzing;

  /// Subscribe to this to get told when the issues list has changed.
  Stream get issuesUpdatedNotification => null;

  Future<ErrorsResult> getErrors(String filePath) {
    if (isActive) {
      return _server.analysis.getErrors(filePath);
    } else {
      return new Future.value(new ErrorsResult([]));
    }
  }

  void updateRoots() {
    if (isActive) {
      List<String> roots = new List.from(knownRoots.map((dir) => dir.path));
      var pkgRoots = <String, String>{};
      for (String root in roots) {
        if (dartino.isProject(root)) {
          String pkgRoot = dartino.sdkFor(root, quiet: true)?.packageRoot(root);
          if (pkgRoot != null) pkgRoots[root] = pkgRoot;
        }
      }
      _logger.fine("setAnalysisRoots(${roots}, packageRoots: $pkgRoots)");
      _server.analysis.setAnalysisRoots(roots, [], packageRoots: pkgRoots);
    }
  }

  void dispose() {
    _logger.fine('dispose()');

    _checkTrigger(dispose: true);

    subs.cancel();
    disposables.dispose();
  }

  void _reconcileRoots(List<DartProject> currentProjects) {
    Set oldSet = new Set.from(knownRoots);
    Set currentSet = new Set.from(currentProjects);

    Set addedProjects = currentSet.difference(oldSet);
    Set removedProjects = oldSet.difference(currentSet);

    // Create a copy of the list.
    knownRoots.clear();
    knownRoots.addAll(currentProjects);

    if (removedProjects.isNotEmpty) {
      _logger.fine("removed: ${removedProjects}");
      removedProjects.forEach(
          (project) => errorRepository.clearForDirectory(project.directory));
    }

    if (addedProjects.isNotEmpty) _logger.fine("added: ${addedProjects}");

    if (removedProjects.isNotEmpty || addedProjects.isNotEmpty) {
      updateRoots();
    }

    _checkTrigger();
  }

  void _handleSdkChange(Sdk newSdk) {
    _checkTrigger();
  }

  void _focusedEditorChanged(TextEditor editor) {
    if (!isActive || editor == null) return;

    String path = editor.getPath();

    if (path != null) {
      _server.analysis.setSubscriptions({
        'NAVIGATION': [path],
        'OUTLINE': [path]
      });

      server.analysis.setPriorityFiles([path]).catchError((e) {
        if (e is RequestError && e.code == 'UNANALYZED_PRIORITY_FILES') {
          AnalysisOutline outline = new AnalysisOutline(path, null, null);
          _onOutlineController.add(outline);
        } else {
          _logger.warning('Error from setPriorityFiles()', e);
        }
      });
    }
  }

  /// Explicitly and manually start the analysis server. This will not succeed
  /// if there is no SDK.
  void start() {
    if (!sdkManager.hasSdk) return;

    if (_server == null) {
      _AnalysisServerWrapper server =
          _AnalysisServerWrapper.create(sdkManager.sdk);
      _server = server;
      _initNewServer(server);
    } else if (!_server.isRunning) {
      _server.restart(sdkManager.sdk);
      _initExistingServer(_server);
    }
  }

  /// Reanalyze the world.
  void reanalyzeSources() {
    if (isActive) _server.analysis.reanalyze();
  }

  Stream<SearchResult> _searchResultsStream(String id) {
    StreamSubscription sub;
    StreamController<SearchResult> controller =
        new StreamController(onCancel: () => sub.cancel());

    sub = server.search.onResults.listen((SearchResults result) {
      if (id == result.id && !controller.isClosed) {
        for (SearchResult r in result.results) {
          controller.add(r);
        }

        if (result.isLast) {
          sub.cancel();
          controller.close();
        }
      }
    });

    return controller.stream;
  }

  Future<List<SearchResult>> getSearchResults(String searchId) {
    return _searchResultsStream(searchId).toList();
  }

  Future<FormatResult> format(
      String path, int selectionOffset, int selectionLength,
      {int lineLength}) {
    return server.edit
        .format(path, selectionOffset, selectionLength, lineLength: lineLength);
  }

  Future<AvailableRefactoringsResult> getAvailableRefactorings(
      String path, int offset, int length) {
    return server.edit.getAvailableRefactorings(path, offset, length);
  }

  Future<RefactoringResult> getRefactoring(
      String kind, String path, int offset, int length, bool validateOnly,
      {RefactoringOptions options}) {
    return server.edit.getRefactoring(kind, path, offset, length, validateOnly,
        options: options);
  }

  Future<NavigationResult> getNavigation(String path, int offset, int length) {
    return server.analysis.getNavigation(path, offset, length);
  }

  Future<FixesResult> getFixes(String path, int offset) {
    return server.edit.getFixes(path, offset);
  }

  Future<AssistsResult> getAssists(String path, int offset, int length) {
    return server.edit.getAssists(path, offset, length);
  }

  Future<HoverResult> getHover(String file, int offset) {
    return server.analysis.getHover(file, offset);
  }

  Future<FindElementReferencesResult> findElementReferences(
      String path, int offset, bool includePotential) {
    return server.search.findElementReferences(path, offset, includePotential);
  }

  Future<TypeHierarchyResult> getTypeHierarchy(String path, int offset) =>
      server.search.getTypeHierarchy(path, offset);

  /// Update the given file with a new overlay. [contentOverlay] can be one of
  /// [AddContentOverlay], [ChangeContentOverlay], or [RemoveContentOverlay].
  Future updateContent(String path, ContentOverlayType contentOverlay) {
    return server.analysis.updateContent({path: contentOverlay});
  }

  /// If an analysis server is running, terminate it.
  void shutdown() {
    if (_server != null) _server.kill();
  }

  void _checkTrigger({bool dispose: false}) {
    bool shouldBeRunning = knownRoots.isNotEmpty && sdkManager.hasSdk;

    if (dispose || (!shouldBeRunning && _server != null)) {
      // shutdown
      if (_server != null) _server.kill();
    } else if (shouldBeRunning) {
      // startup
      if (_server == null) {
        _AnalysisServerWrapper server =
            _AnalysisServerWrapper.create(sdkManager.sdk);
        _server = server;
        _initNewServer(server);
      } else if (!_server.isRunning) {
        _server.restart(sdkManager.sdk);
        _initExistingServer(_server);
      }
    }
  }

  void _initNewServer(_AnalysisServerWrapper server) {
    server.onAnalyzing.listen((value) => _serverBusyController.add(value));
    server.onDisposed.listen((exitCode) => _handleServerDeath(server));

    server.onSend.listen((message) => _onSendController.add(message));
    server.onReceive.listen((message) => _onReceiveController.add(message));

    server.analysis.onNavigation.listen((e) => _onNavigatonController.add(e));
    server.analysis.onOutline.listen((e) => _onOutlineController.add(e));

    onBusy.listen((busy) {
      if (!busy && _job != null) {
        _job.finish();
        _job = null;
      } else if (busy && _job == null) {
        _job = new _AnalyzingJob()..start();
      }
    });

    _initExistingServer(server);
  }

  void _initExistingServer(AnalysisServer server) {
    server.willSend = _willSend;
    _serverActiveController.add(true);
    updateRoots();
    _focusedEditorChanged(editorManager.dartProjectEditors.activeEditor);
  }

  void _handleServerDeath(AnalysisServer server) {
    if (_server == server) {
      _serverActiveController.add(false);
      _serverBusyController.add(false);
      errorRepository.clearAll();
    }
  }
}

class _AnalyzingJob extends Job {
  static const Duration _debounceDelay = const Duration(milliseconds: 400);

  Completer completer = new Completer();
  VoidHandler _infoAction;

  _AnalyzingJob() : super('Analyzing source') {
    _infoAction = () {
      statusViewManager.showSection('analysis-server');
    };
  }

  bool get quiet => true;

  VoidHandler get infoAction => _infoAction;

  Future run() => completer.future;

  void start() {
    // Debounce the analysis busy event.
    new Timer(_debounceDelay, () {
      if (!completer.isCompleted) schedule();
    });
  }

  void finish() {
    if (!completer.isCompleted) completer.complete();
  }
}

typedef void _AnalysisServerWriter(String message);

class _AnalysisServerWrapper extends AnalysisServer {
  static _AnalysisServerWrapper create(Sdk sdk) {
    StreamController<String> controller = new StreamController();
    ProcessRunner process = _createProcess(sdk);
    Completer<int> completer = _startProcess(process, controller);

    _AnalysisServerWrapper wrapper = new _AnalysisServerWrapper(
        process, completer, controller.stream, _messageWriter(process));
    wrapper.setup();
    return wrapper;
  }

  ProcessRunner process;
  Completer<int> _processCompleter;
  bool analyzing = false;
  StreamController<bool> _analyzingController =
      new StreamController.broadcast();
  StreamController<int> _disposedController = new StreamController.broadcast();

  _AnalysisServerWrapper(
      this.process,
      this._processCompleter,
      Stream<String> inStream,
      void writeMessage(String message))
      : super(inStream, writeMessage, _processCompleter) {
    _processCompleter.future.then((result) {
      _disposedController.add(result);
      process = null;
    });
  }

  void setup() {
    server.setSubscriptions(['STATUS']);

    server.getVersion().then((v) => _logger.info('version ${v.version}'));
    server.onStatus.listen((ServerStatus status) {
      if (status.analysis != null) {
        analyzing = status.analysis.isAnalyzing;
        _analyzingController.add(analyzing);
      }
    });

    server.onError.listen((ServerError error) {
      StackTrace st = error.stackTrace == null
          ? null
          : new StackTrace.fromString(error.stackTrace);

      _logger.info(error.message, null, st);

      Notification notification;

      List<NotificationButton> buttons = [
        new NotificationButton('Report Error', () {
          notification.dismiss();
          _reportError(error);
        })
      ];

      if (error.isFatal) {
        notification = atom.notifications.addError(
            'Error from the analysis server: ${error.message}',
            detail: error.stackTrace,
            dismissable: true,
            buttons: buttons);
      } else {
        notification = atom.notifications.addWarning(
            'Error from the analysis server: ${error.message}',
            detail: error.stackTrace,
            dismissable: true,
            buttons: buttons);
      }
    });
  }

  Future _reportError(ServerError error) async {
    String sdkVersion = await sdkManager.sdk.getVersion();
    String pluginVersion = await atomPackage.getPackageVersion();

    String text = '''
Please report the following to https://github.com/dart-lang/sdk/issues/new:
Exception from analysis server (running from Atom)
### what happened
<please describe what you were doing when this exception occurred>
### version information
- Dart SDK ${sdkVersion}
- Atom ${atom.getVersion()}
- ${pluginId} ${pluginVersion}
### the exception
${error.message} ${error.isFatal ? ' (fatal)' : ''}
```
${error.stackTrace?.trim()}
```
''';

    String filePath = fs.join(fs.tmpdir, 'bug.md');
    fs.writeFileSync(filePath, text);
    atom.workspace.openPending(filePath);
  }

  bool get isRunning => process != null;

  Stream<bool> get onAnalyzing => _analyzingController.stream;

  Stream<int> get onDisposed => _disposedController.stream;

  /// Restarts, or starts, the analysis server process.
  void restart(Sdk sdk) {
    var startServer = () {
      StreamController<String> controller = new StreamController();
      process = _createProcess(sdk);
      _processCompleter = _startProcess(process, controller);
      _processCompleter.future.then((result) {
        _disposedController.add(result);
        process = null;
      });
      configure(controller.stream, _messageWriter(process));
      setup();
    };

    if (isRunning) {
      process.kill().then((_) => startServer());
    } else {
      startServer();
    }
  }

  Future<int> kill() {
    _logger.fine("server forcibly terminated");

    if (process != null) {
      try {
        server.shutdown().catchError((e) => null);
      } catch (e) {}

      /*Future f =*/ process.kill();
      process = null;

      try {
        dispose();
      } catch (e) {}

      if (!_processCompleter.isCompleted) _processCompleter.complete(0);

      return new Future.value(0);
    } else {
      _logger.info("kill signal sent to dead analysis server");
      return new Future.value(1);
    }
  }

  /// Creates a process.
  static ProcessRunner _createProcess(Sdk sdk) {
    List<String> arguments = <String>[];

    // Start in checked mode?
    if (AtomAnalysisServer.useChecked) {
      arguments.add('--checked');
    }

    if (AtomAnalysisServer.startWithDiagnostics) {
      arguments.add('--enable-vm-service=0');
    }

    String path = sdk.getSnapshotPath('analysis_server.dart.snapshot');

    // Run from source if local config points to analysis_server/bin/server.dart.
    final String pathPref = '${pluginId}.analysisServerPath';
    String serverPath = atom.config.getValue(pathPref);
    if (serverPath is String) {
      atom.notifications.addSuccess('Running analysis server from source',
          detail: serverPath);
      path = serverPath;
    } else if (serverPath != null) {
      atom.notifications.addError('$pathPref is defined but not a String');
    }

    arguments.add(path);

    // Specify the path to the SDK.
    arguments.add('--sdk=${sdk.path}');

    // Check to see if we should start with diagnostics enabled.
    if (AtomAnalysisServer.startWithDiagnostics) {
      arguments.add('--port=${AtomAnalysisServer.DIAGNOSTICS_PORT}');
      _logger.info('analysis server diagnostics available at '
          '${AtomAnalysisServer.diagnosticsUrl}.');
    }

    arguments.add('--client-id=atom-dart');
    arguments.add('--client-version=${pluginVersion}');

    // Allow arbitrary CLI options to the analysis server.
    final String optionsPrefPath = '${pluginId}.analysisServerOptions';
    if (atom.config.getValue(optionsPrefPath) != null) {
      dynamic options = atom.config.getValue(optionsPrefPath);
      if (options is List) {
        arguments.addAll(new List.from(options));
      } else if (options is String) {
        arguments.addAll(options.split('\n'));
      }
    }

    return new ProcessRunner(sdk.dartVm.path, args: arguments);
  }

  /// Starts a process, and returns a [Completer] that completes when the
  /// process is no longer running.
  static Completer<int> _startProcess(
      ProcessRunner process, StreamController sc) {
    Completer<int> completer = new Completer();
    process.onStderr.listen((String str) => _logger.severe(str.trim()));

    process.onStdout.listen((String str) {
      List<String> lines = str.trim().split('\n');
      for (String line in lines) {
        sc.add(line.trim());
      }
    });

    process.execStreaming().then((int exitCode) {
      _logger.fine("exited with code ${exitCode}");
      if (!completer.isCompleted) completer.complete(exitCode);
    });

    return completer;
  }

  /// Returns a function that writes to a process stream.
  static _AnalysisServerWriter _messageWriter(ProcessRunner process) {
    return (String message) {
      if (process != null) process.write("${message}\n");
    };
  }
}

// TODO: We need more visible progress for this job - it should put up a toast
// after a ~400ms delay.

typedef Future PerformRequest();

/// A [Job] implementation to wrap calls to the analysis server. It will not run
/// if the analysis server is not active. If the call results in an error from
/// the analysis server, the error will be displayed in a toast and will not be
/// passed back from the returned Future.
class AnalysisRequestJob extends Job {
  final PerformRequest _fn;

  AnalysisRequestJob(String name, this._fn) : super(toTitleCase(name));

  bool get quiet => true;

  Future run() {
    if (!analysisServer.isActive) {
      atom.beep();
      return new Future.value();
    }

    return _fn().catchError((e) {
      if (!analysisServer.isActive) return null;

      if (e is RequestError) {
        atom.notifications
            .addError('${name} error', detail: '${e.message} (${e.code})');

        if (e.stackTrace == null) {
          _logger.warning('${name} error', e);
        } else {
          _logger.warning(
              '${name} error', e, new StackTrace.fromString(e.stackTrace));
        }

        return null;
      } else {
        throw e;
      }
    });
  }
}
