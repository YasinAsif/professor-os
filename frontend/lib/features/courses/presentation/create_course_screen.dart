/// ProfessorOS – Create / Edit Course Screen (2-step wizard).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/error_parser.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/prof_weight_slider.dart';
import '../../../shared/widgets/prof_breadcrumbs.dart';
import '../../admin/providers/admin_providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/course_repository.dart';
import '../providers/course_providers.dart';

class _CategoryItem {
  final TextEditingController nameCtrl;
  double weight;
  final bool isCustom;
  final bool isFixed;
  _CategoryItem({
    required String name,
    required this.weight,
    this.isCustom = true,
    this.isFixed = false,
  }) : nameCtrl = TextEditingController(text: name);

  void dispose() {
    nameCtrl.dispose();
  }
}

class CreateCourseScreen extends ConsumerStatefulWidget {
  final String? courseId;
  const CreateCourseScreen({super.key, this.courseId});

  @override
  ConsumerState<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends ConsumerState<CreateCourseScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController(text: 'Section A');
  final _semCtrl = TextEditingController(text: 'Spring 2027');
  final _descCtrl = TextEditingController();

  double _atRisk = 40;
  bool _loading = false;
  Map<String, dynamic>? _existing;
  int? _selectedProfessorId;
  int? _selectedMasterCourseId;
  List<Map<String, dynamic>> _masterCourses = [];
  bool _loadingMasterCourses = false;

  late List<_CategoryItem> _categories;

