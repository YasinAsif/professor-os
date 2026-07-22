/// ProfessorOS – Create / Edit Course Screen (2-step wizard).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/prof_card.dart';
import '../../../shared/widgets/prof_weight_slider.dart';
import '../data/course_repository.dart';
import '../providers/course_providers.dart';

class _CategoryItem {
  final TextEditingController nameCtrl;
  double weight;
  final bool isCustom;
  _CategoryItem(
      {required String name, required this.weight, this.isCustom = true})
      : nameCtrl = TextEditingController(text: name);

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
  final _semCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  double _atRisk = 40;
  bool _loading = false;
  Map<String, dynamic>? _existing;

  late List<_CategoryItem> _categories;

  @override
  void initState() {
    super.initState();
    _categories = [
      _CategoryItem(name: 'Quizzes', weight: 20, isCustom: false),
      _CategoryItem(name: 'Assignments', weight: 20, isCustom: false),
      _CategoryItem(name: 'Midterm', weight: 20, isCustom: false),
      _CategoryItem(name: 'Final Exam', weight: 40, isCustom: false),
    ];
    if (widget.courseId != null) _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _codeCtrl.dispose();
    _semCtrl.dispose();
    _descCtrl.dispose();
    for (var c in _categories) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _existing =
          await CourseRepository().getCourse(int.parse(widget.courseId!));
      _titleCtrl.text = _existing!['title'];
      _codeCtrl.text = _existing!['code'];
      _semCtrl.text = _existing!['semester'];
      _descCtrl.text = _existing!['description'] ?? '';
      _atRisk = (_existing!['at_risk_threshold'] as num).toDouble();

      final q = (_existing!['quiz_weight'] as num?)?.toDouble() ?? 20;
      final a = (_existing!['assignment_weight'] as num?)?.toDouble() ?? 20;
      final m = (_existing!['midterm_weight'] as num?)?.toDouble() ?? 20;
      final f = (_existing!['final_weight'] as num?)?.toDouble() ?? 40;

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
    final total = _categories.fold<double>(0, (sum, item) => sum + item.weight);
    if (total != 100) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Category weights must sum to exactly 100% (currently ${total.toInt()}%)'),
        backgroundColor: AppColors.dangerRose,
      ));
      return;
    }

    setState(() => _loading = true);
    try {
      double q = 0, a = 0, m = 0, f = 0;
      for (var cat in _categories) {
        final name = cat.nameCtrl.text.toLowerCase().trim();
        // Use exact matching for the 4 HEC categories (non-custom items)
        if (name == 'quizzes' || name.startsWith('quiz')) {
          q += cat.weight;
        } else if (name == 'assignments' || name.startsWith('assign')) {
          a += cat.weight;
        } else if (name == 'midterm' || name.startsWith('mid')) {
          m += cat.weight;
        } else if (name == 'final exam' || name.startsWith('final')) {
          f += cat.weight;
        } else {
          // Custom categories: show warning but map to finals
          f += cat.weight;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Custom category "${cat.nameCtrl.text}" mapped to Final Exam weight. '
                  'Use the 4 built-in HEC categories (Quiz, Assignments, Midterm, Final) for precise tracking.'),
              backgroundColor: AppColors.accentAmber,
              duration: const Duration(seconds: 5),
            ));
          }
        }
      }

      final data = {
        'title': _titleCtrl.text.trim(),
        'code': _codeCtrl.text.trim().toUpperCase(),
        'semester': _semCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'at_risk_threshold': _atRisk,
        'quiz_weight': q.toInt(),
        'assignment_weight': a.toInt(),
        'midterm_weight': m.toInt(),
        'final_weight': f.toInt(),
      };

      if (_existing != null) {
        await CourseRepository()
            .updateCourse(int.parse(widget.courseId!), data);
      } else {
        await CourseRepository().createCourse(data);
      }

      if (mounted) {
        ref.invalidate(courseListProvider);
        context.go('/courses');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: AppColors.dangerRose,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _existing == null && widget.courseId != null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isEdit = _existing != null;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.go('/courses')),
        title: Text(isEdit ? 'Edit Course' : 'Create New Course',
            style:
                GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            children: [
              // Progress Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: AppGradients.primaryButton,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: _currentStep == 1
                              ? AppGradients.primaryButton
                              : null,
                          color: _currentStep == 1 ? null : AppColors.border,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: _currentStep == 0 ? _buildStep1() : _buildStep2(),
                  ),
                ),
              ),
              // Sticky Action Footer
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.bgSurface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep == 1)
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _currentStep = 0),
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Back'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    ElevatedButton(
                      onPressed: _loading
                          ? null
                          : () {
                              if (_currentStep == 0) {
                                if (_formKey.currentState!.validate())
                                  setState(() => _currentStep = 1);
                              } else {
                                _save();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryIndigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(
                              _currentStep == 0
                                  ? 'Next: HEC Weightage'
                                  : (isEdit ? 'Save Changes' : 'Create Course'),
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return ProfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.primaryIndigo.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.menu_book_rounded,
                    color: AppColors.primaryIndigo, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Step 1: Course Info',
                      style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  Text('Basic academic details and risk threshold',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textMuted)),
                ],
              )),
            ],
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _titleCtrl,
            validator: Validators.required,
            decoration: const InputDecoration(
                labelText: 'Course Title',
                hintText: 'e.g. Object Oriented Programming'),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final codeField = TextFormField(
                controller: _codeCtrl,
                validator: Validators.required,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                    labelText: 'Course Code', hintText: 'CS-201'),
              );
              final semesterField = TextFormField(
                controller: _semCtrl,
                validator: Validators.required,
                decoration: const InputDecoration(
                    labelText: 'Semester', hintText: 'Fall 2026'),
              );
              if (constraints.maxWidth < 520) {
                return Column(children: [
                  codeField,
                  const SizedBox(height: 16),
                  semesterField
                ]);
              }
              return Row(children: [
                Expanded(child: codeField),
                const SizedBox(width: 16),
                Expanded(child: semesterField)
              ]);
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Brief syllabus or outcome objectives...'),
          ),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 12,
            children: [
              Text('At-Risk Performance Threshold',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.dangerRose.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('${_atRisk.toInt()}% Marks',
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dangerRose)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
              'Students scoring below this cumulative score will be flagged on your Cohort Intelligence dashboard.',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textMuted, height: 1.4)),
          const SizedBox(height: 12),
          ProfWeightSlider(
              value: _atRisk, onChanged: (v) => setState(() => _atRisk = v)),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    final total = _categories.fold<double>(0, (sum, item) => sum + item.weight);
    final isValid = total == 100;

    return ProfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.primaryIndigo.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.scale_rounded,
                    color: AppColors.primaryIndigo, size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Step 2: Assessment Weightage',
                      style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  Text(
                      'HEC policy requires assessment categories to sum to exactly 100%.',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Total Validation Banner
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isValid
                  ? AppColors.successGreen.withOpacity(0.08)
                  : AppColors.dangerRose.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isValid
                      ? AppColors.successGreen.withOpacity(0.3)
                      : AppColors.dangerRose.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                    isValid
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    color:
                        isValid ? AppColors.successGreen : AppColors.dangerRose,
                    size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isValid
                            ? 'Assessment Weights Valid (100%)'
                            : 'Total Weight: ${total.toInt()}% (Must equal 100%)',
                        style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isValid
                                ? AppColors.successGreen
                                : AppColors.dangerRose),
                      ),
                      Text(
                        isValid
                            ? 'All course categories are compliant with HEC rules.'
                            : 'Adjust sliders or add/remove categories to reach 100%.',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Category List
          ..._categories.asMap().entries.map((entry) {
            final idx = entry.key;
            final cat = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  if (cat.isCustom)
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: cat.nameCtrl,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          hintText: 'Category Name',
                        ),
                      ),
                    ),
                  Expanded(
                    flex: 4,
                    child: ProfWeightSlider(
                      label: cat.isCustom ? null : cat.nameCtrl.text,
                      value: cat.weight,
                      onChanged: (v) => setState(() => cat.weight = v),
                    ),
                  ),
                  if (cat.isCustom)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.dangerRose, size: 20),
                      onPressed: () =>
                          setState(() => _categories.removeAt(idx)),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(() => _categories.add(_CategoryItem(
                name: 'Course Project', weight: 0, isCustom: true))),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Custom Category'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
