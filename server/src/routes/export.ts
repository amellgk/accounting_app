import { Router } from 'express';
import { parse as csvParse } from 'csv-parse/sync';
import { prisma } from '../db';
import { authMiddleware } from '../middleware/auth';

export const exportRouter = Router();
exportRouter.use(authMiddleware);

// 导出 CSV
exportRouter.get('/csv', async (req, res, next) => {
  try {
    const { startDate, endDate } = req.query;

    const where = { userId: req.userId };
    if (startDate || endDate) {
      where.transactionDate = {};
      if (startDate) where.transactionDate.gte = new Date(startDate);
      if (endDate) where.transactionDate.lte = new Date(endDate);
    }

    const transactions = await prisma.transaction.findMany({
      where,
      include: { category: true },
      orderBy: { transactionDate: 'desc' },
    });

    const header = '日期,类型,分类,金额,备注\n';
    const rows = transactions.map(t => {
      const type = t.type === 'income' ? '收入' : '支出';
      const date = t.transactionDate.toISOString().split('T')[0];
      const note = (t.note || '').replace(/"/g, '""');
      return `${date},${type},${t.category.name},${t.amount},"${note}"`;
    }).join('\n');

    const csv = '\uFEFF' + header + rows; // BOM for Excel

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename=account_export_${Date.now()}.csv`);
    res.send(csv);
  } catch (err) {
    next(err);
  }
});

// 获取导入记录历史
exportRouter.get('/import-history', async (req, res, next) => {
  try {
    const records = await prisma.importRecord.findMany({
      where: { userId: req.userId },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
    res.json({ records });
  } catch (err) {
    next(err);
  }
});
