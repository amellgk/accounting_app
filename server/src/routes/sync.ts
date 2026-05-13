import { Router } from 'express';
import { prisma } from '../db';
import { authMiddleware } from '../middleware/auth';

export const syncRouter = Router();
syncRouter.use(authMiddleware);

// 批量同步（上传离线期间创建的记录）
syncRouter.post('/', async (req, res, next) => {
  try {
    const { transactions } = req.body;
    if (!transactions || !Array.isArray(transactions)) {
      return res.status(400).json({ error: '请提供 transactions 数组' });
    }

    const results = { created: [], skipped: [], errors: [] };

    for (const t of transactions) {
      try {
        // 检查是否已存在（通过 id 去重）
        const existing = await prisma.transaction.findUnique({
          where: { id: t.id },
        });

        if (existing) {
          // 已存在，检查版本冲突
          if ((t.syncVersion || 1) >= existing.syncVersion) {
            await prisma.transaction.update({
              where: { id: t.id },
              data: {
                amount: t.amount,
                categoryId: t.categoryId,
                note: t.note,
                type: t.type,
                transactionDate: new Date(t.transactionDate),
                syncVersion: existing.syncVersion + 1,
              },
            });
            results.created.push(t.id);
          } else {
            results.skipped.push(t.id);
          }
        } else {
          // 验证分类存在
          const cat = await prisma.category.findFirst({
            where: { id: t.categoryId, userId: req.userId },
          });
          if (!cat) {
            results.errors.push({ id: t.id, error: '分类不存在' });
            continue;
          }

          await prisma.transaction.create({
            data: {
              id: t.id,
              userId: req.userId,
              categoryId: t.categoryId,
              type: t.type,
              amount: t.amount,
              note: t.note || '',
              transactionDate: new Date(t.transactionDate),
              syncVersion: t.syncVersion || 1,
            },
          });
          results.created.push(t.id);
        }
      } catch (e) {
        results.errors.push({ id: t.id, error: e.message });
      }
    }

    res.json(results);
  } catch (err) {
    next(err);
  }
});

// 获取云端全部数据（用于首次同步到新设备）
syncRouter.get('/full', async (req, res, next) => {
  try {
    const [categories, transactions] = await Promise.all([
      prisma.category.findMany({ where: { userId: req.userId } }),
      prisma.transaction.findMany({
        where: { userId: req.userId },
        orderBy: { updatedAt: 'desc' },
      }),
    ]);

    res.json({ categories, transactions });
  } catch (err) {
    next(err);
  }
});
