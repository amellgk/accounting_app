# 清爽记账 App

## 📋 前提条件

- **Node.js** >= 18
- **PostgreSQL**（推荐 1Panel 应用商店安装）
- **Flutter SDK**（编译 APK 用）

## 🚀 快速启动

### 1. 1Panel 安装 PostgreSQL

打开 1Panel → **应用商店** → 安装 **PostgreSQL**

安装后创建数据库和用户：

```sql
CREATE USER accounting WITH PASSWORD '你的密码';
CREATE DATABASE accounting_db OWNER accounting;
GRANT ALL PRIVILEGES ON DATABASE accounting_db TO accounting;
```

或者直接在 1Panel 数据库管理页面创建。

### 2. 配置连接

编辑 `server/.env`，填入你的 PostgreSQL 连接信息：

```env
DATABASE_URL="postgresql://accounting:你的密码@localhost:5432/accounting_db"
JWT_SECRET="改成你自己的密钥"
```

> 如果后端和数据库不在同一台机器，把 `localhost` 换成数据库的 IP 地址

### 3. 启动后端

```bash
cd server
npm install
npx prisma db push    # 同步数据库表结构
npm start              # 启动 → http://localhost:3000
```

### 4. 编译运行 App

```bash
cd flutter_app
flutter pub get
flutter build apk --release
```

> 打包前修改 `lib/services/api_service.dart` 里的 `baseUrl`：
> - 模拟器测试: `http://10.0.2.2:3000`
> - 真机测试: 换成你树莓派的局域网 IP

### 5. 测试 API

```bash
# 健康检查
curl http://localhost:3000/api/health

# 注册新用户
curl -X POST http://localhost:3000/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"你的名字","password":"123456"}'

# 登录
curl -X POST http://localhost:3000/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"你的名字","password":"123456"}'
```

## 📁 项目结构

```
accounting_app/
├── server/          # 后端 Node.js + Prisma + PostgreSQL
│   ├── prisma/      # 数据库模型
│   └── src/
│       ├── routes/  # API 路由
│       └── middleware/
└── flutter_app/     # 前端 Flutter App
    └── lib/
        ├── pages/   # 页面
        ├── widgets/ # 组件
        ├── models/  # 数据模型
        ├── services/# API + 本地数据库
        ├── providers/# 状态管理
        └── theme/   # 主题
```

## ✨ 功能

- 注册/登录（JWT 认证）
- 记账（选择分类 → 输入金额 → 备注）
- 16 个预设 Emoji 分类
- 月度收入/支出/结余概览
- 统计页（环形图 + 分类排行）
- 支付宝/微信 CSV 账单导入
- CSV 数据导出
- 离线存储 + 联网同步
- 清爽蓝 UI 主题

## 🐳 Docker 部署（可选）

如果你想把后端跑在 Docker 里：

```dockerfile
# server/Dockerfile
FROM node:20-alpine
WORKDIR /app
COPY . .
RUN npm install && npx prisma generate
EXPOSE 3000
CMD ["npm", "start"]
```
