-- Stored procedures and helper functions for course selection (Kingbase/PostgreSQL compatible)

-- Cleanup
DROP FUNCTION IF EXISTS FN_HASH_PASSWORD(TEXT);
DROP FUNCTION IF EXISTS FN_VERIFY_PASSWORD(TEXT, TEXT);
DROP FUNCTION IF EXISTS FN_LOGIN(TEXT, TEXT);
DROP PROCEDURE IF EXISTS PROC_SET_PASSWORD(INT, TEXT, BOOLEAN, TEXT);
DROP PROCEDURE IF EXISTS PROC_SELECT_COURSE(INT, INT, VARCHAR, BOOLEAN, TEXT);
DROP PROCEDURE IF EXISTS PROC_DROP_COURSE(INT, INT, VARCHAR, BOOLEAN, TEXT);
DROP PROCEDURE IF EXISTS PROC_JOIN_WAITLIST(INT, INT, VARCHAR, BOOLEAN, TEXT);
DROP PROCEDURE IF EXISTS PROC_PROCESS_WAITLIST(INT, VARCHAR, INT, BOOLEAN, TEXT);
DROP FUNCTION IF EXISTS FN_JOIN_WAITLIST(INT, INT, VARCHAR);
DROP FUNCTION IF EXISTS FN_PROCESS_WAITLIST(INT, VARCHAR);
DROP FUNCTION IF EXISTS FN_CHECK_TIME_CONFLICT(INT, INT, VARCHAR);
DROP FUNCTION IF EXISTS FN_STUDENT_TIMETABLE(INT, VARCHAR);
DROP FUNCTION IF EXISTS FN_WAITLIST_BY_STUDENT(INT, VARCHAR);
DROP FUNCTION IF EXISTS PROC_STAT_COURSE_SELECT(VARCHAR);
DROP FUNCTION IF EXISTS FN_STAT_COURSE_TOPN(VARCHAR, INT);
DROP FUNCTION IF EXISTS FN_STAT_DEPT_DISTRIBUTION(VARCHAR);
DROP FUNCTION IF EXISTS FN_STAT_SELECT_TREND(VARCHAR, VARCHAR);

-- Salted password hashing (backward-compatible with legacy md5 hashes)
CREATE OR REPLACE FUNCTION FN_HASH_PASSWORD(
    p_plain_password TEXT
) RETURNS TEXT
AS $$
DECLARE
    v_salt TEXT := substr(md5(random()::text || clock_timestamp()::text), 1, 16);
BEGIN
    IF p_plain_password IS NULL OR LENGTH(TRIM(p_plain_password)) = 0 THEN
        RETURN NULL;
    END IF;
    RETURN v_salt || ':' || md5(v_salt || '|' || TRIM(p_plain_password));
END;
$$ LANGUAGE plpgsql;

-- Password verification with salt support; falls back to legacy md5(plain) if no salt stored
CREATE OR REPLACE FUNCTION FN_VERIFY_PASSWORD(
    p_username TEXT,
    p_plain_password TEXT
) RETURNS BOOLEAN
AS $$
DECLARE
    v_hash TEXT;
    v_salt TEXT;
    v_expected TEXT;
BEGIN
    SELECT PASSWORD_HASH INTO v_hash FROM TB_USER WHERE USERNAME = p_username;
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    -- Legacy hash (no salt)
    IF POSITION(':' IN v_hash) = 0 THEN
        RETURN md5(p_plain_password) = v_hash;
    END IF;

    v_salt := split_part(v_hash, ':', 1);
    v_expected := split_part(v_hash, ':', 2);

    IF v_salt IS NULL OR v_expected IS NULL OR v_expected = '' THEN
        RETURN FALSE;
    END IF;

    RETURN md5(v_salt || '|' || p_plain_password) = v_expected;
END;
$$ LANGUAGE plpgsql;

-- Login helper: return user and linked student/teacher ids
CREATE OR REPLACE FUNCTION FN_LOGIN(
    p_username TEXT,
    p_plain_password TEXT
) RETURNS TABLE (
    USER_ID INT,
    USERNAME VARCHAR,
    ROLE VARCHAR,
    STATUS CHAR(1),
    STU_ID INT,
    TEA_ID INT
)
AS $$
DECLARE
    v_ok BOOLEAN := FALSE;
BEGIN
    v_ok := FN_VERIFY_PASSWORD(p_username, p_plain_password);
    IF NOT v_ok THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT u.USER_ID,
           u.USERNAME,
           u.ROLE,
           u.STATUS,
           s.STU_ID,
           t.TEA_ID
    FROM TB_USER u
    LEFT JOIN TB_STUDENT s ON s.USER_ID = u.USER_ID
    LEFT JOIN TB_TEACHER t ON t.USER_ID = u.USER_ID
    WHERE u.USERNAME = p_username
      AND u.STATUS = '1';
