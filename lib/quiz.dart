import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'main.dart';

class QuizPage extends StatefulWidget {
  final String deviceId;
  final String category;

  const QuizPage({super.key, required this.deviceId, required this.category});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  late FlutterTts flutterTts;
  String _question = '';
  List<String> _options = [];
  int _correctAnswerIndex = -1;
  int _score = 0;
  bool _isButtonEnabled = true;
  bool _isLoadingQuiz = true;
  bool _isSoundOn = false;
  bool _isVoiceOn = false;
  late SpeechToText _speechToText;
  bool _like = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _initSpeech();
    _loadSoundPreference();
    _loadVoicePreference();
    _loadQuiz();
    _loadScore();
  }

  void _initTts() {
    flutterTts = FlutterTts();
    flutterTts.setLanguage("en-US");
    flutterTts.setVolume(1.0);
    flutterTts.setPitch(0.5);
    flutterTts.setSpeechRate(0.5);
  }

  void _initSpeech() async {
    _speechToText = SpeechToText();
    await _speechToText.initialize();
  }

  Future<void> _loadSoundPreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSoundOn = prefs.getBool('isSoundOn') ?? false;
    });
  }

  Future<void> _saveSoundPreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSoundOn', _isSoundOn);
  }

  Future<void> _loadVoicePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isVoiceOn = prefs.getBool('isVoiceOn') ?? false;
    });
  }

  Future<void> _saveVoicePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isVoiceOn', _isVoiceOn);
  }

  void _startListening() async {
    await _speechToText.listen(
      onResult: (result) {
        if (result.hasConfidenceRating && result.confidence > 0.5) {
          String recognizedText = result.recognizedWords.toLowerCase();
          _checkAnswer(recognizedText);
        }
      },
    );
  }

  void _checkAnswer(String recognizedText) {
    for (int i = 0; i < _options.length; i++) {
      if (_options[i].toLowerCase() == recognizedText) {
        setState(() {
          _isButtonEnabled = false;
          if (i == _correctAnswerIndex) {
            _score++;
            _saveScore();
          }
          Future.delayed(const Duration(seconds: 3), () {
            _navigateToQuiz();
          });
        });
        break;
      }
    }
    _speechToText.stop();
  }

  Future<void> _loadQuiz() async {
    try {
      await dotenv.load(fileName: '.env').then((value) async {
        final apiKey = dotenv.env['API_KEY'];
        if (apiKey == null) {
          exit(1);
        }
        final model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: apiKey,
        );
        final content = [
          Content.text('''
                        Create a quiz about ${widget.category}.
                        Output the question, four answer choices, and the index of the correct answer choice on a new line.
                        Specify the index of the correct answer choice in the range of 0 to 3.
                        Omit unnecessary words, symbols, and line breaks.
                        Example:
                        Which is the largest planet in the solar system ?
                        Mars
                        Saturn
                        Jupiter
                        Earth
                        2
          '''),
        ];
        final response = await model.generateContent(content);
        if (response.text != null) {
          final lines = response.text!.split('\n');
          setState(() {
            _question = lines[0];
            _options = lines.sublist(1, 5);
            _correctAnswerIndex = int.parse(lines[5]);
            _isLoadingQuiz = false;
          });
          if (_question.isNotEmpty && _isSoundOn) {
            flutterTts.speak(_question);
          }
          if (_isVoiceOn) {
            _startListening();
          }
        }
      });
    } catch (e) {
      setState(() {
        _navigateToHome();
      });
    }
  }

  Future<void> _loadScore() async {
    final snapshot = await firestore
        .collection('users')
        .where('deviceId', isEqualTo: widget.deviceId)
        .get();
    if (snapshot.docs.isNotEmpty) {
      setState(() {
        _score = snapshot.docs.first['score'];
      });
    }
  }

  Future<void> _saveScore() async {
    final snapshot = await firestore
        .collection('users')
        .where('deviceId', isEqualTo: widget.deviceId)
        .get();
    if (snapshot.docs.isNotEmpty) {
      final userRef = firestore.collection('users').doc(snapshot.docs.first.id);
      await userRef.update({'score': _score});
    }
  }

  Future<void> _saveLike() async {
    final snapshot = await firestore
        .collection('users')
        .where('deviceId', isEqualTo: widget.deviceId)
        .get();
    if (snapshot.docs.isNotEmpty) {
      final userRef = firestore.collection('users').doc(snapshot.docs.first.id);
      await userRef.collection('likes').add({
        'question': _question,
        'options': _options,
        'correctAnswerIndex': _correctAnswerIndex,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.png'),
            fit: BoxFit.fill,
          ),
        ),
        child: Center(
          child: _isLoadingQuiz
              ? const CircularProgressIndicator()
              : Stack(
                  children: [
                    Positioned(
                      top: 40,
                      right: 20,
                      child: IconButton(
                        icon: Icon(
                          _isSoundOn ? Icons.volume_up : Icons.volume_off,
                          size: 40,
                        ),
                        onPressed: () {
                          setState(() {
                            _isSoundOn = !_isSoundOn;
                            _saveSoundPreference();
                          });
                        },
                      ),
                    ),
                    Positioned(
                      top: 40,
                      right: 65,
                      child: IconButton(
                        icon: Icon(
                          _isVoiceOn ? Icons.mic : Icons.mic_off,
                          size: 40,
                        ),
                        onPressed: () {
                          setState(() {
                            _isVoiceOn = !_isVoiceOn;
                            _saveVoicePreference();
                          });
                        },
                      ),
                    ),
                    Positioned(
                      top: 200,
                      left: 20,
                      right: 20,
                      bottom: 500,
                      child: DottedBorder(
                        options: RectDottedBorderOptions(
                          color: Colors.black,
                          dashPattern: const [8, 4],
                          strokeWidth: 2,
                        ),
                        child: Container(
                          width: MediaQuery.of(context).size.width,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Center(
                              child: Text(
                                _question,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 320,
                      right: 20,
                      child: IconButton(
                        icon: Icon(
                          _like ? Icons.favorite : Icons.favorite_border,
                        ),
                        onPressed: () {
                          if (!_like) {
                            setState(() {
                              _like = true;
                            });
                            _saveLike();
                          }
                        },
                      ),
                    ),
                    if (_options.length == 4)
                      Positioned(
                        top: 450,
                        left: 40,
                        right: 40,
                        bottom: 50,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ...List.generate(4, (index) {
                              return SizedBox(
                                width: double.infinity,
                                height: 40,
                                child: ElevatedButton(
                                  onPressed: _isButtonEnabled
                                      ? () {
                                          setState(() {
                                            _isButtonEnabled = false;
                                            if (index == _correctAnswerIndex) {
                                              _score++;
                                              _saveScore();
                                            }
                                            Future.delayed(
                                              const Duration(seconds: 3),
                                              () {
                                                _navigateToQuiz();
                                              },
                                            );
                                          });
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    elevation: 3,
                                    backgroundColor: Colors.grey[50],
                                    disabledBackgroundColor: _isButtonEnabled
                                        ? Colors.grey[50]
                                        : (index == _correctAnswerIndex
                                              ? Colors.blue
                                              : Colors.red),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: const BorderSide(
                                        color: Colors.grey,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    _options[index],
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(
                                  width: 120,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      _navigateToHome();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      elevation: 3,
                                      backgroundColor: Colors.purple,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(22),
                                        side: const BorderSide(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    child: const Text(
                                      'Back',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 120,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      _navigateToQuiz();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      elevation: 3,
                                      backgroundColor: Colors.yellow,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(22),
                                        side: const BorderSide(
                                          color: Colors.black,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    child: const Text(
                                      'Next',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  void _navigateToQuiz() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            QuizPage(deviceId: widget.deviceId, category: widget.category),
      ),
    );
  }

  void _navigateToHome() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MyHomePage()),
    );
  }
}
