import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:easy_chat_app/const.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(
          '设置',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: new SettingsScreen(),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  @override
  State createState() => new SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  TextEditingController controllerNickname;
  TextEditingController controllerAboutMe;

  SharedPreferences prefs;

  String id = '';
  String nickname = '';
  String aboutMe = '';
  String photoUrl = '';

  bool isLoading = false;
  File avatarImageFile;

  final FocusNode focusNodeNickname = new FocusNode();
  final FocusNode focusNodeAboutMe = new FocusNode();

  @override
  void initState() {
    super.initState();
    readLocal();
  }

  void readLocal() async {
    prefs = await SharedPreferences.getInstance();
    id = prefs.getString('id') ?? '';
    nickname = prefs.getString('nickname') ?? '';
    aboutMe = prefs.getString('aboutMe') ?? '';
    photoUrl = prefs.getString('photoUrl') ?? '';

    controllerNickname = new TextEditingController(text: nickname);
    controllerAboutMe = new TextEditingController(text: aboutMe);

    // Force refresh input
    setState(() {});
  }

  Future getImage() async {
    File image = await ImagePicker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        avatarImageFile = image;
        isLoading = true;
      });
    }
    uploadFile();
  }

  Future uploadFile() async {
    String fileName = id;
    StorageReference reference = FirebaseStorage.instance.ref().child(fileName);
    StorageUploadTask uploadTask = reference.putFile(avatarImageFile);
    StorageTaskSnapshot storageTaskSnapshot;
    uploadTask.onComplete.then((value) {
      if (value.error == null) {
        storageTaskSnapshot = value;
        storageTaskSnapshot.ref.getDownloadURL().then((downloadUrl) {
          photoUrl = downloadUrl;
          Firestore.instance
              .collection('users')
              .document(id)
              .updateData({'nickname': nickname, 'aboutMe': aboutMe, 'photoUrl': photoUrl}).then((data) async {
            await prefs.setString('photoUrl', photoUrl);
            setState(() {
              isLoading = false;
            });
            Fluttertoast.showToast(msg: "更新成功");
          }).catchError((err) {
            setState(() {
              isLoading = false;
            });
            Fluttertoast.showToast(msg: err.toString());
          });
        }, onError: (err) {
          setState(() {
            isLoading = false;
          });
          Fluttertoast.showToast(msg: '这不是图片文件');
        });
      } else {
        setState(() {
          isLoading = false;
        });
        Fluttertoast.showToast(msg: '这不是图片文件');
      }
    }, onError: (err) {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(msg: err.toString());
    });
  }

  void handleUpdateData() {
    focusNodeNickname.unfocus();
    focusNodeAboutMe.unfocus();

    setState(() {
      isLoading = true;
    });

    Firestore.instance
        .collection('users')
        .document(id)
        .updateData({'nickname': nickname, 'aboutMe': aboutMe, 'photoUrl': photoUrl}).then((data) async {
      await prefs.setString('nickname', nickname);
      await prefs.setString('aboutMe', aboutMe);
      await prefs.setString('photoUrl', photoUrl);

      setState(() {
        isLoading = false;
      });

      Fluttertoast.showToast(msg: "更新成功");
    }).catchError((err) {
      setState(() {
        isLoading = false;
      });

      Fluttertoast.showToast(msg: err.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        SingleChildScrollView(
          child: Column(
            children: <Widget>[
              // Avatar
              Container(
                child: Center(
                  child: Stack(
                    children: <Widget>[
                      (avatarImageFile == null)
                          ? (photoUrl != ''
                              ? Material(
                                  child: CachedNetworkImage(
                                    placeholder: (context, url) => Container(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.0,
                                            valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                                          ),
                                          width: 90.0,
                                          height: 90.0,
                                          padding: EdgeInsets.all(20.0),
                                        ),
                                    imageUrl: photoUrl,
                                    width: 90.0,
                                    height: 90.0,
                                    fit: BoxFit.cover,
                                  ),
                                  borderRadius: BorderRadius.all(Radius.circular(45.0)),
                                  clipBehavior: Clip.hardEdge,
                                )
                              : Icon(
                                  Icons.account_circle,
                                  size: 90.0,
                                  color: greyColor,
                                ))
                          : Material(
                              child: Image.file(
                                avatarImageFile,
                                width: 90.0,
                                height: 90.0,
                                fit: BoxFit.cover,
                              ),
                              borderRadius: BorderRadius.all(Radius.circular(45.0)),
                              clipBehavior: Clip.hardEdge,
                            ),
                      IconButton(
                        icon: Icon(
                          Icons.camera_alt,
                          color: primaryColor.withOpacity(0.5),
                        ),
                        onPressed: getImage,
                        padding: EdgeInsets.all(30.0),
                        splashColor: Colors.transparent,
                        highlightColor: greyColor,
                        iconSize: 30.0,
                      ),
                    ],
                  ),
                ),
                width: double.infinity,
                margin: EdgeInsets.all(20.0),
              ),

              // Input
              Column(
                children: <Widget>[
                  // Username
                  Container(
                    child: Text(
                      '昵称',
                      style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                    margin: EdgeInsets.only(left: 10.0, bottom: 5.0, top: 10.0),
                  ),
                  Container(
                    child: Theme(
                      data: Theme.of(context).copyWith(primaryColor: primaryColor),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Sweetie',
                          contentPadding: new EdgeInsets.all(5.0),
                          hintStyle: TextStyle(color: greyColor),
                        ),
                        controller: controllerNickname,
                        onChanged: (value) {
                          nickname = value;
                        },
                        focusNode: focusNodeNickname,
                      ),
                    ),
                    margin: EdgeInsets.only(left: 30.0, right: 30.0),
                  ),

                  // About me
                  Container(
                    child: Text(
                      '关于我',
                      style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                    margin: EdgeInsets.only(left: 10.0, top: 30.0, bottom: 5.0),
                  ),
                  Container(
                    child: Theme(
                      data: Theme.of(context).copyWith(primaryColor: primaryColor),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: '设置个人简介',
                          contentPadding: EdgeInsets.all(5.0),
                          hintStyle: TextStyle(color: greyColor),
                        ),
                        controller: controllerAboutMe,
                        onChanged: (value) {
                          aboutMe = value;
                        },
                        focusNode: focusNodeAboutMe,
                      ),
                    ),
                    margin: EdgeInsets.only(left: 30.0, right: 30.0),
                  ),
                ],
                crossAxisAlignment: CrossAxisAlignment.start,
              ),

              // Button
              Container(
                child: FlatButton(
                  onPressed: handleUpdateData,
                  child: Text(
                    '更新',
                    style: TextStyle(fontSize: 16.0),
                  ),
                  color: primaryColor,
                  highlightColor: new Color(0xff8d93a0),
                  splashColor: Colors.transparent,
                  textColor: Colors.white,
                  padding: EdgeInsets.fromLTRB(30.0, 10.0, 30.0, 10.0),
                ),
                margin: EdgeInsets.only(top: 50.0, bottom: 50.0),
              ),
            ],
          ),
          padding: EdgeInsets.only(left: 15.0, right: 15.0),
        ),

        // Loading
        Positioned(
          child: isLoading
              ? Container(
                  child: Center(
                    child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(themeColor)),
                  ),
                  color: Colors.white.withOpacity(0.8),
                )
              : Container(),
        ),
      ],
    );
  }
}