END;
$$ LANGUAGE plpgsql;

-- Password update
CREATE OR REPLACE PROCEDURE PROC_SET_PASSWORD(
    IN p_user_id INT,
    IN p_plain_password TEXT,
    INOUT p_success BOOLEAN,
    INOUT p_message TEXT
)
AS $$
BEGIN
    p_success := FALSE;
    p_message := '';

    IF p_plain_password IS NULL OR LENGTH(TRIM(p_plain_password)) < 6 THEN
        p_message := 'password too short';
        RETURN;
    END IF;

    UPDATE TB_USER
    SET PASSWORD_HASH = FN_HASH_PASSWORD(TRIM(p_plain_password)),
        PASSWORD_UPDATED_AT = CURRENT_TIMESTAMP
    WHERE USER_ID = p_user_id;

    IF NOT FOUND THEN
        p_message := 'user not found';
        RETURN;
    END IF;

    p_success := TRUE;
    p_message := 'password updated';
EXCEPTION WHEN OTHERS THEN
    p_success := FALSE;
    p_message := COALESCE(SQLERRM, 'password update failed');
END;
$$ LANGUAGE plpgsql;

-- Check timetable conflicts between an existing student's active selections and a target course
CREATE OR REPLACE FUNCTION FN_CHECK_TIME_CONFLICT(
    p_stu_id INT,
    p_course_id INT,
    p_term VARCHAR
) RETURNS TABLE (
    CONFLICT BOOLEAN,
    CONFLICT_COURSE_ID INT,
    CONFLICT_COURSE_NAME VARCHAR,
    DAY_OF_WEEK SMALLINT,
    START_SLOT SMALLINT,
    END_SLOT SMALLINT
) AS $$
DECLARE
    v_term VARCHAR(20);
    v_count INT := 0;
BEGIN
    SELECT COALESCE(
               NULLIF(TRIM(p_term), ''),
               (SELECT PARAM_VALUE FROM TB_SYS_PARAM WHERE PARAM_KEY = 'CURRENT_TERM' AND PARAM_VALUE IS NOT NULL),
               (SELECT TERM FROM TB_COURSE WHERE COURSE_ID = p_course_id)
           )
    INTO v_term;
    IF v_term IS NULL THEN
        RETURN QUERY SELECT FALSE, NULL::INT, NULL::VARCHAR, NULL::SMALLINT, NULL::SMALLINT, NULL::SMALLINT;
        RETURN;
    END IF;

    RETURN QUERY
    WITH target AS (
        SELECT ct.DAY_OF_WEEK, ct.START_SLOT, ct.END_SLOT
        FROM TB_COURSE_TIME ct
        WHERE ct.COURSE_ID = p_course_id AND ct.TERM = v_term
    ), mine AS (
        SELECT sc.COURSE_ID,
               c.COURSE_NAME,
               ct.DAY_OF_WEEK,
               ct.START_SLOT,
               ct.END_SLOT
        FROM TB_STUDENT_COURSE sc
        JOIN TB_COURSE_TIME ct ON ct.COURSE_ID = sc.COURSE_ID AND ct.TERM = sc.TERM
        JOIN TB_COURSE c ON c.COURSE_ID = sc.COURSE_ID
        WHERE sc.STU_ID = p_stu_id
          AND sc.TERM = v_term
          AND sc.STATUS = '1'
    )
    SELECT TRUE AS CONFLICT,
           m.COURSE_ID AS CONFLICT_COURSE_ID,
           m.COURSE_NAME AS CONFLICT_COURSE_NAME,
           m.DAY_OF_WEEK,
           GREATEST(m.START_SLOT, t.START_SLOT) AS START_SLOT,
           LEAST(m.END_SLOT, t.END_SLOT) AS END_SLOT
    FROM mine m
    JOIN target t ON m.DAY_OF_WEEK = t.DAY_OF_WEEK
    WHERE m.END_SLOT >= t.START_SLOT AND t.END_SLOT >= m.START_SLOT;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    IF v_count = 0 THEN
        RETURN QUERY SELECT FALSE, NULL::INT, NULL::VARCHAR, NULL::SMALLINT, NULL::SMALLINT, NULL::SMALLINT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 学生课表（含时间地点），供前端周视图使用
