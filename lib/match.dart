import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_border/dotted_border.dart';
import 'snackbar.dart';
import 'main.dart';

class MatchPage extends StatefulWidget {
  final String deviceId;

  const MatchPage({super.key, required this.deviceId});

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  String _name = 'Unknown';
  String _icon = 'assets/icons/pyoko1-1_smile.png';
  late WebSocketChannel channel;
  int connectedUsers = 0;
  String _question = '';
  List<String> _options = [];
  int _correctAnswerIndex = -1;
  bool _isButtonEnabled = true;
  bool _isLoadingQuiz = true;
  int remainingTime = 20;

  @override
  void initState() {
    super.initState();
    channel = IOWebSocketChannel.connect('ws://192.168.3.11:8765');

    channel.stream.listen((message) {
      final lines = message.split('\n');
      if (message.startsWith('connected_users:')) {
        setState(() {
          connectedUsers = int.tryParse(message.split(':')[1])!;
        });
      } else if (message.startsWith('remaining_time:')) {
        setState(() {
          remainingTime = int.tryParse(message.split(':')[1])!;
        });
      } else if (lines.length > 5) {
        setState(() {
          _question = lines[0];
          _options = lines.sublist(1, 5);
          _correctAnswerIndex = int.parse(lines[5]);
        });
      } else if (message.contains('is correct')) {
        _showNormallySnackbar(message);
      } else if (message.contains('is incorrect')) {
        _showErrorSnackbar(message);
      }
      _isLoadingQuiz = false;
    });
    fetchPlayers(widget.deviceId);
  }

  Future<void> fetchPlayers(String? deviceId) async {
    if (deviceId != null) {
      final QuerySnapshot result = await firestore
          .collection('users')
          .where('deviceId', isEqualTo: deviceId)
          .get();

      if (result.docs.isNotEmpty) {
        setState(() {
          _name = result.docs.first['name'];
          _icon = result.docs.first['icon'];
        });
      }
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Players: $connectedUsers',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 80,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Rect: $remainingTime',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                                            if (_correctAnswerIndex == index) {
                                              channel.sink.add(
                                                '$_name:is correct',
                                              );
                                            } else {
                                              channel.sink.add(
                                                '$_name:is incorrect',
                                              );
                                            }
                                            if (index == _correctAnswerIndex) {}
                                            Future.delayed(
                                              const Duration(seconds: 3),
                                              () {
                                                _isButtonEnabled = true;
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

  void _navigateToHome() {
    channel.sink.close();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MyHomePage()),
    );
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      showErrorSnackbar(context, message, _icon);
    }
  }

  void _showNormallySnackbar(String message) {
    if (mounted) {
      showNormallySnackBar(context, message, _icon);
    }
  }
}
