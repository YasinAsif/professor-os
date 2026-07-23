/// ProfessorOS – Analytics Dashboard (M-07).

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/avatar_helper.dart';
import '../../../shared/widgets/prof_card.dart';
import '../../../shared/widgets/prof_shimmer.dart';
import '../../../shared/widgets/assessment_weightage_donut.dart';
import '../providers/analytics_provider.dart';

class AnalyticsDashboardScreen extends ConsumerWidget {
  final int courseId;
  const AnalyticsDashboardScreen({super.key, required this.courseId});

  Future<void> _exportReport(BuildContext context) async {
    final token = await DioClient.getAccessToken();
    if (token == null) return;
    final url = Uri.parse('${ApiConstants.baseUrl}/courses/$courseId/analytics/pdf?token=$token');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not trigger report download.'),
            backgroundColor: AppColors.dangerRose,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(analyticsDashboardProvider(courseId));

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cohort Intelligence',
                style: GoogleFonts.outfit(
                    fontSize: 22, fontWeight: FontWeight.w600)),
            Text('Course Performance & Competency Analytics',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Analytics',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(analyticsDashboardProvider(courseId));
            },
          ),
          Builder(
            builder: (context) {
              final compact = MediaQuery.sizeOf(context).width < 600;
              return Padding(
                padding: EdgeInsets.only(right: compact ? 8 : 24),
                child: compact
                    ? IconButton(
                        tooltip: 'Export Report',
                        icon: const Icon(Icons.picture_as_pdf),
                        onPressed: () => _exportReport(context),
                      )
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: Text('Export Report',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600)),
                        onPressed: () => _exportReport(context),
                      ),
              );
            },
          ),
        ],
      ),
      body: asyncData.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            ProfShimmer.card(height: 120),
            const SizedBox(height: 24),
            ProfShimmer.card(height: 300),
            const SizedBox(height: 24),
            ProfShimmer.card(height: 300),
          ],
        ),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: AppColors.dangerRose))),
        data: (data) {
          if (data['total_students'] == 0 &&
              (data['distribution'] as List).isEmpty) {
            return Center(
              child: Text(
                'No approved grades yet. Analytics will appear after the first submission is graded.',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 900;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Metric Cards Row
                    _KPIMetricRow(data: data, isDesktop: isDesktop),
                    const SizedBox(height: 24),

                    // Middle Row: Distribution & Radar
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              flex: 3,
                              child:
                                  _HistogramPanel(data: data['distribution'])),
                          const SizedBox(width: 24),
                          Expanded(
                              flex: 2,
                              child:
                                  _RadarPanel(data: data['criterion_scores'])),
                        ],
                      )
                    else ...[
                      _HistogramPanel(data: data['distribution']),
                      const SizedBox(height: 24),
                      _RadarPanel(data: data['criterion_scores']),
                    ],
                    const SizedBox(height: 24),

                    // Bottom Row: Cohort Trend & Weightage / At-Risk
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              flex: 3,
                              child: _TrendPanel(data: data['cohort_trend'])),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                _WeightagePanel(data: data),
                                const SizedBox(height: 24),
                                _AtRiskPanel(
                                    students: data['at_risk_students']),
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _TrendPanel(data: data['cohort_trend']),
                      const SizedBox(height: 24),
                      _WeightagePanel(data: data),
                      const SizedBox(height: 24),
                      _AtRiskPanel(students: data['at_risk_students']),
                    ],
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _KPIMetricRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDesktop;
  const _KPIMetricRow({required this.data, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final mean = (data['mean'] as num?)?.toStringAsFixed(1) ?? '0.0';
    final median = (data['median'] as num?)?.toStringAsFixed(1) ?? '0.0';
    final total = data['total_students']?.toString() ?? '0';

    final studentsList = (data['at_risk_students'] as List? ?? []);
    final seen = <dynamic>{};
    final uniqueAtRiskCount = studentsList
        .where((s) => seen.add(s['student_id'] ?? s['student_name']))
        .length;

    final cards = [
      _KPICard(
        title: 'Class Average',
        value: '$mean%',
        subtitle: 'Overall Mean Score',
        icon: Icons.show_chart_rounded,
        iconColor: AppColors.primaryIndigo,
        bgColor: AppColors.primaryIndigo.withOpacity(0.08),
      ),
      _KPICard(
        title: 'Median Score',
        value: '$median%',
        subtitle: '50th Percentile Benchmark',
        icon: Icons.equalizer_rounded,
        iconColor: AppColors.accentCyan,
        bgColor: AppColors.accentCyan.withOpacity(0.08),
      ),
      _KPICard(
        title: 'Total Enrolled',
        value: total,
        subtitle: 'Active Cohort Students',
        icon: Icons.groups_rounded,
        iconColor: AppColors.primaryViolet,
        bgColor: AppColors.primaryViolet.withOpacity(0.08),
      ),
      _KPICard(
        title: 'At-Risk Students',
        value: uniqueAtRiskCount.toString(),
        subtitle:
            uniqueAtRiskCount == 0 ? 'Optimal Status' : 'Requires Intervention',
        icon: Icons.warning_amber_rounded,
        iconColor: uniqueAtRiskCount == 0
            ? AppColors.successGreen
            : AppColors.dangerRose,
        bgColor: (uniqueAtRiskCount == 0
                ? AppColors.successGreen
                : AppColors.dangerRose)
            .withOpacity(0.08),
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards
            .map((card) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: card,
                  ),
                ))
            .toList()
          ..last = Expanded(child: cards.last),
      );
    } else {
      return LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 600 ? 2 : 1;
          final width = columns == 1
              ? constraints.maxWidth
              : (constraints.maxWidth - 16) / 2;
          return Wrap(
            runSpacing: 16,
            spacing: 16,
            children:
                cards.map((c) => SizedBox(width: width, child: c)).toList(),
          );
        },
      );
    }
  }
}