CREATE OR REPLACE FUNCTION FN_STUDENT_TIMETABLE(
    p_stu_id INT,
    p_term VARCHAR
) RETURNS TABLE (
    COURSE_ID INT,
    COURSE_NO VARCHAR(20),
    COURSE_NAME VARCHAR(100),
    TEACHER_NAME VARCHAR(50),
    DAY_OF_WEEK SMALLINT,
    START_SLOT SMALLINT,
    END_SLOT SMALLINT,
    LOCATION VARCHAR(100),
    TERM VARCHAR(20)
) AS $$
DECLARE
    v_term VARCHAR(20);
BEGIN
    SELECT COALESCE(
               NULLIF(TRIM(p_term), ''),
               (SELECT PARAM_VALUE FROM TB_SYS_PARAM WHERE PARAM_KEY = 'CURRENT_TERM' AND PARAM_VALUE IS NOT NULL)
           )
    INTO v_term;
    IF v_term IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT sc.COURSE_ID,
           c.COURSE_NO,
           c.COURSE_NAME,
           t.TEA_NAME,
           ct.DAY_OF_WEEK,
           ct.START_SLOT,
           ct.END_SLOT,
           COALESCE(ct.LOCATION, c.LOCATION) AS LOCATION,
           sc.TERM
    FROM TB_STUDENT_COURSE sc
    JOIN TB_COURSE c ON c.COURSE_ID = sc.COURSE_ID
    LEFT JOIN TB_TEACHER t ON t.TEA_ID = c.TEA_ID
    LEFT JOIN TB_COURSE_TIME ct ON ct.COURSE_ID = sc.COURSE_ID AND ct.TERM = sc.TERM
    WHERE sc.STU_ID = p_stu_id
      AND sc.TERM = v_term
      AND sc.STATUS = '1';
END;
$$ LANGUAGE plpgsql;

-- 学生候补列表
CREATE OR REPLACE FUNCTION FN_WAITLIST_BY_STUDENT(
    p_stu_id INT,
    p_term VARCHAR
) RETURNS TABLE (
    WL_ID INT,
    COURSE_ID INT,
    COURSE_NO VARCHAR(20),
    COURSE_NAME VARCHAR(100),
    STATUS VARCHAR(20),
    MESSAGE VARCHAR(200),
    CREATED_AT TIMESTAMP,
    PROCESSED_AT TIMESTAMP,
    TERM VARCHAR(20)
) AS $$
DECLARE
    v_term VARCHAR(20);
BEGIN
    SELECT COALESCE(
               NULLIF(TRIM(p_term), ''),
               (SELECT PARAM_VALUE FROM TB_SYS_PARAM WHERE PARAM_KEY = 'CURRENT_TERM' AND PARAM_VALUE IS NOT NULL)
           )
    INTO v_term;
    IF v_term IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT wl.WL_ID,
           wl.COURSE_ID,
           c.COURSE_NO,
           c.COURSE_NAME,
           wl.STATUS,
           wl.MESSAGE,
           wl.CREATED_AT,
           wl.PROCESSED_AT,
           wl.TERM
    FROM TB_WAITLIST wl
    LEFT JOIN TB_COURSE c ON c.COURSE_ID = wl.COURSE_ID
    WHERE wl.STU_ID = p_stu_id
      AND wl.TERM = v_term
    ORDER BY wl.CREATED_AT;
END;
$$ LANGUAGE plpgsql;

-- Student course selection
CREATE OR REPLACE PROCEDURE PROC_SELECT_COURSE(
    IN p_stu_id INT,
    IN p_course_id INT,
    IN p_term VARCHAR,
    INOUT p_success BOOLEAN,
    INOUT p_message TEXT
)
AS $$
DECLARE
    v_now TIMESTAMP := CURRENT_TIMESTAMP;
    v_select_start TIMESTAMP;
    v_select_end TIMESTAMP;
    v_course_status CHAR(1);
    v_capacity INT;
    v_selected INT;
    v_course_term VARCHAR(20);
    v_course_tea_id INT;
    v_existing_status CHAR(1);
    v_term VARCHAR(20);
    v_stu_status CHAR(1);
    v_stu_user_status CHAR(1);
    v_tea_status CHAR(1);
    v_tea_user_status CHAR(1);
    v_conflict RECORD;
