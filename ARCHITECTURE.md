# 记账 App — 技术方案 & 架构设计

## 📋 一、需求总览

### 核心功能
1. **记账** — 记录收入/支出（金额、分类、备注、日期）
2. **账单流水** — 按时间排序查看所有记录，支持筛选/搜索
3. **分类管理** — 预设分类 + 自定义分类
4. **统计图表** — 月度/年度汇总、分类占比饼图、趋势折线图
5. **数据导入** — 解析支付宝/微信导出的 CSV 账单
6. **数据导出** — 导出为 CSV/Excel
7. **用户系统** — 账号密码注册登录
8. **云同步** — 本地 SQLite 并行存储，网络畅通时自动上传到云端

### 非功能需求
- 跨平台：iOS + Android
- 离线可用：无网络时正常记账，联网后自动同步
- 数据安全：密码加密存储，传输使用 HTTPS

---

## 🏗️ 二、技术选型

| 层级 | 技术 | 原因 |
|------|------|------|
| **前端** | Flutter 3.x | 一套代码跨平台，性能好，生态成熟 |
| **状态管理** | Riverpod | 类型安全、依赖注入、易于测试 |
| **本地数据库** | SQLite (drift/sqflite) | 成熟、轻量、离线可用 |
| **网络请求** | Dio | 拦截器、重试、超时控制 |
| **后端框架** | Node.js + Express | 开发效率高，与前端同语言生态 |
| **云数据库** | PostgreSQL | 成熟的关系型数据库 |
| **ORM** | Prisma | 类型安全，自动迁移 |
| **认证** | JWT (jsonwebtoken) | 无状态认证，适合移动端 |
| **部署** | 简单 VPS / Railway / Fly.io | 低成本起步 |

---

## 🗄️ 三、数据库设计

### 用户表 (users)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| username | VARCHAR(50) | 用户名，唯一 |
| password_hash | VARCHAR(255) | bcrypt 加密密码 |
| created_at | TIMESTAMP | - |
| updated_at | TIMESTAMP | - |

### 分类表 (categories)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| user_id | UUID | 外键 → users，NULL 表示系统预设 |
| name | VARCHAR(50) | 分类名：餐饮、交通、购物... |
| icon | VARCHAR(50) | 图标标识 |
| type | ENUM('income','expense') | 收入或支出 |
| sort_order | INT | 排序 |
| created_at | TIMESTAMP | - |

### 账单表 (transactions)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| user_id | UUID | 外键 → users |
| category_id | UUID | 外键 → categories |
| type | ENUM('income','expense') | 收入/支出 |
| amount | DECIMAL(12,2) | 金额 |
| note | TEXT | 备注 |
| transaction_date | DATE | 交易日期 |
| created_at | TIMESTAMP | - |
| updated_at | TIMESTAMP | - |
| sync_version | INT | 乐观锁，用于冲突检测 |

### 导入记录表 (import_records)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| user_id | UUID | 外键 → users |
| source | VARCHAR(20) | 来源：alipay / wechat |
| file_name | VARCHAR(255) | 原文件名 |
| total_count | INT | 总条数 |
| imported_count | INT | 成功导入数 |
| created_at | TIMESTAMP | - |

---

## 🔌 四、API 设计

### 认证
```
POST   /api/auth/register     # 注册
POST   /api/auth/login        # 登录
POST   /api/auth/refresh      # 刷新 token
```

### 分类
```
GET    /api/categories        # 获取分类列表
POST   /api/categories        # 创建自定义分类
PUT    /api/categories/:id    # 修改分类
DELETE /api/categories/:id    # 删除分类
```

### 账单
```
GET    /api/transactions      # 获取账单列表（支持分页、筛选）
POST   /api/transactions      # 新增账单
PUT    /api/transactions/:id  # 修改账单
DELETE /api/transactions/:id  # 删除账单
POST   /api/transactions/sync # 批量同步（离线记录上传）
```

### 统计
```
GET    /api/stats/monthly?year=2025&month=4   # 月度统计
GET    /api/stats/yearly?year=2025             # 年度统计
GET    /api/stats/category?start=&end=         # 分类统计
```

### 导入导出
```
POST   /api/import/alipay     # 导入支付宝账单
POST   /api/import/wechat     # 导入微信账单
GET    /api/export/csv        # 导出 CSV
GET    /api/export/excel      # 导出 Excel
```

---

