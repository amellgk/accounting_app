import { Router } from 'express';
import multer from 'multer';
import { parse } from 'csv-parse/sync';
import { prisma } from '../db';
import { authMiddleware } from '../middleware/auth';

export const importRouter = Router();
importRouter.use(authMiddleware);

const upload = multer({ dest: '/tmp/uploads/', limits: { fileSize: 10 * 1024 * 1024 } });

function parseAmount(val) {
  if (!val) return 0;
  const cleaned = String(val).replace(/[,，]/g, '').replace(/[¥￥]/g, '').trim();
  return parseFloat(cleaned) || 0;
}

// 导入支付宝账单
importRouter.post('/alipay', upload.single('file'), async (req, res, next) => {
  try {
    if (!req.file) return res.status(400).json({ error: '请上传文件' });

    const fs = await import('fs');
    const content = fs.readFileSync(req.file.path, 'utf-8');
    
    // 支付宝 CSV 格式通常有表头行
    const rawLines = content.split('\n').filter(line => line.trim());
    let startIndex = 0;
    
    // 跳过支付宝说明行，找到真正的表头
    for (let i = 0; i < rawLines.length; i++) {
      if (rawLines[i].includes('交易时间') || rawLines[i].includes('交易号')) {
        startIndex = i + 1;
        break;
      }
    }

    const records = parse(rawLines.slice(startIndex).join('\n'), {
      columns: true,
      skip_empty_lines: true,
      relax_column_count: true,
      bom: true,
    });

    const categories = await prisma.category.findMany({
      where: { userId: req.userId, type: 'expense' },
    });

    let importedCount = 0;
    const errors = [];

    // 匹配分类（根据商品名称关键词）
    function matchCategory(name) {
      const keywordMap = {
        '餐饮': ['餐饮', '美食', '外卖', '饿了么', '美团', '咖啡', '奶茶', '面包', '餐厅', '饭', '菜'],
        '交通': ['交通', '地铁', '公交', '滴滴', '打车', '出租车', '加油', '停车', '高铁', '火车'],
        '购物': ['购物', '淘宝', '京东', '拼多多', '超市', '便利店', '商场', '买'],
        '娱乐': ['娱乐', '游戏', '电影', '视频', '音乐', 'KTV', '旅游', '门票'],
        '通讯': ['话费', '流量', '宽带', '通讯'],
        '医疗': ['医疗', '医院', '药', '体检', '口罩'],
        '教育': ['教育', '课程', '书', '图书', '培训', '学习'],
        '日用': ['日用', '日用品', '家居', '家电', '家具', '厨房'],
        '服饰': ['服饰', '衣服', '鞋', '包', '穿戴', '服装'],
      };
      
      const lower = (name || '').toLowerCase();
      for (const [catName, keywords] of Object.entries(keywordMap)) {
        if (keywords.some(k => lower.includes(k))) {
          const found = categories.find(c => c.name === catName && c.type === 'expense');
          if (found) return found.id;
        }
      }
      // 默认归类到"其他支出"
      const other = categories.find(c => c.name === '其他支出');
      return other ? other.id : categories[0]?.id;
    }

    for (const record of records) {
      try {
        const timeField = record['交易时间'] || record['交易创建时间'] || record['交易成功时间'];
        const nameField = record['商品名称'] || record['商品说明'] || record['交易对方'] || '';
        const amountField = record['金额'] || record['收入金额'] || record['支出金额'] || record['交易金额'];
        const typeField = record['收/支'] || record['类型'] || '';
        const noteField = record['备注'] || '';

        const isExpense = typeField.includes('支出') || typeField.includes('付款');
        if (!isExpense && !typeField.includes('收入')) continue;

        const amount = Math.abs(parseAmount(amountField));
        if (amount === 0) continue;

        const t = new Date(timeField);
        if (isNaN(t.getTime())) continue;

        const type = isExpense ? 'expense' : 'income';
        let categoryId;

        if (type === 'expense') {
          categoryId = matchCategory(nameField);
        } else {
          const incomeCat = categories.find(c => c.type === 'income');
          categoryId = incomeCat ? incomeCat.id : (await prisma.category.findFirst({
            where: { userId: req.userId, type: 'income' },
          }))?.id;
          if (!categoryId) continue;
        }

        await prisma.transaction.create({
          data: {
            userId: req.userId,
            categoryId,
            type,
            amount,
            note: (nameField || '') + (noteField ? ' | ' + noteField : ''),
            transactionDate: t,
          },
        });
        importedCount++;
      } catch (e) {
        errors.push(e.message);
      }
    }

    // 记录导入日志
    await prisma.importRecord.create({
      data: {
        userId: req.userId,
        source: 'alipay',
        fileName: req.file.originalname,
        totalCount: records.length,
        importedCount,
      },
    });

    // 清理临时文件
    try { fs.unlinkSync(req.file.path); } catch {}

    res.json({
      total: records.length,
      imported: importedCount,
      errors: errors.length,
      errorDetails: errors.slice(0, 5),
    });
  } catch (err) {
    next(err);
  }
});

