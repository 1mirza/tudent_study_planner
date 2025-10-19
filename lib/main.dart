/// PomoPal: A Smart Pomodoro Study Assistant
///
/// Final version incorporating all requested features.
/// The 'vibration' package has been removed to ensure build stability.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:intl/intl.dart' hide TextDirection;
import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shamsi_date/shamsi_date.dart' as shamsi;
// Hid 'isSameDay' from this import to resolve name collision with 'table_calendar'.
import 'package:persian_datetime_picker/persian_datetime_picker.dart'
    hide isSameDay;

// Initialize local notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Timezone and Notification Setup ---
  tz.initializeTimeZones();
  final String timeZoneName = tz.local.name;
  tz.setLocalLocation(tz.getLocation(timeZoneName));

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const PomodoroApp());
}

// ##################################################################
// #                      DATA MODELS                             #
// ##################################################################

enum TaskPriority { none, low, medium, high }

class Task {
  String id;
  String title;
  String subject;
  int estimatedPomodoros;
  int completedPomodoros;
  bool isDone;
  TaskPriority priority;
  DateTime? reminderTime;

  Task({
    required this.title,
    required this.subject,
    this.estimatedPomodoros = 1,
    this.completedPomodoros = 0,
    this.isDone = false,
    this.priority = TaskPriority.none,
    this.reminderTime,
  }) : id = DateTime.now().millisecondsSinceEpoch.toString();

  Task.fromJson(Map<String, dynamic> json)
      : id = json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title = json['title'],
        subject = json['subject'],
        estimatedPomodoros = json['estimatedPomodoros'],
        completedPomodoros = json['completedPomodoros'],
        isDone = json['isDone'],
        priority = TaskPriority.values[json['priority'] ?? 0],
        reminderTime = json['reminderTime'] != null
            ? DateTime.parse(json['reminderTime'])
            : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'estimatedPomodoros': estimatedPomodoros,
        'completedPomodoros': completedPomodoros,
        'isDone': isDone,
        'priority': priority.index,
        'reminderTime': reminderTime?.toIso8601String(),
      };
}

class Goal {
  String id;
  String title;
  String subject; // Link goal to a subject
  int targetPomodoros;
  int completedPomodoros;

  Goal({
    required this.title,
    required this.subject,
    required this.targetPomodoros,
    this.completedPomodoros = 0,
  }) : id = DateTime.now().millisecondsSinceEpoch.toString();

  Goal.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        title = json['title'],
        subject = json['subject'],
        targetPomodoros = json['targetPomodoros'],
        completedPomodoros = json['completedPomodoros'];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'targetPomodoros': targetPomodoros,
        'completedPomodoros': completedPomodoros,
      };
}

class PomodoroHistory {
  final DateTime date;
  PomodoroHistory({required this.date});

  PomodoroHistory.fromJson(Map<String, dynamic> json)
      : date = DateTime.parse(json['date']);

  Map<String, dynamic> toJson() => {'date': date.toIso8601String()};
}

// ##################################################################
// #                      APP ROOT WIDGET                         #
// ##################################################################

class PomodoroApp extends StatelessWidget {
  const PomodoroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'پومویار',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        fontFamily: 'Vazir',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 18.0, color: Colors.black87),
          bodyMedium: TextStyle(fontSize: 16.0, color: Colors.black54),
          titleLarge: TextStyle(
              fontSize: 22.0, fontWeight: FontWeight.bold, color: Colors.red),
          headlineSmall: TextStyle(
              fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      // [FIX]: Replaced deprecated 'DefaultPersianLocalization' with 'GlobalPersianDateLocalization'.
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        DefaultPersianCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fa', ''), // Persian
      ],
      home: const MainScreen(),
    );
  }
}

