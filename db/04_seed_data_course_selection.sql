-- 选课系统初始化示例数据
-- 执行前建议确认表已创建，执行 TRUNCATE 以确保幂等
TRUNCATE TABLE TB_STUDENT_COURSE, TB_COURSE, TB_STUDENT, TB_TEACHER, TB_MAJOR, TB_DEPARTMENT, TB_USER, TB_SYS_PARAM RESTART IDENTITY CASCADE;

-- 用户账号（含管理员、教师、学生），密码使用 md5 哈希
INSERT INTO TB_USER (USERNAME, PASSWORD_HASH, REAL_NAME, ROLE, STATUS, EMAIL, MOBILE)
VALUES
('admin', md5('admin123'), 'Admin', 'ADMIN', '1', 'admin@example.com', '18800000000'),
('t001', md5('teacher123'), 'Teacher Zhang', 'TEACHER', '1', 'teacher1@example.com', '18800000001'),
('t002', md5('teacher123'), 'Teacher Li', 'TEACHER', '1', 'teacher2@example.com', '18800000002'),
('s001', md5('student123'), 'Student A', 'STUDENT', '1', 'student1@example.com', '18800000003'),
('s002', md5('student123'), 'Student B', 'STUDENT', '1', 'student2@example.com', '18800000004'),
('s003', md5('student123'), 'Student C', 'STUDENT', '1', 'student3@example.com', '18800000005');

-- 学院
INSERT INTO TB_DEPARTMENT (DEPT_CODE, DEPT_NAME, STATUS) VALUES
('CS', 'Computer Science', '1');

-- 专业
INSERT INTO TB_MAJOR (MAJOR_CODE, MAJOR_NAME, DEPT_ID, STATUS) VALUES
('SE', 'Software Engineering', 1, '1'),
('IS', 'Information Security', 1, '1');

-- 学生
INSERT INTO TB_STUDENT (STU_NO, STU_NAME, GENDER, DEPT_ID, MAJOR_ID, GRADE, MOBILE, EMAIL, USER_ID, STATUS) VALUES
('2024001', 'Student A', 'M', 1, 1, '2024', '18800000003', 'student1@example.com', 4, '1'),
('2024002', 'Student B', 'F', 1, 1, '2024', '18800000004', 'student2@example.com', 5, '1'),
('2024003', 'Student C', 'M', 1, 2, '2024', '18800000005', 'student3@example.com', 6, '1');

-- 教师
INSERT INTO TB_TEACHER (TEA_NO, TEA_NAME, GENDER, TITLE, DEPT_ID, MOBILE, EMAIL, USER_ID, STATUS) VALUES
('T1001', 'Teacher Zhang', 'M', 'Associate Professor', 1, '18800000001', 'teacher1@example.com', 2, '1'),
('T1002', 'Teacher Li', 'F', 'Lecturer', 1, '18800000002', 'teacher2@example.com', 3, '1');

-- 课程（当前学期 2024-2025-1）
INSERT INTO TB_COURSE (COURSE_NO, COURSE_NAME, COURSE_TYPE, CREDIT, PERIOD, DEPT_ID, TEA_ID, TERM, CAPACITY, SELECTED_NUM, COURSE_DESC, STATUS) VALUES
('C001', 'Database Systems', 'Required', 3.0, 48, 1, 1, '2024-2025-1', 50, 0, 'DB fundamentals and practice', '1'),
('C002', 'Operating Systems', 'Required', 3.0, 48, 1, 2, '2024-2025-1', 40, 0, 'OS principles', '1'),
('C003', 'Python Programming', 'Elective', 2.0, 32, 1, 1, '2024-2025-1', 60, 0, 'Python development cases', '1');

-- 系统参数（时间使用 TIMESTAMP 字段，学期仍用字符）
INSERT INTO TB_SYS_PARAM(PARAM_KEY, PARAM_VALUE, PARAM_VALUE_TS, REMARK) VALUES
('SELECT_START_TIME', NULL, '2024-01-01 00:00:00', '选课开始时间'),
('SELECT_END_TIME',   NULL, '2030-12-31 23:59:59', '选课结束时间'),
('DROP_END_TIME',     NULL, '2030-12-31 23:59:59', '退课截止时间'),
('CURRENT_TERM',      '2024-2025-1', NULL, '当前学期');

-- 示例选课记录：预置一条已选记录便于统计演示
INSERT INTO TB_STUDENT_COURSE(STU_ID, COURSE_ID, TERM, SELECT_TIME, STATUS)
VALUES (1, 1, '2024-2025-1', CURRENT_TIMESTAMP, '1');
