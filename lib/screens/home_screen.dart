import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tickly/screens/login.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:audioplayers/audioplayers.dart';

final _firestore = FirebaseFirestore.instance;
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  tz.initializeTimeZones();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
  );

  await _requestPermissions();

  runApp(const MyApp());
}

Future<void> _requestPermissions() async {
  await [Permission.notification, Permission.ignoreBatteryOptimizations]
      .request();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Tickly",
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          } else if (snapshot.hasData) {
            return const HomeScreen();
          } else if (snapshot.hasError) {
            return const Center(
              child: Text('Something went wrong'),
            );
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  GoogleSignInAccount? _currentUser;
  late TabController _tabController;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  final AudioPlayer audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _tabController = TabController(length: 3, vsync: this);
  }

  Future<void> _getCurrentUser() async {
    final user = await GoogleSignIn().signInSilently();
    setState(() {
      _currentUser = user;
    });
  }

  @override
  void dispose() {
    titleController.dispose();
    noteController.dispose();
    _tabController.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  Future<void> scheduleAlarm(DateTime scheduledDate) async {
    tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'alarm_notif',
      'alarm_notif',
      channelDescription: 'Channel for Alarm notification',
      icon: '@mipmap/ic_launcher',
      sound: RawResourceAndroidNotificationSound('alarm_sound'),
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Alarm',
      'It\'s time!',
      tzScheduledDate,
      platformChannelSpecifics,
      androidAllowWhileIdle: true,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            if (_currentUser != null) ...[
              CircleAvatar(
                backgroundImage: NetworkImage(_currentUser!.photoUrl ?? ''),
              ),
              SizedBox(width: 8),
              Text(
                _currentUser!.displayName ?? '',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await GoogleSignIn().signOut();
              await FirebaseAuth.instance.signOut().then(
                    (value) => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    ),
                  );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'All'),
            Tab(text: 'In Progress'),
            Tab(text: 'Complete'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTaskList(_firestore
              .collection('tasks')
              .where('userId',
                  isEqualTo: FirebaseAuth.instance.currentUser?.uid)
              .snapshots()),
          _buildTaskList(_firestore
              .collection('tasks')
              .where('completed', isEqualTo: false)
              .where('userId',
                  isEqualTo: FirebaseAuth.instance.currentUser?.uid)
              .snapshots()),
          _buildTaskList(_firestore
              .collection('tasks')
              .where('completed', isEqualTo: true)
              .where('userId',
                  isEqualTo: FirebaseAuth.instance.currentUser?.uid)
              .snapshots()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showTaskModal(context);
        },
        backgroundColor: Colors.blue, // Change this to the desired blue color
        shape: CircleBorder(),
        child: const Icon(
          Icons.add,
          color: Colors.white, // White color for the plus icon
          size: 30, // Adjust the size as needed
        ),
      ),
    );
  }

  Widget _buildTaskList(Stream<QuerySnapshot> taskStream) {
    return StreamBuilder<QuerySnapshot>(
      stream: taskStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return Padding(
          padding: const EdgeInsets.all(10.0),
          child: ListView(
            children: snapshot.data!.docs.map((DocumentSnapshot document) {
              Map<String, dynamic> data =
                  document.data()! as Map<String, dynamic>;
              return NoteCard(
                document: document,
                data: data,
                audioPlayer: audioPlayer,
                scheduleAlarm: scheduleAlarm, // Pass the scheduleAlarm function
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null && pickedDate != selectedDate) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );
    if (pickedTime != null && pickedTime != selectedTime) {
      setState(() {
        selectedTime = pickedTime;
      });
    }
  }

  void _showTaskModal(BuildContext context,
      {DocumentSnapshot? document, Map<String, dynamic>? data}) {
    final _formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: data?['title'] ?? '');
    final noteController = TextEditingController(text: data?['note'] ?? '');
    bool isEdit = document != null;

    // Set default date and time if not editing
    if (!isEdit) {
      selectedDate = DateTime.now();
      selectedTime = TimeOfDay.now();
    } else {
      Timestamp timestamp = data?['timestamp'] ?? Timestamp.now();
      selectedDate = timestamp.toDate();
      selectedTime = TimeOfDay.fromDateTime(timestamp.toDate());
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      hintText: 'Apa yang ingin kamu lakukan?',
                      border: InputBorder.none,
                    ),
                    style: TextStyle(fontSize: 20),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  Divider(),
                  const SizedBox(height: 10.0),
                  Expanded(
                    child: TextFormField(
                      controller: noteController,
                      maxLines: null,
                      expands: true,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        hintText: 'Description',
                        border: InputBorder.none,
                      ),
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a note';
                        }
                        return null;
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.access_time),
                        onPressed: () {
                          _selectTime(context);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.calendar_today),
                        onPressed: () {
                          _selectDate(context);
                        },
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            try {
                              DateTime scheduledDate = DateTime(
                                selectedDate!.year,
                                selectedDate!.month,
                                selectedDate!.day,
                                selectedTime!.hour,
                                selectedTime!.minute,
                              );

                              scheduleAlarm(scheduledDate);

                              if (isEdit) {
                                await _firestore
                                    .collection('tasks')
                                    .doc(document!.id)
                                    .update({
                                  'title': titleController.text,
                                  'note': noteController.text,
                                  'timestamp': scheduledDate,
                                  'completed': data!['completed'],
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Note berhasil diperbarui')),
                                );
                              } else {
                                await _firestore.collection('tasks').add({
                                  'title': titleController.text,
                                  'note': noteController.text,
                                  'timestamp': scheduledDate,
                                  'completed': false,
                                  'userId':
                                      FirebaseAuth.instance.currentUser?.uid,
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Note ditambahkan')),
                                );
                              }
                              Navigator.pop(context);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            }
                          }
                        },
                        child: const Text('Simpan'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class NoteCard extends StatelessWidget {
  final DocumentSnapshot document;
  final Map<String, dynamic> data;
  final AudioPlayer audioPlayer;
  final Function(DateTime) scheduleAlarm; // Add this line

  const NoteCard(
      {Key? key,
      required this.document,
      required this.data,
      required this.audioPlayer,
      required this.scheduleAlarm})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 15.0, horizontal: 30.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 35,
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: data['completed'] == true ? Colors.grey : Colors.blue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8.0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.flag,
                      color: Colors.white,
                      size: 16.0,
                    ),
                    SizedBox(width: 8.0),
                    Text(
                      data['completed'] == true ? 'Complete' : 'In Progress',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditModal(context, document, data);
                    } else if (value == 'delete') {
                      _firestore.collection('tasks').doc(document.id).delete();
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Text(
                        'Edit',
                        style: TextStyle(
                          color: Colors.blue, // Text color
                          fontWeight: FontWeight.w500, // Bold text
                        ),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(
                          color: Colors.red, // Text color
                          fontWeight: FontWeight.w500, // Bold text
                        ),
                      ),
                    ),
                  ],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10), // Rounded corners
                  ),
                  color: Colors.white, // Background color
                ),
              ],
            ),
          ),
          Padding(padding: EdgeInsets.symmetric(vertical: 5)),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    bool newStatus =
                        !(data['completed'] ?? false); // Handle null case
                    await _firestore
                        .collection('tasks')
                        .doc(document.id)
                        .update({'completed': newStatus});
                    if (newStatus) {
                      await audioPlayer.play(AssetSource(
                          'audio/notification_sound.mp3')); // Change to the correct audio source
                    }
                  },
                  child: Icon(
                    (data['completed'] ?? false)
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 27.0,
                  ),
                ),
                SizedBox(width: 13.0),
                Expanded(
                  child: Text(
                    data['title'],
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 18.0,
                      decoration: (data['completed'] ?? false)
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(), // Garis pembagi tidak full width
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 5.0, horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.alarm,
                      size: 18.0,
                      color: Colors.blue,
                    ),
                    SizedBox(width: 4.0),
                    Text(
                      DateFormat('hh:mm a')
                          .format((data['timestamp'] as Timestamp).toDate()),
                      style: TextStyle(color: Colors.blue),
                    ),
                  ],
                ),
                Text(
                  DateFormat('EEE, d MMM yyyy')
                      .format((data['timestamp'] as Timestamp).toDate()),
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 7,
          )
        ],
      ),
    );
  }

  void _showEditModal(BuildContext context, DocumentSnapshot document,
      Map<String, dynamic> data) {
    final _formKey = GlobalKey<FormState>();
    final titleEdc = TextEditingController(text: data['title']);
    final noteEdc = TextEditingController(text: data['note']);
    DateTime selectedDate = (data['timestamp'] as Timestamp).toDate();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleEdc,
                    decoration: const InputDecoration(
                      hintText: 'Buat judul task',
                      border: InputBorder.none,
                    ),
                    style: TextStyle(fontSize: 24),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10.0),
                  Expanded(
                    child: TextFormField(
                      controller: noteEdc,
                      maxLines: null,
                      expands: true,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        hintText: 'Description',
                        border: InputBorder.none,
                      ),
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a note';
                        }
                        return null;
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.access_time),
                        onPressed: () async {
                          final TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (pickedTime != null &&
                              pickedTime != selectedTime) {
                            selectedTime = pickedTime;
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.calendar_today),
                        onPressed: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                          );
                          if (pickedDate != null &&
                              pickedDate != selectedDate) {
                            selectedDate = pickedDate;
                          }
                        },
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            try {
                              DateTime scheduledDate = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              );

                              await _firestore
                                  .collection('tasks')
                                  .doc(document.id)
                                  .update({
                                'title': titleEdc.text,
                                'note': noteEdc.text,
                                'timestamp': scheduledDate,
                                'completed': data['completed'],
                              });

                              scheduleAlarm(scheduledDate);

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Note berhasil diperbarui')),
                              );
                              Navigator.pop(context);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            }
                          }
                        },
                        child: const Text('Simpan'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
