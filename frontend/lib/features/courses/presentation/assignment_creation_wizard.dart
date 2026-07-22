import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/prof_card.dart';
import '../../../shared/widgets/prof_weight_slider.dart';
import '../data/course_repository.dart';
import '../providers/course_providers.dart';

class AssignmentCreationWizard extends ConsumerStatefulWidget {
  final int courseId;
  const AssignmentCreationWizard({super.key, required this.courseId});

  @override
  ConsumerState<AssignmentCreationWizard> createState() => _WizardState();
}

class _WizardState extends ConsumerState<AssignmentCreationWizard> {
  int _step = 0;
  bool _loading = false;

  // Step 1: Type
  String _type =
      'text'; // 'text', 'qna', 'file', 'mcq', 'programming', 'hybrid'

  // Step 2: Details
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _marksCtrl = TextEditingController(text: '100');
  final _quillCtrl = quill.QuillController.basic();
  String _category =
      'assignments'; // 'quizzes', 'assignments', 'midterm', 'final', 'project'
  bool _allowLate = false;
  double _latePenalty = 10;
  double _maxPenaltyCap = 50;
  String? _selectedFileName;
  String? _selectedFileSizeStr;
  Uint8List? _selectedFileBytes;
  final Set<int> _selectedCloIds = {};

  // Step 3: Rubric Builder (Criteria list)
  final List<_RubricRow> _criteria = [
    _RubricRow(name: 'Technical Accuracy', weight: 40),
    _RubricRow(name: 'Structure & Quality', weight: 30),
    _RubricRow(name: 'Documentation', weight: 30),
  ];

  // ── Predefined level names for rubrics ─────────────
  static const List<String> _levelNames = [
    'excellent',
    'satisfactory',
    'developing',
    'insufficient'
  ];
  static const List<String> _levelLabels = [
    'Excellent',
    'Satisfactory',
    'Developing',
    'Insufficient'
  ];
  static const List<String> _levelDefaults = [
    'Exceptional quality with deep mastery',
    'Good quality showing solid understanding',
    'Basic quality with room for improvement',
    'Below expected standard, needs significant revision',
  ];

  // Step 4: TA Delegation
  String _taBatchPolicy = 'all'; // 'all', 'split_equal'

