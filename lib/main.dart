import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';



Future main() async {
  try {
    await dotenv.load(fileName: ".env");
    print(dotenv.env['OPENAI_API_KEY']);
  } catch (e) {
    print("Error loading .env file: $e");
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Assistant App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ApplianceSelectionScreen(),
    );
  }
}


class ApplianceSelectionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select an Appliance'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      assistantId: 'asst_dmDDvtYeFlpkTTMW2XqUS1oL',
                      instructions: 'You are a helpful assistant whose job is to understand the attached manual to the SKS CR3001P 30-inch Integrated Column Refrigerator. You can just call it "your fridge". You then answer questions about the fridge for users. Do not provide references to where in the document you found the information.',
                    ),
                  ),
                );
              },
              child: Text('Fridge Manual'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      assistantId: 'asst_MvvekqgiAczbSAuyqU9MmKh7',
                      instructions: 'You are a helpful assistant whose job is to understand the attached manual to the Bosch 800 Series Combination Oven 30. You can just call it "your oven/microwave". You then answer questions about the oven for users. Do not provide references to where in the document you found the information.',
                    ),
                  ),
                );
              },
              child: Text('Oven Manual'),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String assistantId;
  final String instructions;

  ChatScreen({Key? key, required this.assistantId, required this.instructions}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? threadId;
  int _lastMessageTimestamp = 0;
  bool _isLoading = false;
  @override
  void initState() {
    super.initState();
    _initializeThread();
  }

@override
Widget build(BuildContext context) {
  final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
  return Scaffold(
    resizeToAvoidBottomInset: false, // Prevent resizing of the scaffold
    appBar: AppBar(
      title: Text('Chat with Assistant'),
    ),
    body: Padding(
      padding: EdgeInsets.only(bottom: bottomPadding), // Add padding at the bottom
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isLoading && index == 0) {
                  return _buildTypingIndicator();
                }
                final int messageIndex = _isLoading ? index - 1 : index;
                return _buildMessage(_messages[messageIndex]);
              },
            ),
          ),
          // Input field
          Padding(
            padding: EdgeInsets.all(4), // Adjust padding
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    onSubmitted: _handleSubmitted,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      hintText: 'Send a message',
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () => _handleSubmitted(_textController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}


// This function builds a typing indicator widget
Widget _buildTypingIndicator() {
  return Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 3,
            ),
          ),
          SizedBox(width: 8),
          Text("Finding Answer..."),
        ],
      ),
    ),
  );
}

  Future<void> _initializeThread() async {
  String? openAiApiKey = dotenv.env['OPENAI_API_KEY'];
  final url = 'https://api.openai.com/v1/threads';

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $openAiApiKey',
        'Content-Type': 'application/json',
        'OpenAI-Beta': 'assistants=v1',
      },
    );

    print('API Response: ${response.body}');

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse != null) {
        if (jsonResponse['id'] != null) {
          setState(() {
            threadId = jsonResponse['id'];
          });
        } else {
          print('No "id" key in the response.');
        }
      } else {
        print('jsonResponse is null.');
      }
    } else {
      print('Failed to initialize thread. Status code: ${response.statusCode}');
      print('Response body: ${response.body}');
    }
  } catch (e) {
    print('Error initializing thread: $e');
  }
}


  void _handleSubmitted(String text) {
    if (text.isEmpty) return;
    setState(() {
      _messages.insert(0, ChatMessage(message: text, isUser: true));
    });
    _textController.clear();
    _sendMessageToThread(text);
    _runAssistantAndGetResponse();
  }

  Future<void> _sendMessageToThread(String text) async {
    print("Running _sendMessageToThread");
    if (threadId == null) {
      print('Thread ID is null. Cannot send message.');
      return;
    }
    String? openAiApiKey = dotenv.env['OPENAI_API_KEY'];
    final url = 'https://api.openai.com/v1/threads/$threadId/messages';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $openAiApiKey',
          'Content-Type': 'application/json',
          'OpenAI-Beta': 'assistants=v1',
        },
        body: json.encode({
          'role': 'user',
          'content': text,
        }),
      );
      setState(() {
        _isLoading = true;
      });
      print(response.body);
      if (response.statusCode != 200) {
        print('Failed to send message. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error sending message to thread: $e');
    }
  }

  Future<void> _runAssistantAndGetResponse() async {
  print("Running _runAssistantAndGetResponse");
  if (threadId == null) {
    print('Thread ID is null. Cannot run assistant.');
    return;
  }
  String? openAiApiKey = dotenv.env['OPENAI_API_KEY'];
  final runUrl = 'https://api.openai.com/v1/threads/$threadId/runs';

  try {
    final runResponse = await http.post(
      Uri.parse(runUrl),
      headers: {
        'Authorization': 'Bearer $openAiApiKey',
        'Content-Type': 'application/json',
        'OpenAI-Beta': 'assistants=v1',
      },
      body: json.encode({
        'assistant_id': widget.assistantId,
        'instructions': widget.instructions,
      }),
    );
    print(runResponse.statusCode);
    print(runResponse.body);

    if (runResponse.statusCode == 200) {
      final jsonResponse = json.decode(runResponse.body);
      String runId = jsonResponse['id'];
      await _checkRunStatusUntilCompleted(runId);
    } else {
      print('Failed to run assistant. Status code: ${runResponse.statusCode}');
      print('Response body: ${runResponse.body}');
    }
  } catch (e) {
    print('Error running assistant: $e');
  }
}

