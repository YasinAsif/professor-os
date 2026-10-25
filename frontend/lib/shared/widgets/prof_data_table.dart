import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import 'prof_button.dart';

class ProfColumn {
  final String label;
  final double? width;
  final int flex;
  final Alignment alignment;

  const ProfColumn({
    required this.label,
    this.width,
    this.flex = 1,
    this.alignment = Alignment.centerLeft,
  });
}

class ProfDataTable extends StatelessWidget {
  final List<ProfColumn> columns;
  final List<List<Widget>> rows;
  final bool isLoading;
  final Widget? emptyState;
  final int currentPage;
  final int totalPages;
  final ValueChanged<int>? onPageChanged;
  final int? totalItems;

  const ProfDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.isLoading = false,
    this.emptyState,
    this.currentPage = 1,
    this.totalPages = 1,
    this.onPageChanged,
    this.totalItems,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ruleColor = isDark ? AppColors.rule : AppColorsLight.rule;
    final headerBg = isDark ? AppColors.surfaceMid.withOpacity(0.5) : AppColorsLight.surfaceMid;
    final rowHoverBg = isDark ? AppColors.surfaceMid.withOpacity(0.3) : const Color(0xFFF8FAFC);
    final headerTextColor = isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : AppColorsLight.surface,
        borderRadius: BorderRadius.circular(AppRadius.r8),
        border: Border.all(color: ruleColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.r8),
                topRight: Radius.circular(AppRadius.r8),
              ),
              border: Border(bottom: BorderSide(color: ruleColor, width: 1)),
            ),
            child: Row(
              children: columns.map((col) {
                final child = Align(
                  alignment: col.alignment,
                  child: Text(
                    col.label.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: headerTextColor,
                    ),
                  ),
                );
                return col.width != null
                    ? SizedBox(width: col.width, child: child)
                    : Expanded(flex: col.flex, child: child);
              }).toList(),
            ),
          ),

          // Content / Loading / Empty
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else if (rows.isEmpty)
            emptyState ??
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No records found.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? AppColors.inkGhost : AppColorsLight.inkGhost,
                      ),
                    ),
                  ),
                )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rows.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: ruleColor),
              itemBuilder: (context, rowIndex) {
                final cells = rows[rowIndex];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: rowIndex % 2 == 1 ? rowHoverBg : Colors.transparent,
                  child: Row(
                    children: List.generate(columns.length, (colIndex) {
                      final col = columns[colIndex];
                      final cellWidget = colIndex < cells.length
                          ? cells[colIndex]
                          : const SizedBox.shrink();
                      final aligned = Align(
                        alignment: col.alignment,
                        child: cellWidget,
                      );
                      return col.width != null
                          ? SizedBox(width: col.width, child: aligned)
                          : Expanded(flex: col.flex, child: aligned);
                    }),
                  ),
                );
              },
            ),

          // Pagination Bar
          if (totalPages > 1 || totalItems != null) ...[
            Divider(height: 1, color: ruleColor),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    totalItems != null
                        ? 'Total: $totalItems item${totalItems == 1 ? '' : 's'}'
                        : 'Page $currentPage of $totalPages',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary,
                    ),
                  ),
                  Row(
                    children: [
                      ProfButton(
                        label: 'Previous',
                        size: ProfButtonSize.sm,
                        variant: ProfButtonVariant.ghost,
                        icon: Icons.chevron_left_rounded,
                        onPressed: currentPage > 1 && onPageChanged != null
                            ? () => onPageChanged!(currentPage - 1)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$currentPage / $totalPages',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.inkPrimary : AppColorsLight.inkPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ProfButton(
                        label: 'Next',
                        size: ProfButtonSize.sm,
                        variant: ProfButtonVariant.ghost,
                        trailingIcon: Icons.chevron_right_rounded,
                        onPressed: currentPage < totalPages && onPageChanged != null
                            ? () => onPageChanged!(currentPage + 1)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
