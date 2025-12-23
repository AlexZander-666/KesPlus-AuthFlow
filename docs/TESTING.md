# 手工/接口测试要点

## 登录
- 学生：`s001 / student123`
- 教师：`t001 / teacher123`
- 管理员：`admin / admin123`
- API 示例（返回 token，后续请求放到 `Authorization: Bearer <token>`）：
```bash
curl -X POST http://localhost:3000/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"s001","password":"student123"}'
```

## 学期配置
```bash
curl http://localhost:3000/api/config/term
```

## 学生选课/退课
1) 选课：
```bash
TOKEN=<登录得到的token>
curl -X POST http://localhost:3000/api/select \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"stu_id":1,"course_id":1}'
```
2) 我的课程：
```bash
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/api/courses/my?stu_id=1"
```
3) 冲突检测（选课前可选）：
```bash
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/api/courses/conflict?stu_id=1&course_id=1"
```
4) 我的课表：
```bash
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/api/courses/timetable?stu_id=1"
```
5) 退课：
```bash
curl -X POST http://localhost:3000/api/drop \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"stu_id":1,"course_id":1}'
```

## 候补队列（学生）
1) 加入候补（课程满员时）：
```bash
TOKEN=<登录得到的token>
curl -X POST http://localhost:3000/api/waitlist/join \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"stu_id":1,"course_id":1}'
```
2) 我的候补：
```bash
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/api/waitlist/my?stu_id=1"
```

## 统计（教师/管理员）
```bash
TOKEN=<教师/管理员登录 token>
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/api/stat"
```

## 扩展统计与导出（教师/管理员）
```bash
TOKEN=<教师/管理员登录 token>
curl -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/stat/top?limit=10"
curl -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/stat/dept"
curl -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/stat/trend?bucket=day"
curl -H "Authorization: Bearer $TOKEN" "http://localhost:3000/api/export/stat" --output stat.csv
```

## 候补处理（管理员）
```bash
TOKEN=<管理员登录 token>
curl -X POST http://localhost:3000/api/waitlist/process \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"course_id":1}'
```

## 健康检查
```bash
curl http://localhost:3000/health
```