Future<void> _checkRunStatusUntilCompleted(String runId) async {
  bool isCompleted = false;
  while (!isCompleted) {
    await Future.delayed(Duration(seconds: 2)); // Poll every 2 seconds
    final statusUrl = 'https://api.openai.com/v1/threads/$threadId/runs/$runId';
    try {
      final statusResponse = await http.get(
        Uri.parse(statusUrl),
        headers: {
          'Authorization': 'Bearer ${dotenv.env['OPENAI_API_KEY']}',
          'OpenAI-Beta': 'assistants=v1',
        },
      );
      if (statusResponse.statusCode == 200) {
        final jsonResponse = json.decode(statusResponse.body);
        String status = jsonResponse['status'];
        if (status == 'completed') {
          isCompleted = true;
          await _fetchThreadMessages();
        }
      } else {
        print('Failed to check run status. Status code: ${statusResponse.statusCode}');
        print('Response body: ${statusResponse.body}');
      }
    } catch (e) {
      print('Error checking run status: $e');
    }
  }
  setState(() {
  _isLoading = false;
  });
}

  Future<void> _fetchThreadMessages() async {
  if (threadId == null) {
    print('Thread ID is null. Cannot fetch messages.');
    return;
  }
  String? openAiApiKey = dotenv.env['OPENAI_API_KEY'];
  final messagesUrl = 'https://api.openai.com/v1/threads/$threadId/messages';

  try {
    final messagesResponse = await http.get(
      Uri.parse(messagesUrl),
      headers: {
        'Authorization': 'Bearer $openAiApiKey',
        'OpenAI-Beta': 'assistants=v1',
      },
    );

    if (messagesResponse.statusCode == 200) {
      final String responseBody = utf8.decode(messagesResponse.bodyBytes);
      final jsonResponse = json.decode(responseBody);
      if (jsonResponse['data'] is List) {
        List<dynamic> messages = jsonResponse['data'];
        for (var message in messages.reversed) { // Process the list in reverse to get the latest messages first
          int messageTimestamp = message['created_at'];
          if (messageTimestamp > _lastMessageTimestamp) {
            if (message['role'] == 'assistant' && message['content'] is List) {
              var contentList = message['content'] as List;
              for (var content in contentList) {
                if (content['type'] == 'text' && content['text'] is Map) {
                  var textContent = content['text'] as Map;
                  if (textContent['value'] is String) {
                    setState(() {
                      _messages.insert(0, ChatMessage(message: textContent['value'], isUser: false));
                      _lastMessageTimestamp = messageTimestamp; // Update the last message timestamp
                    });
                  }
                }
              }
            }
          }
        }
      }
    } else {
      print('Failed to fetch messages. Status code: ${messagesResponse.statusCode}');
      print('Response body: ${messagesResponse.body}');
    }
  } catch (e) {
    print('Error fetching messages: $e');
  }
}



  Widget _buildMessage(ChatMessage message) {
  // For the user's messages, display them as plain text.
  if (message.isUser) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.blueAccent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          message.message,
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  } else {
    // For the assistant's messages, parse and display them with links.
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        // Use the parseSourceText function to create a RichText widget.
        child: parseSourceText(message.message),
      ),
    );
  }
}

// Add the parseSourceText function if you haven't already.
RichText parseSourceText(String text) {
  final RegExp pattern = RegExp(r'\[\d+†source\]');
  final Iterable<RegExpMatch> matches = pattern.allMatches(text);
  List<TextSpan> spans = [];
  int start = 0;

  matches.forEach((match) {
    // Add any text before the match as a regular TextSpan
    spans.add(TextSpan(text: text.substring(start, match.start)));
    // Extract the number from the match
    String sourceNumber = text.substring(match.start + 1, match.end - 8);
    // Add the source number as a clickable TextSpan
    spans.add(TextSpan(
      text: 'source',
      style: TextStyle(color: Colors.blue),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          // TODO: Insert your link or action associated with the source number
          // launch('https://your-source-link/$sourceNumber');
        },
    ));
    start = match.end;
  });

  // Add any remaining text after the last match
  if (start < text.length) {
    spans.add(TextSpan(text: text.substring(start)));
  }

  return RichText(
    text: TextSpan(
      style: TextStyle(color: Colors.black87),
      children: spans,
    ),
  );
}

}

class ChatMessage {
  final String message;
  final bool isUser;

  ChatMessage({required this.message, required this.isUser});
}
