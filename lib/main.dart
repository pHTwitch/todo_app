import 'package:flutter/material.dart';

void main() {
  runApp(const TodoApp());
}

class TodoApp extends StatefulWidget {
  const TodoApp({super.key});

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To-Do List',
      debugShowCheckedModeBanner: false,
      theme: _isDarkMode ? AppThemes.darkTheme : AppThemes.lightTheme,
      home: TodoListScreen(
        isDarkMode: _isDarkMode,
        onThemeChanged: (bool isDark) {
          setState(() {
            _isDarkMode = isDark;
          });
        },
      ),
    );
  }
}

class AppThemes {
  // Light Theme (Original Microsoft Blue)
  static final ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme.light(
      primary: const Color(0xFF2564CF), // Microsoft Blue
      secondary: const Color(0xFF0078D4), // Bright Blue
      tertiary: const Color(0xFF106EBE), // Darker Blue
      surface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: const Color(0xFF323130),
    ),
    scaffoldBackgroundColor: const Color(0xFFF3F2F1),
    cardColor: Colors.white,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF2564CF),
      elevation: 0,
    ),
  );

  // Dark Theme (Microsoft To Do Dark)
  static final ThemeData darkTheme = ThemeData(
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFF0078D4), // Microsoft To Do Blue
      secondary: const Color(0xFF106EBE),
      tertiary: const Color(0xFF2564CF),
      surface: const Color(0xFF1F1F1F),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: const Color(0xFFE1E1E1),
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF2D2D2D),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0078D4),
      elevation: 0,
    ),
  );
}

class TodoListScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  const TodoListScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final List<TodoItem> _todos = [];
  final TextEditingController _textController = TextEditingController();

  void _addTodo() {
    if (_textController.text.trim().isEmpty) return;

    setState(() {
      _todos.add(TodoItem(
        id: DateTime.now().toString(),
        title: _textController.text.trim(),
      ));
      _textController.clear();
    });
  }

  void _toggleTodo(int index) {
    setState(() {
      _todos[index].isCompleted = !_todos[index].isCompleted;
    });
  }

  void _deleteTodo(int index) {
    setState(() {
      _todos.removeAt(index);
    });
  }

  void _editTodo(int index) {
    _textController.text = _todos[index].title;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Task'),
        content: TextField(
          controller: _textController,
          decoration: const InputDecoration(
            hintText: 'Enter task',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              _textController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (_textController.text.trim().isNotEmpty) {
                setState(() {
                  _todos[index].title = _textController.text.trim();
                  _textController.clear();
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _toggleTheme() {
    widget.onThemeChanged(!widget.isDarkMode);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final completedCount = _todos.where((todo) => todo.isCompleted).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        elevation: 0,
        title: const Text(
          'My Day',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: _toggleTheme,
            tooltip: widget.isDarkMode ? 'Light Mode' : 'Dark Mode',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Completed: $completedCount / ${_todos.length}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Add a task',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _addTodo(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _addTodo,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _todos.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: colorScheme.primary.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tasks yet!',
                    style: TextStyle(
                      fontSize: 18,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a task to get started',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _todos.length,
              itemBuilder: (context, index) {
                final todo = _todos[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: BorderSide(
                      color: colorScheme.onSurface.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    leading: Checkbox(
                      value: todo.isCompleted,
                      onChanged: (_) => _toggleTodo(index),
                    ),
                    title: Text(
                      todo.title,
                      style: TextStyle(
                        decoration: todo.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: todo.isCompleted
                            ? colorScheme.onSurface.withOpacity(0.5)
                            : null,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editTodo(index),
                          color: colorScheme.primary,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteTodo(index),
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TodoItem {
  String id;
  String title;
  bool isCompleted;

  TodoItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });
}