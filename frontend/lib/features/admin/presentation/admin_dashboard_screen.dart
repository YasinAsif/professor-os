import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import 'user_management_screen.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Text('Administrator Dashboard',
            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.signal,
          labelColor: AppColors.signal,
          unselectedLabelColor: AppColors.inkSecondary,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'User Management'),
            Tab(text: 'Semesters'),
            Tab(text: 'HEC Guidelines'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          UserManagementTab(),
          AdminSemestersTab(),
          AdminHECTab(),
        ],
      ),
    );
  }
}

class AdminSemestersTab extends StatefulWidget {
  const AdminSemestersTab({super.key});
  @override
  State<AdminSemestersTab> createState() => _AdminSemestersTabState();
}

class _AdminSemestersTabState extends State<AdminSemestersTab> {
  final List<Map<String, dynamic>> _semesters = [
    {'name': 'Fall 2026', 'start': 'Sep 2026', 'end': 'Jan 2027', 'active': true},
    {'name': 'Spring 2027', 'start': 'Feb 2027', 'end': 'Jun 2027', 'active': false},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Academic Semesters', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w600)),
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    final nameCtrl = TextEditingController();
                    final startCtrl = TextEditingController();
                    final endCtrl = TextEditingController();
                    return AlertDialog(
                      title: const Text('Add Semester'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Semester Name')),
                          const SizedBox(height: 8),
                          TextField(controller: startCtrl, decoration: const InputDecoration(labelText: 'Start Month/Year')),
                          const SizedBox(height: 8),
                          TextField(controller: endCtrl, decoration: const InputDecoration(labelText: 'End Month/Year')),
                        ],
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _semesters.insert(0, {
                                'name': nameCtrl.text,
                                'start': startCtrl.text,
                                'end': endCtrl.text,
                                'active': false,
                              });
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    );
                  },
                );
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Semester'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryIndigo,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ..._semesters.map((s) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s['name'], style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('${s['start']} - ${s['end']}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkSecondary)),
                  ],
                ),
              ),
              Switch(
                value: s['active'],
                onChanged: (val) => setState(() => s['active'] = val),
                activeColor: AppColors.primaryIndigo,
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }
}

class AdminHECTab extends StatefulWidget {
  const AdminHECTab({super.key});
  @override
  State<AdminHECTab> createState() => _AdminHECTabState();
}

class _AdminHECTabState extends State<AdminHECTab> {
  double _creditLimit = 18;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('HEC Guidelines & Policies', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Maximum Credit Hours', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Limit the number of credits a student can take per semester.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkSecondary)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _creditLimit,
                      min: 12,
                      max: 24,
                      divisions: 12,
                      label: '${_creditLimit.toInt()} Credits',
                      onChanged: (val) => setState(() => _creditLimit = val),
                    ),
                  ),
                  Text('${_creditLimit.toInt()} Credits', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Standard Grading Curve', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Enforce university-wide grading thresholds.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkSecondary)),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Absolute Grading'),
                trailing: const Icon(Icons.check_circle, color: AppColors.successGreen),
                tileColor: AppColors.successGreen.withOpacity(0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('Relative Grading (Bell Curve)'),
                trailing: const Icon(Icons.radio_button_unchecked),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