// 导入微信账单
importRouter.post('/wechat', upload.single('file'), async (req, res, next) => {
  try {
    if (!req.file) return res.status(400).json({ error: '请上传文件' });

    const fs = await import('fs');
    const content = fs.readFileSync(req.file.path, 'utf-8');
    
    const rawLines = content.split('\n').filter(line => line.trim());
    let startIndex = 0;
    
    for (let i = 0; i < rawLines.length; i++) {
      if (rawLines[i].includes('交易时间') || rawLines[i].includes('微信支付') || rawLines[i].includes('微信账单')) {
        // 微信账单的下一行通常是表头
        if (i + 1 < rawLines.length && (rawLines[i + 1].includes('时间') || rawLines[i + 1].includes('金额'))) {
          startIndex = i + 2;
        } else {
          startIndex = i + 1;
        }
        break;
      }
    }

    const records = parse(rawLines.slice(startIndex).join('\n'), {
      columns: true,
      skip_empty_lines: true,
      relax_column_count: true,
      bom: true,
    });

    const categories = await prisma.category.findMany({
      where: { userId: req.userId },
    });

    let importedCount = 0;
    const errors = [];

    function matchCategory(name) {
      const keywordMap = {
        '餐饮': ['餐饮', '美食', '外卖', '饿了么', '美团', '咖啡', '奶茶', '面包', '餐厅', '饭', '菜', '食堂', '小吃', '早餐', '午餐', '晚餐'],
        '交通': ['交通', '地铁', '公交', '滴滴', '打车', '出租车', '加油', '停车', '高铁', '火车', '骑车', '单车'],
        '购物': ['购物', '淘宝', '京东', '拼多多', '超市', '便利店', '商场', '买', '网购', '商城', '支付', '消费'],
        '娱乐': ['娱乐', '游戏', '电影', '视频', '音乐', 'KTV', '旅游', '门票', '景点', '休闲'],
        '通讯': ['话费', '流量', '宽带', '通讯', '手机', '电信', '联通', '移动'],
        '医疗': ['医疗', '医院', '药', '体检', '口罩', '看病', '诊所'],
        '教育': ['教育', '课程', '书', '图书', '培训', '学习', '考试', '教材'],
        '日用': ['日用', '日用品', '家居', '家电', '家具', '厨房', '洗护', '清洁'],
        '服饰': ['服饰', '衣服', '鞋', '包', '穿戴', '服装', '穿搭', '饰品'],
      };
      
      const lower = (name || '').toLowerCase();
      for (const [catName, keywords] of Object.entries(keywordMap)) {
        if (keywords.some(k => lower.includes(k))) {
          const found = categories.find(c => c.name === catName);
          if (found) return found.id;
        }
      }
      const other = categories.find(c => c.name === '其他支出');
      return other ? other.id : categories[0]?.id;
    }

    for (const record of records) {
      try {
        const timeField = record['交易时间'] || record['时间'] || record['交易时间(第一笔)'] || '';
        const nameField = record['交易对方'] || record['商品'] || record['说明'] || record['备注'] || '';
        const amountField = record['金额(元)'] || record['金额'] || record['收入'] || record['支出'] || record['合计'] || '';
        const typeField = record['收/支'] || record['类型'] || record['交易类型'] || '';
        const noteField = record['备注'] || record['商品'] || '';

        const isExpense = /支出|付款|消费/.test(typeField);
        if (!isExpense && !/收入|收款/.test(typeField)) continue;

        const amount = Math.abs(parseAmount(amountField));
        if (amount === 0) continue;

        const t = new Date(timeField);
        if (isNaN(t.getTime())) continue;

        const type = isExpense ? 'expense' : 'income';
        let categoryId;

        if (type === 'expense') {
          categoryId = matchCategory(nameField || noteField);
        } else {
          const incomeCat = categories.find(c => c.type === 'income');
          categoryId = incomeCat ? incomeCat.id : (await prisma.category.findFirst({
            where: { userId: req.userId, type: 'income' },
          }))?.id;
          if (!categoryId) continue;
        }

        await prisma.transaction.create({
          data: {
            userId: req.userId,
            categoryId,
            type,
            amount,
            note: (nameField || '') + (noteField && noteField !== nameField ? ' | ' + noteField : ''),
            transactionDate: t,
          },
        });
        importedCount++;
      } catch (e) {
        errors.push(e.message);
      }
    }

    await prisma.importRecord.create({
      data: {
        userId: req.userId,
        source: 'wechat',
        fileName: req.file.originalname,
        totalCount: records.length,
        importedCount,
      },
    });

    try { fs.unlinkSync(req.file.path); } catch {}

    res.json({
      total: records.length,
      imported: importedCount,
      errors: errors.length,
      errorDetails: errors.slice(0, 5),
    });
  } catch (err) {
    next(err);
  }
});