  @override
  void initState() {
    super.initState();
    _categories = [
      _CategoryItem(name: 'Quizzes', weight: 15, isCustom: false),
      _CategoryItem(name: 'Assignments', weight: 15, isCustom: false),
      _CategoryItem(name: 'Midterm', weight: 20, isCustom: false, isFixed: true),
      _CategoryItem(name: 'Final Exam', weight: 50, isCustom: false, isFixed: true),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).valueOrNull;
      if (user != null && user['role'] != 'admin') {
        _selectedProfessorId = user['id'] as int?;
      }
    });
    _loadMasterCourses();
    if (widget.courseId != null) _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _codeCtrl.dispose();
    _sectionCtrl.dispose();
    _semCtrl.dispose();
    _descCtrl.dispose();
    for (var c in _categories) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMasterCourses() async {
    setState(() => _loadingMasterCourses = true);
    try {
      final list = await CourseRepository().listMasterCourses();
      if (mounted) {
        setState(() {
          _masterCourses = List<Map<String, dynamic>>.from(list);
          if (_existing != null && _existing!['master_course_id'] != null) {
            _selectedMasterCourseId = _existing!['master_course_id'] as int?;
          }
        });
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loadingMasterCourses = false);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _existing = await CourseRepository().getCourse(int.parse(widget.courseId!));
      _titleCtrl.text = _existing!['title'] ?? '';
      _codeCtrl.text = _existing!['code'] ?? '';
      _sectionCtrl.text = _existing!['section'] ?? 'Section A';
      _semCtrl.text = _existing!['semester'] ?? 'Spring 2027';
      _descCtrl.text = _existing!['description'] ?? '';
      _atRisk = (_existing!['at_risk_threshold'] as num?)?.toDouble() ?? 40;
      _selectedProfessorId = _existing!['professor_id'] as int?;
      _selectedMasterCourseId = _existing!['master_course_id'] as int?;

      final q = (_existing!['quiz_weight'] as num?)?.toDouble() ?? 15;
      final a = (_existing!['assignment_weight'] as num?)?.toDouble() ?? 15;
      final m = (_existing!['midterm_weight'] as num?)?.toDouble() ?? 20;
      final f = (_existing!['final_weight'] as num?)?.toDouble() ?? 50;

      for (var cat in _categories) {
        if (cat.nameCtrl.text == 'Quizzes') cat.weight = q;
        if (cat.nameCtrl.text == 'Assignments') cat.weight = a;
        if (cat.nameCtrl.text == 'Midterm') cat.weight = m;
        if (cat.nameCtrl.text == 'Final Exam') cat.weight = f;
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProfessorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select an assigned professor for this course.'),
        backgroundColor: AppColors.feedbackRed,
      ));
      return;
    }

    double q = 0, a = 0, m = 20, f = 50;
    for (var cat in _categories) {
      final name = cat.nameCtrl.text.toLowerCase().trim();
      if (name == 'quizzes' || name.startsWith('quiz')) {
        q += cat.weight;
      } else if (name == 'assignments' || name.startsWith('assign')) {
        a += cat.weight;
      } else if (name == 'midterm' || name.startsWith('mid')) {
        m = cat.weight;
      } else {
        f = cat.weight;
      }
    }

    if (m != 20) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Midterm weightage must be exactly 20 marks.'),
        backgroundColor: AppColors.feedbackRed,
      ));
      return;
    }
    if (f != 50) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Final Exam weightage must be exactly 50 marks.'),
        backgroundColor: AppColors.feedbackRed,
      ));
      return;
    }
    if ((q + a) > 30) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Internal assessment weightage cannot exceed 30 marks.'),
        backgroundColor: AppColors.feedbackRed,
      ));
      return;
    }

    final total = q + a + m + f;
    if (total != 100) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Category weights must sum to exactly 100% (currently ${total.toInt()}%)'),
        backgroundColor: AppColors.feedbackRed,
      ));
      return;
    }

    setState(() => _loading = true);
    try {
      final data = {
        if (_selectedMasterCourseId != null) 'master_course_id': _selectedMasterCourseId,
        'title': _titleCtrl.text.trim(),
        'code': _codeCtrl.text.trim().toUpperCase(),
        'section': _sectionCtrl.text.trim().isEmpty ? 'Section A' : _sectionCtrl.text.trim(),
        'semester': _semCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        if (_selectedProfessorId != null) 'professor_id': _selectedProfessorId,
        'at_risk_threshold': _atRisk,
        'quiz_weight': q.toInt(),
        'assignment_weight': a.toInt(),
        'midterm_weight': m.toInt(),
        'final_weight': f.toInt(),
      };

      Map<String, dynamic>? newCourse;
      if (_existing != null) {
        await CourseRepository().updateCourse(int.parse(widget.courseId!), data);
      } else {
        newCourse = await CourseRepository().createCourse(data);
      }

      if (mounted) {
        ref.invalidate(courseListProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_existing != null
              ? 'Course updated successfully.'
              : 'Course created successfully.'),
          backgroundColor: AppColors.verified,
        ));
        final newId = newCourse?['id'] ?? widget.courseId;
        if (newId != null) {
          context.go('/courses/$newId');
        } else {
          context.go('/courses');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ErrorParser.parse(e)),
        backgroundColor: AppColors.feedbackRed,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeStateProvider);
    final isDark = themeState.themeMode == JournalThemeMode.dark;
    final bgPage = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final ruleColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inkPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final inkSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final role = ref.watch(authProvider).valueOrNull?['role'] as String? ?? 'student';
    final isAdmin = role == 'admin';

    if (widget.courseId == null && !isAdmin) {
      return Scaffold(
        backgroundColor: bgPage,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.go('/courses'),
          ),
          title: Text(
            'Access Restricted',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 64, color: AppColors.feedbackRed),
              const SizedBox(height: 16),
              Text(
                'Admin Permission Required',
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: inkPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Only administrators can create new courses and assign faculty.',
                style: GoogleFonts.inter(fontSize: 14, color: inkSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/courses'),
                child: const Text('Back to Courses'),
              ),
            ],
          ),
        ),
      );
    }

    final isEdit = widget.courseId != null;

    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/courses'),
        ),
        title: Text(
          isEdit ? 'Edit Course Offering' : 'Create Course Offering',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: inkPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: ruleColor, height: 1),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                children: [
                  ProfBreadcrumbs(
                    items: [
                      BreadcrumbItem(label: 'Courses', path: '/courses'),
                      BreadcrumbItem(label: isEdit ? 'Edit Offering' : 'New Offering'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Step indicators
                  Row(
                    children: [
                      _buildStepTab(
                        index: 0,
                        title: '1. Course Details',
                        isActive: _currentStep == 0,
                        isComplete: _currentStep > 0,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 12),
                      _buildStepTab(
                        index: 1,
                        title: '2. Weightage & OBE',
                        isActive: _currentStep == 1,
                        isComplete: false,
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Step body
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ruleColor),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: _currentStep == 0
                        ? _buildStep1(isDark, inkPrimary, inkSecondary, ruleColor)
                        : _buildStep2(isDark, inkPrimary, inkSecondary, ruleColor),
                  ),

                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentStep == 1)
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _currentStep = 0),
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                          label: const Text('Back'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      ElevatedButton(
                        onPressed: _loading
                            ? null
                            : () {
                                if (_currentStep == 0) {
                                  if (_formKey.currentState!.validate()) {
                                    setState(() => _currentStep = 1);
                                  }
                                } else {
                                  _save();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                _currentStep == 0
                                    ? 'Next: Assessment Weightage →'
                                    : (isEdit ? 'Save Changes' : 'Create Course Offering'),
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStepTab({
    required int index,
    required String title,
    required bool isActive,
    required bool isComplete,
    required bool isDark,
  }) {
    final activeBg = const Color(0xFF4F46E5).withOpacity(0.1);
    const activeBorder = Color(0xFF4F46E5);
    final inactiveBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    return InkWell(
      onTap: () {
        if (index == 0) {
          setState(() => _currentStep = 0);
        } else if (_formKey.currentState!.validate()) {
          setState(() => _currentStep = 1);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? activeBorder : (isComplete ? const Color(0xFF10B981) : inactiveBorder),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isComplete)
              const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981))
            else
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? const Color(0xFF4F46E5) : Colors.grey.withOpacity(0.3),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? const Color(0xFF4F46E5) : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1(
    bool isDark,
    Color inkPrimary,
    Color inkSecondary,
    Color ruleColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.menu_book_rounded, color: Color(0xFF4F46E5), size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step 1: Course Offering & Faculty Assignment',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: inkPrimary,
                  ),
                ),
                Text(
                  'Select master curriculum course, assign section and faculty instructor.',
                  style: GoogleFonts.inter(fontSize: 12.5, color: inkSecondary),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Assigned Professor Dropdown
        Consumer(
          builder: (context, ref, child) {
            final profsAsync = ref.watch(professorsListProvider);
            return profsAsync.when(
              loading: () => const LinearProgressIndicator(color: Color(0xFF4F46E5)),
              error: (e, _) => Text('Error loading faculty list: $e',
                  style: const TextStyle(color: AppColors.feedbackRed)),
              data: (profs) {
                return DropdownButtonFormField<int>(
                  value: _selectedProfessorId,
                  validator: (v) => v == null ? 'Select an assigned professor' : null,
                  decoration: InputDecoration(
                    labelText: 'Assigned Professor / Faculty *',
                    labelStyle: GoogleFonts.inter(color: inkSecondary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: ruleColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                    ),
                  ),
                  items: profs.map<DropdownMenuItem<int>>((p) {
                    final id = p['id'] as int;
                    final name = p['full_name'] as String? ?? p['email'] as String;
                    return DropdownMenuItem<int>(value: id, child: Text(name));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedProfessorId = val),
                );
              },
            );
          },
        ),
        const SizedBox(height: 18),

        // Master Course Title Selection
        Text(
          'Master Course Curriculum *',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: inkPrimary),
        ),
        const SizedBox(height: 6),
        if (_loadingMasterCourses)
          const LinearProgressIndicator(color: Color(0xFF4F46E5))
        else if (_masterCourses.isNotEmpty)
          DropdownButtonFormField<int>(
            value: _selectedMasterCourseId,
            isExpanded: true,
            validator: (v) => v == null ? 'Please select a course from the curriculum list' : null,
            decoration: InputDecoration(
              hintText: 'Select master course (e.g. Design & Analysis of Algorithms)',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: inkSecondary.withOpacity(0.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: ruleColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
              ),
            ),
            items: _masterCourses.map<DropdownMenuItem<int>>((c) {
              final id = c['id'] as int;
              final title = c['title'] as String;
              final code = c['code'] as String;
              return DropdownMenuItem<int>(
                value: id,
                child: Text(
                  '$title ($code)',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13.5),
                ),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedMasterCourseId = val;
                final match = _masterCourses.firstWhere((c) => c['id'] == val, orElse: () => {});
                if (match.isNotEmpty) {
                  _titleCtrl.text = match['title'] ?? '';
                  _codeCtrl.text = match['code'] ?? '';
                }
              });
            },
          )
        else
          TextFormField(
            controller: _titleCtrl,
            validator: Validators.required,
            style: GoogleFonts.inter(fontSize: 14, color: inkPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. Design & Analysis of Algorithms',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: ruleColor),
              ),
            ),
          ),
        const SizedBox(height: 18),

        // Course Code (Read-Only) & Section & Semester
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Course Code (Locked)',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: inkPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _codeCtrl,
                    readOnly: true,
                    validator: Validators.required,
                    textCapitalization: TextCapitalization.characters,
                    style: GoogleFonts.jetBrainsMono(fontSize: 14, color: inkPrimary, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Auto-fills code',
                      hintStyle: GoogleFonts.jetBrainsMono(fontSize: 12, color: inkSecondary.withOpacity(0.5)),
                      helperText: 'Auto-synced with master course',
                      helperStyle: GoogleFonts.inter(fontSize: 11, color: inkSecondary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A).withOpacity(0.6) : const Color(0xFFF1F5F9),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: ruleColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: ruleColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Section Offering *',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: inkPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _sectionCtrl,
                    validator: Validators.required,
                    style: GoogleFonts.inter(fontSize: 14, color: inkPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. Section A',
                      helperText: 'Enables multi-teacher offerings',
                      helperStyle: GoogleFonts.inter(fontSize: 11, color: inkSecondary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: ruleColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Semester *',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: inkPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _semCtrl,
                    validator: Validators.required,
                    style: GoogleFonts.inter(fontSize: 14, color: inkPrimary),
                    decoration: InputDecoration(
                      hintText: 'Spring 2027',
                      helperText: 'Active academic period',
                      helperStyle: GoogleFonts.inter(fontSize: 11, color: inkSecondary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: ruleColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Description
        Text(
          'Course Description & Syllabus Objectives (Optional)',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: inkPrimary),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _descCtrl,
          maxLines: 3,
          style: GoogleFonts.inter(fontSize: 14, color: inkPrimary),
          decoration: InputDecoration(
            hintText: 'Summary of course learning outcomes, syllabus objectives, and cohort scope…',
            hintStyle: GoogleFonts.inter(fontSize: 13, color: inkSecondary.withOpacity(0.5)),
            contentPadding: const EdgeInsets.all(14),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: ruleColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 24),

        Divider(color: ruleColor),
        const SizedBox(height: 14),

        // At-risk threshold
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'At-Risk Performance Threshold',
              style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: inkPrimary),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.feedbackRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_atRisk.toInt()}% Cumulative',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.feedbackRed,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Students with cumulative scores below this threshold are automatically flagged on the Cohort Intelligence matrix.',
          style: GoogleFonts.inter(fontSize: 12, color: inkSecondary, height: 1.4),
        ),
        const SizedBox(height: 12),
        ProfWeightSlider(value: _atRisk, onChanged: (v) => setState(() => _atRisk = v)),
      ],
    );
  }

  Widget _buildStep2(
    bool isDark,
    Color inkPrimary,
    Color inkSecondary,
    Color ruleColor,
  ) {
    double q = 0, a = 0, m = 0, f = 0;
    for (var cat in _categories) {
      final name = cat.nameCtrl.text.toLowerCase().trim();
      if (name == 'quizzes' || name.startsWith('quiz')) {
        q += cat.weight;
      } else if (name == 'assignments' || name.startsWith('assign')) {
        a += cat.weight;
      } else if (name == 'midterm' || name.startsWith('mid')) {
        m += cat.weight;
      } else {
        f += cat.weight;
      }
    }

    final internalTotal = q + a;
    final total = internalTotal + m + f;
    final isInternalValid = internalTotal <= 30;
    final isTotalValid = total == 100;
    final isValid = isInternalValid && isTotalValid && m == 20 && f == 50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.balance_rounded, color: Color(0xFF0D9488), size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step 2: OBE Assessment Weightage Rules',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: inkPrimary,
                  ),
                ),
                Text(
                  'Midterm = 20, Final = 50 (fixed). Internal assessments combined <= 30 marks.',
                  style: GoogleFonts.inter(fontSize: 12.5, color: inkSecondary),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Compliance Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isValid
                ? const Color(0xFF10B981).withOpacity(0.08)
                : AppColors.feedbackRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isValid
                  ? const Color(0xFF10B981).withOpacity(0.3)
                  : AppColors.feedbackRed.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isValid ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                    color: isValid ? const Color(0xFF10B981) : AppColors.feedbackRed,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isValid
                          ? 'Total Weightage: 100% (Midterm 20, Final 50, Internal ${internalTotal.toInt()}/30)'
                          : (!isInternalValid
                              ? 'Internal assessment weightage cannot exceed 30 marks (currently ${internalTotal.toInt()}).'
                              : 'Total Weightage must sum to 100% (currently ${total.toInt()}%).'),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isValid ? const Color(0xFF10B981) : AppColors.feedbackRed,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Text(
                  'Midterm: 20 marks | Final: 50 marks | Internal (Quizzes + Assignments): max 30 marks',
                  style: GoogleFonts.inter(fontSize: 11.5, color: inkSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Categories
        ..._categories.asMap().entries.map((entry) {
          final idx = entry.key;
          final cat = entry.value;
          final isFixedCat = cat.isFixed;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                if (cat.isCustom)
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextFormField(
                        controller: cat.nameCtrl,
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  flex: 4,
                  child: ProfWeightSlider(
                    label: isFixedCat
                        ? '${cat.nameCtrl.text} (Fixed)'
                        : (cat.isCustom ? null : cat.nameCtrl.text),
                    value: cat.weight,
                    onChanged: isFixedCat
                        ? (v) {} // Locked
                        : (v) => setState(() => cat.weight = v),
                  ),
                ),
                if (cat.isCustom)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.feedbackRed),
                    onPressed: () => setState(() => _categories.removeAt(idx)),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
