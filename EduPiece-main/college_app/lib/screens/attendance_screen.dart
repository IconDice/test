import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../models/attendance_entry.dart';

class AttendanceScreen extends StatefulWidget {
  final String classId;
  final String subjectId;

  const AttendanceScreen(
      {super.key, required this.classId, required this.subjectId});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with TickerProviderStateMixin {
  List<AttendanceEntry> _allStudents = [];
  List<AttendanceEntry> _filteredStudents = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Swipe mode variables
  bool _isSwipeMode = true;
  int _currentCardIndex = 0;
  bool _isAnimating = false; // NEW: Prevents double-clicks
  late AnimationController _cardAnimationController;
  late AnimationController _celebrationController;
  late Animation<Offset> _cardSlideAnimation;
  late Animation<double> _cardRotateAnimation;
  late Animation<double> _cardScaleAnimation;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _loadRollList();
    _searchController.addListener(_filterSearch);

    _cardAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // Slightly faster
    );

    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _cardAnimationController.dispose();
    _celebrationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRollList() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final list =
          await ApiService.fetchRollList(widget.classId, widget.subjectId);
      if (!mounted) return;
      setState(() {
        _allStudents = list;
        _filteredStudents = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _filterSearch() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStudents = _allStudents
          .where((s) => s.rollNo.toLowerCase().contains(query))
          .toList();
      _currentCardIndex = 0;
    });
  }

  void _markAll(String status) {
    setState(() {
      for (var s in _allStudents) {
        s.status = status;
      }
    });
  }

  double get _progress {
    if (_allStudents.isEmpty) return 0;
    return _allStudents.where((s) => s.status != null).length /
        _allStudents.length;
  }

  void _onSwipe(String status) {
    // 1. Safety Checks
    if (_currentCardIndex >= _filteredStudents.length) return;
    if (_isAnimating) return; // FIX: Prevents double triggering

    setState(() => _isAnimating = true); // Lock animation

    HapticFeedback.lightImpact();

    final direction = status == 'PRESENT' ? 1.0 : -1.0;

    _cardSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(direction * 3, -0.5),
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeInBack,
    ));

    _cardRotateAnimation = Tween<double>(
      begin: 0,
      end: direction * 0.4,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeOut,
    ));

    _cardScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeOut,
    ));

    // 2. Mark Data Immediately
    setState(() {
      _filteredStudents[_currentCardIndex].status = status;
    });

    // 3. Play Animation
    _cardAnimationController.forward().then((_) {
      setState(() {
        _currentCardIndex++;
        _dragOffset = Offset.zero;
        _isAnimating = false; // Unlock
      });
      _cardAnimationController.reset();

      if (_currentCardIndex >= _filteredStudents.length) {
        _celebrationController.forward();
      }
    });
  }

  void _undoLast() {
    if (_currentCardIndex > 0 && !_isAnimating) {
      HapticFeedback.selectionClick();
      setState(() {
        _currentCardIndex--;
        _filteredStudents[_currentCardIndex].status = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildModernAppBar(),
                Expanded(
                  child:
                      _isSwipeMode ? _buildSwipeView() : _buildListViewMode(),
                ),
                _buildBottomAction(),
              ],
            ),
    );
  }

  // ... (Keep _buildModernAppBar, _buildModeToggle as is) ...
  Widget _buildModernAppBar() {
    // Re-calculate counts on every build
    int markedCount = _allStudents.where((s) => s.status != null).length;
    int totalCount = _allStudents.length;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade600, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.subjectId.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$markedCount / $totalCount Marked • Class ${widget.classId}',
                          style: TextStyle(
                            color: Colors.white.withAlpha((0.8*255).round()),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isSwipeMode)
                    TextButton.icon(
                      onPressed: () => _markAll('PRESENT'),
                      icon: const Icon(Icons.check_circle,
                          color: Colors.white, size: 18),
                      label: const Text('All',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withAlpha((0.2*255).round()),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                ],
              ),
            ),
            // Progress Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _progress,
                            backgroundColor: Colors.white.withAlpha((0.2*255).round()),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.greenAccent),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withAlpha((0.2*255).round()),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(_progress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildModeToggle(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... (Keep _buildModeToggle) ...
  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.15*255).round()),
        borderRadius: BorderRadius.circular(25),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isSwipeMode = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isSwipeMode ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _isSwipeMode
                      ? [
                          BoxShadow(
                              color: Colors.black.withAlpha((0.1*255).round()),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.swipe_rounded,
                      color: _isSwipeMode
                          ? Colors.indigo.shade600
                          : Colors.white.withAlpha((0.7*255).round()),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Swipe',
                      style: TextStyle(
                        color: _isSwipeMode
                            ? Colors.indigo.shade600
                            : Colors.white.withAlpha((0.7*255).round()),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isSwipeMode = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isSwipeMode ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: !_isSwipeMode
                      ? [
                          BoxShadow(
                              color: Colors.black.withAlpha((0.1*255).round()),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.list_rounded,
                      color: !_isSwipeMode
                          ? Colors.indigo.shade600
                          : Colors.white.withAlpha((0.7*255).round()),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'List',
                      style: TextStyle(
                        color: !_isSwipeMode
                            ? Colors.indigo.shade600
                            : Colors.white.withAlpha((0.7*255).round()),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ... (Updated _buildSwipeView) ...
  Widget _buildSwipeView() {
    return _currentCardIndex >= _filteredStudents.length
        ? _buildCompletionView()
        : Column(
            children: [
              const SizedBox(height: 20),
              _buildCardCounter(),
              const SizedBox(height: 12),
              Expanded(child: _buildCardStack()),
              _buildSwipeActions(),
              const SizedBox(height: 20),
            ],
          );
  }

  Widget _buildCardCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05*255).round()),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '${_currentCardIndex + 1} of ${_filteredStudents.length}',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  // ... (Keep _buildCardStack) ...
  Widget _buildCardStack() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Second card (more background)
            if (_currentCardIndex + 2 < _filteredStudents.length)
              Center(
                child: Transform.scale(
                  scale: 0.88,
                  child: Transform.translate(
                    offset: const Offset(0, 20),
                    child: Opacity(
                      opacity: 0.3,
                      child: _buildStudentCard(
                          _filteredStudents[_currentCardIndex + 2],
                          isInteractive: false),
                    ),
                  ),
                ),
              ),
            // Next card (background)
            if (_currentCardIndex + 1 < _filteredStudents.length)
              Center(
                child: Transform.scale(
                  scale: 0.94,
                  child: Transform.translate(
                    offset: const Offset(0, 10),
                    child: Opacity(
                      opacity: 0.6,
                      child: _buildStudentCard(
                          _filteredStudents[_currentCardIndex + 1],
                          isInteractive: false),
                    ),
                  ),
                ),
              ),
            // Current card (foreground)
            Center(
              child: GestureDetector(
                // Only allow dragging if not animating
                onPanStart: (_) => setState(() {
                  if (!_isAnimating) _isDragging = true;
                }),
                onPanUpdate: (details) {
                  if (!_isAnimating) {
                    setState(() {
                      _dragOffset += details.delta;
                    });
                  }
                },
                onPanEnd: (details) {
                  setState(() => _isDragging = false);

                  if (_dragOffset.dx > 100) {
                    _onSwipe('PRESENT');
                  } else if (_dragOffset.dx < -100) {
                    _onSwipe('ABSENT');
                  } else {
                    setState(() => _dragOffset = Offset.zero);
                  }
                },
                child: AnimatedBuilder(
                  animation: _cardAnimationController,
                  builder: (context, child) {
                    final offset = _cardAnimationController.isAnimating
                        ? _cardSlideAnimation.value
                        : Offset(_dragOffset.dx / constraints.maxWidth,
                            _dragOffset.dy / constraints.maxHeight);

                    final rotation = _cardAnimationController.isAnimating
                        ? _cardRotateAnimation.value
                        : _dragOffset.dx / 1000;

                    final scale = _cardAnimationController.isAnimating
                        ? _cardScaleAnimation.value
                        : 1.0;

                    return Transform.scale(
                      scale: scale,
                      child: Transform.translate(
                        offset: Offset(offset.dx * constraints.maxWidth,
                            offset.dy * constraints.maxHeight),
                        child: Transform.rotate(
                          angle: rotation,
                          child: _buildStudentCard(
                              _filteredStudents[_currentCardIndex]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_isDragging && _dragOffset.dx.abs() > 30) _buildSwipeOverlay(),
          ],
        );
      },
    );
  }

  // ... (Keep _buildSwipeOverlay, _buildStudentCard, _buildSwipeActions) ...
  Widget _buildSwipeOverlay() {
    final isPresentSwipe = _dragOffset.dx > 0;
    final opacity = (_dragOffset.dx.abs() / 150).clamp(0.0, 1.0);

    return Center(
      child: Transform.rotate(
        angle: isPresentSwipe ? -0.2 : 0.2,
        child: Opacity(
          opacity: opacity,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color:
                  (isPresentSwipe ? Colors.green : Colors.red).withAlpha((0.9*255).round()),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPresentSwipe ? Icons.check_circle : Icons.cancel,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  isPresentSwipe ? 'PRESENT' : 'ABSENT',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(AttendanceEntry student,
      {bool isInteractive = true}) {
    bool isSriram = student.rollNo == '2301105277';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.12*255).round()),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isSriram
                      ? [Colors.orange.shade400, Colors.deepOrange.shade500]
                      : [Colors.indigo.shade400, Colors.blue.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.2*255).round()),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor: isSriram
                        ? Colors.orange.shade400
                        : Colors.indigo.shade400,
                    child: isSriram
                        ? const Icon(Icons.star, color: Colors.white, size: 40)
                        : Text(
                            student.rollNo.substring(student.rollNo.length - 2),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Text(
                    student.rollNo,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSriram
                          ? Colors.orange.shade50
                          : Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isSriram ? 'SRIRAM SAHOO' : 'Computer Science',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSriram
                            ? Colors.orange.shade700
                            : Colors.indigo.shade700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (isInteractive)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.swipe,
                            color: Colors.grey.shade400, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Swipe or tap buttons below',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionButton(
            icon: Icons.close_rounded,
            color: Colors.red.shade400,
            label: 'Absent',
            onPressed: () => _onSwipe('ABSENT'),
          ),
          _buildActionButton(
            icon: Icons.refresh_rounded,
            color: Colors.orange.shade400,
            label: 'Undo',
            onPressed: _undoLast,
            isSecondary: true,
          ),
          _buildActionButton(
            icon: Icons.check_rounded,
            color: Colors.green.shade400,
            label: 'Present',
            onPressed: () => _onSwipe('PRESENT'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
    bool isSecondary = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: isSecondary ? 2 : 8,
          shadowColor: color.withAlpha((0.4*255).round()),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Container(
              width: isSecondary ? 56 : 70,
              height: isSecondary ? 56 : 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSecondary
                    ? null
                    : LinearGradient(
                        colors: [color, color.withAlpha((0.8*255).round())],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                border: isSecondary
                    ? Border.all(color: color.withAlpha((0.3*255).round()), width: 2)
                    : null,
              ),
              child: Icon(
                icon,
                color: isSecondary ? color : Colors.white,
                size: isSecondary ? 24 : 32,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // ... (Keep _buildCompletionView, _buildListViewMode, _buildSearchBar, _buildListView) ...
  Widget _buildCompletionView() {
    return Center(
      child: AnimatedBuilder(
        animation: _celebrationController,
        builder: (context, child) {
          return Transform.scale(
            scale: 0.8 + (_celebrationController.value * 0.2),
            child: Opacity(
              opacity: _celebrationController.value,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.teal.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withAlpha((0.3*255).round()),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.celebration,
                        size: 80, color: Colors.white),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'All Done!',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Marked ${_filteredStudents.length} students',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {
                      _currentCardIndex = 0;
                      _celebrationController.reset();
                    }),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Review Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListViewMode() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(child: _buildListView()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by roll number...',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredStudents.length,
      itemBuilder: (context, index) =>
          _buildListStudentCard(_filteredStudents[index]),
    );
  }

  // ... (Keep _buildListStudentCard) ...
  Widget _buildListStudentCard(AttendanceEntry student) {
    bool isSriram = student.rollNo == '2301105277';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: student.status == 'PRESENT'
              ? Colors.green.shade300
              : (student.status == 'ABSENT'
                  ? Colors.red.shade300
                  : Colors.grey.shade200),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.04*255).round()),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSriram
                          ? [Colors.orange.shade400, Colors.deepOrange.shade500]
                          : [Colors.indigo.shade300, Colors.blue.shade400],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    child: isSriram
                        ? Icon(Icons.star,
                            color: Colors.orange.shade500, size: 24)
                        : Text(
                            student.rollNo.substring(student.rollNo.length - 2),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.rollNo,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSriram ? 'SRIRAM SAHOO' : 'Computer Science',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildCompactAction(student, 'PRESENT',
                    Icons.check_circle_rounded, Colors.green.shade400),
                const SizedBox(width: 8),
                _buildCompactAction(student, 'ABSENT', Icons.cancel_rounded,
                    Colors.red.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ... (Keep _buildCompactAction, _buildBottomAction, _submit) ...
  Widget _buildCompactAction(
      AttendanceEntry student, String status, IconData icon, Color color) {
    bool active = student.status == status;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => student.status = status);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active ? color : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: active ? Colors.white : Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05*255).round()),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade600,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          onPressed: _submit,
          child: const Text(
            'Submit Attendance',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_allStudents.any((s) => s.status == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Please mark all students!'),
            ],
          ),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    try {
      await ApiService.submitAttendance(
          widget.subjectId, DateTime.now(), _allStudents);

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.cloud_done_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Attendance Secured in Cloud!'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 1200));

      if (!mounted) return;
      nav.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}
