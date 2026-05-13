import { Router } from 'express';
import { prisma } from '../db';
import { authMiddleware } from '../middleware/auth';

export const statsRouter = Router();
statsRouter.use(authMiddleware);

// 月度统计
statsRouter.get('/monthly', async (req, res, next) => {
  try {
    const year = parseInt(req.query.year) || new Date().getFullYear();
    const month = parseInt(req.query.month) || (new Date().getMonth() + 1);

    const startDate = new Date(year, month - 1, 1);
    const endDate = new Date(year, month, 0, 23, 59, 59, 999);

    const transactions = await prisma.transaction.findMany({
      where: {
        userId: req.userId,
        transactionDate: { gte: startDate, lte: endDate },
      },
      include: { category: true },
    });

    const income = transactions
      .filter(t => t.type === 'income')
      .reduce((sum, t) => sum + t.amount, 0);

    const expense = transactions
      .filter(t => t.type === 'expense')
      .reduce((sum, t) => sum + t.amount, 0);

    // 分类统计
    const categoryStats = {};
    transactions.forEach(t => {
      const key = t.categoryId;
      if (!categoryStats[key]) {
        categoryStats[key] = {
          categoryId: t.categoryId,
          categoryName: t.category.name,
          categoryIcon: t.category.icon,
          type: t.type,
          amount: 0,
          count: 0,
        };
      }
      categoryStats[key].amount += t.amount;
      categoryStats[key].count += 1;
    });

    res.json({
      year,
      month,
      income: Math.round(income * 100) / 100,
      expense: Math.round(expense * 100) / 100,
      balance: Math.round((income - expense) * 100) / 100,
      totalCount: transactions.length,
      categoryStats: Object.values(categoryStats),
    });
  } catch (err) {
    next(err);
  }
});

// 年度统计
statsRouter.get('/yearly', async (req, res, next) => {
  try {
    const year = parseInt(req.query.year) || new Date().getFullYear();

    const startDate = new Date(year, 0, 1);
    const endDate = new Date(year, 11, 31, 23, 59, 59, 999);

    const transactions = await prisma.transaction.findMany({
      where: {
        userId: req.userId,
        transactionDate: { gte: startDate, lte: endDate },
      },
    });

    // 按月统计
    const monthlyData = {};
    for (let m = 1; m <= 12; m++) {
      monthlyData[m] = { month: m, income: 0, expense: 0 };
    }

    transactions.forEach(t => {
      const m = t.transactionDate.getMonth() + 1;
      if (t.type === 'income') {
        monthlyData[m].income += t.amount;
      } else {
        monthlyData[m].expense += t.amount;
      }
    });

    Object.values(monthlyData).forEach(d => {
      d.income = Math.round(d.income * 100) / 100;
      d.expense = Math.round(d.expense * 100) / 100;
    });

    const totalIncome = transactions
      .filter(t => t.type === 'income')
      .reduce((s, t) => s + t.amount, 0);
    const totalExpense = transactions
      .filter(t => t.type === 'expense')
      .reduce((s, t) => s + t.amount, 0);

    res.json({
      year,
      totalIncome: Math.round(totalIncome * 100) / 100,
      totalExpense: Math.round(totalExpense * 100) / 100,
      totalBalance: Math.round((totalIncome - totalExpense) * 100) / 100,
      monthlyData: Object.values(monthlyData),
    });
  } catch (err) {
    next(err);
  }
});
