import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_tts/flutter_tts.dart';

const String _apiKey = String.fromEnvironment('API_KEY',
    defaultValue: "YourAPIKey");

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.title, required this.prompt});

  final String title;
  final String prompt;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ChatWidget(
        apiKey: _apiKey,
        prompt: widget.prompt,
        title: '',
      ),
    );
  }
}

class ChatWidget extends StatefulWidget {
  const ChatWidget({
    required this.apiKey,
    required this.prompt,
    required this.title,
    super.key,
  });

  final String apiKey;
  final String prompt;
  final String title;
  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  late final GenerativeModel _model;
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  final FlutterTts _flutterTts = FlutterTts();
  bool _loading = false;
  final List<({Image? image, String? text, bool fromUser})> _generatedContent =
      <({Image? image, String? text, bool fromUser})>[];

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
      model: 'gemini-pro-vision',
      apiKey: widget.apiKey,
    );
    _flutterTts.setLanguage("en-US");
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: () => _selectAndSendImage(ImageSource.gallery),
      onLongPress: () => _selectAndSendImage(ImageSource.camera),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemBuilder: (context, idx) {
                    final content = _generatedContent[idx];
                    return MessageWidget(
                      text: content.text,
                      image: content.image,
                      isFromUser: content.fromUser,
                    );
                  },
                  itemCount: _generatedContent.length,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 25,
                  horizontal: 15,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: IconButton(
                          icon: Icon(Icons.image, size: 30),
                          onPressed: () =>
                              _selectAndSendImage(ImageSource.gallery),
                          tooltip: 'Select Image from Gallery',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: IconButton(
                          icon: Icon(Icons.camera_alt, size: 30),
                          onPressed: () =>
                              _selectAndSendImage(ImageSource.camera),
                          tooltip: 'Capture Image with Camera',
                        ),
                      ),
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

  void _selectAndSendImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

    setState(() {
      _loading = true;
      _generatedContent.add((
        image: Image.file(File(image.path)),
        text: "Image uploaded successfully!",
        fromUser: true,
      ));
    });

    final Uint8List imageBytes = await image.readAsBytes();

    try {
      final response = await _model.generateContent(
        [
          Content.multi([
            TextPart(widget.prompt),
            DataPart('image/jpeg', imageBytes),
          ])
        ],
      );

      final textResponse = response.text ?? "No response from API.";

      _generatedContent.add((image: null, text: textResponse, fromUser: false));
      await _speak(textResponse);
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() {
        _loading = false;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _speak(String text) async {
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Error'),
          content: SingleChildScrollView(
            child: Text(message),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context)..pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

class MessageWidget extends StatelessWidget {
  const MessageWidget({
    super.key,
    this.image,
    this.text,
    required this.isFromUser,
  });

  final Image? image;
  final String? text;
  final bool isFromUser;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment:
            isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (image != null)
            Container(
              margin: const EdgeInsets.only(right: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.6,
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image(
                  image: image!.image,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              decoration: BoxDecoration(
                color: isFromUser
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 16,
              ),
              child: SelectableText(text ?? ''),
            ),
          ),
        ],
      ),
    );
  }
}