BEGIN
    p_success := FALSE;
    p_message := '';

    SELECT COALESCE(
               NULLIF(TRIM(p_term), ''),
               (SELECT PARAM_VALUE FROM TB_SYS_PARAM WHERE PARAM_KEY = 'CURRENT_TERM' AND PARAM_VALUE IS NOT NULL)
           )
    INTO v_term;
    IF v_term IS NULL THEN
        SELECT TERM INTO v_term FROM TB_COURSE WHERE COURSE_ID = p_course_id;
    END IF;
    IF v_term IS NULL THEN
        p_message := 'term missing';
        RETURN;
    END IF;

    SELECT PARAM_VALUE_TS INTO v_select_start FROM TB_SYS_PARAM WHERE PARAM_KEY = 'SELECT_START_TIME';
    SELECT PARAM_VALUE_TS INTO v_select_end FROM TB_SYS_PARAM WHERE PARAM_KEY = 'SELECT_END_TIME';

    IF v_select_start IS NOT NULL AND v_now < v_select_start THEN
        p_message := 'selection not started';
        RETURN;
    END IF;
    IF v_select_end IS NOT NULL AND v_now > v_select_end THEN
        p_message := 'selection ended';
        RETURN;
    END IF;

    SELECT s.STATUS, u.STATUS
    INTO v_stu_status, v_stu_user_status
    FROM TB_STUDENT s
    LEFT JOIN TB_USER u ON s.USER_ID = u.USER_ID
    WHERE s.STU_ID = p_stu_id;

    IF NOT FOUND THEN
        p_message := 'student not found';
        RETURN;
    END IF;
    IF v_stu_status <> '1' OR v_stu_user_status <> '1' THEN
        p_message := 'student disabled';
        RETURN;
    END IF;

    SELECT STATUS, CAPACITY, SELECTED_NUM, TERM, TEA_ID
    INTO v_course_status, v_capacity, v_selected, v_course_term, v_course_tea_id
    FROM TB_COURSE
    WHERE COURSE_ID = p_course_id
    FOR UPDATE;

    IF NOT FOUND THEN
        p_message := 'course not found';
        RETURN;
    END IF;

    IF v_course_status <> '1' THEN
        p_message := 'course unavailable';
        RETURN;
    END IF;

    IF v_course_term IS NOT NULL AND v_course_term <> v_term THEN
        p_message := 'term mismatch';
        RETURN;
    END IF;

    SELECT * INTO v_conflict
    FROM FN_CHECK_TIME_CONFLICT(p_stu_id, p_course_id, v_term)
    WHERE CONFLICT = TRUE
    LIMIT 1;
    IF FOUND THEN
        p_message := COALESCE(format('time conflict with %s', v_conflict.CONFLICT_COURSE_NAME), 'time conflict');
        RETURN;
    END IF;

    IF v_selected >= v_capacity THEN
        p_message := 'course full; you may join waitlist';
        RETURN;
    END IF;

    SELECT t.STATUS, u.STATUS
    INTO v_tea_status, v_tea_user_status
    FROM TB_TEACHER t
    LEFT JOIN TB_USER u ON t.USER_ID = u.USER_ID
    WHERE t.TEA_ID = v_course_tea_id;

    IF FOUND THEN
        IF v_tea_status <> '1' OR v_tea_user_status <> '1' THEN
            p_message := 'teacher disabled';
            RETURN;
        END IF;
    END IF;

    SELECT STATUS INTO v_existing_status
    FROM TB_STUDENT_COURSE
    WHERE STU_ID = p_stu_id AND COURSE_ID = p_course_id AND TERM = v_term
    FOR UPDATE;

    IF FOUND THEN
        IF v_existing_status = '1' THEN
            p_message := 'course already selected';
            RETURN;
        ELSE
            UPDATE TB_STUDENT_COURSE
            SET STATUS = '1',
                SELECT_TIME = v_now,
                DROP_TIME = NULL
            WHERE STU_ID = p_stu_id AND COURSE_ID = p_course_id AND TERM = v_term;
            DELETE FROM TB_WAITLIST WHERE STU_ID = p_stu_id AND COURSE_ID = p_course_id AND TERM = v_term;
            p_success := TRUE;
            p_message := 'selection restored';
            RETURN;
        END IF;
    END IF;

    INSERT INTO TB_STUDENT_COURSE(STU_ID, COURSE_ID, TERM, SELECT_TIME, DROP_TIME, STATUS)
    VALUES (p_stu_id, p_course_id, v_term, v_now, NULL, '1');

    -- 清理可能存在的候补记录
    DELETE FROM TB_WAITLIST WHERE STU_ID = p_stu_id AND COURSE_ID = p_course_id AND TERM = v_term;

    p_success := TRUE;
    p_message := 'selection ok';
EXCEPTION WHEN OTHERS THEN
    p_success := FALSE;
    p_message := COALESCE(SQLERRM, 'selection failed');
END;
$$ LANGUAGE plpgsql;

