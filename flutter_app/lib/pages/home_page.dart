import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'add_transaction_page.dart';
import 'stats_page.dart';
import 'import_page.dart';
import 'settings_page.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentTab = 0;

  final _pages = <Widget>[
    const _HomeTab(),
    const StatsPage(),
    const ImportPage(),
    const SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tx = context.read<TransactionProvider>();
      tx.loadCategories();
      tx.loadTransactions(refresh: true);
      tx.loadMonthlyStats();
    });
  }

  void _showAddTransaction() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddTransactionPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentTab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined, size: 28), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined, size: 28), label: '统计'),
          BottomNavigationBarItem(icon: Icon(Icons.download_outlined, size: 28), label: '导入'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline, size: 28), label: '我的'),
        ],
      ),
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton(
              onPressed: _showAddTransaction,
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            )
          : null,
    );
  }
}

// ===================== 首页 Tab =====================
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          final tx = context.read<TransactionProvider>();
          await Future.wait([
            tx.loadTransactions(refresh: true),
            tx.loadMonthlyStats(),
            tx.loadCategories(),
          ]);
        },
        child: CustomScrollView(
          slivers: [
            // 顶部标题
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Consumer<AuthProvider>(
                      builder: (_, auth, __) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '你好, ${auth.user?.username ?? ''} 👋',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const Text(
                            '今天也要好好记账哦~',
                            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 本月概览卡片
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Consumer<TransactionProvider>(
                  builder: (_, tx, __) {
                    final stats = tx.monthlyStats;
                    final income = stats?['income'] ?? 0.0;
                    final expense = stats?['expense'] ?? 0.0;
                    final balance = stats?['balance'] ?? 0.0;

                    return GlassCard(
                      child: Column(
                        children: [
                          const Text(
                            '本月概览',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '¥${balance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _StatItem(
                                  label: '收入',
                                  amount: income,
                                  color: AppTheme.income,
                                ),
                              ),
                              Container(width: 1, height: 40, color: AppTheme.divider),
                              Expanded(
                                child: _StatItem(
                                  label: '支出',
                                  amount: expense,
                                  color: AppTheme.expense,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // 最近账单标题
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '最近账单',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Consumer<TransactionProvider>(
                      builder: (_, tx, __) {
                        if (tx.transactions.isEmpty) return const SizedBox.shrink();
                        return TextButton(
                          onPressed: () {},
                          child: const Text('查看全部', style: TextStyle(color: AppTheme.primary)),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // 账单列表
            Consumer<TransactionProvider>(
              builder: (_, tx, __) {
                if (tx.loading && tx.transactions.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (tx.transactions.isEmpty) {
                  return const SliverFillRemaining(
                    child: EmptyState(icon: '📖', message: '今天还没记账哦~'),
                  );
                }

                // 按日期分组
                final grouped = <String, List>{};
                for (final t in tx.transactions) {
                  final date = DateFormat('MM月dd日').format(t.transactionDate);
                  grouped.putIfAbsent(date, () => []).add(t);
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final date = grouped.keys.elementAt(index);
                      final items = grouped[date]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                            child: Text(
                              date,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          ...items.map((t) => TransactionCard(
                                icon: t.categoryIcon ?? '📦',
                                categoryName: t.categoryName ?? '未分类',
                                note: t.note,
                                amount: t.formattedAmount,
                                isIncome: t.type == 'income',
                                onDelete: () => tx.deleteTransaction(t.id),
                              )),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                    childCount: grouped.length,
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _StatItem({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Text(
          '¥${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
