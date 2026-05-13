import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  bool _importing = false;

  Future<void> _import(String source) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.single.path == null) return;

    setState(() => _importing = true);

    try {
      final api = context.read<ApiService>();
      final data = await api.importFile(source, result.files.single.path!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 共 ${data['total']} 条，成功导入 ${data['imported']} 条'),
            backgroundColor: AppTheme.income,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 导入失败: $e'),
            backgroundColor: AppTheme.expense,
          ),
        );
      }
    }

    setState(() => _importing = false);
  }

  Future<void> _export() async {
    try {
      final api = context.read<ApiService>();
      final csv = await api.exportCsv();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 导出成功！文件已保存到下载目录'),
            backgroundColor: AppTheme.income,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 导出失败: $e'),
            backgroundColor: AppTheme.expense,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              '数据导入导出',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const Text(
            '支持导入支付宝和微信支付的 CSV 账单文件，系统会自动识别分类。',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),

          // 导入支付宝
          _ImportCard(
            icon: '💳',
            title: '导入支付宝账单',
            subtitle: '支持支付宝 CSV 格式',
            color: const Color(0xFF1677FF),
            loading: _importing,
            onTap: () => _import('alipay'),
          ),
          const SizedBox(height: 12),

          // 导入微信
          _ImportCard(
            icon: '💬',
            title: '导入微信账单',
            subtitle: '支持微信支付 CSV 格式',
            color: const Color(0xFF07C160),
            loading: _importing,
            onTap: () => _import('wechat'),
          ),
          const SizedBox(height: 24),

          const Divider(),
          const SizedBox(height: 16),

          // 导出
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _export,
              icon: const Icon(Icons.download),
              label: const Text('导出账单 CSV'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // 使用说明
          const Text(
            '使用说明',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const _TipItem('1. 打开支付宝/微信，进入账单页面'),
          const _TipItem('2. 选择"导出账单"，格式选 CSV'),
          const _TipItem('3. 选择时间范围，导出文件'),
          const _TipItem('4. 点击上方按钮选择文件导入'),
          const _TipItem('5. 系统会自动匹配分类，导入后可手动调整'),
        ],
      ),
    );
  }
}

class _ImportCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _ImportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 28))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.upload_file, color: AppTheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  final String text;
  const _TipItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(text, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
    );
  }
}
