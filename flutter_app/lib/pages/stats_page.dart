import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  bool _showIncome = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadMonthlyStats(
        year: _selectedYear,
        month: _selectedMonth,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await context.read<TransactionProvider>().loadMonthlyStats(
                year: _selectedYear,
                month: _selectedMonth,
              );
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '统计',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        _MonthButton(
                          icon: Icons.chevron_left,
                          onTap: () {
                            setState(() {
                              _selectedMonth--;
                              if (_selectedMonth == 0) {
                                _selectedMonth = 12;
                                _selectedYear--;
                              }
                            });
                            context.read<TransactionProvider>().loadMonthlyStats(
                              year: _selectedYear,
                              month: _selectedMonth,
                            );
                          },
                        ),
                        Text(
                          '${_selectedYear}年${_selectedMonth}月',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        _MonthButton(
                          icon: Icons.chevron_right,
                          onTap: () {
                            setState(() {
                              final now = DateTime.now();
                              if (_selectedYear == now.year && _selectedMonth == now.month) return;
                              _selectedMonth++;
                              if (_selectedMonth == 13) {
                                _selectedMonth = 1;
                                _selectedYear++;
                              }
                            });
                            context.read<TransactionProvider>().loadMonthlyStats(
                              year: _selectedYear,
                              month: _selectedMonth,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 收入/支出切换
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showIncome = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _showIncome ? Colors.transparent : AppTheme.expense,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Text('支出', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showIncome = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _showIncome ? AppTheme.income : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Text('收入', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // 环形图
            SliverToBoxAdapter(
              child: Consumer<TransactionProvider>(
                builder: (_, tx, __) {
                  if (tx.loading && tx.monthlyStats == null) {
                    return const SizedBox(
                      height: 260,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final stats = tx.monthlyStats;
                  if (stats == null) {
                    return const SizedBox(
                      height: 260,
                      child: EmptyState(icon: '📊', message: '暂无数据'),
                    );
                  }

                  final catStats = (stats['categoryStats'] as List?) ?? [];
                  final filtered = catStats
                      .where((c) => c['type'] == (_showIncome ? 'income' : 'expense'))
                      .toList();

                  if (filtered.isEmpty) {
                    return SizedBox(
                      height: 260,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_showIncome ? '💵' : '💸', style: const TextStyle(fontSize: 48)),
                            const SizedBox(height: 8),
                            const Text('该月暂无记录', style: TextStyle(color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    );
                  }

                  final colors = [
                    AppTheme.primary, AppTheme.secondary, AppTheme.expense,
                    AppTheme.income, const Color(0xFFFFD93D), const Color(0xFF6BCB77),
                    const Color(0xFF4D96FF), const Color(0xFFFF6B6B),
                  ];

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: GlassCard(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 180,
                            child: PieChart(
                              PieChartData(
                                sections: filtered.asMap().entries.map((e) {
                                  final total = filtered.fold<double>(
                                    0, (sum, c) => sum + (c['amount'] as num).toDouble());
                                  final pct = total > 0
                                      ? ((e.value['amount'] as num).toDouble() / total * 100)
                                      : 0;
                                  return PieChartSectionData(
                                    color: colors[e.key % colors.length],
                                    value: pct,
                                    title: pct > 5 ? '${pct.toStringAsFixed(0)}%' : '',
                                    radius: 50,
                                    titleStyle: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  );
                                }).toList(),
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // 图例
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: filtered.asMap().entries.map((e) {
                              final total = filtered.fold<double>(
                                0, (sum, c) => sum + (c['amount'] as num).toDouble());
                              final amount = (e.value['amount'] as num).toDouble();
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 10, height: 10,
                                    decoration: BoxDecoration(
                                      color: colors[e.key % colors.length],
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${e.value['categoryIcon']} ${e.value['categoryName']} ¥${amount.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

class _MonthButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MonthButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 22, color: AppTheme.primary),
        ),
      ),
    );
  }
}