## 📱 五、Flutter 页面结构

```
lib/
├── main.dart                 # 入口
├── app.dart                  # MaterialApp 配置
├── router.dart               # 路由配置
├── models/                   # 数据模型
│   ├── user.dart
│   ├── transaction.dart
│   └── category.dart
├── providers/                # 状态管理 (Riverpod)
│   ├── auth_provider.dart
│   ├── transaction_provider.dart
│   └── sync_provider.dart
├── services/                 # 业务逻辑
│   ├── api_service.dart      # 网络请求
│   ├── local_db_service.dart # 本地数据库
│   ├── sync_service.dart     # 同步逻辑
│   └── import_service.dart   # 导入解析
├── pages/                    # 页面
│   ├── login_page.dart
│   ├── register_page.dart
│   ├── home_page.dart        # 主页（本月概览）
│   ├── transaction_list_page.dart
│   ├── add_transaction_page.dart
│   ├── stats_page.dart
│   ├── categories_page.dart
│   ├── import_page.dart
│   └── settings_page.dart
├── widgets/                  # 可复用组件
│   ├── amount_input.dart
│   ├── category_picker.dart
│   ├── transaction_card.dart
│   └── stat_chart.dart
└── utils/                    # 工具
    ├── date_utils.dart
    └── csv_parser.dart       # CSV 解析器
```

---

## 🔄 六、离线同步策略

```
用户操作 → 写入本地 SQLite → 标记为待同步
              │
              ▼
    检查网络是否可用？
       ├── 否 → 留在本地，下次启动时重试
       └── 是 → 上传到云端 PostgreSQL
                   │
                   ▼
              冲突检测（sync_version）
       ├── 无冲突 → 写入云端，更新 sync_version
       └── 有冲突 → 以最后修改为准（last-write-wins）
```

- **同步时机**：每次记账操作后、App 启动时、后台定时（每 5 分钟）
- **同步方向**：双向同步（本地↔云端）
- **冲突处理**：乐观锁 + last-write-wins

---

## 📊 七、统计功能

1. **月度概览**：本月收入/支出/结余，环形图展示分类占比
2. **趋势图**：近 6 个月/12 个月的收支趋势折线图
3. **分类排行**：支出最多的 Top 5 分类
4. **日历视图**：在日历上标记有支出的日子，点击查看当天明细

---

## ✨ 八、UI 设计 — 清新可爱风 🌸

### 整体风格
- **清新干净、清爽治愈**，参考风格：清爽蓝调 + 极简卡片风
- 主色调：**清爽蓝 (#7EC8E3) + 薄荷绿 (#A8E6CF)**，搭配干净辅助色
- 圆角适中、留白舒适，卡片采用磨砂玻璃质感（毛玻璃效果）
- 图标使用简洁线条风 Emoji/简洁图标
- 字体干净清晰，数字使用等宽圆体

### 配色方案
| 用途 | 颜色 | 色值 |
|------|------|------|
| 主色 | 清爽蓝 | #7EC8E3 |
| 辅色 | 薄荷绿 | #A8E6CF |
| 收入色 | 柔绿 | #88D8A8 |
| 支出色 | 暖橙 | #FFB347 |
| 背景 | 冷白 | #F5F9FC |
| 文字主 | 深蓝灰 | #2C3E50 |
| 浅色文字 | 冷灰 | #95A5A6 |

### 页面特色
- **首页** — 上方显示毛玻璃卡片本月概览（收入/支出/结余），下方按日期分组展示最近账单
- **记账按钮** — 底部居中大圆按钮，带蓝色渐变和微光晕
- **新增记账页** — 分类选择用 Emoji 大图标网格排列（🍔🚌🛍️🏠📱），选择分类后金额输入自动弹出数字键盘
- **统计页** — 环形图配色柔和，分类统计用圆角小标签展示
- **空状态** — 没有记录时显示小插画 + 鼓励语（"今天还没记账哦~"）

### 动效
- 页面切换使用柔和淡入淡出
- 点击按钮有弹性反馈
- 新增账单后卡片从底部滑入
- 删除记录时有个缩小消失动画

### 其他
- 深色模式自动适配（蓝色变暗蓝色，背景变深蓝灰）
- 启动页显示 App 名称 + 小猫咪/小花朵 Logo
- 底部导航栏 4 个 Tab：首页 📖 | 统计 📊 | 导入 📥 | 我的 👤
