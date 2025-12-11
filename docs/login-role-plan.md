# 登录与角色分流方案

## 目标
- 保持单一、简洁的登录表单（用户名 + 密码 + 登录按钮），不要求手动选择角色。
- 基于后端 `/api/login` 返回的 `role`（ADMIN/TEACHER/STUDENT）进行跳转，未登录访问时统一重定向到登录页。
- 优先复用现有 API（`/api/login`, `/api/courses/selectable`, `/api/courses/my`, `/api/select`, `/api/drop`, `/api/stat`），前期不改动后端。

## 登录页
- 位置：复用 `web/index.html` 作为登录页；功能页另建 `web/student.html`、`web/teacher.html`、`web/admin.html`。
- 结构：用户名、密码输入 + 登录按钮 + 状态提示；默认 focus 用户名，Enter 触发提交。提交时禁用按钮并显示“正在登录”，失败红色提示。
- 请求示例：
```js
const res = await fetch('/api/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ username, password }),
});
if (!res.ok) throw new Error('登录失败');
const data = await res.json(); // { user_id, role, stu_id, tea_id }
```

## 分流与跳转
- role 映射：`ADMIN -> /admin/index.html`，`TEACHER -> /teacher/index.html`，`STUDENT -> /student/index.html`。
- 登录成功后：
```js
sessionStorage.setItem('session', JSON.stringify(data));
window.location.href = getRedirectPath(data.role);
```
- 各角色页入口必须检测 `sessionStorage.session`，缺失则 `location.href = '/index.html'`。退出登录：清除 session 后跳转登录页。保持登录页干净，不在此堆叠角色内容。

## 各角色页面职责（最小可用版）
- 学生：可选课程（GET `/api/courses/selectable?term=...`）、我的选课（GET `/api/courses/my?stu_id=...&term=...`），按钮调用 POST `/api/select` 与 `/api/drop`，错误就地提示。
- 教师：先复用 `/api/stat?term=...` 展示课程选课情况，前端按 `tea_name/tea_id` 过滤；如需“我的授课”，补充 GET `/api/courses/teacher?tea_id=...`（可由现有表关联实现）。
- 管理员：复用 `/api/stat` 全局视图，并预留管理入口（用户/课程/参数）。在新增 CRUD API 前可放置占位，后续绑定到存储过程。

## 状态与安全
- session 存储：`sessionStorage` 保存 `{ user_id, role, stu_id, tea_id }`，不落地密码；可附带 `term` 缓存。需要跨页持久可切换为 `localStorage`。
- API 封装：统一 fetch 包装，遇到 401/500 清除 session 后返回登录页；界面提示采用单行 Banner，保持页面简洁。
- 环境：使用 `.env` 的 `PORT` 和数据库参数。上线前务必更换默认密码、启用 HTTPS/同源策略，并限制静态资源来源。
