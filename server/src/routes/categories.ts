import { Router } from 'express';
import { prisma } from '../db';
import { authMiddleware } from '../middleware/auth';

export const categoryRouter = Router();
categoryRouter.use(authMiddleware);

// 获取分类列表
categoryRouter.get('/', async (req, res, next) => {
  try {
    const categories = await prisma.category.findMany({
      where: { userId: req.userId },
      orderBy: [
        { type: 'asc' },
        { sortOrder: 'asc' },
      ],
    });
    res.json({ categories });
  } catch (err) {
    next(err);
  }
});

// 创建自定义分类
categoryRouter.post('/', async (req, res, next) => {
  try {
    const { name, icon, type, sortOrder } = req.body;
    if (!name || !type) {
      return res.status(400).json({ error: '分类名称和类型不能为空' });
    }
    if (!['income', 'expense'].includes(type)) {
      return res.status(400).json({ error: '类型必须是 income 或 expense' });
    }

    const maxOrder = await prisma.category.findFirst({
      where: { userId: req.userId, type },
      orderBy: { sortOrder: 'desc' },
    });

    const category = await prisma.category.create({
      data: {
        userId: req.userId,
        name,
        icon: icon || '📦',
        type,
        sortOrder: sortOrder ?? (maxOrder ? maxOrder.sortOrder + 1 : 1),
      },
    });
    res.status(201).json({ category });
  } catch (err) {
    next(err);
  }
});

// 修改分类
categoryRouter.put('/:id', async (req, res, next) => {
  try {
    const { name, icon, sortOrder } = req.body;
    const category = await prisma.category.findFirst({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!category) {
      return res.status(404).json({ error: '分类未找到' });
    }

    const updated = await prisma.category.update({
      where: { id: req.params.id },
      data: {
        ...(name !== undefined && { name }),
        ...(icon !== undefined && { icon }),
        ...(sortOrder !== undefined && { sortOrder }),
      },
    });
    res.json({ category: updated });
  } catch (err) {
    next(err);
  }
});

// 删除分类
categoryRouter.delete('/:id', async (req, res, next) => {
  try {
    const category = await prisma.category.findFirst({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!category) {
      return res.status(404).json({ error: '分类未找到' });
    }

    // 检查分类下是否有账单
    const count = await prisma.transaction.count({
      where: { categoryId: req.params.id },
    });
    if (count > 0) {
      return res.status(400).json({
        error: `该分类下有 ${count} 条账单记录，请先删除或转移这些记录`,
      });
    }

    await prisma.category.delete({ where: { id: req.params.id } });
    res.json({ message: '删除成功' });
  } catch (err) {
    next(err);
  }
});
