import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

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
      primary: const Color(0xFF2564CF),
      secondary: const Color(0xFF0078D4),
      tertiary: const Color(0xFF106EBE),
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
      primary: const Color(0xFF0078D4),
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

enum Priority { low, medium, high }

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

class _TodoListScreenState extends State<TodoListScreen> with TickerProviderStateMixin {
  final List<TodoItem> _todos = [];
  final List<String> _categories = ['My Day', 'Work', 'Personal', 'Shopping'];
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  late SharedPreferences _prefs;
  bool _isLoading = true;
  String _selectedCategory = 'My Day';
  String _filterType = 'all';
  bool _isSidebarOpen = true;

  // Animation controllers
  late AnimationController _sidebarAnimationController;
  late AnimationController _fadeInAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializePreferences();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Sidebar slide animation
    _sidebarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _sidebarAnimationController, curve: Curves.easeInOut));

    // Fade in animation for tasks
    _fadeInAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeInAnimationController, curve: Curves.easeIn),
    );
  }

  Future<void> _initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadCategories();
    await _loadTodos();
    _isSidebarOpen = _prefs.getBool('sidebarOpen') ?? true;
    setState(() {
      _isLoading = false;
    });
    _fadeInAnimationController.forward();
  }

  Future<void> _loadTodos() async {
    try {
      final todosJson = _prefs.getStringList('todos') ?? [];
      _todos.clear();
      for (var json in todosJson) {
        _todos.add(TodoItem.fromJson(jsonDecode(json)));
      }
    } catch (e) {
      debugPrint('Error loading todos: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categoriesJson = _prefs.getStringList('categories');
      if (categoriesJson != null && categoriesJson.isNotEmpty) {
        _categories.clear();
        _categories.addAll(categoriesJson);
      } else {
        await _saveCategories();
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _saveTodos() async {
    try {
      final todosJson =
      _todos.map((todo) => jsonEncode(todo.toJson())).toList();
      await _prefs.setStringList('todos', todosJson);
    } catch (e) {
      debugPrint('Error saving todos: $e');
    }
  }

  Future<void> _saveCategories() async {
    try {
      await _prefs.setStringList('categories', _categories);
    } catch (e) {
      debugPrint('Error saving categories: $e');
    }
  }

  Future<void> _saveSidebarState() async {
    try {
      await _prefs.setBool('sidebarOpen', _isSidebarOpen);
    } catch (e) {
      debugPrint('Error saving sidebar state: $e');
    }
  }

  void _addTodo() {
    if (_textController.text.trim().isEmpty) return;

    setState(() {
      _todos.add(TodoItem(
        id: DateTime.now().toString(),
        title: _textController.text.trim(),
        category: _selectedCategory,
      ));
      _textController.clear();
    });
    _saveTodos();
  }

  void _toggleTodo(int index) {
    setState(() {
      _todos[index].isCompleted = !_todos[index].isCompleted;
    });
    _saveTodos();
  }

  void _deleteTodo(int index) {
    final deletedTodo = _todos[index];
    setState(() {
      _todos.removeAt(index);
    });
    _saveTodos();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Task deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _todos.insert(index, deletedTodo);
            });
            _saveTodos();
          },
        ),
      ),
    );
  }

  void _editTodo(int index) {
    _textController.text = _todos[index].title;
    _notesController.text = _todos[index].notes;
    _showEditDialog(index);
  }

  void _showEditDialog(int index) {
    final todo = _todos[index];
    DateTime? selectedDate = todo.dueDate;
    Priority selectedPriority = todo.priority;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    labelText: 'Task Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Priority'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: Priority.values.map((priority) {
                    return ChoiceChip(
                      label: Text(_getPriorityLabel(priority)),
                      selected: selectedPriority == priority,
                      selectedColor:
                      _getPriorityColor(priority).withValues(alpha: 0.3),
                      onSelected: (selected) {
                        setState(() {
                          selectedPriority = priority;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Due Date'),
                  subtitle: Text(selectedDate != null
                      ? DateFormat('MMM dd, yyyy').format(selectedDate!)
                      : 'No due date'),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          selectedDate = pickedDate;
                        });
                      }
                    },
                  ),
                ),
                if (selectedDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Clear Due Date'),
                      onPressed: () {
                        setState(() {
                          selectedDate = null;
                        });
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _textController.clear();
                _notesController.clear();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (_textController.text.trim().isNotEmpty) {
                  setState(() {
                    _todos[index].title = _textController.text.trim();
                    _todos[index].priority = selectedPriority;
                    _todos[index].dueDate = selectedDate;
                    _todos[index].notes = _notesController.text.trim();
                    _textController.clear();
                    _notesController.clear();
                  });
                  _saveTodos();
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleTheme() {
    widget.onThemeChanged(!widget.isDarkMode);
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
    if (_isSidebarOpen) {
      _sidebarAnimationController.forward();
    } else {
      _sidebarAnimationController.reverse();
    }
    _saveSidebarState();
  }

  void _addCategory() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New List'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter list name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _categories.add(controller.text.trim());
                });
                _saveCategories();
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deleteCategory(String category) {
    if (_categories.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must keep at least one list')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete List'),
        content: Text(
            'Delete "$category"? Tasks in this list will be moved to My Day.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                for (var todo in _todos) {
                  if (todo.category == category) {
                    todo.category = 'My Day';
                  }
                }
                _categories.remove(category);
                if (_selectedCategory == category) {
                  _selectedCategory = 'My Day';
                }
              });
              _saveCategories();
              _saveTodos();
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _getPriorityLabel(Priority priority) {
    switch (priority) {
      case Priority.low:
        return 'Low';
      case Priority.medium:
        return 'Medium';
      case Priority.high:
        return 'High';
    }
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.low:
        return Colors.blue;
      case Priority.medium:
        return Colors.orange;
      case Priority.high:
        return Colors.red;
    }
  }

  List<TodoItem> _getFilteredTodos() {
    var filtered =
    _todos.where((todo) => todo.category == _selectedCategory).toList();

    if (_filterType == 'completed') {
      filtered = filtered.where((todo) => todo.isCompleted).toList();
    } else if (_filterType == 'active') {
      filtered = filtered.where((todo) => !todo.isCompleted).toList();
    }

    filtered.sort((a, b) {
      final priorityOrder = {
        Priority.high: 0,
        Priority.medium: 1,
        Priority.low: 2
      };
      return (priorityOrder[a.priority] ?? 3)
          .compareTo(priorityOrder[b.priority] ?? 3);
    });

    return filtered;
  }

  @override
  void dispose() {
    _textController.dispose();
    _notesController.dispose();
    _sidebarAnimationController.dispose();
    _fadeInAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final filteredTodos = _getFilteredTodos();
    final completedCount =
        filteredTodos.where((todo) => todo.isCompleted).length;
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        elevation: 0,
        title: const Text(
          'My Tasks',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSidebarOpen ? Icons.menu_open : Icons.menu,
              color: Colors.white,
            ),
            onPressed: _toggleSidebar,
            tooltip: _isSidebarOpen ? 'Close Menu' : 'Open Menu',
          ),
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
              'Completed: $completedCount / ${filteredTodos.length}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
      body: isMobile
          ? _buildMobileLayout(colorScheme, filteredTodos, screenSize)
          : _buildDesktopLayout(colorScheme, filteredTodos),
    );
  }

  // Replace the _buildMobileLayout method with this fixed version:

