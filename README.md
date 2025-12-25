# KesPlus-AuthFlow

> 基于 KES Plus 平台的高校选课管理系统 - 完整的三端（学生/教师/管理员）选课管理解决方案

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Node.js](https://img.shields.io/badge/node-%3E%3D14.0.0-brightgreen.svg)](https://nodejs.org/)
[![PostgreSQL](https://img.shields.io/badge/postgresql-%3E%3D12.0-blue.svg)](https://www.postgresql.org/)

## 🎯 项目概述

KesPlus-AuthFlow 是一个功能完整的高校选课管理系统，基于 KES Plus 平台开发，提供学生选课、教师管理、管理员控制等全方位功能。系统采用前后端分离架构，支持智能冲突检测、候补队列、数据可视化等高级特性。

**项目状态**: ✅ 已完成所有核心功能开发

## 📋 快速开始

### 环境要求

- **Node.js**: 14.0 或更高版本
- **数据库**: PostgreSQL 12+ 或 Kingbase ES V8
- **包管理器**: npm 或 yarn
- **操作系统**: Windows / Linux / macOS

### 安装步骤

```bash
# 1. 克隆项目
git clone https://github.com/AlexZander-666/KesPlus-AuthFlow.git
cd KesPlus-AuthFlow

# 2. 安装后端依赖
cd server
npm install

# 3. 配置数据库连接
cp .env.example .env
# 编辑 .env 文件，填入你的数据库信息：
# DB_HOST=localhost
# DB_PORT=5432
# DB_USER=your_username
# DB_PASSWORD=your_password
# DB_NAME=course_selection_db
# PORT=3000

# 4. 初始化数据库（按顺序执行）
psql -h localhost -p 5432 -U your_username -d course_selection_db -f ../db/01_schema_course_selection.sql
psql -h localhost -p 5432 -U your_username -d course_selection_db -f ../db/02_triggers_course_selection.sql
psql -h localhost -p 5432 -U your_username -d course_selection_db -f ../db/03_procedures_course_selection.sql
psql -h localhost -p 5432 -U your_username -d course_selection_db -f ../db/04_seed_data_course_selection.sql

# 5. 启动服务
npm start
# 或使用开发模式（支持热重载）
npm run dev
```

### 访问系统

服务启动后，打开浏览器访问：**http://localhost:3000**

### 测试账号

系统预置了以下测试账号供快速体验：

| 角色 | 用户名 | 密码 | 说明 |
|------|--------|------|------|
| 管理员 | admin | admin123 | 完整系统管理权限 |
| 教师 | t001 | teacher123 | 教师管理功能 |
| 教师 | t002 | teacher123 | 教师管理功能 |
| 学生 | s001 | student123 | 学生选课功能 |
| 学生 | s002 | student123 | 学生选课功能 |

> 💡 提示：首次登录后建议修改默认密码

## 🌟 核心功能

### 👨‍🎓 学生端功能
- ✅ **课程浏览** - 查看所有可选课程，支持按学院、课程类型筛选
- ✅ **智能选课** - 自动检测时间冲突，防止课程时间重叠
- ✅ **退课管理** - 在规定时间内退选课程
- ✅ **个人课表** - 可视化展示个人课程安排
- ✅ **候补队列** - 课程满员时自动加入候补，有空位时自动补位
- ✅ **候补状态** - 实时查看候补队列状态和排名

### 👨‍🏫 教师端功能
- ✅ **课程管理** - 查看本人授课的所有课程
- ✅ **学生名单** - 查看选课学生详细信息
- ✅ **成绩录入** - 在线录入和修改学生成绩
- ✅ **课程统计** - 查看课程选课人数、成绩分布等统计信息
- ✅ **数据导出** - 支持导出学生名单和成绩单

### 👨‍💼 管理员端功能
- ✅ **用户管理** - 完整的用户 CRUD（增删改查）操作
- ✅ **课程管理** - 完整的课程 CRUD 操作，包括课程时间设置
- ✅ **学院/专业管理** - 管理学院和专业信息
- ✅ **系统参数配置** - 设置选课开始/结束时间等系统参数
- ✅ **数据统计分析** - 多维度数据统计和可视化
- ✅ **数据导出** - 支持 CSV 格式导出各类数据

### 📊 数据可视化
- ✅ **热门课程排行** - ECharts 柱状图展示 TopN 热门课程
- ✅ **学院分布统计** - 饼图展示各学院学生分布
- ✅ **选课趋势分析** - 折线图展示选课趋势变化
- ✅ **实时数据大屏** - Vue3 + ECharts 实现的数据可视化大屏

## 🏗️ 技术架构

### 后端技术栈
- **运行环境**: Node.js 14+
- **Web 框架**: Express.js 5.x
- **数据库**: PostgreSQL 12+ / Kingbase ES V8
- **数据库连接**: pg (node-postgres)
- **认证方式**: 基于 Session 的身份验证
- **密码安全**: SHA-256 + Salt 哈希加密
- **日志记录**: Morgan
- **跨域支持**: CORS
- **环境配置**: dotenv

### 前端技术栈
- **基础技术**: HTML5 + CSS3 + 原生 JavaScript (ES6+)
- **前端框架**: Vue 3 (用于数据大屏)
- **图表库**: Apache ECharts 5.x
- **UI 设计**: 响应式布局，现代化 UI 设计
- **字体**: Manrope (Google Fonts)
- **图标**: 自定义 SVG 图标

### 数据库设计
- **数据表**: 11 个核心业务表
  - TB_USER (用户表)
  - TB_DEPARTMENT (学院表)
  - TB_MAJOR (专业表)
  - TB_STUDENT (学生表)
  - TB_TEACHER (教师表)
  - TB_COURSE (课程表)
  - TB_STUDENT_COURSE (选课记录表)
  - TB_COURSE_TIME (课程时间表)
  - TB_WAITLIST (候补队列表)
  - TB_SYS_PARAM (系统参数表)

- **存储过程/函数**: 15+ 个业务函数
  - FN_LOGIN - 用户登录验证
  - FN_SELECT_COURSE - 学生选课
  - FN_DROP_COURSE - 学生退课
  - FN_CHECK_TIME_CONFLICT - 时间冲突检测
  - FN_STUDENT_TIMETABLE - 学生课表查询
  - FN_STAT_COURSE_TOPN - TopN 课程统计
  - PROC_PROCESS_WAITLIST - 候补队列处理
  - 更多业务函数...

- **触发器**: 4 个自动触发器
  - TRG_AFTER_DROP_COURSE - 退课后自动处理候补
  - TRG_BEFORE_INSERT_USER - 用户插入前密码加密
  - TRG_BEFORE_UPDATE_USER - 用户更新时密码处理
  - TRG_UPDATE_PASSWORD_TIME - 密码更新时间记录

- **索引优化**: 13 个高频查询索引
  - 用户名、学号、工号等唯一索引
  - 课程、选课记录等查询索引
  - 候补队列状态索引

### API 接口设计
- **RESTful API**: 35+ 个接口
- **接口分类**:
  - 认证接口: `/api/login`, `/api/logout`, `/api/session`
  - 学生接口: `/api/courses`, `/api/select`, `/api/drop`, `/api/timetable`
  - 教师接口: `/api/teacher/*`, `/api/grades/*`
  - 管理员接口: `/api/admin/*`, `/api/stat/*`
- **数据格式**: JSON
- **错误处理**: 统一错误响应格式

## 📁 项目结构

```
KesPlus-AuthFlow/
├── server/                      # 后端服务目录
│   ├── index.js                # Express 主入口 (35+ API 接口)
│   ├── db.js                   # PostgreSQL 连接池配置
│   ├── .env.example            # 环境变量配置模板
│   ├── package.json            # 后端依赖配置
│   └── node_modules/           # 后端依赖包
│
├── web/                         # 前端页面目录
│   ├── index.html              # 登录页面（统一入口）
│   ├── student.html            # 学生选课页面
│   ├── teacher.html            # 教师统计页面
│   ├── teacher-manage.html     # 教师管理页面（成绩录入）
│   ├── admin.html              # 管理员看板
│   ├── admin-manage.html       # 管理员管理页面（CRUD）
│   └── vue-dashboard.html      # 数据可视化大屏（Vue3 + ECharts）
│
├── db/                          # 数据库脚本目录
│   ├── 01_schema_course_selection.sql       # 表结构定义
│   ├── 02_triggers_course_selection.sql     # 触发器定义
│   ├── 03_procedures_course_selection.sql   # 存储过程/函数定义
│   ├── 04_seed_data_course_selection.sql    # 测试数据
│   └── 05_randomize_student_names.sql       # 学生姓名随机化脚本
│
├── docs/                        # 文档目录
│   ├── KESPLUS操作指南.md      # KES Plus 平台操作指南
│   ├── login-accounts.md        # 测试账号说明
│   └── KesPlus_页面与数据源设计.txt  # 页面设计文档
│
├── tests/                       # 测试脚本目录
│   └── db_trigger_procedure_tests.sql  # 数据库功能测试
│
├── backups/                     # 数据库备份目录
│   ├── course_selection_db.sql # 完整数据库备份
│   └── manual_20251224/        # 手动备份
│
├── deliverables/                # 交付物目录
│   ├── kesplus_export/         # KES Plus 导出文件
│   └── README.md               # 交付说明
│
├── .gitignore                   # Git 忽略配置
├── AGENTS.md                    # 项目开发指南
├── README.md                    # 项目说明文档（本文件）
└── package-lock.json            # 依赖锁定文件
```

## 🎨 页面展示

### 登录页面
- 统一登录入口，支持三种角色（学生/教师/管理员）
- 角色自动识别和路由跳转
- 安全的密码加密验证机制
- 现代化 UI 设计，响应式布局

### 学生端页面
- **选课页面**: 展示所有可选课程，支持筛选和搜索
- **课程详情**: 显示课程信息、教师、时间、地点等
- **时间冲突检测**: 选课前自动检测时间冲突
- **个人课表**: 可视化展示个人课程安排
- **候补管理**: 查看候补状态，支持取消候补

### 教师端页面
- **课程统计**: 展示授课课程的选课情况
- **学生名单**: 查看选课学生详细信息
- **成绩管理**: 在线录入和修改学生成绩
- **数据导出**: 支持导出学生名单和成绩单

### 管理员端页面
- **用户管理**: 用户的增删改查，支持批量操作
- **课程管理**: 课程的增删改查，包括时间设置
- **系统配置**: 设置选课时间等系统参数
- **数据统计**: 多维度数据统计和可视化
- **数据导出**: CSV 格式导出各类数据

### 数据可视化大屏
- **实时数据**: 基于 Vue3 的响应式数据展示
- **多种图表**: ECharts 实现的柱状图、饼图、折线图
- **交互式**: 支持图表交互和数据钻取
- **全屏展示**: 适合大屏展示和演示

## 🔧 开发命令

```bash
# 进入后端目录
cd server

# 安装依赖
npm install

# 开发模式（支持热重载）
npm run dev

# 生产模式
npm start

# 健康检查
curl http://localhost:3000/health

# 数据库功能测试（在事务中执行，自动回滚）
psql -d course_selection_db -f tests/db_trigger_procedure_tests.sql

# 查看 API 日志
# 服务启动后会自动输出请求日志
```

### 环境变量配置

在 `server/.env` 文件中配置以下变量：

```env
# 数据库配置
DB_HOST=localhost
DB_PORT=5432
DB_USER=your_username
DB_PASSWORD=your_password
DB_NAME=course_selection_db

# 服务端口（可选，默认 3000）
PORT=3000
```

## 📊 数据库设计详情

### 核心数据表（11 个）

1. **TB_USER** - 用户表
   - 存储所有用户的基本信息和认证信息
   - 支持三种角色：ADMIN、TEACHER、STUDENT
   - 密码采用 SHA-256 + Salt 加密存储

2. **TB_DEPARTMENT** - 学院表
   - 管理学院信息

3. **TB_MAJOR** - 专业表
   - 管理专业信息，关联学院

4. **TB_STUDENT** - 学生表
   - 学生详细信息，关联用户、学院、专业

5. **TB_TEACHER** - 教师表
   - 教师详细信息，关联用户、学院

6. **TB_COURSE** - 课程表
   - 课程基本信息、容量、已选人数
   - 包含课程时间信息（星期、节次、地点）

7. **TB_STUDENT_COURSE** - 选课记录表
   - 学生选课关系，包含成绩字段
   - 支持选课和退课状态管理

8. **TB_COURSE_TIME** - 课程时间表
   - 详细的课程时间安排
   - 用于时间冲突检测

9. **TB_WAITLIST** - 候补队列表
   - 课程满员时的候补管理
   - 支持自动补位机制

10. **TB_SYS_PARAM** - 系统参数表
    - 系统配置参数（选课时间等）

### 核心存储过程/函数（15+）

- **FN_LOGIN(p_username, p_password)** - 用户登录验证
- **FN_SELECT_COURSE(p_stu_id, p_course_id, p_term)** - 学生选课
- **FN_DROP_COURSE(p_stu_id, p_course_id, p_term)** - 学生退课
- **FN_CHECK_TIME_CONFLICT(p_stu_id, p_course_id, p_term)** - 时间冲突检测
- **FN_STUDENT_TIMETABLE(p_stu_id, p_term)** - 查询学生课表
- **FN_STAT_COURSE_TOPN(p_term, p_top_n)** - TopN 热门课程统计
- **PROC_PROCESS_WAITLIST(p_course_id, p_term)** - 处理候补队列
- 更多业务函数...

### 触发器（4 个）

- **TRG_AFTER_DROP_COURSE** - 退课后自动处理候补队列
- **TRG_BEFORE_INSERT_USER** - 用户插入前密码加密
- **TRG_BEFORE_UPDATE_USER** - 用户更新时密码处理
- **TRG_UPDATE_PASSWORD_TIME** - 密码更新时间记录

### 索引优化（13 个）

针对高频查询字段建立索引，提升查询性能：
- 用户名、学号、工号等唯一索引
- 课程编号、课程名称查询索引
- 选课记录、课程时间查询索引
- 候补队列状态索引

## 🚀 核心特性与创新点

### 1. 智能时间冲突检测
- 选课前自动检测课程时间是否冲突
- 基于课程时间表的精确匹配算法
- 友好的冲突提示信息

### 2. 候补队列自动补位
- 课程满员时自动加入候补队列
- 退课后自动处理候补队列，按时间顺序补位
- 实时候补状态查询

### 3. 密码安全机制
- SHA-256 + Salt 哈希加密
- 密码更新时间记录
- 触发器自动处理密码加密

### 4. 数据可视化
- ECharts 实现多维度统计图表
- Vue3 响应式数据大屏
- 支持数据导出（CSV 格式）

### 5. 完整的 CRUD 管理
- 管理员可管理所有用户、课程、学院、专业
- 支持批量操作和数据导出
- 完善的权限控制

### 6. 成绩管理系统
- 教师在线录入和修改成绩
- 成绩统计和分析
- 成绩单导出功能

### 7. 系统参数配置
- 灵活的选课时间配置
- 支持时间戳和字符串两种参数类型
- 实时生效，无需重启服务

### 8. 响应式设计
- 现代化 UI 设计
- 支持多种屏幕尺寸
- 良好的用户体验

## 📖 相关文档

- [KES Plus 操作指南](docs/KESPLUS操作指南.md) - KES Plus 平台集成和部署说明
- [测试账号说明](docs/login-accounts.md) - 系统测试账号列表
- [页面设计文档](docs/KesPlus_页面与数据源设计.txt) - 页面功能和数据源设计
- [项目开发指南](AGENTS.md) - 项目结构、开发规范、提交指南

## 🧪 测试说明

### 数据库功能测试

项目提供了完整的数据库功能测试脚本：

```bash
# 运行数据库测试（在事务中执行，自动回滚）
psql -d course_selection_db -f tests/db_trigger_procedure_tests.sql
```

测试内容包括：
- 密码加密和验证
- 选课功能（包括冲突检测）
- 退课功能（包括候补处理）
- 候补队列管理
- 成绩录入
- 统计查询

### API 接口测试

可以使用 curl 或 Postman 测试 API 接口：

```bash
# 健康检查
curl http://localhost:3000/health

# 登录测试
curl -X POST http://localhost:3000/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"s001","password":"student123"}'

# 查询课程
curl http://localhost:3000/api/courses?term=2024-2025-1

# 更多接口测试...
```

## 🔒 安全性说明

### 密码安全
- 所有密码采用 SHA-256 + Salt 哈希加密存储
- 数据库中不存储明文密码
- 密码更新时自动触发加密

### 数据库安全
- 使用参数化查询，防止 SQL 注入
- 数据库连接信息通过环境变量配置
- 不在代码中硬编码敏感信息

### 会话管理
- 基于 Session 的身份验证
- 登录状态持久化
- 支持登出清除会话

## 🤝 贡献指南

本项目为课程作业项目，欢迎提出建议和改进意见。

### 提交规范

- **Commit 格式**: 使用简短的祈使句描述变更
  - 示例: `Add course selection API`, `Fix time conflict detection`
- **Commit 内容**: 在提交信息中说明数据库迁移、环境变量变更等重要信息
- **Pull Request**: 描述行为变更、受影响的接口/SQL 对象、验证步骤

### 不要提交的内容

- `.env` 文件（包含敏感信息）
- `node_modules/` 目录
- 数据库备份文件（`.sql` 大文件）
- 临时文件和日志文件

## 📄 许可证

本项目仅用于学习和教学目的。

## 📞 联系方式

如有问题或建议，欢迎通过以下方式联系：

- GitHub Issues: [提交问题](https://github.com/AlexZander-666/KesPlus-AuthFlow/issues)
- 项目文档: 查看 `docs/` 目录下的相关文档

---

## ✅ 项目完成情况

### 基本要求 ✅
- ✅ 基于 KES Plus 平台（使用 Kingbase 兼容数据库）
- ✅ 数据表 ≥ 5 个（实际 11 个）
- ✅ 页面 ≥ 5 个（实际 7 个功能页面）
- ✅ 数据库访问功能（35+ API 接口）

### 扩展要求 ✅
- ✅ 数据统计和图表展示（ECharts）
- ✅ Vue 前端页面（Vue 3）
- ✅ 自定义函数（15+ 个存储过程/函数）
- ✅ 前后端交互（RESTful API）
- ✅ 触发器（4 个自动触发器）
- ✅ 索引优化（13 个索引）

### 额外特性 ✅
- ✅ 智能时间冲突检测
- ✅ 候补队列自动补位
- ✅ 密码安全加密
- ✅ 完整的 CRUD 管理
- ✅ 成绩管理系统
- ✅ 数据导出功能
- ✅ 响应式设计

---

**项目状态**: ✅ 已完成所有功能开发和测试

**技术栈**: Node.js + Express + PostgreSQL + Vue3 + ECharts

**开发时间**: 2024-2025 学年

**最后更新**: 2024-12-25

---

⭐ 如果这个项目对你有帮助，欢迎 Star！