// ##################################################################
// #                      MAIN SCREEN & STATE                     #
// ##################################################################

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 2; // Start on Timer screen
  bool _isLoading = true;

  // --- State Data ---
  List<String> _subjects = [];
  Map<String, List<Task>> _weeklySchedule = {};
  List<Goal> _goals = [];
  List<PomodoroHistory> _pomodoroHistory = [];
  int _points = 0;
  List<String> _notes = [];
  int _focusDuration = 25;
  int _shortBreakDuration = 5;
  int _longBreakDuration = 15;
  bool _isSoundEnabled = true;
  Task? _activeTask;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // --- Data Persistence ---
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _subjects = prefs.getStringList('subjects') ?? ['ریاضی', 'شیمی', 'فیزیک'];
      _notes = prefs.getStringList('notes') ?? [];
      _focusDuration = prefs.getInt('focusDuration') ?? 25;
      _shortBreakDuration = prefs.getInt('shortBreakDuration') ?? 5;
      _longBreakDuration = prefs.getInt('longBreakDuration') ?? 15;
      _points = prefs.getInt('points') ?? 0;
      _isSoundEnabled = prefs.getBool('isSoundEnabled') ?? true;

      final goalsString = prefs.getString('goals');
      if (goalsString != null) {
        final List<dynamic> decodedList = json.decode(goalsString);
        _goals = decodedList.map((g) => Goal.fromJson(g)).toList();
      }

      final historyString = prefs.getString('pomodoroHistory');
      if (historyString != null) {
        final List<dynamic> decodedList = json.decode(historyString);
        _pomodoroHistory =
            decodedList.map((h) => PomodoroHistory.fromJson(h)).toList();
      }

      final scheduleString = prefs.getString('weeklySchedule');
      if (scheduleString != null) {
        final Map<String, dynamic> decodedMap = json.decode(scheduleString);
        _weeklySchedule = decodedMap.map((key, value) {
          final tasks = (value as List)
              .map((taskJson) => Task.fromJson(taskJson))
              .toList();
          return MapEntry(key, tasks);
        });
      } else {
        _weeklySchedule = {
          'شنبه': [],
          'یکشنبه': [],
          'دوشنبه': [],
          'سه‌شنبه': [],
          'چهارشنبه': [],
          'پنج‌شنبه': [],
          'جمعه': [],
        };
      }
      _isLoading = false;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('subjects', _subjects);
    await prefs.setStringList('notes', _notes);
    await prefs.setInt('focusDuration', _focusDuration);
    await prefs.setInt('shortBreakDuration', _shortBreakDuration);
    await prefs.setInt('longBreakDuration', _longBreakDuration);
    await prefs.setInt('points', _points);
    await prefs.setBool('isSoundEnabled', _isSoundEnabled);

    await prefs.setString(
        'goals', json.encode(_goals.map((g) => g.toJson()).toList()));
    await prefs.setString('pomodoroHistory',
        json.encode(_pomodoroHistory.map((h) => h.toJson()).toList()));
    final scheduleString = json.encode(_weeklySchedule.map((key, value) {
      return MapEntry(key, value.map((task) => task.toJson()).toList());
    }));
    await prefs.setString('weeklySchedule', scheduleString);
  }

  void _updateState(VoidCallback callback) {
    setState(callback);
    _saveData();
  }

  // --- Business Logic Methods ---
  void _addSubject(String subject) {
    if (subject.isNotEmpty && !_subjects.contains(subject)) {
      _updateState(() => _subjects.add(subject));
    }
  }

  void _deleteSubject(String subject) {
    _updateState(() {
      _subjects.remove(subject);
      _weeklySchedule.forEach((day, tasks) {
        tasks.removeWhere((task) => task.subject == subject);
      });
      _goals.removeWhere((goal) => goal.subject == subject);
    });
  }

  void _editSubject(String oldSubject, String newSubject) {
    if (newSubject.isNotEmpty && !_subjects.contains(newSubject)) {
      _updateState(() {
        final index = _subjects.indexOf(oldSubject);
        if (index != -1) {
          _subjects[index] = newSubject;
          _weeklySchedule.forEach((day, tasks) {
            for (var task in tasks) {
              if (task.subject == oldSubject) task.subject = newSubject;
            }
          });
          for (var goal in _goals) {
            if (goal.subject == oldSubject) goal.subject = newSubject;
          }
        }
      });
    }
  }

  void _addTask(String day, Task task) {
    _updateState(() {
      _weeklySchedule[day]?.add(task);
      if (task.reminderTime != null) _scheduleNotification(task);
    });
  }

  void _deleteTask(String day, Task task) {
    _updateState(() {
      _weeklySchedule[day]?.remove(task);
      if (task.reminderTime != null) _cancelNotification(task);
    });
  }

  void _toggleTask(String day, Task task) =>
      _updateState(() => task.isDone = !task.isDone);

  void _addGoal(Goal goal) => _updateState(() => _goals.add(goal));
  void _deleteGoal(Goal goal) => _updateState(() => _goals.remove(goal));

  void _onPomodoroCompleted() {
    _updateState(() {
      _pomodoroHistory.add(PomodoroHistory(date: DateTime.now()));
      _points += 10;
      if (_activeTask != null) {
        _activeTask!.completedPomodoros++;
        for (var goal in _goals) {
          if (goal.subject == _activeTask!.subject) goal.completedPomodoros++;
        }
      }
    });
  }

  void _setActiveTask(Task? task) => setState(() => _activeTask = task);

  // --- Notification Logic ---
  Future<void> _scheduleNotification(Task task) async {
    final tz.TZDateTime scheduledDate =
        tz.TZDateTime.from(task.reminderTime!, tz.local);
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails('pomopal_channel_id', 'PomoPal Reminders',
            channelDescription: 'Channel for task reminders in PomoPal app',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: false);
    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      task.id.hashCode,
      'یادآور فعالیت',
      'زمان انجام فعالیت "${task.title}" فرا رسیده است!',
      scheduledDate,
      platformDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _cancelNotification(Task task) async {
    await flutterLocalNotificationsPlugin.cancel(task.id.hashCode);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<Widget> pages = [
      PlannerScreen(
          schedule: _weeklySchedule,
          subjects: _subjects,
          onAddTask: _addTask,
          onToggleTask: _toggleTask,
          onDeleteTask: _deleteTask,
          onSetActiveTask: _setActiveTask,
          activeTask: _activeTask),
      GoalsScreen(
          goals: _goals,
          subjects: _subjects,
          onAddGoal: _addGoal,
          onDeleteGoal: _deleteGoal),
      TimerScreen(
          key: ValueKey(
              '$_focusDuration-$_shortBreakDuration-$_longBreakDuration-$_isSoundEnabled'),
          focusDuration: _focusDuration,
          shortBreakDuration: _shortBreakDuration,
          longBreakDuration: _longBreakDuration,
          isSoundEnabled: _isSoundEnabled,
          activeTask: _activeTask,
          onPomodoroCompleted: _onPomodoroCompleted),
      StatsScreen(history: _pomodoroHistory, schedule: _weeklySchedule),
      SettingsScreen(
          subjects: _subjects,
          onAddSubject: _addSubject,
          onDeleteSubject: _deleteSubject,
          onEditSubject: _editSubject,
          focusDuration: _focusDuration,
          shortBreakDuration: _shortBreakDuration,
          longBreakDuration: _longBreakDuration,
          isSoundEnabled: _isSoundEnabled,
          onSoundToggle: (value) => _updateState(() => _isSoundEnabled = value),
          onSettingsChanged: (focus, short, long) => _updateState(() {
                _focusDuration = focus;
                _shortBreakDuration = short;
                _longBreakDuration = long;
              }),
          points: _points,
          notes: _notes,
          onAddNote: (note) => _updateState(() => _notes.add(note)),
          onDeleteNote: (index) => _updateState(() => _notes.removeAt(index))),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey.shade600,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined), label: 'برنامه‌ریز'),
          BottomNavigationBarItem(
              icon: Icon(Icons.flag_outlined), label: 'اهداف'),
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'تایمر'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined), label: 'گزارش'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined), label: 'تنظیمات'),
        ],
      ),
    );
  }
}