-- Student drop course
CREATE OR REPLACE PROCEDURE PROC_DROP_COURSE(
    IN p_stu_id INT,
    IN p_course_id INT,
    IN p_term VARCHAR,
    INOUT p_success BOOLEAN,
    INOUT p_message TEXT
)
AS $$
DECLARE
    v_now TIMESTAMP := CURRENT_TIMESTAMP;
    v_drop_end TIMESTAMP;
    v_old_status CHAR(1);
    v_term VARCHAR(20);
    v_stu_status CHAR(1);
    v_stu_user_status CHAR(1);
    v_processed INT := 0;
    v_proc_success BOOLEAN;
    v_proc_message TEXT;
BEGIN
    p_success := FALSE;
    p_message := '';

    SELECT COALESCE(
               NULLIF(TRIM(p_term), ''),
               (SELECT PARAM_VALUE FROM TB_SYS_PARAM WHERE PARAM_KEY = 'CURRENT_TERM' AND PARAM_VALUE IS NOT NULL)
           )
    INTO v_term;
    IF v_term IS NULL THEN
        SELECT TERM INTO v_term FROM TB_COURSE WHERE COURSE_ID = p_course_id;
    END IF;
    IF v_term IS NULL THEN
        p_message := 'term missing';
        RETURN;
    END IF;

    SELECT PARAM_VALUE_TS INTO v_drop_end FROM TB_SYS_PARAM WHERE PARAM_KEY = 'DROP_END_TIME';

    IF v_drop_end IS NOT NULL AND v_now > v_drop_end THEN
        p_message := 'drop expired';
        RETURN;
    END IF;

    SELECT s.STATUS, u.STATUS
    INTO v_stu_status, v_stu_user_status
    FROM TB_STUDENT s
    LEFT JOIN TB_USER u ON s.USER_ID = u.USER_ID
    WHERE s.STU_ID = p_stu_id;

    IF NOT FOUND THEN
        p_message := 'student not found';
        RETURN;
    END IF;
    IF v_stu_status <> '1' OR v_stu_user_status <> '1' THEN
        p_message := 'student disabled';
        RETURN;
    END IF;

    SELECT STATUS INTO v_old_status
    FROM TB_STUDENT_COURSE
    WHERE STU_ID = p_stu_id AND COURSE_ID = p_course_id AND TERM = v_term
    FOR UPDATE;

    IF NOT FOUND OR v_old_status <> '1' THEN
        p_message := 'no active record';
        RETURN;
    END IF;

    UPDATE TB_STUDENT_COURSE
    SET STATUS = '0',
        DROP_TIME = v_now
    WHERE STU_ID = p_stu_id AND COURSE_ID = p_course_id AND TERM = v_term;

    p_success := TRUE;
    p_message := 'drop ok';

    -- 退课后尝试处理候补队列（忽略失败，以主流程为准）
    BEGIN
        CALL PROC_PROCESS_WAITLIST(p_course_id, v_term, v_processed, v_proc_success, v_proc_message);
    EXCEPTION WHEN OTHERS THEN
        -- ignore waitlist errors to keep drop path stable
        NULL;
    END;
EXCEPTION WHEN OTHERS THEN
    p_success := FALSE;
    p_message := COALESCE(SQLERRM, 'drop failed');
END;
$$ LANGUAGE plpgsql;

-- 加入候补队列（课程满员时使用）
CREATE OR REPLACE PROCEDURE PROC_JOIN_WAITLIST(
    IN p_stu_id INT,
    IN p_course_id INT,
    IN p_term VARCHAR,
    INOUT p_success BOOLEAN,
    INOUT p_message TEXT
)
AS $$
DECLARE
    v_term VARCHAR(20);
    v_course_status CHAR(1);
    v_capacity INT;
    v_selected INT;
    v_stu_status CHAR(1);
    v_stu_user_status CHAR(1);
    v_existing_status CHAR(1);
