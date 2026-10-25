import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/app_store.dart';
import '../services/report_period.dart';
import '../widgets/app_widgets.dart';
import 'report_detail_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key, required this.store});
  final AppStore store;

  static const _icons = <ReportPeriod, IconData>{
    ReportPeriod.today: Icons.today_rounded,
    ReportPeriod.week: Icons.date_range_rounded,
    ReportPeriod.month: Icons.calendar_month_rounded,
    ReportPeriod.year: Icons.event_note_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 720;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: EdgeInsets.fromLTRB(narrow ? 16 : 28, 26, narrow ? 16 : 28, 32),
          children: [
            const PageHeading(
              title: 'Reports',
              subtitle: 'Select a period to view, save, or print its records.'),
            const SizedBox(height: 22),
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 690 ? 2 : 1;
              return GridView.builder(
                itemCount: ReportPeriod.values.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  mainAxisExtent: 124,
                ),
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final period = ReportPeriod.values[index];
                  return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) =>
                              ReportDetailScreen(store: store, period: period))),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.border)),
                          child: Row(children: [
                            Container(
                              width: 58, height: 58,
                              decoration: BoxDecoration(
                                color: AppColors.lightTeal,
                                borderRadius: BorderRadius.circular(17)),
                              child: Icon(_icons[period], color: AppColors.teal, size: 30)),
                            const SizedBox(width: 17),
                            Expanded(child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(period.label,
                                  style: const TextStyle(color: AppColors.navy,
                                      fontWeight: FontWeight.w900, fontSize: 18)),
                                const SizedBox(height: 5),
                                const Text('View records & print',
                                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
                              ],
                            )),
                            const Icon(Icons.arrow_forward_ios_rounded,
                              color: AppColors.muted, size: 17),
                          ]),
                        ),
                      ),
                    );
                },
              );
            }),
            const SizedBox(height: 19),
            const Text('Reports use the date orders were registered. They show recorded '
                'order values, not verified payments.',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