// ##################################################################
// #                         SCREENS                              #
// ##################################################################

class ShamsiClock extends StatefulWidget {
  const ShamsiClock({super.key});
  @override
  State<ShamsiClock> createState() => _ShamsiClockState();
}

class _ShamsiClockState extends State<ShamsiClock> {
  late Timer _timer;
  late shamsi.Jalali _now;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer =
        Timer.periodic(const Duration(seconds: 1), (timer) => _updateTime());
  }

  void _updateTime() {
    if (mounted) setState(() => _now = shamsi.Jalali.now());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formattedTime = DateFormat('HH:mm:ss').format(DateTime.now());
    final formattedDate =
        '${_now.formatter.wN}، ${_now.formatter.d} ${_now.formatter.mN}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Center(
        child: Text('$formattedDate | $formattedTime',
            style: const TextStyle(fontSize: 14, color: Colors.black54)),
      ),
    );
  }
}

class TimerScreen extends StatefulWidget {
  final int focusDuration, shortBreakDuration, longBreakDuration;
  final bool isSoundEnabled;
  final Task? activeTask;
  final VoidCallback onPomodoroCompleted;

  const TimerScreen(
      {super.key,
      required this.focusDuration,
      required this.shortBreakDuration,
      required this.longBreakDuration,
      required this.isSoundEnabled,
      required this.activeTask,
      required this.onPomodoroCompleted});
  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

enum TimerMode { focus, shortBreak, longBreak }

class _TimerScreenState extends State<TimerScreen> {
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isActive = false;
  TimerMode _currentMode = TimerMode.focus;
  int _pomodoroCount = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  int get _durationForCurrentMode {
    switch (_currentMode) {
      case TimerMode.focus:
        return widget.focusDuration * 60;
      case TimerMode.shortBreak:
        return widget.shortBreakDuration * 60;
      case TimerMode.longBreak:
        return widget.longBreakDuration * 60;
    }
  }

  void _startNextMode() {
    _timer?.cancel();
    setState(() {
      _isActive = false;
      if (_currentMode == TimerMode.focus) {
        widget.onPomodoroCompleted();
        _pomodoroCount++;
        _currentMode = (_pomodoroCount % 4 == 0)
            ? TimerMode.longBreak
            : TimerMode.shortBreak;
      } else {
        _currentMode = TimerMode.focus;
      }
      _resetTimer();
      _toggleTimer();
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isActive = false;
      _remainingSeconds = _durationForCurrentMode;
    });
  }