// MOBILE LAYOUT - Sidebar as drawer overlay with animation (FIXED)
  Widget _buildMobileLayout(ColorScheme colorScheme, List<TodoItem> filteredTodos, Size screenSize) {
    return Stack(
      children: [
        // Main content area
        Column(
          children: [
            _buildFilterSection(colorScheme),
            _buildAddTaskSection(colorScheme),
            _buildTaskList(colorScheme, filteredTodos),
          ],
        ),
        // Animated sidebar overlay
        if (_isSidebarOpen)
          Positioned.fill(
            child: Row(
              children: [
                // Backdrop that fades in
                Expanded(
                  child: GestureDetector(
                    onTap: () => _toggleSidebar(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      color: Colors.black.withValues(
                        alpha: _isSidebarOpen ? 0.4 : 0.0,
                      ),
                    ),
                  ),
                ),
                // Sidebar slides in from RIGHT to LEFT (correct direction)
                SlideTransition(
                  position: _slideAnimation,
                  child: SizedBox(
                    width: screenSize.width * 0.65,
                    child: Material(
                      child: _buildSidebar(colorScheme),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }


  // DESKTOP LAYOUT - Sidebar as fixed panel with animation
  Widget _buildDesktopLayout(ColorScheme colorScheme, List<TodoItem> filteredTodos) {
    return Row(
      children: [
        // Animated sidebar for desktop
        if (_isSidebarOpen)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 220),
            duration: const Duration(milliseconds: 300),
            builder: (context, width, child) {
              return SizedBox(
                width: width,
                child: child,
              );
            },
            child: _buildSidebar(colorScheme),
          ),
        // Main content - takes remaining space
        Expanded(
          child: Column(
            children: [
              _buildFilterSection(colorScheme),
              _buildAddTaskSection(colorScheme),
              _buildTaskList(colorScheme, filteredTodos),
            ],
          ),
        ),
      ],
    );
  }

  // SIDEBAR WIDGET
  Widget _buildSidebar(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final count =
                    _todos.where((t) => t.category == category).length;

                return ListTile(
                  title: Text(category),
                  subtitle: Text('$count'),
                  selected: _selectedCategory == category,
                  selectedTileColor: colorScheme.primary.withValues(alpha: 0.1),
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                    // Close sidebar on mobile when selecting
                    if (MediaQuery.of(context).size.width < 600) {
                      _toggleSidebar();
                    }
                  },
                  trailing: _categories.length > 1
                      ? PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: const Text('Delete'),
                        onTap: () => _deleteCategory(category),
                      ),
                    ],
                  )
                      : null,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _addCategory,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New List'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // FILTER SECTION
  Widget _buildFilterSection(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: const Text('All'),
              selected: _filterType == 'all',
              onSelected: (selected) {
                setState(() {
                  _filterType = 'all';
                });
              },
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Active'),
              selected: _filterType == 'active',
              onSelected: (selected) {
                setState(() {
                  _filterType = 'active';
                });
              },
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Completed'),
              selected: _filterType == 'completed',
              onSelected: (selected) {
                setState(() {
                  _filterType = 'completed';
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // ADD TASK SECTION
  Widget _buildAddTaskSection(ColorScheme colorScheme) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: isMobile
          ? Column(
        children: [
          TextField(
            controller: _textController,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Add a task to $_selectedCategory',
              hintStyle: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
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
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _addTodo,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ),
        ],
      )
          : Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Add a task to $_selectedCategory',
                hintStyle: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
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
    );
  }

  // TASK LIST SECTION with animations
  Widget _buildTaskList(ColorScheme colorScheme, List<TodoItem> filteredTodos) {
    return Expanded(
      child: filteredTodos.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No tasks yet!',
              style: TextStyle(
                fontSize: 18,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a task to get started',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: filteredTodos.length,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (context, index) {
          final todo = filteredTodos[index];
          final actualIndex = _todos.indexOf(todo);

          return AnimatedTaskCard(
            key: ValueKey(todo.id),
            todo: todo,
            actualIndex: actualIndex,
            colorScheme: colorScheme,
            onToggle: () => _toggleTodo(actualIndex),
            onEdit: () => _editTodo(actualIndex),
            onDelete: () => _deleteTodo(actualIndex),
            getPriorityLabel: _getPriorityLabel,
            getPriorityColor: _getPriorityColor,
          );
        },
      ),
    );
  }
}

// ANIMATED TASK CARD WIDGET
class AnimatedTaskCard extends StatefulWidget {
  final TodoItem todo;
  final int actualIndex;
  final ColorScheme colorScheme;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(Priority) getPriorityLabel;
  final Color Function(Priority) getPriorityColor;

  const AnimatedTaskCard({
    required Key key,
    required this.todo,
    required this.actualIndex,
    required this.colorScheme,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.getPriorityLabel,
    required this.getPriorityColor,
  }) : super(key: key);

  @override
  State<AnimatedTaskCard> createState() => _AnimatedTaskCardState();
}

class _AnimatedTaskCardState extends State<AnimatedTaskCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Card(
          margin: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(
              color: widget.getPriorityColor(widget.todo.priority)
                  .withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: Checkbox(
                value: widget.todo.isCompleted,
                onChanged: (_) => widget.onToggle(),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.todo.title,
                    style: TextStyle(
                      decoration: widget.todo.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: widget.todo.isCompleted
                          ? widget.colorScheme.onSurface.withValues(alpha: 0.5)
                          : null,
                    ),
                  ),
                  if (widget.todo.dueDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Due: ${DateFormat('MMM dd').format(widget.todo.dueDate!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  if (widget.todo.notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        widget.todo.notes,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
              trailing: SizedBox(
                width: 140,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.getPriorityColor(widget.todo.priority)
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.getPriorityLabel(widget.todo.priority),
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.getPriorityColor(widget.todo.priority),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 32, minHeight: 32),
                      onPressed: () => widget.onEdit(),
                      color: widget.colorScheme.primary,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 32, minHeight: 32),
                      onPressed: () => widget.onDelete(),
                      color: widget.colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TodoItem {
  String id;
  String title;
  bool isCompleted;
  DateTime? dueDate;
  Priority priority;
  String category;
  String notes;

  TodoItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.dueDate,
    this.priority = Priority.low,
    this.category = 'My Day',
    this.notes = '',
  });

  /// Convert TodoItem to JSON for storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isCompleted': isCompleted,
    'dueDate': dueDate?.toIso8601String(),
    'priority': priority.index,
    'category': category,
    'notes': notes,
  };

  /// Create TodoItem from JSON
  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
    id: json['id'] as String,
    title: json['title'] as String,
    isCompleted: json['isCompleted'] as bool? ?? false,
    dueDate: json['dueDate'] != null
        ? DateTime.parse(json['dueDate'] as String)
        : null,
    priority: Priority.values[json['priority'] as int? ?? 0],
    category: json['category'] as String? ?? 'My Day',
    notes: json['notes'] as String? ?? '',
  );
}