//rubbish
library rx;

export 'src/rx.dart';
export 'src/streams/connectable_stream.dart';
export 'src/utils/composite_subscription.dart';
export 'streams.dart';
export 'subjects.dart';
export 'transformers.dart';

library rx_streams;

export 'src/streams/combine_latest.dart';
export 'src/streams/concat.dart';
export 'src/streams/concat_eager.dart';
export 'src/streams/connectable_stream.dart';
export 'src/streams/defer.dart';
export 'src/streams/fork_join.dart';
export 'src/streams/merge.dart';
export 'src/streams/never.dart';
export 'src/streams/race.dart';
export 'src/streams/range.dart';
export 'src/streams/repeat.dart';
export 'src/streams/replay_stream.dart';
export 'src/streams/retry.dart';
export 'src/streams/retry_when.dart';
export 'src/streams/sequence_equal.dart';
export 'src/streams/switch_latest.dart';
export 'src/streams/timer.dart';
export 'src/streams/utils.dart';
export 'src/streams/value_stream.dart';
export 'src/streams/zip.dart';

library rx_subjects;

export 'src/subjects/subject.dart';
export 'src/subjects/behavior_subject.dart';
export 'src/subjects/publish_subject.dart';
export 'src/subjects/replay_subject.dart';

library rx_transformers;

export 'src/transformers/default_if_empty.dart';
export 'src/transformers/delay.dart';
export 'src/transformers/dematerialize.dart';
export 'src/transformers/distinct_unique.dart';
export 'src/transformers/do.dart';
export 'src/transformers/exhaust_map.dart';
export 'src/transformers/flat_map.dart';
export 'src/transformers/group_by.dart';
export 'src/transformers/ignore_elements.dart';
export 'src/transformers/interval.dart';
export 'src/transformers/map_to.dart';
export 'src/transformers/materialize.dart';
export 'src/transformers/on_error_resume.dart';
export 'src/transformers/min.dart';
export 'src/transformers/max.dart';
export 'src/transformers/scan.dart';
export 'src/transformers/skip_until.dart';
export 'src/transformers/start_with.dart';
export 'src/transformers/start_with_many.dart';
export 'src/transformers/switch_if_empty.dart';
export 'src/transformers/switch_map.dart';
export 'src/transformers/take_until.dart';
export 'src/transformers/time_interval.dart';
export 'src/transformers/timestamp.dart';
export 'src/transformers/where_type.dart';
export 'src/transformers/with_latest_from.dart';
export 'src/utils/notification.dart';

