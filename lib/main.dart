import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:quiz_app/firebase_options.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'quiz.dart';
import 'leaderboard.dart';
// import 'match.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiz App',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: AppBarTheme(color: Colors.grey[50]),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  String? _deviceId;
  String _name = 'Unknown';
  String _icon = 'pyoko1-1_smile.png';
  int _score = 0;

  final List _imgList = [
    'assets/categories/perry.png',
    'assets/categories/space_kikansen.png',
    'assets/categories/job_scientist_mad.png',
    'assets/categories/book_smile_boys.png',
    'assets/categories/music_norinori_man.png',
    'assets/categories/movie_man_sleep.png',
    'assets/categories/rock_climbing_woman.png',
    'assets/categories/ai_talk_ai.png',
    'assets/categories/fashion_subculture.png',
  ];

  final List _nameList = [
    'History',
    'Geography',
    'Science',
    'Literature',
    'Music',
    'Film',
    'Sports',
    'Technology',
    'Pop culture',
  ];

  final List<String> _iconList = [
    'boy_01.png',
    'girl_13.png',
    'youngman_25.png',
    'youngwoman_37.png',
    'man_49.png',
    'woman_61.png',
    'oldman_73.png',
    'oldwoman_85.png',
  ];

  @override
  void initState() {
    super.initState();
    _getDeviceId();
  }

  Future<void> _getDeviceId() async {
    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
      _deviceId = androidInfo.id;
      await _saveUserData(_deviceId);
    }
  }

  Future<void> _saveUserData(String? deviceId) async {
    if (deviceId != null) {
      final QuerySnapshot result = await firestore
          .collection('users')
          .where('deviceId', isEqualTo: deviceId)
          .get();

      if (result.docs.isEmpty) {
        await firestore.collection('users').add({
          'deviceId': deviceId,
          'name': 'Unknown',
          'icon': 'pyoko1-1_smile.png',
          'score': 0,
        });
      } else {
        setState(() {
          _name = result.docs.first['name'];
          _icon = result.docs.first['icon'];
          _score = result.docs.first['score'];
        });
      }
    }
  }

  Future<void> _editName() async {
    String? newName = await showDialog(
      context: context,
      builder: (context) {
        TextEditingController nameController = TextEditingController();
        return AlertDialog(
          backgroundColor: Colors.white,
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'New name'),
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.white,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, nameController.text);
              },
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty) {
      setState(() {
        _name = newName;
      });
      await firestore
          .collection('users')
          .where('deviceId', isEqualTo: _deviceId)
          .get()
          .then((snapshot) {
            if (snapshot.docs.isNotEmpty) {
              snapshot.docs.first.reference.update({'name': _name});
            }
          });
    }
  }

  Future<void> _selectIcon() async {
    String? selectedIcon = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return ListView.builder(
          itemCount: _iconList.length,
          itemBuilder: (context, index) {
            return ListTile(
              leading: Image.asset(
                'assets/icons/${_iconList[index]}',
                width: 50,
              ),
              onTap: () {
                Navigator.pop(context, _iconList[index]);
              },
            );
          },
        );
      },
    );

    if (selectedIcon != null) {
      setState(() {
        _icon = selectedIcon;
      });
      await firestore
          .collection('users')
          .where('deviceId', isEqualTo: _deviceId)
          .get()
          .then((snapshot) {
            if (snapshot.docs.isNotEmpty) {
              snapshot.docs.first.reference.update({'icon': _icon});
            }
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 70,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _selectIcon,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 2),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/icons/$_icon',
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Good Afternoon!',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      GestureDetector(
                        onTap: _editName,
                        child: Text(
                          _name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.blue[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.star,
                          color: Colors.blue[200],
                          size: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_score',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.blue[200],
                      border: Border.all(color: Colors.black, width: 2),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(40),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Category',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _imgList.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => QuizPage(
                                          deviceId: _deviceId ?? '',
                                          category: _nameList[index],
                                        ),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        side: const BorderSide(
                                          color: Colors.black,
                                          width: 2,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(2),
                                        child: ListTile(
                                          leading: Image.asset(
                                            _imgList[index],
                                            width: 60,
                                            height: 60,
                                          ),
                                          title: Text(
                                            _nameList[index],
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'Learn about ${_nameList[index]}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                          trailing: Image.asset(
                                            'assets/play.png',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // オンライン対戦に遷移するボタン
          // FloatingActionButton(
          //   heroTag: 'btn1',
          //   onPressed: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //         builder: (context) => MatchPage(deviceId: _deviceId!),
          //       ),
          //     );
          //   },
          //   backgroundColor: Colors.orange[400],
          //   shape: RoundedRectangleBorder(
          //     borderRadius: BorderRadius.circular(20),
          //     side: const BorderSide(color: Colors.black, width: 3),
          //   ),
          //   child: Image.asset(
          //     'assets/internet_mark.png',
          //     width: 30,
          //     height: 30,
          //   ),
          // ),
          // const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LeaderboardPage(deviceId: _deviceId!),
                ),
              );
            },
            backgroundColor: Colors.purple[400],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Colors.black, width: 3),
            ),
            child: Image.asset(
              'assets/mark_oukan_crown1_gold.png',
              width: 30,
              height: 30,
            ),
          ),
        ],
      ),
    );
  }
}
