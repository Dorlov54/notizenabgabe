import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutterfire_ui/auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notizen App',
      theme: ThemeData.light().copyWith(
        primaryColor: Colors.blueGrey,
        colorScheme: ThemeData.light().colorScheme.copyWith(
          secondary: Colors.indigoAccent,
        ),
        backgroundColor: Colors.white,
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Colors.indigo,
        colorScheme: ThemeData.dark().colorScheme.copyWith(
          secondary: Colors.deepOrangeAccent,
        ),
        backgroundColor: Colors.black,
      ),
      home: AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SignInScreen(providerConfigs: [
            EmailProviderConfiguration(),
          ]);
        }
        return NotesApp();
      },
    );
  }
}

class NotesApp extends StatefulWidget {
  @override
  _NotesAppState createState() => _NotesAppState();
}

class _NotesAppState extends State<NotesApp> {
  int _currentIndex = 0;
  bool isDarkMode = false;
  String selectedFont = 'Roboto';

  late stt.SpeechToText _speech;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  toggleDarkMode() => setState(() => isDarkMode = !isDarkMode);

  List<Note> notes = [];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notizen App',
      theme: isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Notizen App'),
          actions: [
            IconButton(
              onPressed: () => _signOut(),
              icon: Icon(Icons.logout),
            ),
            IconButton(
              onPressed: () => _openSettings(),
              icon: Icon(Icons.settings),
            ),
          ],
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Entwickler:",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    Text("Dennis, Terry, Fatma",
                        style: TextStyle(fontSize: 14, color: Colors.white)),
                  ],
                ),
              ),
              ListTile(
                title: Text('Einstellungen'),
                leading: Icon(Icons.settings),
                onTap: () {
                  Navigator.pop(context);
                  _openSettings();
                },
              ),
              ListTile(
                title: Text('Abmelden'),
                leading: Icon(Icons.logout),
                onTap: () {
                  _signOut();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
        body: _getTabScreen(_currentIndex) as Widget,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _changeTab,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.note),
              label: 'Notizen',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt),
              label: 'Kamera',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.mic),
              label: 'Sprache',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startListening() async {
    if (!_speech.isListening) {
      bool available = await _speech.initialize();
      if (available) {
        _speech.listen(
          onResult: (result) {
            setState(() {
              // Handle the speech-to-text result here
            });
          },
        );
      }
    }
  }

  Future<void> _stopListening() async {
    if (_speech.isListening) {
      _speech.stop();
    }
  }

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  _getTabScreen(int currentIndex) {
    switch (currentIndex) {
      case 0:
        return NotesList(notes, _updateNotes, _showNoteDetails);
      case 1:
        return CameraTab();
      case 2:
        return SpeechTab(
          startListening: _startListening,
          stopListening: _stopListening,
        );
      default:
        return NotesList(notes, _updateNotes, _showNoteDetails);
    }
  }

  _openSettings() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Einstellungen"),
          content: Column(
            children: [
              Text("Dennis war hier."),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  toggleDarkMode();
                  Navigator.of(context).pop();
                },
                child: Text("Dark Mode umschalten"),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Schließen"),
            ),
          ],
        );
      },
    );
  }

  void _updateNotes(List<Note> updatedNotes) {
    setState(() {
      notes = updatedNotes;
    });
  }

  void _showNoteDetails(Note note) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(note.title),
          content: Text(note.content),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Schließen"),
            ),
          ],
        );
      },
    );
  }
}

class VoiceNotesTab {}

class NotesList extends StatefulWidget {
  final List<Note> notes;
  final Function(List<Note>) updateNotes;
  final Function(Note) showNoteDetails;

  NotesList(this.notes, this.updateNotes, this.showNoteDetails);

  @override
  _NotesListState createState() => _NotesListState();
}

class _NotesListState extends State<NotesList> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notizen'),
      ),
      body: ListView.builder(
        itemCount: widget.notes.length,
        itemBuilder: (context, index) => Card(
          elevation: 5,
          margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            title: Text(
              widget.notes[index].title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              widget.notes[index].content,
              style: TextStyle(fontSize: 14),
            ),
            onTap: () {
              widget.showNoteDetails(widget.notes[index]);
            },
            trailing: IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                widget.notes.removeAt(index);
                widget.updateNotes(widget.notes);
              },
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newNote = await Navigator.push(
              context, MaterialPageRoute(builder: (context) => NoteEditor()));
          if (newNote != null) {
            widget.notes.add(newNote);
            widget.updateNotes(widget.notes);
          }
        },
        child: Icon(Icons.add),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }
}

class SpeechTab extends StatelessWidget {
  final Function() startListening;
  final Function() stopListening;

  SpeechTab({required this.startListening, required this.stopListening});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sprache'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: startListening,
              child: Text('Aufnahme'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: stopListening,
              child: Text('Beenden'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> deleteDataFromFirestore(String docId) async {
  CollectionReference notes = FirebaseFirestore.instance.collection('notes');
  await notes.doc(docId).delete();
}

class Note {
  String title, content;

  Note(this.title, this.content);
}

class CameraTab extends StatefulWidget {
  @override
  _CameraTabState createState() => _CameraTabState();
}

class _CameraTabState extends State<CameraTab> {
  XFile? _pickedImage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kamera'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _pickedImage == null
                ? Text('Bild auswählen', style: TextStyle(fontSize: 20))
                : _getImageWidget(),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _pickImageFromGallery(context);
              },
              child: Text('Bild aus Galerie auswählen'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _pickImageFromCamera(context);
              },
              child: Text('Bild mit Kamera aufnehmen'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getImageWidget() {
    if (kIsWeb) {
      // Flutter Web
      return Image.network(
        _pickedImage!.path,
        fit: BoxFit.contain,
        height: 420,
        width: 500,
      );
    } else {
      return Container(
        height: 20,
        child: Image.file(
          File(_pickedImage!.path),
          fit: BoxFit.contain,
        ),
      );
    }
  }

  Future _pickImageFromGallery(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
    await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _pickedImage = pickedFile;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Bild aus Galerie ausgewählt: ${pickedFile.path}'),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Kein Bild ausgewählt'),
      ));
    }
  }

  Future _pickImageFromCamera(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
    await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _pickedImage = pickedFile;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Bild mit Kamera aufgenommen: ${pickedFile.path}'),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Kein Bild aufgenommen'),
      ));
    }
  }
}

class NoteEditor extends StatefulWidget {
  @override
  _NoteEditorState createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController contentController = TextEditingController();

  Future<void> writeNoteToFirestore(Note note) async {
    CollectionReference notes =
    FirebaseFirestore.instance.collection('notes');
    await notes.add({
      'title': note.title,
      'content': note.content,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notiz hinzufügen')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              style: TextStyle(fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Titel',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 5),
            TextField(
              controller: contentController,
              style: TextStyle(fontSize: 16),
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Inhalt',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text;
                final content = contentController.text;

                if (title.isNotEmpty && content.isNotEmpty) {
                  final newNote = Note(title, content);
                  writeNoteToFirestore(newNote);
                  Navigator.pop(context, newNote);
                }
              },
              child: Text('Speichern'),
              style: ElevatedButton.styleFrom(
                primary: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