BEGIN
    p_success := FALSE;
    p_message := '';

    SELECT COALESCE(
               NULLIF(TRIM(p_term), ''),
               (SELECT PARAM_VALUE FROM TB_SYS_PARAM WHERE PARAM_KEY = 'CURRENT_TERM' AND PARAM_VALUE IS NOT NULL),
               (SELECT TERM FROM TB_COURSE WHERE COURSE_ID = p_course_id)
           )
    INTO v_term;
    IF v_term IS NULL THEN
        p_message := 'term missing';
        RETURN;
    END IF;

    SELECT s.STATUS, u.STATUS
    INTO v_stu_status, v_stu_user_status
    FROM TB_STUDENT s
    LEFT JOIN TB_USER u ON s.USER_ID = u.USER_ID
    WHERE s.STU_ID = p_stu_id;

    IF NOT FOUND OR v_stu_status <> '1' OR v_stu_user_status <> '1' THEN
        p_message := 'student disabled';
        RETURN;
    END IF;

    SELECT STATUS, CAPACITY, SELECTED_NUM
    INTO v_course_status, v_capacity, v_selected
    FROM TB_COURSE
    WHERE COURSE_ID = p_course_id AND TERM = v_term
    FOR UPDATE;

    IF NOT FOUND THEN
        p_message := 'course not found';
        RETURN;
    END IF;
    IF v_course_status <> '1' THEN
        p_message := 'course unavailable';
        RETURN;
    END IF;

    SELECT STATUS INTO v_existing_status
    FROM TB_STUDENT_COURSE
    WHERE STU_ID = p_stu_id AND COURSE_ID = p_course_id AND TERM = v_term
    FOR UPDATE;

    IF FOUND AND v_existing_status = '1' THEN
        p_message := 'course already selected';
        RETURN;
    END IF;

    IF v_selected < v_capacity THEN
        p_message := 'course not full';
        RETURN;
    END IF;

    INSERT INTO TB_WAITLIST (STU_ID, COURSE_ID, TERM, STATUS, MESSAGE)
    VALUES (p_stu_id, p_course_id, v_term, 'PENDING', NULL)
    ON CONFLICT (STU_ID, COURSE_ID, TERM)
    DO UPDATE SET STATUS = 'PENDING', MESSAGE = NULL, PROCESSED_AT = NULL;

    p_success := TRUE;
    p_message := 'waitlist joined';
EXCEPTION WHEN OTHERS THEN
    p_success := FALSE;
    p_message := COALESCE(SQLERRM, 'waitlist failed');
END;
$$ LANGUAGE plpgsql;

-- 处理候补队列：按创建时间顺序尝试补位
CREATE OR REPLACE PROCEDURE PROC_PROCESS_WAITLIST(
    IN p_course_id INT,
    IN p_term VARCHAR,
    INOUT p_processed INT,
    INOUT p_success BOOLEAN,
    INOUT p_message TEXT
)
AS $$
DECLARE
    v_term VARCHAR(20);
    v_row RECORD;
    v_select_ok BOOLEAN;
    v_select_msg TEXT;
    v_capacity INT;
    v_selected INT;
BEGIN
    p_processed := 0;
    p_success := FALSE;
    p_message := '';

    SELECT COALESCE(
               NULLIF(TRIM(p_term), ''),
               (SELECT PARAM_VALUE FROM TB_SYS_PARAM WHERE PARAM_KEY = 'CURRENT_TERM' AND PARAM_VALUE IS NOT NULL),
               (SELECT TERM FROM TB_COURSE WHERE COURSE_ID = p_course_id)
           )
    INTO v_term;
    IF v_term IS NULL THEN
        p_message := 'term missing';
        RETURN;
    END IF;

    SELECT CAPACITY, SELECTED_NUM
    INTO v_capacity, v_selected
    FROM TB_COURSE
    WHERE COURSE_ID = p_course_id AND TERM = v_term
    FOR UPDATE;

    IF NOT FOUND THEN
        p_message := 'course not found';
        RETURN;
    END IF;

    FOR v_row IN
        SELECT WL_ID, STU_ID
        FROM TB_WAITLIST
        WHERE COURSE_ID = p_course_id AND TERM = v_term AND STATUS = 'PENDING'
        ORDER BY CREATED_AT, WL_ID
    LOOP
        EXIT WHEN v_selected >= v_capacity;
        BEGIN
            CALL PROC_SELECT_COURSE(v_row.STU_ID, p_course_id, v_term, v_select_ok, v_select_msg);
            IF v_select_ok THEN
                UPDATE TB_WAITLIST
                SET STATUS = 'CONFIRMED',
                    MESSAGE = 'auto enrolled',
                    PROCESSED_AT = CURRENT_TIMESTAMP
                WHERE WL_ID = v_row.WL_ID;
                p_processed := p_processed + 1;
                v_selected := v_selected + 1;
            ELSE
                UPDATE TB_WAITLIST
                SET STATUS = 'FAILED',
                    MESSAGE = v_select_msg,
                    PROCESSED_AT = CURRENT_TIMESTAMP
                WHERE WL_ID = v_row.WL_ID;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            UPDATE TB_WAITLIST
            SET STATUS = 'FAILED',
                MESSAGE = COALESCE(SQLERRM, 'process failed'),
                PROCESSED_AT = CURRENT_TIMESTAMP
            WHERE WL_ID = v_row.WL_ID;
        END;
    END LOOP;

    p_success := TRUE;
    p_message := 'waitlist processed';
