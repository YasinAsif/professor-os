import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_parser.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/prof_card.dart';
import '../../../shared/widgets/prof_breadcrumbs.dart';
import '../data/course_repository.dart';
import '../providers/course_providers.dart';

class AssignmentCreationWizard extends ConsumerStatefulWidget {
  final int courseId;
  const AssignmentCreationWizard({super.key, required this.courseId});

  @override
  ConsumerState<AssignmentCreationWizard> createState() => _WizardState();
}

class _WizardState extends ConsumerState<AssignmentCreationWizard> {
  bool _loading = false;

  // Step 1: Category & Sub-category
  String _primaryCategory = 'midterm'; // 'midterm', 'final', 'internal'
  String _internalSubCategory = 'quiz'; // 'quiz', 'assignment', 'project'

  // Quiz internal type ('mcq' or 'text')
  String _quizType = 'mcq';
  // Assignment internal type ('text', 'mcq', 'file')
  String _assignType = 'text';

  // Overall type sent to API: 'text', 'file', 'mcq'
  String _type = 'text';

  // Step 2: Details
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _marksCtrl = TextEditingController(text: '20');
  final _weightageCtrl = TextEditingController(text: '20');
  final _timeLimitCtrl = TextEditingController();
  DateTime? _deadline;
  final _quillCtrl = quill.QuillController.basic();
  bool _allowLate = false;
  double _latePenalty = 10;
  double _maxPenaltyCap = 50;
  String? _selectedFileName;
  String? _selectedFileSizeStr;
  final Set<int> _selectedCloIds = {};

  // MCQ Questions
  final List<_McqQuestion> _mcqQuestions = [];

  // Structured Questions for Midterm, Final, and Short Question Quizzes/Assignments
  final List<_MainQuestion> _mainQuestions = [];

  // Step 3: Rubric Builder (Criteria list)
  final List<_RubricRow> _criteria = [
    _RubricRow(name: 'Technical Accuracy', weight: 40),
    _RubricRow(name: 'Structure & Quality', weight: 30),
    _RubricRow(name: 'Documentation', weight: 30),
  ];