  void _toggleTimer() {
    setState(() => _isActive = !_isActive);
    if (_isActive) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds <= 0) {
          _playSound();
          _startNextMode();
        } else {
          setState(() => _remainingSeconds--);
        }
      });
    } else {
      _timer?.cancel();
    }
  }

  String get _timerString {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get _modeString {
    switch (_currentMode) {
      case TimerMode.focus:
        return "زمان تمرکز";
      case TimerMode.shortBreak:
        return "استراحت کوتاه";
      case TimerMode.longBreak:
        return "استراحت بلند";
    }
  }

  Future<void> _playSound() async {
    try {
      if (widget.isSoundEnabled) {
        await _audioPlayer.play(AssetSource('sounds/bell.mp3'));
      }
    } catch (e) {
      print("Error playing sound: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('تایمر پومودورو'), actions: const [ShamsiClock()]),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 280,
              height: 280,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                      painter: PomodoroClockPainter(),
                      size: const Size(280, 280)),
                  Text(_timerString,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                                blurRadius: 10.0,
                                color: Colors.black38,
                                offset: Offset(2.0, 2.0))
                          ])),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(_modeString, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(widget.activeTask?.title ?? "هیچ فعالیتی انتخاب نشده",
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                    icon: const Icon(Icons.replay),
                    onPressed: _resetTimer,
                    iconSize: 40),
                const SizedBox(width: 20),
                IconButton(
                    icon: Icon(_isActive
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled),
                    onPressed: _toggleTimer,
                    iconSize: 70,
                    color: Theme.of(context).primaryColor),
                const SizedBox(width: 20),
                IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: _startNextMode,
                    iconSize: 40),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PlannerScreen extends StatelessWidget {
  final Map<String, List<Task>> schedule;
  final List<String> subjects;
  final Function(String, Task) onAddTask;
  final Function(String, Task) onToggleTask;
  final Function(String, Task) onDeleteTask;
  final Function(Task?) onSetActiveTask;
  final Task? activeTask;

  const PlannerScreen(
      {super.key,
      required this.schedule,
      required this.subjects,
      required this.onAddTask,
      required this.onToggleTask,
      required this.onDeleteTask,
      required this.onSetActiveTask,
      required this.activeTask});

  void _showAddTaskDialog(BuildContext context, String day) {
    final titleController = TextEditingController();
    String selectedSubject = subjects.isNotEmpty ? subjects.first : '';
    final pomodoroController = TextEditingController(text: '1');
    TaskPriority selectedPriority = TaskPriority.none;
    DateTime? selectedReminderTime;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text('افزودن فعالیت برای $day'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                        controller: titleController,
                        decoration:
                            const InputDecoration(labelText: 'عنوان فعالیت')),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                        value: selectedSubject,
                        items: subjects
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (value) =>
                            selectedSubject = value ?? selectedSubject,
                        decoration:
                            const InputDecoration(labelText: 'درس/موضوع')),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<TaskPriority>(
                        value: selectedPriority,
                        items: TaskPriority.values
                            .map((p) => DropdownMenuItem(
                                value: p, child: Text(_priorityToString(p))))
                            .toList(),
                        onChanged: (value) =>
                            selectedPriority = value ?? selectedPriority,
                        decoration: const InputDecoration(labelText: 'اولویت')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: pomodoroController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'تعداد پومودورو لازم')),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: Text(selectedReminderTime == null
                          ? 'افزودن یادآور'
                          : () {
                              final jalali = shamsi.Jalali.fromDateTime(
                                  selectedReminderTime!);
                              final dateComponent =
                                  '${jalali.year}/${jalali.month.toString().padLeft(2, '0')}/${jalali.day.toString().padLeft(2, '0')}';
                              final timeComponent = DateFormat('HH:mm')
                                  .format(selectedReminderTime!);
                              return '$dateComponent – $timeComponent';
                            }()),
                      onPressed: () async {
                        try {
                          Jalali? picked = await showPersianDatePicker(
                            context: context,
                            initialDate: Jalali.now(),
                            firstDate: Jalali.now(),
                            lastDate: Jalali(Jalali.now().year + 1,
                                Jalali.now().month, Jalali.now().day),
                          );

                          if (picked == null) return;

                          final time = await showTimePicker(
                              context: context,
                              initialTime:
                                  TimeOfDay.fromDateTime(DateTime.now()));
                          if (time == null) return;

                          setDialogState(() => selectedReminderTime = picked
                              .toDateTime()
                              .add(Duration(
                                  hours: time.hour, minutes: time.minute)));
                        } catch (e) {
                          print("Error opening date picker: $e");
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'خطایی در باز کردن انتخابگر تاریخ رخ داد.',
                                        textDirection: TextDirection.rtl)));
                          }
                        }
                      },
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('لغو')),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty) {
                      final estPomodoros =
                          int.tryParse(pomodoroController.text) ?? 1;
                      onAddTask(
                          day,
                          Task(
                              title: titleController.text,
                              subject: selectedSubject,
                              estimatedPomodoros: estPomodoros,
                              priority: selectedPriority,
                              reminderTime: selectedReminderTime));
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('افزودن'),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Colors.red.shade300;
      case TaskPriority.medium:
        return Colors.orange.shade300;
      case TaskPriority.low:
        return Colors.blue.shade300;
      default:
        return Colors.transparent;
    }
  }

  static String _priorityToString(TaskPriority p) {
    switch (p) {
      case TaskPriority.high:
        return "بالا";
      case TaskPriority.medium:
        return "متوسط";
      case TaskPriority.low:
        return "پایین";
      default:
        return "هیچکدام";
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: schedule.keys.length,
      child: Builder(builder: (BuildContext builderContext) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('برنامه‌ریز هفتگی'),
            actions: const [ShamsiClock()],
            bottom: TabBar(
                isScrollable: true,
                tabs: schedule.keys.map((day) => Tab(text: day)).toList()),
          ),
          body: TabBarView(
            children: schedule.keys.map((day) {
              final tasks = schedule[day]!;
              if (tasks.isEmpty) {
                return const Center(
                    child: Text("برای این روز فعالیتی ثبت نشده است."));
              }
              tasks
                  .sort((a, b) => b.priority.index.compareTo(a.priority.index));

              return ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final bool isActive = activeTask == task;
                  return Card(
                    shape: RoundedRectangleBorder(
                        side: BorderSide(
                            color: _getPriorityColor(task.priority), width: 2),
                        borderRadius: BorderRadius.circular(8)),
                    color: isActive ? Colors.red.shade50 : null,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      onTap: () => onSetActiveTask(isActive ? null : task),
                      leading: Checkbox(
                          value: task.isDone,
                          onChanged: (val) => onToggleTask(day, task)),
                      title: Text(task.title,
                          style: TextStyle(
                              decoration: task.isDone
                                  ? TextDecoration.lineThrough
                                  : null)),
                      subtitle: Text(task.subject),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (task.reminderTime != null)
                            const Icon(Icons.notifications_active_outlined,
                                size: 16, color: Colors.grey),
                          Text(
                              '${task.completedPomodoros}/${task.estimatedPomodoros}'),
                          IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () => onDeleteTask(day, task)),
                        ],
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              final index = DefaultTabController.of(builderContext).index;
              if (index != -1) {
                final day = schedule.keys.toList()[index];
                _showAddTaskDialog(context, day);
              }
            },
            child: const Icon(Icons.add),
          ),
        );
      }),
    );
  }
}

