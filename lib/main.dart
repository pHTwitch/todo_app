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
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF2564CF),
      secondary: Color(0xFF0078D4),
      tertiary: Color(0xFF106EBE),
      surface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF323130),
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
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF0078D4),
      secondary: Color(0xFF106EBE),
      tertiary: Color(0xFF2564CF),
      surface: Color(0xFF1F1F1F),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFFE1E1E1),
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
  bool _autoSortEnabled = true;

  // Cache for filtered todos
  List<TodoItem>? _cachedFilteredTodos;
  String? _cacheKey;

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

    // Batch all reads together
    final sidebarOpen = _prefs.getBool('sidebarOpen') ?? true;
    final autoSort = _prefs.getBool('autoSortEnabled') ?? true;

    await _loadCategories();
    await _loadTodos();

    setState(() {
      _isSidebarOpen = sidebarOpen;
      _autoSortEnabled = autoSort;
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
      // Use optimized JSON encoding with caching
      final todosJson = _todos.map((todo) => todo.toJsonString()).toList();
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

  Future<void> _saveAutoSortState() async {
    try {
      await _prefs.setBool('autoSortEnabled', _autoSortEnabled);
    } catch (e) {
      debugPrint('Error saving auto-sort state: $e');
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
      _invalidateCache();
    });
    _saveTodos();
  }

  void _toggleTodo(int index) {
    setState(() {
      _todos[index].isCompleted = !_todos[index].isCompleted;
      _todos[index].markDirty();
      _invalidateCache();
    });
    _saveTodos();
  }

  void _deleteTodo(int index) {
    final deletedTodo = _todos[index];
    setState(() {
      _todos.removeAt(index);
      _invalidateCache();
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
              _invalidateCache();
            });
            _saveTodos();
          },
        ),
      ),
    );
  }

  void _reorderTodo(int oldIndex, int newIndex) {
    if (!_autoSortEnabled) {
      setState(() {
        // When moving down, we need to account for the item being removed
        if (newIndex > oldIndex) {
          newIndex -= 1;
        }
        final item = _todos.removeAt(oldIndex);
        _todos.insert(newIndex, item);
        _invalidateCache();
      });
      _saveTodos();
    }
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
        builder: (context, setDialogState) => AlertDialog(
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
                        // Update both dialog state AND parent state
                        setDialogState(() {
                          selectedPriority = priority;
                        });
                        // Also update in the main list to reflect changes immediately
                        setState(() {
                          _todos[index].priority = priority;
                          _todos[index].markDirty();
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
                        setDialogState(() {
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
                        setDialogState(() {
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
                    _todos[index].markDirty();
                    _textController.clear();
                    _notesController.clear();
                    _invalidateCache();
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
                    todo.markDirty();
                  }
                }
                _categories.remove(category);
                if (_selectedCategory == category) {
                  _selectedCategory = 'My Day';
                }
                _invalidateCache();
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
    // Create a cache key based on current filter state
    final currentCacheKey = '$_selectedCategory:$_filterType:$_autoSortEnabled:${_todos.length}';

    // Return cached result if available and valid
    if (_cachedFilteredTodos != null && _cacheKey == currentCacheKey) {
      return _cachedFilteredTodos!;
    }

    var filtered =
    _todos.where((todo) => todo.category == _selectedCategory).toList();

    if (_filterType == 'completed') {
      filtered = filtered.where((todo) => todo.isCompleted).toList();
    } else if (_filterType == 'active') {
      filtered = filtered.where((todo) => !todo.isCompleted).toList();
    }

    // Only sort by priority if auto-sort is enabled
    if (_autoSortEnabled) {
      filtered.sort((a, b) {
        final priorityOrder = {
          Priority.high: 0,
          Priority.medium: 1,
          Priority.low: 2
        };
        return (priorityOrder[a.priority] ?? 3)
            .compareTo(priorityOrder[b.priority] ?? 3);
      });
    }

    // Cache the result
    _cachedFilteredTodos = filtered;
    _cacheKey = currentCacheKey;

    return filtered;
  }

  void _invalidateCache() {
    _cachedFilteredTodos = null;
    _cacheKey = null;
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
    // Compute filtered todos once per build
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

  Widget _buildMobileLayout(ColorScheme colorScheme, List<TodoItem> filteredTodos, Size screenSize) {
    return Stack(
      children: [
        Column(
          children: [
            _buildFilterSection(colorScheme),
            _buildAddTaskSection(colorScheme),
            _buildTaskList(colorScheme, filteredTodos),
          ],
        ),
        if (_isSidebarOpen)
          Positioned.fill(
            child: Row(
              children: [
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

  Widget _buildDesktopLayout(ColorScheme colorScheme, List<TodoItem> filteredTodos) {
    return Row(
      children: [
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

  Widget _buildSidebar(ColorScheme colorScheme) {
    // Pre-calculate category counts to avoid multiple iterations
    final categoryCounts = <String, int>{};
    for (var todo in _todos) {
      categoryCounts[todo.category] = (categoryCounts[todo.category] ?? 0) + 1;
    }

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final count = categoryCounts[category] ?? 0;

                return ListTile(
                  title: Text(category),
                  subtitle: Text('$count'),
                  selected: _selectedCategory == category,
                  selectedTileColor: colorScheme.primary.withValues(alpha: 0.1),
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                      _invalidateCache();
                    });
                    if (MediaQuery.of(context).size.width < 600) {
                      _toggleSidebar();
                    }
                  },
                  trailing: _categories.length > 1
                      ? PopupMenuButton(
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        child: Text('Delete'),
                      ),
                    ],
                    onSelected: (_) => _deleteCategory(category),
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

  Widget _buildFilterSection(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _filterType == 'all',
                  onSelected: (selected) {
                    setState(() {
                      _filterType = 'all';
                      _invalidateCache();
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
                      _invalidateCache();
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
                      _invalidateCache();
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _autoSortEnabled ? Icons.sort : Icons.sort_outlined,
                size: 18,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'Auto-Sort by Priority',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: _autoSortEnabled,
                onChanged: (value) {
                  setState(() {
                    _autoSortEnabled = value;
                    _invalidateCache();
                  });
                  _saveAutoSortState();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

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
          : _autoSortEnabled
              ? ListView.separated(
                  itemCount: filteredTodos.length,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  addAutomaticKeepAlives: false,
                  separatorBuilder: (context, index) => const SizedBox(height: 0),
                  itemBuilder: (context, index) {
                    final todo = filteredTodos[index];
                    final actualIndex = _todos.indexOf(todo);

                    return RepaintBoundary(
                      child: _buildDismissibleTask(todo, actualIndex, colorScheme),
                    );
                  },
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  buildDefaultDragHandles: false,
                  itemCount: filteredTodos.length,
                  onReorder: (oldIndex, newIndex) {
                    // Map filtered list indices to actual todo list indices
                    final actualOldIndex = _todos.indexOf(filteredTodos[oldIndex]);
                    final actualNewIndex = _todos.indexOf(filteredTodos[newIndex > oldIndex ? newIndex - 1 : newIndex]);
                    
                    if (newIndex > oldIndex) {
                      _reorderTodo(actualOldIndex, actualNewIndex + 1);
                    } else {
                      _reorderTodo(actualOldIndex, actualNewIndex);
                    }
                  },
                  itemBuilder: (context, index) {
                    final todo = filteredTodos[index];
                    final actualIndex = _todos.indexOf(todo);

                    return RepaintBoundary(
                      key: ValueKey(todo.id),
                      child: ReorderableDragStartListener(
                        index: index,
                        child: _buildDismissibleTask(todo, actualIndex, colorScheme),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildDismissibleTask(TodoItem todo, int actualIndex, ColorScheme colorScheme) {
    return Dismissible(
      key: ValueKey('${todo.id}_dismissible'),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: Colors.green,
        child: const Row(
          children: [
            Icon(Icons.edit, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Edit',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _editTodo(actualIndex);
          return false;
        } else if (direction == DismissDirection.endToStart) {
          return await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Delete Task'),
                content: const Text('Are you sure you want to delete this task?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Delete'),
                  ),
                ],
              );
            },
          );
        }
        return false;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          _deleteTodo(actualIndex);
        }
      },
      child: AnimatedTaskCard(
        key: ValueKey('${todo.id}_card'),
        todo: todo,
        actualIndex: actualIndex,
        colorScheme: colorScheme,
        onToggle: () => _toggleTodo(actualIndex),
        onEdit: () => _editTodo(actualIndex),
        onDelete: () => _deleteTodo(actualIndex),
        getPriorityLabel: _getPriorityLabel,
        getPriorityColor: _getPriorityColor,
        autoSortEnabled: _autoSortEnabled,
      ),
    );
  }
}

class AnimatedTaskCard extends StatefulWidget {
  final TodoItem todo;
  final int actualIndex;
  final ColorScheme colorScheme;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(Priority) getPriorityLabel;
  final Color Function(Priority) getPriorityColor;
  final bool autoSortEnabled;

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
    required this.autoSortEnabled,
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
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.autoSortEnabled)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.drag_indicator,
                        size: 20,
                        color: widget.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  Checkbox(
                    value: widget.todo.isCompleted,
                    onChanged: (_) => widget.onToggle(),
                  ),
                ],
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
              trailing: Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.getPriorityColor(widget.todo.priority)
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.getPriorityLabel(widget.todo.priority),
                          style: TextStyle(
                            fontSize: 11,
                            color: widget.getPriorityColor(
                                widget.todo.priority),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
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

  // Dirty flag for lazy JSON encoding
  bool _isDirty = false;
  String? _cachedJson;

  TodoItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.dueDate,
    this.priority = Priority.low,
    this.category = 'My Day',
    this.notes = '',
  }) : _isDirty = true;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isCompleted': isCompleted,
    'dueDate': dueDate?.toIso8601String(),
    'priority': priority.index,
    'category': category,
    'notes': notes,
  };

  String toJsonString() {
    if (_isDirty || _cachedJson == null) {
      _cachedJson = jsonEncode(toJson());
      _isDirty = false;
    }
    return _cachedJson!;
  }

  void markDirty() {
    _isDirty = true;
  }

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    final item = TodoItem(
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
    // Mark as clean since we just loaded from JSON
    item._isDirty = false;
    item._cachedJson = jsonEncode(json);
    return item;
  }
}