  @override
  void initState() {
    super.initState();
    _timeLimitCtrl.addListener(_onFieldChanged);
    _titleCtrl.addListener(_onFieldChanged);
    _descCtrl.addListener(_onFieldChanged);
    _marksCtrl.addListener(_onFieldChanged);
    _weightageCtrl.addListener(_onFieldChanged);
    _switchToPrimaryCategory('midterm');
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  void _switchToPrimaryCategory(String cat) {
    setState(() {
      _primaryCategory = cat;
      if (cat == 'midterm') {
        _marksCtrl.text = '20';
        _weightageCtrl.text = '20';
        _type = 'text';
        _mainQuestions.clear();
        for (int i = 0; i < 4; i++) {
          _mainQuestions.add(_MainQuestion(marks: '5.0'));
        }
      } else if (cat == 'final') {
        _marksCtrl.text = '50';
        _weightageCtrl.text = '50';
        _type = 'text';
        _mainQuestions.clear();
        for (int i = 0; i < 5; i++) {
          _mainQuestions.add(_MainQuestion(marks: '10.0'));
        }
      } else {
        _switchToInternalSubCategory(_internalSubCategory);
      }
    });
  }

  void _switchToInternalSubCategory(String sub) {
    setState(() {
      _internalSubCategory = sub;
      _weightageCtrl.text = '10';
      if (sub == 'quiz') {
        _marksCtrl.text = '10';
        _type = _quizType;
        if (_type == 'text' && _mainQuestions.isEmpty) {
          _mainQuestions.add(_MainQuestion(marks: '10.0'));
        } else if (_type == 'mcq' && _mcqQuestions.isEmpty) {
          _mcqQuestions.add(_McqQuestion());
        }
      } else if (sub == 'assignment') {
        _marksCtrl.text = '20';
        _type = _assignType;
        if (_type == 'text' && _mainQuestions.isEmpty) {
          _mainQuestions.add(_MainQuestion(marks: '20.0'));
        } else if (_type == 'mcq' && _mcqQuestions.isEmpty) {
          _mcqQuestions.add(_McqQuestion());
        }
      } else if (sub == 'project') {
        _marksCtrl.text = '30';
        _type = 'file';
        _mainQuestions.clear();
        _mcqQuestions.clear();
      }
    });
  }

  Future<void> _showCreateCloDialog() async {
    final codeCtrl = TextEditingController(text: 'CLO-');
    final descCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Course Learning Outcome',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                  labelText: 'CLO Code', hintText: 'e.g. CLO-2'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g. Design relational database schemas'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final code = codeCtrl.text.trim();
              final desc = descCtrl.text.trim();
              if (code.isEmpty || desc.isEmpty) return;
              try {
                final created = await CourseRepository()
                    .createClo(widget.courseId, code, desc);
                if (mounted) {
                  setState(() {
                    _selectedCloIds.add(created['id'] as int);
                  });
                  ref.invalidate(courseClosProvider(widget.courseId));
                  Navigator.pop(ctx);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ErrorParser.parse(e)),
                    backgroundColor: AppColors.dangerRose,
                  ));
                }
              }
            },
            child: const Text('Add CLO'),
          ),
        ],
      ),
    );
  }

  String? _getValidationIssue() {
    if (_titleCtrl.text.trim().isEmpty) {
      return 'Assessment title is required.';
    }

    if (_primaryCategory == 'midterm' || _primaryCategory == 'final' ||
        (_primaryCategory == 'internal' && (_internalSubCategory == 'quiz' || _internalSubCategory == 'assignment') && _type == 'text')) {
      if (_mainQuestions.isEmpty) {
        return 'Please add at least one question.';
      }
      if (_primaryCategory == 'midterm' && _mainQuestions.length > 4) {
        return 'Midterm can have a maximum of 4 main questions.';
      }
      if (_primaryCategory == 'final' && _mainQuestions.length > 5) {
        return 'Final exam can have a maximum of 5 main questions.';
      }

      double totalMarks = 0.0;
      for (int i = 0; i < _mainQuestions.length; i++) {
        final mq = _mainQuestions[i];
        if (mq.questionCtrl.text.trim().isEmpty) {
          return 'Question ${i + 1} text cannot be empty.';
        }
        if (mq.parts.isNotEmpty) {
          const alphabet = ['a', 'b', 'c', 'd', 'e', 'f'];
          for (int j = 0; j < mq.parts.length; j++) {
            final part = mq.parts[j];
            final partLabel = alphabet[j % alphabet.length];
            if (part.questionCtrl.text.trim().isEmpty) {
              return 'Question ${i + 1} part ($partLabel) text cannot be empty.';
            }
            if (part.refAnswerCtrl.text.trim().isEmpty) {
              return 'Question ${i + 1} part ($partLabel) is missing a reference answer.';
            }
            totalMarks += double.tryParse(part.marksCtrl.text.trim()) ?? 0.0;
          }
        } else {
          if (mq.refAnswerCtrl.text.trim().isEmpty) {
            return 'Question ${i + 1} is missing a reference answer.';
          }
          totalMarks += double.tryParse(mq.marksCtrl.text.trim()) ?? 0.0;
        }
      }

      if (_primaryCategory == 'midterm' && (totalMarks - 20.0).abs() > 0.01) {
        return 'Midterm question marks must sum to exactly 20 (currently ${totalMarks.toStringAsFixed(1)}).';
      }
      if (_primaryCategory == 'final' && (totalMarks - 50.0).abs() > 0.01) {
        return 'Final exam question marks must sum to exactly 50 (currently ${totalMarks.toStringAsFixed(1)}).';
      }
    }

    if (_type == 'mcq') {
      if (_mcqQuestions.isEmpty) {
        return 'MCQ assessment requires at least one question.';
      }
      for (int i = 0; i < _mcqQuestions.length; i++) {
        final q = _mcqQuestions[i];
        if (q.questionCtrl.text.trim().isEmpty) {
          return 'MCQ Question ${i + 1} text cannot be empty.';
        }
        final validOpts = q.optionCtrls.where((c) => c.text.trim().isNotEmpty).toList();
        if (validOpts.length < 2) {
          return 'MCQ Question ${i + 1} must have at least 2 non-empty options.';
        }
        if (q.correctIndex < 0 || q.correctIndex >= q.optionCtrls.length) {
          return 'MCQ Question ${i + 1} must have a selected correct option.';
        }
        if (q.optionCtrls[q.correctIndex].text.trim().isEmpty) {
          return 'MCQ Question ${i + 1} correct option cannot be blank.';
        }
      }
    }

    if (_primaryCategory == 'internal') {
      final w = double.tryParse(_weightageCtrl.text.trim()) ?? 0.0;
      if (w > 30.0) {
        return 'Internal assessment weightage cannot exceed 30 marks.';
      }
    }

    return null;
  }

  Future<void> _publish(bool asDraft) async {
    final validationError = _getValidationIssue();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(validationError),
        backgroundColor: AppColors.dangerRose,
      ));
      return;
    }

    setState(() => _loading = true);
    try {
      final repo = CourseRepository();
      String mappedType = _type;
      if (_type == 'file') {
        mappedType = 'file';
      } else if (_type == 'mcq') {
        mappedType = 'mcq';
      } else {
        mappedType = 'text';
      }

      String category = _primaryCategory == 'internal' ? _internalSubCategory : _primaryCategory;
      double weightage = double.tryParse(_weightageCtrl.text.trim()) ??
          (_primaryCategory == 'midterm' ? 20.0 : (_primaryCategory == 'final' ? 50.0 : 10.0));

      String descriptionPayload = _descCtrl.text.trim();
      if (_primaryCategory == 'midterm' || _primaryCategory == 'final' ||
          (_primaryCategory == 'internal' && (_internalSubCategory == 'quiz' || _internalSubCategory == 'assignment') && _type == 'text')) {
        descriptionPayload = jsonEncode({
          'type': _type,
          'category': category,
          'instructions': _descCtrl.text.trim(),
          'questions': _mainQuestions.asMap().entries.map((e) => e.value.toJson(e.key + 1)).toList(),
        });
      } else if (_type == 'mcq' && _mcqQuestions.isNotEmpty) {
        descriptionPayload = jsonEncode({
          'type': _type,
          'category': category,
          'instructions': _descCtrl.text.trim(),
          'questions': _mcqQuestions.map((q) => q.toJson()).toList(),
        });
      }

      final assignData = {
        'title': _titleCtrl.text.trim(),
        'description': descriptionPayload,
        'category': category,
        'weightage': weightage,
        'type': mappedType,
        'max_marks': double.parse(_marksCtrl.text),
        'deadline': _deadline?.toUtc().toIso8601String(),
        'time_limit_minutes': int.tryParse(_timeLimitCtrl.text.trim()),
        'allow_late': _allowLate,
        'late_penalty_per_day': _latePenalty,
        'max_penalty_cap': _maxPenaltyCap,
        'clo_ids': _selectedCloIds.toList(),
      };
      final created = await repo.createAssignment(widget.courseId, assignData);
      final aid = created['id'] as int;

      // 2. Create Rubric
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

      if (mounted) {
        ref.invalidate(assignmentListProvider(widget.courseId));
        context.go('/courses/${widget.courseId}/assignments/$aid');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ErrorParser.parse(e)),
        backgroundColor: AppColors.dangerRose,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _timeLimitCtrl.removeListener(_onFieldChanged);
    _titleCtrl.removeListener(_onFieldChanged);
    _descCtrl.removeListener(_onFieldChanged);
    _marksCtrl.removeListener(_onFieldChanged);
    _weightageCtrl.removeListener(_onFieldChanged);
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _marksCtrl.dispose();
    _weightageCtrl.dispose();
    _timeLimitCtrl.dispose();
    _quillCtrl.dispose();
    for (var c in _criteria) {
      c.dispose();
    }
    for (var q in _mcqQuestions) {
      q.dispose();
    }
    for (var mq in _mainQuestions) {
      mq.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final validationIssue = _getValidationIssue();

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.pop()),
        title: ProfBreadcrumbs(
          items: [
            const BreadcrumbItem(label: 'Courses', path: '/courses'),
            BreadcrumbItem(label: 'Course', path: '/courses/${widget.courseId}'),
            const BreadcrumbItem(label: 'Create Assessment'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAssessmentHierarchySelector(),
                      const SizedBox(height: 36),
                      _buildStep2Details(),
                      const SizedBox(height: 36),
                      if (_primaryCategory == 'midterm' || _primaryCategory == 'final' ||
                          (_primaryCategory == 'internal' && (_internalSubCategory == 'quiz' || _internalSubCategory == 'assignment') && _type == 'text')) ...[
                        _buildStructuredQuestionsStep(),
                        const SizedBox(height: 36),
                      ] else if (_type == 'mcq') ...[
                        _buildMcqQuestionsStep(),
                        const SizedBox(height: 36),
                      ],
                      _buildStep3Rubric(),
                      const SizedBox(height: 36),
                      _buildStep4TA(),
                      const SizedBox(height: 64),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width < 500 ? 16 : 40,
              vertical: 18,
            ),
            decoration: const BoxDecoration(
              color: AppColors.bgSurface,
              border: Border(top: BorderSide(color: AppColors.marginRule)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (validationIssue != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.dangerRose.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.dangerRose.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppColors.dangerRose, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            validationIssue,
                            style: GoogleFonts.inter(
                              color: AppColors.dangerRose,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                LayoutBuilder(
                  builder: (context, constraints) {
                    final saveDraft = OutlinedButton(
                      onPressed: (_loading || validationIssue != null)
                          ? null
                          : () => _publish(true),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                      ),
                      child: const Text('Save Draft'),
                    );

                    final publish = ElevatedButton(
                      onPressed: (_loading || validationIssue != null)
                          ? null
                          : () {
                              if (!_formKey.currentState!.validate()) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Please complete all required fields.'),
                                        backgroundColor: AppColors.dangerRose));
                                return;
                              }
                              _publish(false);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.signal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text('Publish Assessment',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600)),
                    );

                    if (constraints.maxWidth < 500) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          saveDraft,
                          const SizedBox(height: 10),
                          publish
                        ],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        saveDraft,
                        const SizedBox(width: 16),
                        publish,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentHierarchySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assessment Classification Flow',
          style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        Text(
          'Step 1: Choose examination level. Step 2: Choose internal instrument (if applicable).',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),

        // Step 1: Main Category (Shown ONCE)
        Text(
          'Step 1: Select Assessment Category',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _categoryChoiceCard(
                keyId: 'midterm',
                title: 'Midterm',
                subtitle: '20 Marks (Fixed)\nMax 4 Qs (Short/Long)',
                icon: Icons.assignment_turned_in_rounded,
                selected: _primaryCategory == 'midterm',
                onTap: () => _switchToPrimaryCategory('midterm'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _categoryChoiceCard(
                keyId: 'final',
                title: 'Final Exam',
                subtitle: '50 Marks (Fixed)\nMax 5 Qs (Short/Long)',
                icon: Icons.school_rounded,
                selected: _primaryCategory == 'final',
                onTap: () => _switchToPrimaryCategory('final'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _categoryChoiceCard(
                keyId: 'internal',
                title: 'Internal Assessment',
                subtitle: 'Capped at 30 Marks\nQuiz / Assignment / Project',
                icon: Icons.layers_rounded,
                selected: _primaryCategory == 'internal',
                onTap: () => _switchToPrimaryCategory('internal'),
              ),
            ),
          ],
        ),

        // Step 2: Only for Internal Assessment
        if (_primaryCategory == 'internal') ...[
          const SizedBox(height: 24),
          Text(
            'Step 2: Choose Internal Instrument',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _categoryChoiceCard(
                  keyId: 'quiz',
                  title: 'Quiz',
                  subtitle: 'MCQs or Short Qs\nFast auto-graded checks',
                  icon: Icons.quiz_rounded,
                  selected: _internalSubCategory == 'quiz',
                  onTap: () => _switchToInternalSubCategory('quiz'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _categoryChoiceCard(
                  keyId: 'assignment',
                  title: 'Assignment',
                  subtitle: 'Short Qs, MCQs, or File\nIn-depth coursework',
                  icon: Icons.description_rounded,
                  selected: _internalSubCategory == 'assignment',
                  onTap: () => _switchToInternalSubCategory('assignment'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _categoryChoiceCard(
                  keyId: 'project',
                  title: 'Project / Presentation',
                  subtitle: 'File Upload Only\nNo question builder / MCQs',
                  icon: Icons.co_present_rounded,
                  selected: _internalSubCategory == 'project',
                  onTap: () => _switchToInternalSubCategory('project'),
                ),
              ),
            ],
          ),

          // Sub-type choices for Quiz and Assignment
          if (_internalSubCategory == 'quiz') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Quiz Question Format: ',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('MCQs Only'),
                  selected: _type == 'mcq',
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _quizType = 'mcq';
                        _type = 'mcq';
                        if (_mcqQuestions.isEmpty) {
                          _mcqQuestions.add(_McqQuestion());
                        }
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Short Questions'),
                  selected: _type == 'text',
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _quizType = 'text';
                        _type = 'text';
                        if (_mainQuestions.isEmpty) {
                          _mainQuestions.add(_MainQuestion(marks: '10.0'));
                        }
                      });
                    }
                  },
                ),
              ],
            ),
          ] else if (_internalSubCategory == 'assignment') ...[
            const SizedBox(height: 16),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text('Submission Mode: ',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                ChoiceChip(
                  label: const Text('Short Questions'),
                  selected: _type == 'text',
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _assignType = 'text';
                        _type = 'text';
                        if (_mainQuestions.isEmpty) {
                          _mainQuestions.add(_MainQuestion(marks: '20.0'));
                        }
                      });
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('MCQs'),
                  selected: _type == 'mcq',
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _assignType = 'mcq';
                        _type = 'mcq';
                        if (_mcqQuestions.isEmpty) {
                          _mcqQuestions.add(_McqQuestion());
                        }
                      });
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('File Upload'),
                  selected: _type == 'file',
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _assignType = 'file';
                        _type = 'file';
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _categoryChoiceCard({
    required String keyId,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF4F46E5).withOpacity(0.08)
              : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF4F46E5) : AppColors.marginRule,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 20,
                    color: selected
                        ? const Color(0xFF4F46E5)
                        : AppColors.textSecondary),
                const Spacer(),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      size: 16, color: Color(0xFF4F46E5)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected
                    ? const Color(0xFF4F46E5)
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: AppColors.textMuted,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStructuredQuestionsStep() {
    final isMidterm = _primaryCategory == 'midterm';
    final isFinal = _primaryCategory == 'final';
    final maxQuestions = isMidterm ? 4 : (isFinal ? 5 : 20);

    double currentTotalMarks = 0.0;
    for (var mq in _mainQuestions) {
      currentTotalMarks += mq.totalMarks;
    }

    final targetMarks = double.tryParse(_marksCtrl.text.trim()) ?? 0.0;
    final isMarksMatched = (currentTotalMarks - targetMarks).abs() < 0.01;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Question Paper Builder',
                      style: GoogleFonts.outfit(
                          fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    isMidterm
                        ? 'Midterm Examination (Fixed 20 Marks, Max 4 Main Questions, Short/Long Only)'
                        : (isFinal
                            ? 'Final Examination (Fixed 50 Marks, Max 5 Main Questions, Short/Long Only)'
                            : 'Continuous Assessment Questions with Teacher Reference Answers'),
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isMarksMatched
                    ? const Color(0xFF10B981).withOpacity(0.1)
                    : AppColors.dangerRose.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isMarksMatched
                      ? const Color(0xFF10B981)
                      : AppColors.dangerRose,
                ),
              ),
              child: Text(
                'Total: ${currentTotalMarks.toStringAsFixed(1)} / ${targetMarks.toStringAsFixed(0)} Marks',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isMarksMatched
                      ? const Color(0xFF10B981)
                      : AppColors.dangerRose,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        ..._mainQuestions.asMap().entries.map((entry) {
          final qi = entry.key;
          final mq = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(20),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Question ${qi + 1}',
                          style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF4F46E5))),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Marks: ${mq.totalMarks.toStringAsFixed(1)}',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    if (_mainQuestions.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.dangerRose, size: 20),
                        onPressed: () {
                          setState(() {
                            mq.dispose();
                            _mainQuestions.removeAt(qi);
                          });
                        },
                        tooltip: 'Remove Main Question',
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: mq.questionCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Question ${qi + 1} Prompt *',
                    hintText: 'Enter question statement or problem prompt...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 14),

                // If Question has NO parts yet
                if (mq.parts.isEmpty) ...[
                  Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: TextFormField(
                          controller: mq.marksCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Marks *',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            // Add first two sub-parts with divided marks
                            final cur = double.tryParse(mq.marksCtrl.text) ?? 5.0;
                            final half = (cur / 2).toStringAsFixed(1);
                            mq.parts.add(_QuestionPart(marks: half));
                            mq.parts.add(_QuestionPart(marks: half));
                          });
                        },
                        icon: const Icon(Icons.account_tree_outlined, size: 16),
                        label: const Text('Add Part (a, b)'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: mq.refAnswerCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText:
                          'Teacher Reference Answer (Authoritative Ground Truth) *',
                      hintText:
                          'Provide the exact model answer or key concepts. AI grading strictly evaluates against this answer.',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: const Color(0xFF4F46E5).withOpacity(0.03),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ] else ...[
                  // Question has parts!
                  const SizedBox(height: 8),
                  Text('Question Parts:',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  ...mq.parts.asMap().entries.map((partEntry) {
                    final pi = partEntry.key;
                    final part = partEntry.value;
                    const alphabet = ['a', 'b', 'c', 'd', 'e', 'f'];
                    final label = alphabet[pi % alphabet.length];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.bgPage,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.border.withOpacity(0.8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Part ($label)',
                                  style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF4F46E5))),
                              const Spacer(),
                              SizedBox(
                                width: 100,
                                child: TextFormField(
                                  controller: part.marksCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Marks',
                                    isDense: true,
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    size: 18, color: AppColors.dangerRose),
                                onPressed: () {
                                  setState(() {
                                    part.dispose();
                                    mq.parts.removeAt(pi);
                                  });
                                },
                                tooltip: 'Remove Part',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: part.questionCtrl,
                            decoration: InputDecoration(
                              labelText: 'Part ($label) Statement *',
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: part.refAnswerCtrl,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText:
                                  'Part ($label) Teacher Reference Answer *',
                              hintText:
                                  'Model solution or ground truth for sub-part ($label)...',
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor:
                                  const Color(0xFF4F46E5).withOpacity(0.03),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          mq.parts.add(_QuestionPart(marks: '2.5'));
                        });
                      },
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Another Part'),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),

        if (_mainQuestions.length < maxQuestions)
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                final defMarks = isMidterm ? '5.0' : (isFinal ? '10.0' : '5.0');
                _mainQuestions.add(_MainQuestion(marks: defMarks));
              });
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('Add Question (${_mainQuestions.length + 1})'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.marginRule),
            ),
            child: Text(
              'Maximum $maxQuestions main questions reached for ${_primaryCategory.toUpperCase()}. Optional sub-parts can still be added to any question.',
              style: GoogleFonts.inter(
                  fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _buildMcqQuestionsStep() {
    const optionLabels = ['A', 'B', 'C', 'D'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MCQ Questions',
            style: GoogleFonts.outfit(
                fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Add multiple-choice questions with 4 options and select the correct answer key.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 24),
        if (_mcqQuestions.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.quiz_outlined,
                      size: 44, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text('No MCQ questions yet.',
                      style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Click "Add MCQ" below to create questions.',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
        ...List.generate(_mcqQuestions.length, (qi) {
          final q = _mcqQuestions[qi];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryIndigo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('MCQ ${qi + 1}',
                          style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryIndigo)),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.dangerRose, size: 20),
                      onPressed: () =>
                          setState(() => _mcqQuestions.removeAt(qi)),
                      tooltip: 'Remove Question',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: q.questionCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Question Statement *',
                      hintText:
                          'e.g. What is the time complexity of quicksort in average case?'),
                  maxLines: 2,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                Text('Options — select the radio for the correct option:',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                ...List.generate(
                    4,
                    (oi) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Radio<int>(
                                value: oi,
                                groupValue: q.correctIndex,
                                onChanged: (val) =>
                                    setState(() => q.correctIndex = val!),
                                activeColor: AppColors.successGreen,
                              ),
                              Container(
                                width: 28,
                                height: 28,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: q.correctIndex == oi
                                      ? AppColors.successGreen.withOpacity(0.1)
                                      : AppColors.bgPage,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: q.correctIndex == oi
                                        ? AppColors.successGreen
                                        : AppColors.border,
                                  ),
                                ),
                                child: Center(
                                  child: Text(optionLabels[oi],
                                      style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: q.correctIndex == oi
                                              ? AppColors.successGreen
                                              : AppColors.textSecondary)),
                                ),
                              ),
                              Expanded(
                                child: TextFormField(
                                  controller: q.optionCtrls[oi],
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: 'Option ${optionLabels[oi]} *',
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                        )),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => setState(() => _mcqQuestions.add(_McqQuestion())),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add MCQ Question'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryIndigo,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Details() {
    final extensions = _type == 'file'
        ? '.pdf, .docx, .zip, .png, .jpg'
        : '.pdf, .docx, .txt';

    final isFixedMarks = _primaryCategory == 'midterm' || _primaryCategory == 'final';

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step 2: Assessment Specifications',
              style: GoogleFonts.outfit(
                  fontSize: 22, fontWeight: FontWeight.w700)),
          Text(
              'Configure basic metadata, marks, OBE weightage, and guidelines.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 24),
          ProfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  validator: Validators.required,
                  decoration: const InputDecoration(
                      labelText: 'Assessment Title *',
                      hintText: 'e.g. Midterm Examination - Spring 2027'),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Assessment Guidelines & Student Instructions',
                    hintText:
                        'Enter assessment instructions, allowed materials, or syllabus guidelines...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 18),

                // Category & Marks & Weightage row
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.bgPage,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.marginRule),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Classification',
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: AppColors.textMuted)),
                            const SizedBox(height: 2),
                            Text(
                              _primaryCategory == 'midterm'
                                  ? 'MIDTERM (20 Marks)'
                                  : (_primaryCategory == 'final'
                                      ? 'FINAL EXAM (50 Marks)'
                                      : 'INTERNAL (${_internalSubCategory.toUpperCase()})'),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _marksCtrl,
                        readOnly: isFixedMarks,
                        validator: Validators.required,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isFixedMarks
                              ? 'Total Marks (Fixed)'
                              : 'Total Marks *',
                          filled: isFixedMarks,
                          fillColor: isFixedMarks
                              ? AppColors.bgPage
                              : AppColors.bgSurface,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _weightageCtrl,
                        readOnly: isFixedMarks,
                        validator: Validators.required,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isFixedMarks
                              ? 'Weightage % (Fixed)'
                              : 'Weightage (Max 30) *',
                          helperText: _primaryCategory == 'internal'
                              ? 'Internal cap: 30%'
                              : null,
                          filled: isFixedMarks,
                          fillColor: isFixedMarks
                              ? AppColors.bgPage
                              : AppColors.bgSurface,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: () async {
                          final now = DateTime.now();
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate:
                                _deadline ?? now.add(const Duration(days: 7)),
                            firstDate: now.subtract(const Duration(days: 1)),
                            lastDate: now.add(const Duration(days: 365)),
                          );
                          if (pickedDate != null && mounted) {
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: _deadline != null
                                  ? TimeOfDay(
                                      hour: _deadline!.hour,
                                      minute: _deadline!.minute)
                                  : const TimeOfDay(hour: 23, minute: 59),
                            );
                            if (pickedTime != null && mounted) {
                              setState(() {
                                _deadline = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                              });
                            }
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Due Date & Time (Optional)',
                            suffixIcon: _deadline != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded,
                                        size: 18),
                                    onPressed: () =>
                                        setState(() => _deadline = null),
                                  )
                                : const Icon(Icons.calendar_today_rounded,
                                    size: 18),
                          ),
                          child: Text(
                            _deadline == null
                                ? 'No deadline (untimed / open)'
                                : '${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')} ${_deadline!.hour.toString().padLeft(2, '0')}:${_deadline!.minute.toString().padLeft(2, '0')}',
                            style: GoogleFonts.inter(
                              color: _deadline == null
                                  ? AppColors.textMuted
                                  : AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _timeLimitCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Time Limit (Mins)',
                          hintText: 'e.g. 60 (optional)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Late Submission Policy',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Allow Late Submissions'),
                  subtitle: const Text(
                      'Students can submit after the deadline with a penalty.'),
                  value: _allowLate,
                  onChanged: (val) => setState(() => _allowLate = val),
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primaryIndigo,
                ),
                if (_allowLate) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _latePenalty.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Late Penalty (%) per day',
                              hintText: '10.0'),
                          onChanged: (val) =>
                              _latePenalty = double.tryParse(val) ?? 10.0,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          initialValue: _maxPenaltyCap.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Max Penalty Cap (%)',
                              hintText: '50.0'),
                          onChanged: (val) =>
                              _maxPenaltyCap = double.tryParse(val) ?? 50.0,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Linked Course Learning Outcomes (CLOs)*',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textPrimary)),
                    TextButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label:
                          const Text('Add CLO', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showCreateCloDialog(),
                    ),
                  ],
                ),
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
                        if (_selectedCloIds.isEmpty && clos.isNotEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _selectedCloIds.isEmpty) {
                              setState(() {
                                _selectedCloIds.add(clos.first['id'] as int);
                              });
                            }
                          });
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
                          final allowedExtList = _type == 'file'
                              ? ['pdf', 'docx', 'doc', 'zip', 'png', 'jpg', 'jpeg', 'txt']
                              : ['pdf', 'docx', 'doc', 'txt'];
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: allowedExtList,
                            withData: true,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            final file = result.files.single;
                            final ext = file.name.contains('.')
                                ? file.name.split('.').last.toLowerCase()
                                : '';
                            if (!allowedExtList.contains(ext)) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Invalid file format: .$ext is not permitted.'),
                                        backgroundColor: AppColors.dangerRose));
                              }
                              return;
                            }
                            setState(() {
                              _selectedFileName = file.name;
                              final kb = (file.size / 1024).round();
                              _selectedFileSizeStr = kb > 1024
                                  ? '${(kb / 1024).toStringAsFixed(1)} MB'
                                  : '$kb KB';
                            });
                          }
                        },
                        icon: const Icon(Icons.attach_file_rounded, size: 16),
                        label: const Text('Browse Files'),
                      ),
                      if (_selectedFileName != null) ...[
                        const SizedBox(height: 12),
                        Chip(
                          avatar: const Icon(Icons.insert_drive_file_rounded,
                              size: 16),
                          label: Text(
                              '$_selectedFileName ($_selectedFileSizeStr)'),
                          deleteIcon: const Icon(Icons.close_rounded, size: 16),
                          onDeleted: () => setState(() {
                            _selectedFileName = null;
                            _selectedFileSizeStr = null;
                          }),
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
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: c.nameCtrl,
                          decoration: InputDecoration(
                              labelText: 'Criterion ${index + 1} Name',
                              isDense: true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          initialValue: c.weight.toInt().toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Weight (%)', isDense: true),
                          onChanged: (val) {
                            final w = double.tryParse(val) ?? 0;
                            setState(() => c.weight = w);
                          },
                        ),
                      ),
                      if (_criteria.length > 3)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.dangerRose, size: 20),
                          onPressed: () =>
                              setState(() => _criteria.removeAt(index)),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => setState(() =>
              _criteria.add(_RubricRow(name: 'New Criterion', weight: 0))),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Add Rubric Criterion'),
        ),
      ],
    );
  }

  Widget _buildStep4TA() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 4: TA Delegation',
            style:
                GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700)),
        Text(
            'Enroll TAs from the Students Roster, then assign them to this assessment after it is created.',
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
                            'TA delegation is available from the assessment list after saving this assessment.',
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
              Text('Available workflow:',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              ...[
                'Enroll a TA by email in Students Roster',
                'Assign enrolled TAs to this assessment',
                'Open the SpeedGrader workload from the TA dashboard',
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
}

// ── Question Models ─────────────────────────────────
class _QuestionPart {
  final TextEditingController questionCtrl;
  final TextEditingController marksCtrl;
  final TextEditingController refAnswerCtrl;

  _QuestionPart({String marks = '2.5'})
      : questionCtrl = TextEditingController(),
        marksCtrl = TextEditingController(text: marks),
        refAnswerCtrl = TextEditingController();

  void dispose() {
    questionCtrl.dispose();
    marksCtrl.dispose();
    refAnswerCtrl.dispose();
  }

  Map<String, dynamic> toJson(String label) => {
        'part_label': label,
        'question': questionCtrl.text.trim(),
        'marks': double.tryParse(marksCtrl.text.trim()) ?? 0.0,
        'reference_answer': refAnswerCtrl.text.trim(),
      };
}

class _MainQuestion {
  final TextEditingController questionCtrl;
  final TextEditingController marksCtrl;
  final TextEditingController refAnswerCtrl;
  final List<_QuestionPart> parts;

  _MainQuestion({String marks = '5.0'})
      : questionCtrl = TextEditingController(),
        marksCtrl = TextEditingController(text: marks),
        refAnswerCtrl = TextEditingController(),
        parts = [];

  void dispose() {
    questionCtrl.dispose();
    marksCtrl.dispose();
    refAnswerCtrl.dispose();
    for (final p in parts) {
      p.dispose();
    }
  }

  double get totalMarks {
    if (parts.isNotEmpty) {
      return parts.fold<double>(
          0.0,
          (sum, p) =>
              sum + (double.tryParse(p.marksCtrl.text.trim()) ?? 0.0));
    }
    return double.tryParse(marksCtrl.text.trim()) ?? 0.0;
  }

  Map<String, dynamic> toJson(int index) {
    if (parts.isNotEmpty) {
      const alphabet = ['a', 'b', 'c', 'd', 'e', 'f'];
      return {
        'question': questionCtrl.text.trim(),
        'marks': totalMarks,
        'parts': parts
            .asMap()
            .entries
            .map((e) =>
                e.value.toJson(alphabet[e.key % alphabet.length]))
            .toList(),
      };
    }
    return {
      'question': questionCtrl.text.trim(),
      'marks': totalMarks,
      'reference_answer': refAnswerCtrl.text.trim(),
    };
  }
}

class _McqQuestion {
  final TextEditingController questionCtrl;
  final List<TextEditingController> optionCtrls;
  int correctIndex;

  _McqQuestion()
      : questionCtrl = TextEditingController(),
        optionCtrls = List.generate(4, (_) => TextEditingController()),
        correctIndex = 0;

  void dispose() {
    questionCtrl.dispose();
    for (final c in optionCtrls) {
      c.dispose();
    }
  }

  Map<String, dynamic> toJson() => {
        'question': questionCtrl.text.trim(),
        'options': optionCtrls.map((c) => c.text.trim()).toList(),
        'correct': correctIndex,
      };
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