class GoalsScreen extends StatelessWidget {
  final List<Goal> goals;
  final List<String> subjects;
  final Function(Goal) onAddGoal;
  final Function(Goal) onDeleteGoal;

  const GoalsScreen(
      {super.key,
      required this.goals,
      required this.subjects,
      required this.onAddGoal,
      required this.onDeleteGoal});

  void _showAddGoalDialog(BuildContext context) {
    final titleController = TextEditingController();
    final pomodoroController = TextEditingController();
    String selectedSubject = subjects.isNotEmpty ? subjects.first : '';

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('افزودن هدف جدید'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: titleController,
                      decoration:
                          const InputDecoration(labelText: 'عنوان هدف')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                      value: selectedSubject,
                      items: subjects
                          .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (value) =>
                          selectedSubject = value ?? selectedSubject,
                      decoration:
                          const InputDecoration(labelText: 'درس مرتبط')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: pomodoroController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'تعداد پومودورو برای رسیدن به هدف')),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('لغو')),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.isNotEmpty &&
                      pomodoroController.text.isNotEmpty) {
                    final target = int.tryParse(pomodoroController.text) ?? 0;
                    if (target > 0) {
                      onAddGoal(Goal(
                          title: titleController.text,
                          subject: selectedSubject,
                          targetPomodoros: target));
                      Navigator.pop(context);
                    }
                  }
                },
                child: const Text('افزودن'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('اهداف تحصیلی'), actions: const [ShamsiClock()]),
      body: goals.isEmpty
          ? const Center(child: Text("هنوز هدفی تعیین نکرده‌اید."))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: goals.length,
              itemBuilder: (context, index) {
                final goal = goals[index];
                final progress =
                    (goal.completedPomodoros / goal.targetPomodoros)
                        .clamp(0.0, 1.0);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(goal.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18)),
                            IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                onPressed: () => onDeleteGoal(goal)),
                          ],
                        ),
                        Text(goal.subject,
                            style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                                child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 10,
                                    borderRadius: BorderRadius.circular(5))),
                            const SizedBox(width: 10),
                            Text(
                                '${goal.completedPomodoros}/${goal.targetPomodoros}')
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGoalDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class StatsScreen extends StatelessWidget {
  final List<PomodoroHistory> history;
  final Map<String, List<Task>> schedule;
  const StatsScreen({super.key, required this.history, required this.schedule});

  int _calculateStreak(List<PomodoroHistory> history) {
    if (history.isEmpty) return 0;
    final uniqueDays = history
        .map((h) => DateTime(h.date.year, h.date.month, h.date.day))
        .toSet()
        .toList();
    uniqueDays.sort((a, b) => b.compareTo(a));

    if (uniqueDays.isEmpty) return 0;
    int streak = 0;
    DateTime todayDate = DateTime.now();
    todayDate = DateTime(todayDate.year, todayDate.month, todayDate.day);
    if (uniqueDays.first.isAtSameMomentAs(todayDate) ||
        uniqueDays.first
            .isAtSameMomentAs(todayDate.subtract(const Duration(days: 1)))) {
      streak = 1;
      for (int i = 0; i < uniqueDays.length - 1; i++) {
        if (uniqueDays[i]
            .subtract(const Duration(days: 1))
            .isAtSameMomentAs(uniqueDays[i + 1])) {
          streak++;
        } else {
          break;
        }
      }
    }
    return streak;
  }

  Map<String, double> _getSubjectData() {
    final Map<String, double> subjectPomodoros = {};
    schedule.forEach((day, tasks) {
      for (var task in tasks) {
        if (task.completedPomodoros > 0) {
          subjectPomodoros.update(
            task.subject,
            (value) => value + task.completedPomodoros,
            ifAbsent: () => task.completedPomodoros.toDouble(),
          );
        }
      }
    });
    return subjectPomodoros;
  }

  @override
  Widget build(BuildContext context) {
    final subjectData = _getSubjectData();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('گزارش عملکرد'),
          actions: const [ShamsiClock()],
          bottom: const TabBar(tabs: [
            Tab(text: 'نمای کلی', icon: Icon(Icons.pie_chart_outline)),
            Tab(text: 'نقشه فعالیت', icon: Icon(Icons.calendar_month_outlined)),
          ]),
        ),
        body: TabBarView(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Card(
                    child: ListTile(
                        leading: const Icon(Icons.local_fire_department,
                            color: Colors.orange),
                        title: const Text("زنجیره مطالعه"),
                        trailing: Text(
                            "${_calculateStreak(history)} روز متوالی",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)))),
                const SizedBox(height: 20),
                const Text("پومودوروها بر اساس درس",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                subjectData.isEmpty
                    ? const Text("هنوز پومودورویی ثبت نشده است.")
                    : SizedBox(
                        height: 250,
                        child: PieChart(PieChartData(
                            sections: subjectData.entries.map((entry) {
                              return PieChartSectionData(
                                  color: Colors.primaries[subjectData.keys
                                          .toList()
                                          .indexOf(entry.key) %
                                      Colors.primaries.length],
                                  value: entry.value,
                                  title: '${entry.key}\n${entry.value.toInt()}',
                                  radius: 100,
                                  titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12));
                            }).toList(),
                            sectionsSpace: 2,
                            centerSpaceRadius: 40)),
                      )
              ]),
            ),
            Card(
              margin: const EdgeInsets.all(8),
              child: TableCalendar(
                locale: 'fa_IR',
                startingDayOfWeek: StartingDayOfWeek.saturday,
                headerStyle: const HeaderStyle(
                    formatButtonVisible: false, titleCentered: true),
                focusedDay: DateTime.now(),
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                calendarBuilders: CalendarBuilders(
                  headerTitleBuilder: (context, day) {
                    final jalali = shamsi.Jalali.fromDateTime(day);
                    return Center(
                        child: Text(
                            '${jalali.formatter.mN} ${jalali.formatter.yyyy}',
                            style: Theme.of(context).textTheme.bodyLarge));
                  },
                  defaultBuilder: (context, day, focusedDay) {
                    final jalaliDay = shamsi.Jalali.fromDateTime(day).day;
                    final dayHistory =
                        history.where((h) => isSameDay(h.date, day)).toList();
                    if (dayHistory.isNotEmpty) {
                      return Container(
                          margin: const EdgeInsets.all(4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: Colors.green.withOpacity(
                                  math.min(dayHistory.length / 5, 1.0)),
                              shape: BoxShape.circle),
                          child: Text(jalaliDay.toString(),
                              style: const TextStyle(color: Colors.black)));
                    }
                    return Center(child: Text(jalaliDay.toString()));
                  },
                  todayBuilder: (context, day, focusedDay) {
                    final jalaliDay = shamsi.Jalali.fromDateTime(day).day;
                    final dayHistory =
                        history.where((h) => isSameDay(h.date, day)).toList();
                    return Container(
                      margin: const EdgeInsets.all(4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: dayHistory.isNotEmpty
                            ? Colors.green.withOpacity(
                                math.min(dayHistory.length / 5, 1.0))
                            : Theme.of(context).primaryColor.withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Theme.of(context).primaryColor, width: 1.5),
                      ),
                      child: Text(jalaliDay.toString(),
                          style: const TextStyle(color: Colors.black)),
                    );
                  },
                  outsideBuilder: (context, day, focusedDay) {
                    final jalaliDay = shamsi.Jalali.fromDateTime(day).day;
                    return Center(
                        child: Text(jalaliDay.toString(),
                            style: const TextStyle(color: Colors.grey)));
                  },
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final List<String> subjects;
  final Function(String) onAddSubject, onDeleteSubject;
  final Function(String, String) onEditSubject;
  final int focusDuration, shortBreakDuration, longBreakDuration, points;
  final bool isSoundEnabled;
  final Function(bool) onSoundToggle;
  final Function(int, int, int) onSettingsChanged;
  final List<String> notes;
  final Function(String) onAddNote;
  final Function(int) onDeleteNote;

  const SettingsScreen(
      {super.key,
      required this.subjects,
      required this.onAddSubject,
      required this.onDeleteSubject,
      required this.onEditSubject,
      required this.focusDuration,
      required this.shortBreakDuration,
      required this.longBreakDuration,
      required this.isSoundEnabled,
      required this.onSoundToggle,
      required this.onSettingsChanged,
      required this.points,
      required this.notes,
      required this.onAddNote,
      required this.onDeleteNote});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _focus, _short, _long;

  @override
  void initState() {
    super.initState();
    _focus = widget.focusDuration;
    _short = widget.shortBreakDuration;
    _long = widget.longBreakDuration;
  }

  void _showManageSubjectDialog(BuildContext context,
      {String? existingSubject}) {
    final controller = TextEditingController(text: existingSubject);
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
              existingSubject == null ? 'افزودن موضوع جدید' : 'ویرایش موضوع'),
          content: TextField(
              controller: controller,
              decoration:
                  const InputDecoration(labelText: 'نام درس یا فعالیت')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('لغو')),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  if (existingSubject == null) {
                    widget.onAddSubject(controller.text);
                  } else {
                    widget.onEditSubject(existingSubject, controller.text);
                  }
                  Navigator.pop(context);
                }
              },
              child: Text(existingSubject == null ? 'افزودن' : 'ذخیره'),
            ),
          ],
        ),
      ),
    );
  }

  int get _level => (widget.points / 100).floor() + 1;
  double get _levelProgress => (widget.points % 100) / 100.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('تنظیمات و پروفایل'),
          actions: const [ShamsiClock()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('پروفایل شما', style: Theme.of(context).textTheme.headlineSmall),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(children: [
                Text("سطح $_level",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                    value: _levelProgress,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 8),
                Text("${widget.points % 100} / 100 امتیاز تا سطح بعدی"),
              ]),
            ),
          ),
          const Divider(height: 40),
          ListTile(
              leading: const Icon(Icons.note_alt_outlined),
              title: const Text('یادداشت‌ها'),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (c) => NotesScreen(
                          notes: widget.notes,
                          onAddNote: widget.onAddNote,
                          onDeleteNote: widget.onDeleteNote)))),
          ListTile(
              leading: const Icon(Icons.contact_mail_outlined),
              title: const Text('تماس با ما'),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (c) => const ContactScreen()))),
          const Divider(height: 40),
          Text('تنظیمات تایمر',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          _SettingSlider(
              label: 'زمان تمرکز (دقیقه)',
              value: _focus,
              onChanged: (val) => setState(() => _focus = val.round())),
          _SettingSlider(
              label: 'استراحت کوتاه (دقیقه)',
              value: _short,
              onChanged: (val) => setState(() => _short = val.round())),
          _SettingSlider(
              label: 'استراحت بلند (دقیقه)',
              value: _long,
              max: 30,
              onChanged: (val) => setState(() => _long = val.round())),
          SwitchListTile(
              title: const Text('پخش صدای زنگ پایان'),
              value: widget.isSoundEnabled,
              onChanged: widget.onSoundToggle,
              secondary: const Icon(Icons.volume_up_outlined)),
          ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text("ذخیره تنظیمات تایمر"),
              onPressed: () {
                widget.onSettingsChanged(_focus, _short, _long);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("تغییرات تایمر ذخیره شد.",
                        textDirection: TextDirection.rtl)));
              }),
          const Divider(height: 40),
          Text('مدیریت دروس و فعالیت‌ها',
              style: Theme.of(context).textTheme.headlineSmall),
          ...widget.subjects.map((subject) => ListTile(
                title: Text(subject),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      onPressed: () => _showManageSubjectDialog(context,
                          existingSubject: subject)),
                  IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => widget.onDeleteSubject(subject)),
                ]),
              )),
          ListTile(
              leading: const Icon(Icons.add, color: Colors.green),
              title: const Text('افزودن موضوع جدید...'),
              onTap: () => _showManageSubjectDialog(context)),
        ],
      ),
    );
  }
}