  Future<void> _publish(bool asDraft) async {
    if (!asDraft && _selectedCloIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'HEC Policy Warning: At least 1 CLO must be linked before publishing.'),
        backgroundColor: AppColors.dangerRose,
      ));
      return;
    }

    setState(() => _loading = true);
    try {
      final repo = CourseRepository();
      // 1. Create Assignment
      // Map frontend types to backend-supported types
      String mappedType;
      switch (_type) {
        case 'qna':
        case 'hybrid':
        case 'text':
          mappedType = 'text';
          break;
        case 'file':
          mappedType = 'file';
          break;
        case 'mcq':
          mappedType = 'mcq';
          break;
        case 'programming':
          mappedType = 'programming';
          break;
        default:
          mappedType = 'text';
      }

      final assignData = {
        'title': _titleCtrl.text.trim(),
        'description': '',
        'type': mappedType,
        'max_marks': double.parse(_marksCtrl.text),
        'allow_late': _allowLate,
        'late_penalty_per_day': _latePenalty,
        'max_penalty_cap': _maxPenaltyCap,
        'clo_ids': _selectedCloIds.toList(),
      };
      final created = await repo.createAssignment(widget.courseId, assignData);
      final aid = created['id'] as int;

      // 2. Create Rubric with level descriptions
      final rubricData = {
        'criteria': _criteria
            .map((c) => {
                  'name': c.nameCtrl.text.trim(),
                  'weight': c.weight,
                  'levels': c.levels
                      .map((l) => {
                            'level': l.levelName,
                            'description': l.descCtrl.text.trim(),
                          })
                      .toList(),
                })
            .toList()
      };
      await repo.saveRubric(aid, rubricData);

      // 3. Publish if requested
      if (!asDraft) {
        await repo.publishAssignment(widget.courseId, aid);
      }

      if (mounted) context.pop();
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
  void dispose() {
    _titleCtrl.dispose();
    _marksCtrl.dispose();
    _quillCtrl.dispose();
    for (var c in _criteria) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.pop()),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assignment Wizard',
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            Text('Step ${_step + 1} of 5',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Step Indicator Bar
          LinearProgressIndicator(
            value: (_step + 1) / 5,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation(AppColors.primaryIndigo),
            minHeight: 4,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: _buildStepContent(),
                ),
              ),
            ),
          ),
          // Footer Controls
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.bgSurface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 12,
              children: [
                if (_step > 0)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _step--),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14)),
                  )
                else
                  const SizedBox.shrink(),
                if (_step < 4)
                  ElevatedButton(
                    onPressed: () {
                      if (_step == 1 && !_formKey.currentState!.validate())
                        return;
                      if (_step == 2) {
                        final total = _criteria.fold<double>(
                            0, (sum, item) => sum + item.weight);
                        if (total != 100) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content:
                                Text('Rubric weights must sum to exactly 100%'),
                            backgroundColor: AppColors.dangerRose,
                          ));
                          return;
                        }
                      }
                      setState(() => _step++);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryIndigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Next Step',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _loading ? null : () => _publish(true),
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14)),
                        child: const Text('Save Draft'),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: AppGradients.primaryButton,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            const BoxShadow(
                                color: Color(0x304F46E5),
                                blurRadius: 10,
                                offset: Offset(0, 4))
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _loading ? null : () => _publish(false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : Text('Publish Now',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildStep1Type();
      case 1:
        return _buildStep2Details();
      case 2:
        return _buildStep3Rubric();
      case 3:
        return _buildStep4TA();
      case 4:
        return _buildStep5Review();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1Type() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 1: Select Assessment Type',
            style:
                GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700)),
        Text('Choose how students will submit their responses for evaluation.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 640 ? 2 : 1,
          shrinkWrap: true,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2.4,
          children: [
            _typeCard('text', 'Text Essay', Icons.article_rounded,
                'Open-ended long text evaluated by LLM rubric engine.'),
            _typeCard('qna', 'Short Answer / Q&A', Icons.quiz_rounded,
                'Structured question & answer prompts with key phrases.'),
            _typeCard('file', 'File Upload', Icons.cloud_upload_rounded,
                'Submissions via PDF, DOCX, or ZIP with 25MB cap.'),
            _typeCard('mcq', 'MCQ Quiz', Icons.check_circle_outline_rounded,
                'Multiple choice question sets with instant grading.'),
            _typeCard('programming', 'Programming', Icons.terminal_rounded,
                'Source code submissions evaluated against unit tests.'),
            _typeCard('hybrid', 'Hybrid / Mixed', Icons.hub_rounded,
                'Combines MCQs, Q&A, and programming challenges.'),
          ],
        )
      ],
    );
  }

  Widget _typeCard(String type, String title, IconData icon, String desc) {
    final selected = _type == type;
    return InkWell(
      onTap: () => setState(() => _type = type),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryIndigo.withOpacity(0.06)
              : AppColors.bgSurface,
          border: Border.all(
              color: selected ? AppColors.primaryIndigo : AppColors.border,
              width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: AppColors.primaryIndigo.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryIndigo : AppColors.bgPage,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  size: 24,
                  color: selected ? Colors.white : AppColors.textSecondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(desc,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Details() {
    final extensions = _type == 'programming'
        ? '.zip, .py, .cpp, .java, .js, .cs'
        : _type == 'file'
            ? '.pdf, .docx, .zip, .png, .jpg'
            : '.pdf, .docx, .txt';

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step 2: Assignment Specifications',
              style: GoogleFonts.outfit(
                  fontSize: 22, fontWeight: FontWeight.w700)),
          Text(
              'Configure basic metadata, HEC category, and reference materials.',
              style:
                  GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 24),
          ProfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  validator: Validators.required,
                  decoration: const InputDecoration(
                      labelText: 'Assignment Title',
                      hintText: 'e.g. Midterm Lab Task 1 - Recursion'),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final category = DropdownButtonFormField<String>(
                      value: _category,
                      decoration:
                          const InputDecoration(labelText: 'HEC Category'),
                      items: const [
                        DropdownMenuItem(
                            value: 'quizzes', child: Text('Quizzes Category')),
                        DropdownMenuItem(
                            value: 'assignments',
                            child: Text('Assignments Category')),
                        DropdownMenuItem(
                            value: 'midterm', child: Text('Midterm Category')),
                        DropdownMenuItem(
                            value: 'final', child: Text('Final Exam Category')),
                        DropdownMenuItem(
                            value: 'project',
                            child: Text('Course Project Category')),
                      ],
                      onChanged: (val) => setState(() => _category = val!),
                    );
                    final marks = TextFormField(
                      controller: _marksCtrl,
                      validator: Validators.required,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Max Marks', hintText: '100'),
                    );
                    if (constraints.maxWidth < 520)
                      return Column(children: [
                        category,
                        const SizedBox(height: 16),
                        marks
                      ]);
                    return Row(children: [
                      Expanded(child: category),
                      const SizedBox(width: 16),
                      Expanded(child: marks)
                    ]);
                  },
                ),
                /* Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        decoration: const InputDecoration(labelText: 'HEC Category'),
                        items: const [
                          DropdownMenuItem(value: 'quizzes', child: Text('Quizzes Category')),
                          DropdownMenuItem(value: 'assignments', child: Text('Assignments Category')),
                          DropdownMenuItem(value: 'midterm', child: Text('Midterm Category')),
                          DropdownMenuItem(value: 'final', child: Text('Final Exam Category')),
                          DropdownMenuItem(value: 'project', child: Text('Course Project Category')),
                        ],
                        onChanged: (val) => setState(() => _category = val!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _marksCtrl,
                        validator: Validators.required,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Max Marks', hintText: '100'),
                      ),
                    ),
                  ],
                ), */
                const SizedBox(height: 20),
                Text('Linked Course Learning Outcomes (CLOs)*',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                ref.watch(courseClosProvider(widget.courseId)).when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error loading CLOs: $e',
                          style: const TextStyle(
                              color: AppColors.dangerRose, fontSize: 12)),
                      data: (clos) {
                        if (clos.isEmpty) {
                          return Row(
                            children: [
                              Text('No CLOs defined for this course yet.',
                                  style: GoogleFonts.inter(
                                      color: AppColors.textMuted,
                                      fontSize: 13)),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Add Default CLO-1'),
                                onPressed: () async {
                                  final created = await CourseRepository()
                                      .createClo(widget.courseId, 'CLO-1',
                                          'Basic outcome objectives');
                                  setState(() {
                                    _selectedCloIds.add(created['id'] as int);
                                  });
                                  ref.invalidate(
                                      courseClosProvider(widget.courseId));
                                },
                              )
                            ],
                          );
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: clos.map<Widget>((clo) {
                            final id = clo['id'] as int;
                            final isSelected = _selectedCloIds.contains(id);
                            return FilterChip(
                              selected: isSelected,
                              label:
                                  Text('${clo['code']}: ${clo['description']}'),
                              selectedColor:
                                  AppColors.primaryIndigo.withOpacity(0.18),
                              checkmarkColor: AppColors.primaryIndigo,
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedCloIds.add(id);
                                  } else {
                                    _selectedCloIds.remove(id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),
                const SizedBox(height: 20),
                Text('Reference Materials / Starter Package',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                // Drag & Drop Zone
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.primaryIndigo.withOpacity(0.3),
                        style: BorderStyle.solid),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.cloud_upload_outlined,
                          size: 36, color: AppColors.primaryIndigo),
                      const SizedBox(height: 10),
                      Text('Drag & drop prompt attachment, or browse files',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text(
                          'Max file size: 25 MB • Allowed formats: $extensions',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            withData: true,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            final file = result.files.single;
                            final bytes = file.bytes;
                            final sizeInKb =
                                (file.size / 1024).toStringAsFixed(1);
                            final sizeStr = file.size > 1024 * 1024
                                ? '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB'
                                : '$sizeInKb KB';
                            setState(() {
                              _selectedFileName = file.name;
                              _selectedFileSizeStr = sizeStr;
                              _selectedFileBytes = bytes;
                            });
                          }
                        },
                        icon: const Icon(Icons.folder_open_rounded, size: 16),
                        label: Text(_selectedFileName == null
                            ? 'Select Attachment File'
                            : 'Change File'),
                      ),
                      if (_selectedFileName != null) ...[
                        const SizedBox(height: 12),
                        Chip(
                          avatar: const Icon(Icons.insert_drive_file_rounded,
                              size: 16, color: AppColors.primaryIndigo),
                          label: Text(
                              '$_selectedFileName ($_selectedFileSizeStr)'),
                          onDeleted: () => setState(() {
                            _selectedFileName = null;
                            _selectedFileSizeStr = null;
                            _selectedFileBytes = null;
                          }),
                          deleteIcon: const Icon(Icons.close_rounded, size: 14),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Rubric() {
    final total = _criteria.fold<double>(0, (sum, item) => sum + item.weight);
    final isValid = total == 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 3: Rubric Builder',
            style:
                GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700)),
        Text(
            'HEC policy requires at least 3 criteria, with weights summing to 100%.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 24),
        // Live Validation Bar
        Container(
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
                  size: 20),
              const SizedBox(width: 10),
              Text(
                'Rubric Total Weight: ${total.toInt()}%',
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isValid
                        ? AppColors.successGreen
                        : AppColors.dangerRose),
              ),
              const Spacer(),
              Text('Min 3 Criteria (${_criteria.length} added)',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _criteria.length,
          itemBuilder: (context, index) {
            final c = _criteria[index];
            return Container(
              key: ValueKey(c),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.drag_indicator_rounded,
                          color: AppColors.textMuted),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: c.nameCtrl,
                          decoration: const InputDecoration(
                              isDense: true, labelText: 'Criterion Name'),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 3,
                        child: ProfWeightSlider(
                          value: c.weight,
                          onChanged: (v) => setState(() => c.weight = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.dangerRose),
                        onPressed: _criteria.length > 3
                            ? () => setState(() => _criteria.removeAt(index))
                            : null,
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('Performance Levels',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  ...List.generate(
                      4,
                      (li) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 100,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: li == 0
                                          ? AppColors.successGreen
                                              .withOpacity(0.08)
                                          : li == 3
                                              ? AppColors.dangerRose
                                                  .withOpacity(0.08)
                                              : AppColors.bgPage,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(_levelLabels[li],
                                        style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: c.levels[li].descCtrl,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: _levelDefaults[li],
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          )),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        if (_criteria.length < 10)
          OutlinedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Criterion'),
            onPressed: () => setState(() =>
                _criteria.add(_RubricRow(name: 'New Criterion', weight: 0))),
          ),
      ],
    );
  }

  Widget _buildStep4TA() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 4: TA Delegation (Coming Soon)',
            style:
                GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700)),
        Text(
            'Assign grading batches to Teaching Assistants enrolled in this course.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 24),
        ProfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppColors.accentAmber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.construction_rounded,
                        color: AppColors.accentAmber, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TA Grading Workflow',
                            style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        Text(
                            'Feature in development — all grading will be done by professor initially.',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text('Planned capabilities:',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              ...[
                'Split submissions equally among TAs',
                'Assign specific student groups to TAs',
                'TA-grade with professor review & override',
                'Track TA grading progress in real-time',
              ].map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 16, color: AppColors.primaryIndigo),
                        const SizedBox(width: 10),
                        Text(f,
                            style: GoogleFonts.inter(
                                fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep5Review() {
    final totalWeight =
        _criteria.fold<double>(0, (sum, item) => sum + item.weight);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 5: Review & Publish',
            style:
                GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700)),
        Text(
            'Verify assignment configuration before releasing to enrolled students.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 24),
        ProfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                      _titleCtrl.text.isEmpty
                          ? 'Untitled Assignment'
                          : _titleCtrl.text,
                      style: GoogleFonts.outfit(
                          fontSize: 20, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Chip(
                    label: Text(_type.toUpperCase()),
                    backgroundColor: AppColors.primaryIndigo.withOpacity(0.1),
                    labelStyle: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryIndigo),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _statItem('Max Marks', _marksCtrl.text),
                  _statItem('HEC Category', _category.toUpperCase()),
                  _statItem('Rubric Weight', '${totalWeight.toInt()}%'),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 14),
              Text('Rubric Criteria (${_criteria.length} Items):',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ..._criteria.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            size: 16, color: AppColors.primaryIndigo),
                        const SizedBox(width: 8),
                        Text(c.nameCtrl.text,
                            style: GoogleFonts.inter(
                                fontSize: 13, color: AppColors.textPrimary)),
                        const Spacer(),
                        Text('${c.weight.toInt()}%',
                            style: GoogleFonts.outfit(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statItem(String label, String val) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(val,
              style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _RubricLevel {
  final String levelName;
  final TextEditingController descCtrl;
  _RubricLevel({required this.levelName, String defaultDesc = ''})
      : descCtrl = TextEditingController(text: defaultDesc);
  void dispose() => descCtrl.dispose();
}

class _RubricRow {
  final TextEditingController nameCtrl;
  double weight;
  final List<_RubricLevel> levels;
  _RubricRow({required String name, required this.weight})
      : nameCtrl = TextEditingController(text: name),
        levels = List.generate(4, (i) {
          final levelNames = [
            'excellent',
            'satisfactory',
            'developing',
            'insufficient'
          ];
          final defaults = [
            'Exceptional quality with deep mastery',
            'Good quality showing solid understanding',
            'Basic quality with room for improvement',
            'Below expected standard, needs significant revision',
          ];
          return _RubricLevel(
              levelName: levelNames[i], defaultDesc: defaults[i]);
        });
  void dispose() {
    nameCtrl.dispose();
    for (var l in levels) {
      l.dispose();
    }
  }
}
