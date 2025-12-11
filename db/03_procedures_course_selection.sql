-- Stored procedures and helper functions for course selection (Kingbase/PostgreSQL compatible)

-- Cleanup
DROP FUNCTION IF EXISTS FN_VERIFY_PASSWORD(TEXT, TEXT);
DROP FUNCTION IF EXISTS FN_LOGIN(TEXT, TEXT);
DROP PROCEDURE IF EXISTS PROC_SET_PASSWORD(INT, TEXT, BOOLEAN, TEXT);
DROP PROCEDURE IF EXISTS PROC_SELECT_COURSE(INT, INT, VARCHAR, BOOLEAN, TEXT);
DROP PROCEDURE IF EXISTS PROC_DROP_COURSE(INT, INT, VARCHAR, BOOLEAN, TEXT);
DROP FUNCTION IF EXISTS PROC_STAT_COURSE_SELECT(VARCHAR);

-- Password verification with md5
CREATE OR REPLACE FUNCTION FN_VERIFY_PASSWORD(
    p_username TEXT,
    p_plain_password TEXT
) RETURNS BOOLEAN
AS $$
DECLARE
    v_hash TEXT;
BEGIN
    SELECT PASSWORD_HASH INTO v_hash FROM TB_USER WHERE USERNAME = p_username;
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    RETURN md5(p_plain_password) = v_hash;
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
    SET PASSWORD_HASH = md5(TRIM(p_plain_password)),
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
BEGIN
    p_success := FALSE;
    p_message := '';

    SELECT COALESCE(NULLIF(TRIM(p_term), ''), (SELECT PARAM_VALUE FROM TB_SYS_PARAM WHERE PARAM_KEY = 'CURRENT_TERM')) INTO v_term;
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

    IF v_selected >= v_capacity THEN
        p_message := 'course full';
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
            p_message := '课程已选上';
            RETURN;
        ELSE
            UPDATE TB_STUDENT_COURSE
            SET STATUS = '1',
                SELECT_TIME = v_now,
                DROP_TIME = NULL
            WHERE STU_ID = p_stu_id AND COURSE_ID = p_course_id AND TERM = v_term;
            p_success := TRUE;
            p_message := 'selection restored';
            RETURN;
        END IF;
    END IF;

    INSERT INTO TB_STUDENT_COURSE(STU_ID, COURSE_ID, TERM, SELECT_TIME, DROP_TIME, STATUS)
    VALUES (p_stu_id, p_course_id, v_term, v_now, NULL, '1');

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
BEGIN
    p_success := FALSE;
    p_message := '';

    SELECT COALESCE(NULLIF(TRIM(p_term), ''), (SELECT PARAM_VALUE FROM TB_SYS_PARAM WHERE PARAM_KEY = 'CURRENT_TERM')) INTO v_term;
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
EXCEPTION WHEN OTHERS THEN
    p_success := FALSE;
    p_message := COALESCE(SQLERRM, 'drop failed');
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
    SELECT COALESCE(NULLIF(TRIM(p_term), ''), (SELECT PARAM_VALUE FROM TB_SYS_PARAM WHERE PARAM_KEY = 'CURRENT_TERM')) INTO v_term;
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