END;
$$ LANGUAGE plpgsql;

-- Wrapper functions for procedures above
CREATE OR REPLACE FUNCTION FN_JOIN_WAITLIST(
    p_stu_id INT,
    p_course_id INT,
    p_term VARCHAR
) RETURNS TABLE(success BOOLEAN, message TEXT)
AS $$
DECLARE v_success BOOLEAN; v_msg TEXT;
BEGIN
    CALL PROC_JOIN_WAITLIST(p_stu_id, p_course_id, p_term, v_success, v_msg);
    RETURN QUERY SELECT v_success, v_msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION FN_PROCESS_WAITLIST(
    p_course_id INT,
    p_term VARCHAR
) RETURNS TABLE(processed INT, success BOOLEAN, message TEXT)
AS $$
DECLARE v_processed INT; v_success BOOLEAN; v_msg TEXT;
BEGIN
    CALL PROC_PROCESS_WAITLIST(p_course_id, p_term, v_processed, v_success, v_msg);
    RETURN QUERY SELECT COALESCE(v_processed, 0), v_success, v_msg;
END;
$$ LANGUAGE plpgsql;

-- Selection statistics
CREATE OR REPLACE FUNCTION PROC_STAT_COURSE_SELECT(p_term VARCHAR)
RETURNS TABLE (
    COURSE_NO VARCHAR(20),
    COURSE_NAME VARCHAR(100),
    TEACHER_NAME VARCHAR(50),
    CAPACITY INT,
    SELECTED_NUM INT,
    REMAINING INT
) AS $$
DECLARE
    v_term VARCHAR(20);
BEGIN
    SELECT COALESCE(
               NULLIF(TRIM(p_term), ''),
               (SELECT PARAM_VALUE FROM TB_SYS_PARAM WHERE PARAM_KEY = 'CURRENT_TERM' AND PARAM_VALUE IS NOT NULL)
           )
    INTO v_term;
    IF v_term IS NULL THEN
        RAISE EXCEPTION 'term missing';
    END IF;

    RETURN QUERY
    SELECT c.COURSE_NO,
           c.COURSE_NAME,
           t.TEA_NAME,
           c.CAPACITY,
           c.SELECTED_NUM,
           c.CAPACITY - c.SELECTED_NUM AS REMAINING
    FROM TB_COURSE c
    LEFT JOIN TB_TEACHER t ON c.TEA_ID = t.TEA_ID
    WHERE c.TERM = v_term;
END;
$$ LANGUAGE plpgsql;

-- Wrapper functions to simplify API access (returns success/message)
CREATE OR REPLACE FUNCTION FN_SELECT_COURSE(
    p_stu_id INT,
    p_course_id INT,
    p_term VARCHAR
) RETURNS TABLE(success BOOLEAN, message TEXT)
AS $$
DECLARE v_success BOOLEAN; v_msg TEXT;
BEGIN
    CALL PROC_SELECT_COURSE(p_stu_id, p_course_id, p_term, v_success, v_msg);
    RETURN QUERY SELECT v_success, v_msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION FN_DROP_COURSE(
    p_stu_id INT,
    p_course_id INT,
    p_term VARCHAR
) RETURNS TABLE(success BOOLEAN, message TEXT)
AS $$
DECLARE v_success BOOLEAN; v_msg TEXT;
BEGIN
    CALL PROC_DROP_COURSE(p_stu_id, p_course_id, p_term, v_success, v_msg);
    RETURN QUERY SELECT v_success, v_msg;
END;
$$ LANGUAGE plpgsql;

-- TopN 课程统计
CREATE OR REPLACE FUNCTION FN_STAT_COURSE_TOPN(
    p_term VARCHAR,
    p_limit INT DEFAULT 10
) RETURNS TABLE (
    COURSE_NO VARCHAR(20),
    COURSE_NAME VARCHAR(100),
    TEACHER_NAME VARCHAR(50),
    SELECTED_NUM INT,
    CAPACITY INT,
    REMAINING INT
) AS $$
DECLARE
    v_term VARCHAR(20);
    v_limit INT := COALESCE(NULLIF(p_limit, 0), 10);
