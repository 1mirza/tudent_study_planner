import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

void main() {
  runApp(const PomodoroApp());
}

// --- Data Models ---
class Task {
  String title;
  String subject;
  int estimatedPomodoros;
  int completedPomodoros;
  bool isDone;

  Task({
    required this.title,
    required this.subject,
    this.estimatedPomodoros = 1,
    this.completedPomodoros = 0,
    this.isDone = false,
  });

  // Methods for persistence (saving/loading)
  Map<String, dynamic> toJson() => {
        'title': title,
        'subject': subject,
        'estimatedPomodoros': estimatedPomodoros,
        'completedPomodoros': completedPomodoros,
        'isDone': isDone,
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        title: json['title'],
        subject: json['subject'],
        estimatedPomodoros: json['estimatedPomodoros'],
        completedPomodoros: json['completedPomodoros'],
        isDone: json['isDone'],
      );
}

class PomodoroApp extends StatelessWidget {
  const PomodoroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'برنامه ی زمانبدی درسی دانش اموزان',
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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fa', ''), // Persian
      ],
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 2;
  bool _isLoading = true;

  // --- State Data ---
  List<String> _subjects = [];
  Map<String, List<Task>> _weeklySchedule = {};
  List<String> _notes = [];
  int _focusDuration = 25;
  int _shortBreakDuration = 5;
  int _longBreakDuration = 15;
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

    final scheduleString = json.encode(_weeklySchedule.map((key, value) {
      return MapEntry(key, value.map((task) => task.toJson()).toList());
    }));
    await prefs.setString('weeklySchedule', scheduleString);
  }

  // --- Methods to update state & save ---
  void _updateState(VoidCallback callback) {
    setState(callback);
    _saveData();
  }

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
              if (task.subject == oldSubject) {
                task.subject = newSubject;
              }
            }
          });
        }
      });
    }
  }

  void _addTask(String day, Task task) =>
      _updateState(() => _weeklySchedule[day]?.add(task));
  void _toggleTask(String day, Task task) =>
      _updateState(() => task.isDone = !task.isDone);
  void _deleteTask(String day, Task task) =>
      _updateState(() => _weeklySchedule[day]?.remove(task));
  void _addNote(String note) => _updateState(() => _notes.add(note));
  void _deleteNote(int index) => _updateState(() => _notes.removeAt(index));
  void _setActiveTask(Task? task) => setState(() => _activeTask = task);

  void _onPomodoroCompleted() {
    if (_activeTask != null) {
      _updateState(() => _activeTask!.completedPomodoros++);
    }
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
        activeTask: _activeTask,
      ),
      StatsScreen(schedule: _weeklySchedule),
      TimerScreen(
        key: ValueKey(
            '$_focusDuration-$_shortBreakDuration-$_longBreakDuration'), // Rebuild timer if durations change
        focusDuration: _focusDuration,
        shortBreakDuration: _shortBreakDuration,
        longBreakDuration: _longBreakDuration,
        activeTask: _activeTask,
        onPomodoroCompleted: _onPomodoroCompleted,
      ),
      NotesScreen(
          notes: _notes, onAddNote: _addNote, onDeleteNote: _deleteNote),
      SettingsScreen(
        subjects: _subjects,
        onAddSubject: _addSubject,
        onDeleteSubject: _deleteSubject,
        onEditSubject: _editSubject,
        focusDuration: _focusDuration,
        shortBreakDuration: _shortBreakDuration,
        longBreakDuration: _longBreakDuration,
        onSettingsChanged: (focus, short, long) {
          _updateState(() {
            _focusDuration = focus;
            _shortBreakDuration = short;
            _longBreakDuration = long;
          });
        },
      ),
      const ContactScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey.shade600,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today), label: 'برنامه‌ریز'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'گزارش'),
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'تایمر'),
          BottomNavigationBarItem(icon: Icon(Icons.note), label: 'یادداشت'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'تنظیمات'),
          BottomNavigationBarItem(
              icon: Icon(Icons.contact_mail), label: 'تماس با ما'),
        ],
      ),
    );
  }
}

// --- Screens ---
class TimerScreen extends StatefulWidget {
  final int focusDuration;
  final int shortBreakDuration;
  final int longBreakDuration;
  final Task? activeTask;
  final VoidCallback onPomodoroCompleted;

  const TimerScreen({
    super.key,
    required this.focusDuration,
    required this.shortBreakDuration,
    required this.longBreakDuration,
    required this.activeTask,
    required this.onPomodoroCompleted,
  });

