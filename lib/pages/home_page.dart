import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';
import 'package:voice_assistant/app/colors.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var message = "Seni Dinliyorum...";
  var isListening = true;
  late stt.SpeechToText
      speech; // speech değişkenini initialize etmek için 'late' kullanın

  @override
  void initState() {
    super.initState();
    speech = stt.SpeechToText();
    checkMic();
  }

  void checkMic() async {
    bool micAvailable = await speech.initialize(
      onStatus: (status) {
        print("onStatus: $status");
      },
      onError: (error) {
        print("onError: $error");
      },
    );
    setState(() {
      isListening = micAvailable; // Mic aktifse dinleme durumunu güncelleyin
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: bgColor,
        elevation: 0.8,
        title: const Text(
          "Voice Assistant ",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        margin: const EdgeInsets.only(bottom: 150),
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      floatingActionButton: AvatarGlow(
        animate: isListening,
        duration: const Duration(milliseconds: 2000),
        glowColor: bgColor,
        repeat: true,
        child: GestureDetector(
          onTapDown: (details) async {
            if (isListening) {
              setState(() {
                isListening = false;
              });
              speech.stop();
            } else {
              bool available = await speech.initialize();
              if (available) {
                setState(() {
                  isListening = true;
                });
                speech.listen(
                  onResult: (result) {
                    setState(() {
                      message = result.recognizedWords ??
                          ""; // Sonuç null değilse güncelle
                    });
                  },
                  listenFor: const Duration(seconds: 10),
                );
              }
            }
          },
          child: CircleAvatar(
            backgroundColor: bgColor,
            radius: 60,
            child: Icon(
              isListening ? Icons.mic : Icons.mic_none,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
