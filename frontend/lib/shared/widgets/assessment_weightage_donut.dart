/// ProfessorOS – AssessmentWeightageDonut: Pie chart for weightage.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class AssessmentWeightageDonut extends StatelessWidget {
  final int quiz;
  final int assignment;
  final int midterm;
  final int finalExam;

  const AssessmentWeightageDonut({
    super.key,
    this.quiz = 20,
    this.assignment = 20,
    this.midterm = 20,
    this.finalExam = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 50,
              sections: [
                _section(quiz.toDouble(), 'Quizzes', AppColors.primaryTeal),
                _section(assignment.toDouble(), 'Assignments', AppColors.successGreen),
                _section(midterm.toDouble(), 'Midterm', AppColors.accentAmber),
                _section(finalExam.toDouble(), 'Final', AppColors.dangerRose),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _legend('Quizzes $quiz%', AppColors.primaryTeal),
            _legend('Assignments $assignment%', AppColors.successGreen),
            _legend('Midterm $midterm%', AppColors.accentAmber),
            _legend('Final $finalExam%', AppColors.dangerRose),
          ],
        ),
      ],
    );
  }

  PieChartSectionData _section(double value, String title, Color color) {
    return PieChartSectionData(
      value: value,
      title: '${value.toInt()}%',
      color: color,
      radius: 32,
      titleStyle: GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  Widget _legend(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