class _SettingSlider extends StatelessWidget {
  final String label;
  final int value;
  final double max;
  final Function(double) onChanged;

  const _SettingSlider(
      {required this.label,
      required this.value,
      this.max = 60,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label: $value', style: Theme.of(context).textTheme.bodyMedium),
      Slider(
          value: value.toDouble(),
          min: 1,
          max: max,
          divisions: (max - 1).toInt(),
          label: value.toString(),
          onChanged: onChanged),
    ]);
  }
}

class NotesScreen extends StatelessWidget {
  final List<String> notes;
  final Function(String) onAddNote;
  final Function(int) onDeleteNote;

  const NotesScreen(
      {super.key,
      required this.notes,
      required this.onAddNote,
      required this.onDeleteNote});

  void _showAddNoteDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('یادداشت جدید'),
          content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'متن یادداشت...'),
              maxLines: 4),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('لغو')),
            ElevatedButton(
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    onAddNote(controller.text);
                    Navigator.pop(context);
                  }
                },
                child: const Text('ذخیره')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('یادداشت‌ها'), actions: const [ShamsiClock()]),
      body: notes.isEmpty
          ? const Center(child: Text("یادداشتی برای نمایش وجود ندارد."))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    title: Text(notes[index]),
                    trailing: IconButton(
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => onDeleteNote(index)),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddNoteDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('تماس با ما'), actions: const [ShamsiClock()]),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Icon(Icons.school,
                      size: 80, color: Theme.of(context).primaryColor)),
              const SizedBox(height: 20),
              Text('درباره پومویار',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              const Text(
                  '«پومویار» با تکنیک پومودورو به شما دانش‌آموزان عزیز کمک می‌کند تا زمان خود را بهتر مدیریت کرده، با تمرکز بالاتری درس بخوانید و از استرس خود بکاهید. با برنامه‌ریزی هفتگی و مشاهده گزارش عملکرد، می‌توانید پیشرفت خود را دنبال کنید و به اهداف تحصیلی خود برسید.',
                  style: TextStyle(fontSize: 16, height: 1.8)),
              const Divider(height: 40),
              Text('سازنده', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              const Text('حمیدرضا علی میرزایی',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Text('ارتباط و ارائه پیشنهاد',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              const Text(
                  'نظرات و پیشنهادات شما برای بهبود این برنامه بسیار ارزشمند است. می‌توانید از طریق ایمیل زیر با من در ارتباط باشید:',
                  style: TextStyle(fontSize: 16, height: 1.8)),
              const SizedBox(height: 10),
              SelectableText(
                'alimirzaei.hr@gmail.com',
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ##################################################################
// #                         CUSTOM PAINTERS                      #
// ##################################################################

class PomodoroClockPainter extends CustomPainter {
  PomodoroClockPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 * 0.9;

    final bodyRect = Rect.fromCircle(center: center, radius: radius);
    final bodyPaint = Paint()
      ..shader = const RadialGradient(
          colors: [Color(0xFFFC8181), Color(0xFFE53E3E), Color(0xFFC53030)],
          stops: [0.0, 0.8, 1.0]).createShader(bodyRect);
    canvas.drawCircle(center, radius, bodyPaint);

    final lightPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    final lightPath = Path();
    lightPath.moveTo(center.dx - radius * 0.5, center.dy - radius * 0.6);
    lightPath.quadraticBezierTo(center.dx, center.dy - radius * 1.0,
        center.dx + radius * 0.6, center.dy - radius * 0.5);
    lightPath.quadraticBezierTo(
        center.dx + radius * 0.4,
        center.dy - radius * 0.2,
        center.dx - radius * 0.5,
        center.dy - radius * 0.6);
    lightPath.close();
    canvas.drawPath(lightPath, lightPaint);

    final leafPaint = Paint()..color = const Color(0xFF38A169);
    final stemPaint = Paint()..color = const Color(0xFF2F855A);

    final stemPath = Path();
    stemPath.moveTo(center.dx - 4, center.dy - radius * 0.9);
    stemPath.quadraticBezierTo(center.dx, center.dy - radius * 1.2,
        center.dx + 4, center.dy - radius * 0.9);
    stemPath.cubicTo(center.dx + 6, center.dy - radius * 1.3, center.dx - 6,
        center.dy - radius * 1.3, center.dx - 4, center.dy - radius * 0.9);
    stemPath.close();
    canvas.drawPath(stemPath, stemPaint);

    for (int i = 0; i < 5; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy - radius * 0.9);
      canvas.rotate(i * (360 / 5) * (math.pi / 180));
      final leafPath = Path();
      leafPath.moveTo(0, 0);
      leafPath.quadraticBezierTo(15, -25, 0, -40);
      leafPath.quadraticBezierTo(-15, -25, 0, 0);
      leafPath.close();
      canvas.drawPath(leafPath, leafPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