  @override
  _TimerScreenState createState() => _TimerScreenState();
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

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isActive = false;
      _remainingSeconds = _durationForCurrentMode;
    });
  }

  void _toggleTimer() {
    setState(() {
      _isActive = !_isActive;
      if (_isActive) {
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_remainingSeconds <= 0) {
            _playSoundAndShowDialog();
            _startNextMode();
          } else {
            setState(() => _remainingSeconds--);
          }
        });
      } else {
        _timer?.cancel();
      }
    });
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

  Future<void> _playSoundAndShowDialog() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/bell.mp3'));
    } catch (e) {
      print("Error playing sound: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final double progress = 1.0 -
        (_remainingSeconds /
                (_durationForCurrentMode == 0 ? 1 : _durationForCurrentMode))
            .clamp(0.0, 1.0);
    return Scaffold(
      appBar: AppBar(title: const Text('تایمر پومودورو')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 250,
              height: 250,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: TomatoPainter(progress: progress)),
                  Center(
                    child: Text(
                      _timerString,
                      style: const TextStyle(
                          fontSize: 60,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
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
                  color: Theme.of(context).primaryColor,
                ),
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

class TomatoPainter extends CustomPainter {
  final double progress;
  TomatoPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect =
        Rect.fromCenter(center: center, width: size.width, height: size.height);

    // Tomato Body (background)
    final bodyPaint = Paint()..color = Colors.red.shade200;
    canvas.drawOval(rect, bodyPaint);

    // Tomato Fill (progress)
    final fillPaint = Paint()..color = Colors.red.shade600;
    final path = Path();
    path.moveTo(rect.left, rect.bottom);
    path.lineTo(rect.left, rect.bottom - (rect.height * progress));
    path.lineTo(rect.right, rect.bottom - (rect.height * progress));
    path.lineTo(rect.right, rect.bottom);
    path.close();

    // Create a clip path to keep the fill inside the oval
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    canvas.drawPath(path, fillPaint);
    canvas.restore();

    // Tomato Leaf
    final leafPaint = Paint()..color = Colors.green.shade700;
    final leafPath = Path();
    leafPath.moveTo(center.dx, center.dy - size.height * 0.4);
    leafPath.quadraticBezierTo(center.dx + 20, center.dy - size.height * 0.5,
        center.dx, center.dy - size.height * 0.6);
    leafPath.quadraticBezierTo(center.dx - 20, center.dy - size.height * 0.5,
        center.dx, center.dy - size.height * 0.4);
    canvas.drawPath(leafPath, leafPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PlannerScreen extends StatelessWidget {
  final Map<String, List<Task>> schedule;
  final List<String> subjects;
  final Function(String, Task) onAddTask;
  final Function(String, Task) onToggleTask;
  final Function(String, Task) onDeleteTask;
  final Function(Task?) onSetActiveTask;
  final Task? activeTask;

  const PlannerScreen({
    super.key,
    required this.schedule,
    required this.subjects,
    required this.onAddTask,
    required this.onToggleTask,
    required this.onDeleteTask,
    required this.onSetActiveTask,
    required this.activeTask,
  });

  void _showAddTaskDialog(BuildContext context, String day) {
    final titleController = TextEditingController();
    String selectedSubject = subjects.isNotEmpty ? subjects.first : '';
    final pomodoroController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) {
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
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (value) =>
                        selectedSubject = value ?? selectedSubject,
                    decoration: const InputDecoration(labelText: 'درس/موضوع'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                      controller: pomodoroController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'تعداد پومودورو لازم')),
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
                            estimatedPomodoros: estPomodoros));
                    Navigator.pop(context);
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
    return DefaultTabController(
      length: schedule.keys.length,
      child: Builder(builder: (BuildContext builderContext) {
        // <-- [FIX] Added Builder widget
        return Scaffold(
          appBar: AppBar(
            title: const Text('برنامه‌ریز هفتگی'),
            bottom: TabBar(
              isScrollable: true,
              tabs: schedule.keys.map((day) => Tab(text: day)).toList(),
            ),
          ),
          body: TabBarView(
            children: schedule.keys.map((day) {
              final tasks = schedule[day]!;
              if (tasks.isEmpty) {
                return const Center(
                    child: Text("برای این روز فعالیتی ثبت نشده است."));
              }
              return ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final bool isActive = activeTask == task;
                  return Card(
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
              // Use builderContext which is a descendant of DefaultTabController
              final index = DefaultTabController.of(builderContext).index;
              if (index != -1) {
                final day = schedule.keys.toList()[index];
                _showAddTaskDialog(builderContext, day);
              }
            },
            child: const Icon(Icons.add),
          ),
        );
      }),
    );
  }
}

class StatsScreen extends StatelessWidget {
  final Map<String, List<Task>> schedule;
  const StatsScreen({super.key, required this.schedule});

  @override
  Widget build(BuildContext context) {
    final Map<String, int> subjectPomodoros = {};
    schedule.forEach((day, tasks) {
      for (var task in tasks) {
        subjectPomodoros.update(
          task.subject,
          (value) => value + task.completedPomodoros,
          ifAbsent: () => task.completedPomodoros,
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('گزارش عملکرد')),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('پومودوروهای انجام شده این هفته',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              if (subjectPomodoros.isEmpty ||
                  subjectPomodoros.values.every((v) => v == 0))
                const Center(child: Text("هنوز پومودورویی ثبت نشده است."))
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: subjectPomodoros.length,
                    itemBuilder: (context, index) {
                      final subject = subjectPomodoros.keys.elementAt(index);
                      final count = subjectPomodoros[subject]!;
                      if (count == 0) return const SizedBox.shrink();
                      return Card(
                        child: ListTile(
                          title: Text(subject),
                          trailing: Text('$count پومودورو',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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
            maxLines: 4,
          ),
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
      appBar: AppBar(title: const Text('یادداشت‌ها')),
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
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => onDeleteNote(index),
                    ),
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

class SettingsScreen extends StatefulWidget {
  final List<String> subjects;
  final Function(String) onAddSubject;
  final Function(String) onDeleteSubject;
  final Function(String, String) onEditSubject;
  final int focusDuration;
  final int shortBreakDuration;
  final int longBreakDuration;
  final Function(int, int, int) onSettingsChanged;

  const SettingsScreen({
    super.key,
    required this.subjects,
    required this.onAddSubject,
    required this.onDeleteSubject,
    required this.onEditSubject,
    required this.focusDuration,
    required this.shortBreakDuration,
    required this.longBreakDuration,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _focus;
  late int _short;
  late int _long;

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
            decoration: const InputDecoration(labelText: 'نام درس یا فعالیت'),
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              widget.onSettingsChanged(_focus, _short, _long);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("تغییرات ذخیره شد.",
                        textDirection: TextDirection.rtl)),
              );
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('تنظیمات تایمر',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          _SettingSlider(
            label: 'زمان تمرکز (دقیقه)',
            value: _focus,
            onChanged: (val) => setState(() => _focus = val.round()),
          ),
          _SettingSlider(
            label: 'استراحت کوتاه (دقیقه)',
            value: _short,
            onChanged: (val) => setState(() => _short = val.round()),
          ),
          _SettingSlider(
            label: 'استراحت بلند (دقیقه)',
            value: _long,
            max: 30,
            onChanged: (val) => setState(() => _long = val.round()),
          ),
          const Divider(height: 40),
          Text('مدیریت دروس و فعالیت‌ها',
              style: Theme.of(context).textTheme.headlineSmall),
          ...widget.subjects.map((subject) => ListTile(
                title: Text(subject),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      onPressed: () => _showManageSubjectDialog(context,
                          existingSubject: subject),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => widget.onDeleteSubject(subject),
                    ),
                  ],
                ),
              )),
          ListTile(
            leading: const Icon(Icons.add, color: Colors.green),
            title: const Text('افزودن موضوع جدید...'),
            onTap: () => _showManageSubjectDialog(context),
          ),
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

  const _SettingSlider({
    required this.label,
    required this.value,
    this.max = 60,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value', style: Theme.of(context).textTheme.bodyMedium),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: max,
          divisions: (max - 1).toInt(),
          label: value.toString(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تماس با ما')),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Icon(Icons.school,
                    size: 80, color: Theme.of(context).primaryColor),
              ),
              const SizedBox(height: 20),
              Text(
                'درباره اپلیکیشن',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              const Text(
                'این برنامه با تکنیک پومودورو به شما دانش‌آموزان عزیز کمک می‌کند تا زمان خود را بهتر مدیریت کرده، با تمرکز بالاتری درس بخوانید و از استرس خود بکاهید. با برنامه‌ریزی هفتگی و مشاهده گزارش عملکرد، می‌توانید پیشرفت خود را دنبال کنید و به اهداف تحصیلی خود برسید.',
                style: TextStyle(fontSize: 16, height: 1.8),
              ),
              const Divider(height: 40),
              Text(
                'سازنده',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              const Text(
                'حمیدرضا علی میرزایی',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text(
                'ارتباط و ارائه پیشنهاد',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              const Text(
                'نظرات و پیشنهادات شما برای بهبود این برنامه بسیار ارزشمند است. می‌توانید از طریق ایمیل زیر با من در ارتباط باشید:',
                style: TextStyle(fontSize: 16, height: 1.8),
              ),
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
