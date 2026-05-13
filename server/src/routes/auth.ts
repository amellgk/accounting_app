import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { prisma } from '../db';
import { generateToken, JWT_SECRET } from '../middleware/auth';
import jwt from 'jsonwebtoken';

export const authRouter = Router();

// 注册
authRouter.post('/register', async (req, res, next) => {
  try {
    const { username, password } = req.body;
    
    if (!username || !password) {
      return res.status(400).json({ error: '用户名和密码不能为空' });
    }
    if (username.length < 2) {
      return res.status(400).json({ error: '用户名至少2个字符' });
    }
    if (password.length < 6) {
      return res.status(400).json({ error: '密码至少6个字符' });
    }

    const existing = await prisma.user.findUnique({ where: { username } });
    if (existing) {
      return res.status(409).json({ error: '用户名已存在' });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const user = await prisma.user.create({
      data: { username, passwordHash },
    });

    // 为新用户创建默认分类
    const defaultCategories = [
      { name: '餐饮', icon: '🍔', type: 'expense', sortOrder: 1 },
      { name: '交通', icon: '🚌', type: 'expense', sortOrder: 2 },
      { name: '购物', icon: '🛍️', type: 'expense', sortOrder: 3 },
      { name: '住房', icon: '🏠', type: 'expense', sortOrder: 4 },
      { name: '娱乐', icon: '🎮', type: 'expense', sortOrder: 5 },
      { name: '通讯', icon: '📱', type: 'expense', sortOrder: 6 },
      { name: '医疗', icon: '💊', type: 'expense', sortOrder: 7 },
      { name: '教育', icon: '📚', type: 'expense', sortOrder: 8 },
      { name: '日用', icon: '🧴', type: 'expense', sortOrder: 9 },
      { name: '服饰', icon: '👔', type: 'expense', sortOrder: 10 },
      { name: '其他支出', icon: '💸', type: 'expense', sortOrder: 99 },
      { name: '工资', icon: '💰', type: 'income', sortOrder: 1 },
      { name: '红包', icon: '🧧', type: 'income', sortOrder: 2 },
      { name: '理财', icon: '📈', type: 'income', sortOrder: 3 },
      { name: '兼职', icon: '💼', type: 'income', sortOrder: 4 },
      { name: '其他收入', icon: '💵', type: 'income', sortOrder: 99 },
    ];

    await prisma.category.createMany({
      data: defaultCategories.map(c => ({ ...c, userId: user.id })),
    });

    const token = generateToken(user.id);
    res.status(201).json({ token, user: { id: user.id, username: user.username } });
  } catch (err) {
    next(err);
  }
});

// 登录
authRouter.post('/login', async (req, res, next) => {
  try {
    const { username, password } = req.body;
    
    if (!username || !password) {
      return res.status(400).json({ error: '用户名和密码不能为空' });
    }

    const user = await prisma.user.findUnique({ where: { username } });
    if (!user) {
      return res.status(401).json({ error: '用户名或密码错误' });
    }

    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) {
      return res.status(401).json({ error: '用户名或密码错误' });
    }

    const token = generateToken(user.id);
    res.json({ token, user: { id: user.id, username: user.username } });
  } catch (err) {
    next(err);
  }
});

// 获取当前用户信息
authRouter.get('/me', async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader) return res.status(401).json({ error: '未登录' });
    
    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, JWT_SECRET);
    const user = await prisma.user.findUnique({ where: { id: decoded.userId } });
    if (!user) return res.status(404).json({ error: '用户不存在' });
    
    res.json({ user: { id: user.id, username: user.username } });
  } catch (err) {
    next(err);
  }
});