export 'src/transformers/backpressure/buffer.dart';
export 'src/transformers/backpressure/debounce.dart';
export 'src/transformers/backpressure/pairwise.dart';
export 'src/transformers/backpressure/sample.dart';
export 'src/transformers/backpressure/throttle.dart';
export 'src/transformers/backpressure/window.dart';
// Objectives
// 1. Higher-Order Function:
// How to pass function as parameter?
// How to return a function from another function?


void main() {

	// Example One: Passing Function to Higher-Order Function
	Function addNumbers = (a, b) => print(a + b);
	someOtherFunction("Hello", addNumbers);


	// Example Two: Receiving Function from Higher-Order Function
	var myFunc = taskToPerform();
	print(myFunc(10));      // multiplyFour(10)         // number * 4       // 10 * 4       // OUTPUT: 40
}



// Example one: Accepts function as parameter
void someOtherFunction(String message, Function myFunction) {       // Higher-Order Function

	print(message);
	myFunction(2, 4);       // addNumbers(2, 4)    // print(a + b);   // print(2 + 4)       // OUTPUT: 6
}


// Example two: Returns a function
Function taskToPerform() {       // Higher-Order Function

	Function multiplyFour = (int number) => number * 4;
	return multiplyFour;
}void main() {

	// Literals
	var isCool = true;
	int x = 2;
	"John";
	4.5;

	// Various ways to define String Literals in Dart
	String s1 = 'Single';
	String s2 = "Double";
	String s3 = 'It\'s easy';
	String s4 = "It's easy";

	String s5 = 'This is going to be a very long String. '
			'This is just a sample String demo in Dart Programming Language';


	// String Interpolation : Use ["My name is $name"] instead of ["My name is " + name]
	String name = "Kevin";

	print("My name is $name");
	print("The number of characters in String Kevin is ${name.length}");


	int l = 20;
	int b = 10;

	print("The sum of $l and $b is ${l + b}");
	print("The area of rectangle with length $l and breadth $b is ${l * b}");
}


// Objective
// 1. Closures


void main() {

	// Definition 1:
	// A closure is a function that has access to the parent scope, even after the scope has closed.

	String message = "Dar is good";

	Function showMessage = () {
		message = "Dart is awesome";
		print(message);
	};

	showMessage();


	// Definition 2:
	// A closure is a function object that has access to variables in its lexical scope,
	// even when the function is used outside of its original scope.

	Function talk = () {

		String msg = "Hi";

		Function say = () {
			msg = "Hello";
			print(msg);
		};

		return say;
	};

	Function speak = talk();

	speak();        // talk()       // say()        //  print(msg)      // "Hello"
}
library atom.atom_package_deps;

import 'dart:async';

import 'package:atom/atom.dart';
import 'package:atom/node/notification.dart';
import 'package:atom/node/package.dart';
import 'package:atom/node/process.dart';
import 'package:logging/logging.dart';

import 'jobs.dart';

final Logger _logger = new Logger('atom.atom_package_deps');

Future install() {
  return atomPackage.loadPackageJson().then((Map info) {
    List<String> installedPackages = atom.packages.getAvailablePackageNames();
    List<String> requiredPackages = new List.from(info['required-packages']);

    if (requiredPackages == null || requiredPackages.isEmpty) {
      return null;
    }

    Set<String> toInstall = new Set.from(requiredPackages);
    toInstall.removeAll(installedPackages);

    if (toInstall.isEmpty) return null;

    _logger.info('installing ${toInstall}');

    return new _InstallJob(toInstall.toList()).schedule();
  });
}

class _InstallJob extends Job {
  final List<String> packages;
  bool quitRequested = false;
  int errorCount = 0;

  _InstallJob(this.packages) : super("Installing Packages");

  bool get quiet => true;

  Future run() {
    packages.sort();

    Notification notification = atom.notifications.addInfo(name,
        detail: '', description: 'Installing…', dismissable: true);

    NotificationHelper helper = new NotificationHelper(notification.view);
    helper.setNoWrap();
    helper.setRunning();

    helper.appendText('Installing packages ${packages.join(', ')}.');

    notification.onDidDismiss.listen((_) => quitRequested = true);

    return Future.forEach(packages, (String name) {
      return _install(helper, name);
    }).whenComplete(() {
      if (errorCount == 0) {
        helper.showSuccess();
        helper.setSummary('Finished.');
      } else {
        helper.showError();
        helper.setSummary('Errors installing packages.');
      }
    });
  }

  Future _install(NotificationHelper helper, String name) {
    final String apm = atom.packages.getApmPath();

    ProcessRunner runner = new ProcessRunner(
        apm, args: ['--no-color', 'install', name]);
    return runner.execSimple().then((ProcessResult result) {
      if (result.stdout != null && result.stdout.isNotEmpty) {
        helper.appendText(result.stdout.trim());
      }
      if (result.stderr != null && result.stderr.isNotEmpty) {
        helper.appendText(result.stderr.trim(), stderr: true);
      }
      if (result.exit != 0) {
        errorCount++;
      } else {
        atom.packages.activatePackage(name);
      }
    });
  }
}
