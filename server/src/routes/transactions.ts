import { Router } from 'express';
import { prisma } from '../db';
import { authMiddleware } from '../middleware/auth';

export const transactionRouter = Router();
transactionRouter.use(authMiddleware);

// 获取账单列表
transactionRouter.get('/', async (req, res, next) => {
  try {
    const {
      page = '1',
      limit = '20',
      type,
      categoryId,
      startDate,
      endDate,
      search,
    } = req.query;

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const take = parseInt(limit);

    const where = { userId: req.userId };

    if (type) where.type = type;
    if (categoryId) where.categoryId = categoryId;
    if (startDate || endDate) {
      where.transactionDate = {};
      if (startDate) where.transactionDate.gte = new Date(startDate);
      if (endDate) where.transactionDate.lte = new Date(endDate);
    }
    if (search) {
      where.note = { contains: search };
    }

    const [transactions, total] = await Promise.all([
      prisma.transaction.findMany({
        where,
        include: { category: true },
        orderBy: { transactionDate: 'desc' },
        skip,
        take,
      }),
      prisma.transaction.count({ where }),
    ]);

    res.json({
      transactions,
      pagination: {
        page: parseInt(page),
        limit: take,
        total,
        totalPages: Math.ceil(total / take),
      },
    });
  } catch (err) {
    next(err);
  }
});

// 新增账单
transactionRouter.post('/', async (req, res, next) => {
  try {
    const { categoryId, type, amount, note, transactionDate } = req.body;

    if (!categoryId || !type || amount === undefined) {
      return res.status(400).json({ error: '分类、类型和金额不能为空' });
    }
    if (!['income', 'expense'].includes(type)) {
      return res.status(400).json({ error: '类型必须是 income 或 expense' });
    }
    if (amount <= 0) {
      return res.status(400).json({ error: '金额必须大于0' });
    }

    // 验证分类属于当前用户
    const category = await prisma.category.findFirst({
      where: { id: categoryId, userId: req.userId },
    });
    if (!category) {
      return res.status(404).json({ error: '分类未找到' });
    }

    const transaction = await prisma.transaction.create({
      data: {
        userId: req.userId,
        categoryId,
        type,
        amount: Math.round(amount * 100) / 100,
        note: note || '',
        transactionDate: transactionDate ? new Date(transactionDate) : new Date(),
      },
      include: { category: true },
    });

    res.status(201).json({ transaction });
  } catch (err) {
    next(err);
  }
});

// 修改账单
transactionRouter.put('/:id', async (req, res, next) => {
  try {
    const existing = await prisma.transaction.findFirst({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!existing) {
      return res.status(404).json({ error: '账单记录未找到' });
    }

    const { categoryId, type, amount, note, transactionDate } = req.body;

    const data = {};
    if (categoryId !== undefined) {
      const cat = await prisma.category.findFirst({
        where: { id: categoryId, userId: req.userId },
      });
      if (!cat) return res.status(404).json({ error: '分类未找到' });
      data.categoryId = categoryId;
    }
    if (type !== undefined) {
      if (!['income', 'expense'].includes(type)) {
        return res.status(400).json({ error: '类型必须是 income 或 expense' });
      }
      data.type = type;
    }
    if (amount !== undefined) {
      if (amount <= 0) return res.status(400).json({ error: '金额必须大于0' });
      data.amount = Math.round(amount * 100) / 100;
    }
    if (note !== undefined) data.note = note;
    if (transactionDate !== undefined) data.transactionDate = new Date(transactionDate);

    const transaction = await prisma.transaction.update({
      where: { id: req.params.id },
      data,
      include: { category: true },
    });

    res.json({ transaction });
  } catch (err) {
    next(err);
  }
});

// 删除账单
transactionRouter.delete('/:id', async (req, res, next) => {
  try {
    const existing = await prisma.transaction.findFirst({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!existing) {
      return res.status(404).json({ error: '账单记录未找到' });
    }

    await prisma.transaction.delete({ where: { id: req.params.id } });
    res.json({ message: '删除成功' });
  } catch (err) {
    next(err);
  }
});
