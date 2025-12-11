-- 数据库触发器与存储过程测试脚本
-- 建议先执行 db/04_seed_data_course_selection.sql 以准备基础数据
-- 使用事务包裹，便于测试后回滚

BEGIN;

-- ========== 登录与密码哈希 ==========
SELECT 'L1_admin_hash_exists' AS step, LENGTH(PASSWORD_HASH) > 0 AS ok FROM TB_USER WHERE USERNAME = 'admin';
SELECT 'L2_verify_ok' AS step, FN_VERIFY_PASSWORD('admin', 'admin123') AS ok;
SELECT 'L3_verify_fail' AS step, FN_VERIFY_PASSWORD('admin', 'wrong') AS ok;

DO $$
DECLARE v_success BOOLEAN; v_msg TEXT;
BEGIN
    CALL PROC_SET_PASSWORD(1, 'admin999', v_success, v_msg);
    RAISE NOTICE 'L4 set password -> success=%, msg=%', v_success, v_msg;
END$$;
SELECT 'L5_verify_new_password' AS step, FN_VERIFY_PASSWORD('admin', 'admin999') AS ok;
SELECT 'L6_login_result' AS step, * FROM FN_LOGIN('admin', 'admin999');

-- ========== 触发器测试 ==========
-- 用例 T1：插入 STATUS=1 的选课记录，课程已选人数 +1
SELECT 'T1_before' AS step, COURSE_ID, SELECTED_NUM FROM TB_COURSE WHERE COURSE_ID = 1;
INSERT INTO TB_STUDENT_COURSE(STU_ID, COURSE_ID, TERM, STATUS)
VALUES (2, 1, '2024-2025-1', '1');
SELECT 'T1_after' AS step, COURSE_ID, SELECTED_NUM FROM TB_COURSE WHERE COURSE_ID = 1;

-- 用例 T2：将 STATUS 由 1 改为 0，课程已选人数 -1
UPDATE TB_STUDENT_COURSE
SET STATUS = '0'
WHERE STU_ID = 2 AND COURSE_ID = 1 AND TERM = '2024-2025-1';
SELECT 'T2_after' AS step, COURSE_ID, SELECTED_NUM FROM TB_COURSE WHERE COURSE_ID = 1;

-- 用例 T3：删除 STATUS=1 记录时回收人数
INSERT INTO TB_STUDENT_COURSE(STU_ID, COURSE_ID, TERM, STATUS)
VALUES (3, 1, '2024-2025-1', '1');
SELECT 'T3_before_delete' AS step, COURSE_ID, SELECTED_NUM FROM TB_COURSE WHERE COURSE_ID = 1;
DELETE FROM TB_STUDENT_COURSE WHERE STU_ID = 3 AND COURSE_ID = 1 AND TERM = '2024-2025-1';
SELECT 'T3_after_delete' AS step, COURSE_ID, SELECTED_NUM FROM TB_COURSE WHERE COURSE_ID = 1;

-- ========== PROC_SELECT_COURSE 测试 ==========
-- 用例 P1：正常选课
DO $$
DECLARE v_success BOOLEAN; v_msg TEXT;
BEGIN
    CALL PROC_SELECT_COURSE(2, 2, '2024-2025-1', v_success, v_msg);
    RAISE NOTICE 'P1 正常选课 -> success=%, msg=%', v_success, v_msg;
END$$;
SELECT 'P1_verify' AS step, STATUS FROM TB_STUDENT_COURSE WHERE STU_ID=2 AND COURSE_ID=2 AND TERM='2024-2025-1';

-- 用例 P2：容量已满选课失败（将课程2设置为已满后尝试选课）
UPDATE TB_COURSE SET CAPACITY = 1, SELECTED_NUM = 1 WHERE COURSE_ID = 2;
DO $$
DECLARE v_success BOOLEAN; v_msg TEXT;
BEGIN
    CALL PROC_SELECT_COURSE(3, 2, '2024-2025-1', v_success, v_msg);
    RAISE NOTICE 'P2 课程已满 -> success=%, msg=%', v_success, v_msg;
END$$;

-- 用例 P3：重复选课失败（再次选择课程2）
DO $$
DECLARE v_success BOOLEAN; v_msg TEXT;
BEGIN
    CALL PROC_SELECT_COURSE(2, 2, '2024-2025-1', v_success, v_msg);
    RAISE NOTICE 'P3 重复选课 -> success=%, msg=%', v_success, v_msg;
END$$;

-- 用例 P4：学生状态失效，选课失败
UPDATE TB_STUDENT SET STATUS = '0' WHERE STU_ID = 3;
DO $$
DECLARE v_success BOOLEAN; v_msg TEXT;
BEGIN
    CALL PROC_SELECT_COURSE(3, 3, '2024-2025-1', v_success, v_msg);
    RAISE NOTICE 'P4 学生失效 -> success=%, msg=%', v_success, v_msg;
END$$;
UPDATE TB_STUDENT SET STATUS = '1' WHERE STU_ID = 3;

-- 用例 P5：学期参数为空时使用 CURRENT_TERM
DO $$
DECLARE v_success BOOLEAN; v_msg TEXT;
BEGIN
    CALL PROC_SELECT_COURSE(2, 3, NULL, v_success, v_msg);
    RAISE NOTICE 'P5 默认学期 -> success=%, msg=%', v_success, v_msg;
END$$;

-- ========== PROC_DROP_COURSE 测试 ==========
-- 用例 D1：退课时间内成功退课（保证存在有效记录）
UPDATE TB_COURSE SET CAPACITY = 40 WHERE COURSE_ID = 2; -- 恢复容量
UPDATE TB_SYS_PARAM SET PARAM_VALUE_TS = '2030-12-31 23:59:59' WHERE PARAM_KEY='DROP_END_TIME';
DO $$
DECLARE v_success BOOLEAN; v_msg TEXT;
BEGIN
    CALL PROC_DROP_COURSE(2, 2, '2024-2025-1', v_success, v_msg);
    RAISE NOTICE 'D1 正常退课 -> success=%, msg=%', v_success, v_msg;
END$$;
SELECT 'D1_verify' AS step, STATUS FROM TB_STUDENT_COURSE WHERE STU_ID=2 AND COURSE_ID=2 AND TERM='2024-2025-1';

-- 用例 D1b：退课记录包含 DROP_TIME 且 SELECT_TIME 不被覆盖
SELECT 'D1b_times' AS step, SELECT_TIME, DROP_TIME FROM TB_STUDENT_COURSE WHERE STU_ID=2 AND COURSE_ID=2 AND TERM='2024-2025-1';

-- 用例 D2：超出退课时间退课失败
UPDATE TB_SYS_PARAM SET PARAM_VALUE_TS = '2000-01-01 00:00:00' WHERE PARAM_KEY='DROP_END_TIME';
DO $$
DECLARE v_success BOOLEAN; v_msg TEXT;
BEGIN
    CALL PROC_DROP_COURSE(3, 2, '2024-2025-1', v_success, v_msg);
    RAISE NOTICE 'D2 超时退课 -> success=%, msg=%', v_success, v_msg;
END$$;

-- ========== PROC_STAT_COURSE_SELECT 测试 ==========
-- 用例 S1：统计指定学期选课结果
SELECT * FROM PROC_STAT_COURSE_SELECT('2024-2025-1');
-- 用例 S2：学期为空时使用 CURRENT_TERM
SELECT * FROM PROC_STAT_COURSE_SELECT(NULL);

-- 回滚测试数据
ROLLBACK;
