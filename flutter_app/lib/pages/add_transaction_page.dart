import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'home_page.dart';

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({super.key});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _selectedType = 'expense';
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择分类')),
      );
      return;
    }

    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效金额')),
      );
      return;
    }

    final tx = context.read<TransactionProvider>();
    final success = await tx.addTransaction(
      categoryId: _selectedCategoryId!,
      type: _selectedType,
      amount: amount,
      note: _noteCtrl.text.trim(),
      transactionDate: _selectedDate.toIso8601String().split('T')[0],
    );

    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 记账成功！'),
          backgroundColor: AppTheme.income,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ ${tx.error ?? '记账失败'}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('记一笔'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 收支切换
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedType = 'expense';
                          _selectedCategoryId = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedType == 'expense'
                                ? AppTheme.expense
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text(
                              '支出',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedType = 'income';
                          _selectedCategoryId = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedType == 'income'
                                ? AppTheme.income
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text(
                              '收入',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 金额输入
              AmountInput(
                controller: _amountCtrl,
                isIncome: _selectedType == 'income',
              ),
              const SizedBox(height: 24),

              // 日期
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _selectedDate = date);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20, color: AppTheme.textSecondary),
                      const SizedBox(width: 12),
                      Text(
                        '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日',
                        style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 分类选择
              const Text(
                '选择分类',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              Consumer<TransactionProvider>(
                builder: (_, tx, __) {
                  final cats = _selectedType == 'expense'
                      ? tx.expenseCategories
                      : tx.incomeCategories;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: cats.length,
                    itemBuilder: (context, index) {
                      final cat = cats[index];
                      return CategoryChip(
                        icon: cat.icon,
                        name: cat.name,
                        selected: _selectedCategoryId == cat.id,
                        onTap: () => setState(() => _selectedCategoryId = cat.id),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),

              // 备注
              TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  hintText: '添加备注...',
                  prefixIcon: Icon(Icons.edit_note),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