BEGIN
    SELECT COALESCE(
               NULLIF(TRIM(p_term), ''),
               (SELECT PARAM_VALUE FROM TB_SYS_PARAM WHERE PARAM_KEY = 'CURRENT_TERM' AND PARAM_VALUE IS NOT NULL)
           )
    INTO v_term;
    IF v_term IS NULL THEN
        RAISE EXCEPTION 'term missing';
    END IF;

    RETURN QUERY
    SELECT c.COURSE_NO,
           c.COURSE_NAME,
           t.TEA_NAME,
           c.SELECTED_NUM,
           c.CAPACITY,
           c.CAPACITY - c.SELECTED_NUM AS REMAINING
    FROM TB_COURSE c
    LEFT JOIN TB_TEACHER t ON c.TEA_ID = t.TEA_ID
    WHERE c.TERM = v_term
    ORDER BY c.SELECTED_NUM DESC, c.COURSE_NO
    LIMIT v_limit;
END;
$$ LANGUAGE plpgsql;

-- 学院分布统计
CREATE OR REPLACE FUNCTION FN_STAT_DEPT_DISTRIBUTION(
    p_term VARCHAR
) RETURNS TABLE (
    DEPT_ID INT,
    DEPT_NAME VARCHAR(100),
    COURSE_COUNT INT,
    SELECTED_TOTAL INT,
    CAPACITY_TOTAL INT,
    REMAINING_TOTAL INT,
    FILL_RATE NUMERIC
) AS $$
DECLARE
    v_term VARCHAR(20);
BEGIN
    SELECT COALESCE(
               NULLIF(TRIM(p_term), ''),
               (SELECT PARAM_VALUE FROM TB_SYS_PARAM WHERE PARAM_KEY = 'CURRENT_TERM' AND PARAM_VALUE IS NOT NULL)
           )
    INTO v_term;
    IF v_term IS NULL THEN
        RAISE EXCEPTION 'term missing';
    END IF;

    RETURN QUERY
    SELECT d.DEPT_ID,
           d.DEPT_NAME,
           COUNT(c.COURSE_ID)::INT AS COURSE_COUNT,
           COALESCE(SUM(c.SELECTED_NUM), 0)::INT AS SELECTED_TOTAL,
           COALESCE(SUM(c.CAPACITY), 0)::INT AS CAPACITY_TOTAL,
           COALESCE(SUM(c.CAPACITY - c.SELECTED_NUM), 0)::INT AS REMAINING_TOTAL,
           CASE
               WHEN COALESCE(SUM(c.CAPACITY), 0) = 0 THEN 0
               ELSE ROUND(SUM(c.SELECTED_NUM)::NUMERIC / NULLIF(SUM(c.CAPACITY), 0), 4)
           END AS FILL_RATE
    FROM TB_DEPARTMENT d
    LEFT JOIN TB_COURSE c ON c.DEPT_ID = d.DEPT_ID AND c.TERM = v_term
    GROUP BY d.DEPT_ID, d.DEPT_NAME
    ORDER BY FILL_RATE DESC, d.DEPT_NAME;
END;
$$ LANGUAGE plpgsql;

-- 选课趋势统计（按日/小时）
CREATE OR REPLACE FUNCTION FN_STAT_SELECT_TREND(
    p_term VARCHAR,
    p_bucket VARCHAR DEFAULT 'day'
) RETURNS TABLE (
    BUCKET_LABEL TEXT,
    BUCKET_START TIMESTAMP,
    TOTAL INT
) AS $$
DECLARE
    v_term VARCHAR(20);
    v_bucket TEXT;
    v_trunc TEXT;
    v_fmt TEXT;
BEGIN
    SELECT COALESCE(
               NULLIF(TRIM(p_term), ''),
               (SELECT PARAM_VALUE FROM TB_SYS_PARAM WHERE PARAM_KEY = 'CURRENT_TERM' AND PARAM_VALUE IS NOT NULL)
           )
    INTO v_term;
    IF v_term IS NULL THEN
        RAISE EXCEPTION 'term missing';
    END IF;

    v_bucket := lower(COALESCE(NULLIF(TRIM(p_bucket), ''), 'day'));
    v_trunc := CASE WHEN v_bucket = 'hour' THEN 'hour' ELSE 'day' END;
    v_fmt := CASE WHEN v_bucket = 'hour' THEN 'YYYY-MM-DD HH24:00' ELSE 'YYYY-MM-DD' END;

    RETURN QUERY
    SELECT to_char(date_trunc(v_trunc, sc.SELECT_TIME), v_fmt) AS BUCKET_LABEL,
           date_trunc(v_trunc, sc.SELECT_TIME) AS BUCKET_START,
           COUNT(*)::INT AS TOTAL
    FROM TB_STUDENT_COURSE sc
    WHERE sc.TERM = v_term
      AND sc.STATUS = '1'
    GROUP BY date_trunc(v_trunc, sc.SELECT_TIME)
    ORDER BY BUCKET_START;
END;
$$ LANGUAGE plpgsql;