class _KPICard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;

  const _KPICard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return ProfCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value,
                    style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistogramPanel extends StatelessWidget {
  final List<dynamic> data;
  const _HistogramPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final barGroups = data.asMap().entries.map((e) {
      final idx = e.key;
      final bucket = e.value;
      final count = (bucket['count'] as num).toDouble();
      return BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: count,
            gradient: AppGradients.primaryButton,
            width: 36,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
        ],
        showingTooltipIndicators: count > 0 ? [0] : [],
      );
    }).toList();

    return ProfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Grade Distribution',
              style: GoogleFonts.outfit(
                  fontSize: 20, fontWeight: FontWeight.w600)),
          Text('Normal curve & student frequency analysis',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barGroups: barGroups,
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < data.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(data[idx]['label'],
                                style: GoogleFonts.inter(
                                    fontSize: 12, fontWeight: FontWeight.w500)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (val, meta) => Text('${val.toInt()}',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ),
                  ),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) =>
                        FlLine(color: AppColors.border, strokeWidth: 0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPanel extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RadarPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    // Shorten long key titles for radar display to prevent clipping
    String shortenLabel(String name) {
      if (name.length > 12) {
        final words = name.split(' ');
        if (words.length > 1) {
          return '${words[0]}\n${words.skip(1).join(' ')}'; // Split into 2 lines
        }
        return '${name.substring(0, 10)}..';
      }
      return name;
    }

    return ProfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rubric Competency',
              style: GoogleFonts.outfit(
                  fontSize: 20, fontWeight: FontWeight.w600)),
          Text('Learning Outcome Mastery',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          if (data.keys.length < 3)
            const SizedBox(
              height: 250,
              child: Center(
                  child: Text('Add more criteria to render radar chart.',
                      style: TextStyle(color: AppColors.textSecondary))),
            )
          else
            SizedBox(
              height: 250,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: RadarChart(
                  RadarChartData(
                    radarShape: RadarShape.polygon,
                    tickCount: 4,
                    ticksTextStyle: const TextStyle(color: Colors.transparent),
                    titlePositionPercentageOffset: 0.15,
                    getTitle: (index, angle) => RadarChartTitle(
                      text: shortenLabel(data.keys.elementAt(index)),
                      angle: 0,
                    ),
                    dataSets: [
                      RadarDataSet(
                        fillColor: AppColors.primaryIndigo.withOpacity(0.20),
                        borderColor: AppColors.primaryIndigo,
                        borderWidth: 2,
                        entryRadius: 4,
                        dataEntries: data.values
                            .map(
                                (v) => RadarEntry(value: (v as num).toDouble()))
                            .toList(),
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
}

class _WeightagePanel extends StatelessWidget {
  final Map<String, dynamic> data;
  const _WeightagePanel({required this.data});

  @override
  Widget build(BuildContext context) {
    return ProfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Assessment Weightage',
              style: GoogleFonts.outfit(
                  fontSize: 20, fontWeight: FontWeight.w600)),
          Text('Grading breakdown policy',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          AssessmentWeightageDonut(
            quiz: data['quiz_weight'],
            assignment: data['assignment_weight'],
            midterm: data['midterm_weight'],
            finalExam: data['final_weight'],
          ),
        ],
      ),
    );
  }
}

class _AtRiskPanel extends StatelessWidget {
  final List<dynamic> students;
  const _AtRiskPanel({required this.students});

  @override
  Widget build(BuildContext context) {
    final seen = <dynamic>{};
    final uniqueStudents = students.where((s) {
      final key = s['student_id'] ?? s['student_name'];
      return seen.add(key);
    }).toList();

    return ProfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('At-Risk Students',
                  style: GoogleFonts.outfit(
                      fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: AppColors.dangerRose.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('ACTION REQUIRED',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dangerRose)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (uniqueStudents.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No students currently at risk ✅',
                    style: TextStyle(
                        color: AppColors.successGreen,
                        fontWeight: FontWeight.w500)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: uniqueStudents.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final s = uniqueStudents[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AvatarHelper.colorFor(s['student_name']),
                    radius: 18,
                    child: Text(AvatarHelper.initialsFor(s['student_name']),
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                  title: Text(s['student_name'],
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(s['reason'],
                      style: GoogleFonts.inter(
                          color: AppColors.dangerRose, fontSize: 12)),
                  trailing: Text(
                    '${(s['average_score'] as num).toStringAsFixed(1)}%',
                    style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dangerRose),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _TrendPanel extends StatelessWidget {
  final List<dynamic> data;
  const _TrendPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    return ProfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cohort Trend',
              style: GoogleFonts.outfit(
                  fontSize: 20, fontWeight: FontWeight.w600)),
          Text('Average student progression over time',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          if (data.isEmpty)
            const SizedBox(
              height: 250,
              child: Center(
                  child: Text('Not enough data for trend line.',
                      style: TextStyle(color: AppColors.textSecondary))),
            )
          else
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) =>
                        FlLine(color: AppColors.border, strokeWidth: 0.5),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: data.length > 5
                            ? (data.length / 5).ceilToDouble()
                            : 1.0,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx >= 0 && idx < data.length) {
                            String title = data[idx]['assignment_title'] ?? '';
                            // Shorten common words to prevent overlap
                            title = title.replaceAll(
                                RegExp(r'Assignment', caseSensitive: false),
                                'Asg');
                            title = title.replaceAll(
                                RegExp(r'Quiz', caseSensitive: false), 'Qz');
                            title = title.replaceAll(
                                RegExp(r'Midterm', caseSensitive: false),
                                'Mid');
                            if (title.length > 8)
                              title = '${title.substring(0, 6)}..';

                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(title,
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (val, meta) => Text('${val.toInt()}%',
                            style: GoogleFonts.inter(
                                fontSize: 10, color: AppColors.textSecondary)),
                      ),
                    ),
                    topTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  minY: 0,
                  maxY: 100,
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: data
                          .asMap()
                          .entries
                          .map((e) => FlSpot(e.key.toDouble(),
                              (e.value['average_score'] as num).toDouble()))
                          .toList(),
                      isCurved: true,
                      color: AppColors.primaryIndigo,
                      barWidth: 3.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryIndigo.withOpacity(0.25),
                            AppColors.primaryIndigo.withOpacity(0.01),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
