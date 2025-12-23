# 登录与角色分流说明（现状对齐）

本文件用于说明当前工程中“登录 → 颁发 token → 前端按角色跳转 → 调用受保护接口”的实际实现，便于写入报告与在 KesPlus 中复刻同等逻辑。

## 1. 登录接口与返回字段

- 接口：`POST /api/login`
- 请求体：`{ "username": "...", "password": "..." }`
- 逻辑：后端调用数据库函数 `FN_LOGIN(username, password)`，校验账号状态后签发 token。
- 返回（示例字段，实际可能因角色不同而增减）：
  - `user_id`：用户 ID
  - `role`：`ADMIN | TEACHER | STUDENT`
  - `stu_id` / `tea_id`：学生/教师关联 ID（按角色返回）
  - `term`：当前学期（优先取 `TB_SYS_PARAM.CURRENT_TERM`，无则用后端 `DEFAULT_TERM`，仍无则报错）
  - `token`：后端签发的 Bearer token
  - 学生额外字段：`stu_name`、`stu_no`、`real_name`（用于页面展示）

## 2. token 规则（后端实现）

后端在 `server/index.js` 中使用 HMAC-SHA256 对 payload 做签名，token 结构为：

`base64url(payload_json) + "." + base64url(hmac_sha256(payload))`

关键点：
- `AUTH_SECRET` 来自环境变量（建议生产环境必须配置强随机值），示例见 `server/.env.example`。
- payload 内包含：`user_id`、`role`、`stu_id`、`tea_id`、`username`、`term`、`ts`（签发时间戳）。
- 该 token 是“无状态”的，服务端通过签名验证其完整性；目前未实现过期/刷新机制，若要用于验收演示可保持简单，但报告中建议写明可扩展点（增加 `exp` 并做过期校验）。

## 3. 前端会话存储与跳转（静态页）

静态前端在 `web/index.html` 中：
- 使用 `sessionStorage` 保存登录结果（key：`session`），包含 `token`、`role`、`stu_id/tea_id` 等字段。
- 按角色跳转页面：
  - `ADMIN` → `/admin.html`
  - `TEACHER` → `/teacher.html`
  - `STUDENT`（默认）→ `/student.html`

各角色页面请求后端接口时会带上：

`Authorization: Bearer <token>`

## 4. 授权与越权防护（后端校验方式）

后端通过中间件 `requireAuth(roles)` 做两层校验：
1) 是否携带 Bearer token 且签名有效（无效 → 401）
2) 角色是否在允许列表中（不匹配 → 403）

对“学生只能操作本人”的校验策略：
- 受保护接口（如 `/api/courses/my`、`/api/select`、`/api/drop` 等）除了校验角色为 `STUDENT`，还会校验 `req.auth.stu_id === 请求参数/请求体中的 stu_id`，否则返回 403。

> 报告撰写建议：在“系统安全设计”或“权限控制”章节用 1 张表说明：角色 → 可访问接口/页面 → 数据范围（本人/本人授课/全局）。

## 5. KesPlus 平台落地建议（写进报告或实施说明）

若在 KesPlus 内实现同等逻辑，可按两条路径选择：
- 直接数据库数据源：KesPlus 页面按钮事件调用过程/函数（如 `FN_LOGIN`、`PROC_SELECT_COURSE` 等），由平台权限控制页面可见性。
- HTTP 数据源：KesPlus 通过 HTTP 调用 `/api/*`，沿用本项目 token 方案；页面侧统一在请求头附带 `Authorization: Bearer <token>`。

无论哪种方式，建议在 KesPlus 菜单/权限中做到：
- 学生只见学生菜单
- 教师只见教师菜单
- 管理员拥有全局维护与统计导出权限

