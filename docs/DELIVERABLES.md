# 交付物清单与生成方式

## 数据库逻辑备份
- 备份文件：`backups/course_selection_db.sql`（由 `sys_dump` 生成，包含最新表结构/触发器/过程/数据）。
- 生成命令（需 `KBPASSWORD` 或连接串内含密码）：
```bash
sys_dump.exe -F p -f backups/course_selection_db.sql \
  -d "dbname=course_selection_db host=localhost port=54322 user=system password=123456"
```

## 环境变量
- 示例：`server/.env.example`，包含 DB 连接和 `AUTH_SECRET`。
- 实际 `.env` 已被 `.gitignore` 忽略，请按示例自填。

## API 测试
- 参见 `docs/TESTING.md`，包含登录、选/退课、统计与健康检查的 curl 用例。

## KesPlus 前端导出
- 需在 KESPlus 平台完成页面配置后，从平台导出项目包；本仓库未包含导出物，请按平台指引执行并将导出文件放入 `deliverables/kesplus_export/`。
