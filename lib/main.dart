import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:imageclassification/auth_screen.dart';
import 'gemini_helper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'classifier.dart';
import 'classifier_env2s_float.dart';
import 'package:logger/logger.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const GenerativeAISample());
}

class GenerativeAISample extends StatelessWidget {
  const GenerativeAISample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Query Helper',
      theme: ThemeData(
        textTheme: GoogleFonts.sansitaTextTheme(
          Theme.of(context).textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
        ),
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color.fromARGB(255, 171, 222, 244),
        ),
        useMaterial3: true,
      ),
      home: AuthScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  _MainMenuState createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void triggerFirstButton() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatScreen(
            title: 'Online Object Detection',
            prompt:
                "what is the main object in this photo with a very breif description (in two sentences at maximum)?"),
      ),
    );
  }

  void triggerSecondButton() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatScreen(
            title: 'Navigation Helper',
            prompt:
                "Replay in two sentences at maximum, Analyze this photo and provide instructions on how to avoid obstacles if any to safely navigate around this place.\n "
                "the instructions are for a visually imapired user walking on foot "
                "Example: there is a car infront of you, walk to the right to avoid it"),
      ),
    );
  }

  void triggerThirdButton() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyHomePage(title: 'Offline Object Detection'),
      ),
    );
  }

  void _logout() async {
    await _auth.signOut();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => AuthScreen()),
    );
  }

  TextStyle buttonTextStyle = TextStyle(
    fontSize: 25,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (DragEndDetails details) {
        if (details.primaryVelocity! < 0) {
          // Swipe Up
          triggerFirstButton(); // Online Object Detection
        } else if (details.primaryVelocity! > 0) {
          // Swipe Down
          triggerThirdButton(); // Offline Object Detection
        }
      },
      onHorizontalDragEnd: (DragEndDetails details) {
        // Horizontal swipe
        triggerSecondButton(); // Navigation Helper
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vision Owl'),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.info_outline, color: Colors.white),
              onPressed: _showAppInfo,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: MaterialButton(
                onPressed: triggerFirstButton,
                child: Text('Online Object Detection', style: buttonTextStyle),
                color: Color.fromARGB(255, 0, 56, 78),
                height: double.infinity,
                minWidth: double.infinity,
              ),
            ),
            Expanded(
              child: MaterialButton(
                onPressed: triggerSecondButton,
                child: Text('Navigation Helper', style: buttonTextStyle),
                color: Color.fromARGB(255, 70, 130, 180),
                height: double.infinity,
                minWidth: double.infinity,
              ),
            ),
            Expanded(
              child: MaterialButton(
                onPressed: triggerThirdButton,
                child: Text('Offline Object Detection', style: buttonTextStyle),
                color: Color.fromARGB(255, 104, 135, 177),
                height: double.infinity,
                minWidth: double.infinity,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: MaterialButton(
                onPressed: _logout,
                child: Text('Log Out',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                color: Colors.red,
                minWidth: 200,
                height: 50,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'About Vision Owl\n',
          ),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Swipe Down for Online Object Detection,\n'
                    'Swipe Up for Offline Object Detection,\n'
                    'Swipe Horizontally for Navigation Helper.\n'
                    'Long Press for Camera.\n'
                    'Double Tab to select from Gallery.\n'
                    '\nDeveloped by :\n  Engineer. Kareem Mohamed\n'
                    'Under the supervision of:\n  Prof. Sara Nabil'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String? title;

  MyHomePage({Key? key, this.title}) : super(key: key);

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  late Classifier classifier;
  var logger = Logger();
  File? image;
  final picker = ImagePicker();
  Image? imageWidget;
  img.Image? fox;
  Category? category;
  late final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    classifier = ClassifierENV2SFloat();
    initTts();
  }

  void initTts() {
    flutterTts.setLanguage("en-US");
    flutterTts.setPitch(1.0);
  }

  Future<void> pickAnImage() async {
    try {
      final XFile? pickedFile =
          await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          image = File(pickedFile.path);
          imageWidget = Image.file(image!);
          predict();
        });
      }
    } catch (e) {
      print('Failed to pick image: $e');
    }
  }

  Future<void> shotAnImage() async {
    try {
      final XFile? pickedFile =
          await picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        setState(() {
          image = File(pickedFile.path);
          imageWidget = Image.file(image!);
          predict();
        });
      }
    } catch (e) {
      print('Failed to pick image: $e');
    }
  }

  void predict() async {
    img.Image imageInput = img.decodeImage(image!.readAsBytesSync())!;
    var pred = classifier.predict(imageInput);
    setState(() {
      category = pred;
    });
    if (category != null) {
      await flutterTts
          .speak(category!.label); // Speak the label of the detected object
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: pickAnImage,
      onLongPress: shotAnImage,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title ?? 'Image Classifier',
              style: TextStyle(color: Colors.white)),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Center(
              child: image == null
                  ? Container(
                      margin: const EdgeInsets.all(32.0),
                      padding: const EdgeInsets.all(4.0),
                      child: Text('Please take or pick an image to continue.'))
                  : Container(
                      constraints: BoxConstraints(
                          maxHeight:
                              MediaQuery.of(context).size.height * 2 / 5),
                      decoration: BoxDecoration(border: Border.all()),
                      child: imageWidget,
                    ),
            ),
            SizedBox(height: 36),
            Text(
              category != null ? category!.label : '',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
            SizedBox(height: 8),
            Text(
              category != null
                  ? 'Confidence (out of 10): ${category!.score.toStringAsFixed(2)}'
                  : '',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ],
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.fromLTRB(64, 0, 32, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              FloatingActionButton(
                heroTag: 'cameraButton',
                onPressed: shotAnImage,
                tooltip: 'Take a picture',
                child: Icon(Icons.camera),
              ),
              FloatingActionButton(
                heroTag: 'galleryButton',
                onPressed: pickAnImage,
                tooltip: 'Pick an image',
                child: Icon(Icons.image),
              )
            ],
          ),
        ),
      ),
    );
  }
}
