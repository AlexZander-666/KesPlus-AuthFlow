--
-- PostgreSQL database dump
--

\restrict AikpdwqMkQQhSPkua7Swysds6K1LIkDcAvcEAAwSH3f0gsIqEchPjGpk1627sMK

-- Dumped from database version 12.1
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: anon; Type: SCHEMA; Schema: -; Owner: system
--

CREATE SCHEMA anon;


ALTER SCHEMA anon OWNER TO system;

--
-- Name: perf; Type: SCHEMA; Schema: -; Owner: system
--

CREATE SCHEMA perf;


ALTER SCHEMA perf OWNER TO system;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: system
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO system;

--
-- Name: session_variable; Type: SCHEMA; Schema: -; Owner: system
--

CREATE SCHEMA session_variable;


ALTER SCHEMA session_variable OWNER TO system;

--
-- Name: SCHEMA session_variable; Type: COMMENT; Schema: -; Owner: system
--

COMMENT ON SCHEMA session_variable IS 'Belongs to the session_variable extension';


--
-- Name: src_restrict; Type: SCHEMA; Schema: -; Owner: system
--

CREATE SCHEMA src_restrict;


ALTER SCHEMA src_restrict OWNER TO system;

--
-- Name: sys_catalog; Type: SCHEMA; Schema: -; Owner: system
--

CREATE SCHEMA sys_catalog;


ALTER SCHEMA sys_catalog OWNER TO system;

--
-- Name: SCHEMA sys_catalog; Type: COMMENT; Schema: -; Owner: system
--

COMMENT ON SCHEMA sys_catalog IS 'kingbase sys_catalog schema';


--
-- Name: sysaudit; Type: SCHEMA; Schema: -; Owner: system
--

CREATE SCHEMA sysaudit;


ALTER SCHEMA sysaudit OWNER TO system;

--
-- Name: sysmac; Type: SCHEMA; Schema: -; Owner: system
--

CREATE SCHEMA sysmac;


ALTER SCHEMA sysmac OWNER TO system;

--
-- Name: session_variable; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS session_variable WITH SCHEMA session_variable;


--
-- Name: EXTENSION session_variable; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION session_variable IS 'session_variable - registration and manipulation of session variables and constants';


--
-- Name: sys_lsn; Type: DOMAIN; Schema: sys_catalog; Owner: system
--

CREATE DOMAIN sys_catalog.sys_lsn AS pg_lsn;


ALTER DOMAIN sys_catalog.sys_lsn OWNER TO system;

--
-- Name: fn_check_time_conflict(integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: system
--

CREATE FUNCTION public.fn_check_time_conflict(p_stu_id integer, p_course_id integer, p_term character varying) RETURNS TABLE(conflict boolean, conflict_course_id integer, conflict_course_name character varying, day_of_week smallint, start_slot smallint, end_slot smallint)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.fn_check_time_conflict(p_stu_id integer, p_course_id integer, p_term character varying) OWNER TO system;

--
-- Name: fn_drop_course(integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: system
--

CREATE FUNCTION public.fn_drop_course(p_stu_id integer, p_course_id integer, p_term character varying) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql
    AS $$
DECLARE v_success BOOLEAN; v_msg TEXT;
BEGIN
    CALL PROC_DROP_COURSE(p_stu_id, p_course_id, p_term, v_success, v_msg);
    RETURN QUERY SELECT v_success, v_msg;
END;
$$;


ALTER FUNCTION public.fn_drop_course(p_stu_id integer, p_course_id integer, p_term character varying) OWNER TO system;

--
-- Name: fn_hash_password(text); Type: FUNCTION; Schema: public; Owner: system
--

CREATE FUNCTION public.fn_hash_password(p_plain_password text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_salt TEXT := substr(md5(random()::text || clock_timestamp()::text), 1, 16);
BEGIN
    IF p_plain_password IS NULL OR LENGTH(TRIM(p_plain_password)) = 0 THEN
        RETURN NULL;
    END IF;
    RETURN v_salt || ':' || md5(v_salt || '|' || TRIM(p_plain_password));
END;
$$;


ALTER FUNCTION public.fn_hash_password(p_plain_password text) OWNER TO system;

--
-- Name: fn_join_waitlist(integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: system
--

CREATE FUNCTION public.fn_join_waitlist(p_stu_id integer, p_course_id integer, p_term character varying) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql
    AS $$
DECLARE v_success BOOLEAN; v_msg TEXT;
BEGIN
    CALL PROC_JOIN_WAITLIST(p_stu_id, p_course_id, p_term, v_success, v_msg);
    RETURN QUERY SELECT v_success, v_msg;
END;
$$;


ALTER FUNCTION public.fn_join_waitlist(p_stu_id integer, p_course_id integer, p_term character varying) OWNER TO system;

--
-- Name: fn_login(text, text); Type: FUNCTION; Schema: public; Owner: system
--

CREATE FUNCTION public.fn_login(p_username text, p_plain_password text) RETURNS TABLE(user_id integer, username character varying, role character varying, status bpchar, stu_id integer, tea_id integer)
    LANGUAGE plpgsql
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
$$;


ALTER FUNCTION public.fn_login(p_username text, p_plain_password text) OWNER TO system;

--
-- Name: fn_process_waitlist(integer, character varying); Type: FUNCTION; Schema: public; Owner: system
--

CREATE FUNCTION public.fn_process_waitlist(p_course_id integer, p_term character varying) RETURNS TABLE(processed integer, success boolean, message text)
    LANGUAGE plpgsql
    AS $$
DECLARE v_processed INT; v_success BOOLEAN; v_msg TEXT;
BEGIN
    CALL PROC_PROCESS_WAITLIST(p_course_id, p_term, v_processed, v_success, v_msg);
    RETURN QUERY SELECT COALESCE(v_processed, 0), v_success, v_msg;
END;
$$;


ALTER FUNCTION public.fn_process_waitlist(p_course_id integer, p_term character varying) OWNER TO system;

--
-- Name: fn_sc_dec_course_num(); Type: FUNCTION; Schema: public; Owner: system
--

CREATE FUNCTION public.fn_sc_dec_course_num() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_capacity INT;
    v_selected INT;
BEGIN
    IF OLD.STATUS = '1' AND NEW.STATUS = '0' THEN
        UPDATE TB_COURSE
        SET SELECTED_NUM = GREATEST(SELECTED_NUM - 1, 0)
        WHERE COURSE_ID = NEW.COURSE_ID;
    ELSIF OLD.STATUS = '0' AND NEW.STATUS = '1' THEN
        -- 允许从退课恢复到选课，保持人数一致
        UPDATE TB_COURSE
        SET SELECTED_NUM = SELECTED_NUM + 1
        WHERE COURSE_ID = NEW.COURSE_ID
        RETURNING CAPACITY, SELECTED_NUM INTO v_capacity, v_selected;

        IF v_selected > v_capacity THEN
            RAISE EXCEPTION '课程容量已满';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_sc_dec_course_num() OWNER TO system;

--
-- Name: fn_sc_del_course_num(); Type: FUNCTION; Schema: public; Owner: system
--

CREATE FUNCTION public.fn_sc_del_course_num() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF OLD.STATUS = '1' THEN
        UPDATE TB_COURSE
        SET SELECTED_NUM = GREATEST(SELECTED_NUM - 1, 0)
        WHERE COURSE_ID = OLD.COURSE_ID;
    END IF;
    RETURN OLD;
END;
$$;


ALTER FUNCTION public.fn_sc_del_course_num() OWNER TO system;

--
-- Name: fn_sc_grade_check(); Type: FUNCTION; Schema: public; Owner: system
--

CREATE FUNCTION public.fn_sc_grade_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.GRADE IS NOT NULL AND (NEW.GRADE < 0 OR NEW.GRADE > 100) THEN
        RAISE EXCEPTION '成绩必须在0到100之间';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_sc_grade_check() OWNER TO system;

--
-- Name: fn_sc_inc_course_num(); Type: FUNCTION; Schema: public; Owner: system
--

CREATE FUNCTION public.fn_sc_inc_course_num() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_capacity INT;
    v_selected INT;
BEGIN
    IF NEW.STATUS = '1' THEN
        UPDATE TB_COURSE
        SET SELECTED_NUM = SELECTED_NUM + 1
        WHERE COURSE_ID = NEW.COURSE_ID
        RETURNING CAPACITY, SELECTED_NUM INTO v_capacity, v_selected;

        IF v_selected > v_capacity THEN
            RAISE EXCEPTION '课程容量已满';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_sc_inc_course_num() OWNER TO system;

--
-- Name: fn_select_course(integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: system
--

CREATE FUNCTION public.fn_select_course(p_stu_id integer, p_course_id integer, p_term character varying) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql
    AS $$
DECLARE v_success BOOLEAN; v_msg TEXT;
BEGIN
    CALL PROC_SELECT_COURSE(p_stu_id, p_course_id, p_term, v_success, v_msg);
    RETURN QUERY SELECT v_success, v_msg;
END;
$$;


ALTER FUNCTION public.fn_select_course(p_stu_id integer, p_course_id integer, p_term character varying) OWNER TO system;

--
-- Name: fn_stat_course_topn(character varying, integer); Type: FUNCTION; Schema: public; Owner: system
--

CREATE FUNCTION public.fn_stat_course_topn(p_term character varying, p_limit integer DEFAULT 10) RETURNS TABLE(course_no character varying, course_name character varying, teacher_name character varying, selected_num integer, capacity integer, remaining integer)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.fn_stat_course_topn(p_term character varying, p_limit integer) OWNER TO system;

--
-- Name: fn_stat_dept_distribution(character varying); Type: FUNCTION; Schema: public; Owner: system
--

CREATE FUNCTION public.fn_stat_dept_distribution(p_term character varying) RETURNS TABLE(dept_id integer, dept_name character varying, course_count integer, selected_total integer, capacity_total integer, remaining_total integer, fill_rate numeric)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.fn_stat_dept_distribution(p_term character varying) OWNER TO system;

--
-- Name: fn_stat_select_trend(character varying, character varying); Type: FUNCTION; Schema: public; Owner: system
--

CREATE FUNCTION public.fn_stat_select_trend(p_term character varying, p_bucket character varying DEFAULT 'day'::character varying) RETURNS TABLE(bucket_label text, bucket_start timestamp without time zone, total integer)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.fn_stat_select_trend(p_term character varying, p_bucket character varying) OWNER TO system;

--
-- Name: fn_student_timetable(integer, character varying); Type: FUNCTION; Schema: public; Owner: system
--

CREATE FUNCTION public.fn_student_timetable(p_stu_id integer, p_term character varying) RETURNS TABLE(course_id integer, course_no character varying, course_name character varying, teacher_name character varying, day_of_week smallint, start_slot smallint, end_slot smallint, location character varying, term character varying)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.fn_student_timetable(p_stu_id integer, p_term character varying) OWNER TO system;

--
-- Name: fn_verify_password(text, text); Type: FUNCTION; Schema: public; Owner: system
--

CREATE FUNCTION public.fn_verify_password(p_username text, p_plain_password text) RETURNS boolean
    LANGUAGE plpgsql
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
$$;


ALTER FUNCTION public.fn_verify_password(p_username text, p_plain_password text) OWNER TO system;

--
-- Name: fn_waitlist_by_student(integer, character varying); Type: FUNCTION; Schema: public; Owner: system
--

CREATE FUNCTION public.fn_waitlist_by_student(p_stu_id integer, p_term character varying) RETURNS TABLE(wl_id integer, course_id integer, course_no character varying, course_name character varying, status character varying, message character varying, created_at timestamp without time zone, processed_at timestamp without time zone, term character varying)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.fn_waitlist_by_student(p_stu_id integer, p_term character varying) OWNER TO system;

--
-- Name: proc_drop_course(integer, integer, character varying, boolean, text); Type: PROCEDURE; Schema: public; Owner: system
--

CREATE PROCEDURE public.proc_drop_course(p_stu_id integer, p_course_id integer, p_term character varying, INOUT p_success boolean, INOUT p_message text)
    LANGUAGE plpgsql
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
$$;


ALTER PROCEDURE public.proc_drop_course(p_stu_id integer, p_course_id integer, p_term character varying, INOUT p_success boolean, INOUT p_message text) OWNER TO system;

--
-- Name: proc_join_waitlist(integer, integer, character varying, boolean, text); Type: PROCEDURE; Schema: public; Owner: system
--

CREATE PROCEDURE public.proc_join_waitlist(p_stu_id integer, p_course_id integer, p_term character varying, INOUT p_success boolean, INOUT p_message text)
    LANGUAGE plpgsql
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
$$;


ALTER PROCEDURE public.proc_join_waitlist(p_stu_id integer, p_course_id integer, p_term character varying, INOUT p_success boolean, INOUT p_message text) OWNER TO system;

--
-- Name: proc_process_waitlist(integer, character varying, integer, boolean, text); Type: PROCEDURE; Schema: public; Owner: system
--

CREATE PROCEDURE public.proc_process_waitlist(p_course_id integer, p_term character varying, INOUT p_processed integer, INOUT p_success boolean, INOUT p_message text)
    LANGUAGE plpgsql
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
$$;


ALTER PROCEDURE public.proc_process_waitlist(p_course_id integer, p_term character varying, INOUT p_processed integer, INOUT p_success boolean, INOUT p_message text) OWNER TO system;

--
-- Name: proc_select_course(integer, integer, character varying, boolean, text); Type: PROCEDURE; Schema: public; Owner: system
--

CREATE PROCEDURE public.proc_select_course(p_stu_id integer, p_course_id integer, p_term character varying, INOUT p_success boolean, INOUT p_message text)
    LANGUAGE plpgsql
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
$$;


ALTER PROCEDURE public.proc_select_course(p_stu_id integer, p_course_id integer, p_term character varying, INOUT p_success boolean, INOUT p_message text) OWNER TO system;

--
-- Name: proc_set_password(integer, text, boolean, text); Type: PROCEDURE; Schema: public; Owner: system
--

CREATE PROCEDURE public.proc_set_password(p_user_id integer, p_plain_password text, INOUT p_success boolean, INOUT p_message text)
    LANGUAGE plpgsql
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
$$;


ALTER PROCEDURE public.proc_set_password(p_user_id integer, p_plain_password text, INOUT p_success boolean, INOUT p_message text) OWNER TO system;

--
-- Name: proc_stat_course_select(character varying); Type: FUNCTION; Schema: public; Owner: system
--

CREATE FUNCTION public.proc_stat_course_select(p_term character varying) RETURNS TABLE(course_no character varying, course_name character varying, teacher_name character varying, capacity integer, selected_num integer, remaining integer)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.proc_stat_course_select(p_term character varying) OWNER TO system;

--
-- Name: alteruserreadonly(character varying, character varying, boolean); Type: PROCEDURE; Schema: sys_catalog; Owner: system
--

CREATE PROCEDURE sys_catalog.alteruserreadonly(database character varying, username character varying, isreadonly boolean)
    LANGUAGE plpgsql
    AS $$
declare
        DefaultTransacReadOnly varchar;
        ReadOnlyUser varchar;
begin
        if userName is null or userName=''
        then
                raise exception 'userName is null';
        end if;
        call pg_catalog.modify_sys_privilege_readonly(username, isReadOnly);
        if "database" is null or "database"=''
        then
                if isReadOnly = true
                then
                        DefaultTransacReadOnly := 'alter user '||userName||' set default_transaction_read_only = on';
                        ReadOnlyUser := 'alter user '||userName||' set read_only_user = on';
                else
                        DefaultTransacReadOnly := 'alter user '||userName||' set default_transaction_read_only = off';
                        ReadOnlyUser := 'alter user '||userName||' set read_only_user = off';
                end if;
        else
                if isReadOnly = true
                then
                        DefaultTransacReadOnly := 'alter user '||userName||' IN DATABASE '||"database"||' set default_transaction_read_only = on';
                        ReadOnlyUser := 'alter user '||userName||' IN DATABASE '||"database"||' set read_only_user = on';
                else
                        DefaultTransacReadOnly := 'alter user '||userName||' IN DATABASE '||"database"||' set default_transaction_read_only = off';
                        ReadOnlyUser := 'alter user '||userName||' IN DATABASE '||"database"||' set read_only_user = off';
                end if;
        end if;
                EXECUTE ReadOnlyUser;
                EXECUTE DefaultTransacReadOnly;
end;
$$;


ALTER PROCEDURE sys_catalog.alteruserreadonly(database character varying, username character varying, isreadonly boolean) OWNER TO system;

--
-- Name: sys_advisory_lock(bigint); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_advisory_lock(bigint) RETURNS void
    LANGUAGE internal STRICT
    AS $$sys_advisory_lock_int8$$;


ALTER FUNCTION sys_catalog.sys_advisory_lock(bigint) OWNER TO system;

--
-- Name: sys_advisory_lock(integer, integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_advisory_lock(integer, integer) RETURNS void
    LANGUAGE internal STRICT
    AS $$sys_advisory_lock_int4$$;


ALTER FUNCTION sys_catalog.sys_advisory_lock(integer, integer) OWNER TO system;

--
-- Name: sys_advisory_lock_shared(bigint); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_advisory_lock_shared(bigint) RETURNS void
    LANGUAGE internal STRICT
    AS $$sys_advisory_lock_shared_int8$$;


ALTER FUNCTION sys_catalog.sys_advisory_lock_shared(bigint) OWNER TO system;

--
-- Name: sys_advisory_lock_shared(integer, integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_advisory_lock_shared(integer, integer) RETURNS void
    LANGUAGE internal STRICT
    AS $$sys_advisory_lock_shared_int4$$;


ALTER FUNCTION sys_catalog.sys_advisory_lock_shared(integer, integer) OWNER TO system;

--
-- Name: sys_advisory_unlock(bigint); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_advisory_unlock(bigint) RETURNS boolean
    LANGUAGE internal STRICT
    AS $$sys_advisory_unlock_int8$$;


ALTER FUNCTION sys_catalog.sys_advisory_unlock(bigint) OWNER TO system;

--
-- Name: sys_advisory_unlock(integer, integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_advisory_unlock(integer, integer) RETURNS boolean
    LANGUAGE internal STRICT
    AS $$sys_advisory_unlock_int4$$;


ALTER FUNCTION sys_catalog.sys_advisory_unlock(integer, integer) OWNER TO system;

--
-- Name: sys_advisory_unlock_all(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_advisory_unlock_all() RETURNS void
    LANGUAGE internal STRICT
    AS $$sys_advisory_unlock_all$$;


ALTER FUNCTION sys_catalog.sys_advisory_unlock_all() OWNER TO system;

--
-- Name: sys_advisory_unlock_shared(bigint); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_advisory_unlock_shared(bigint) RETURNS boolean
    LANGUAGE internal STRICT
    AS $$sys_advisory_unlock_shared_int8$$;


ALTER FUNCTION sys_catalog.sys_advisory_unlock_shared(bigint) OWNER TO system;

--
-- Name: sys_advisory_unlock_shared(integer, integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_advisory_unlock_shared(integer, integer) RETURNS boolean
    LANGUAGE internal STRICT
    AS $$sys_advisory_unlock_shared_int4$$;


ALTER FUNCTION sys_catalog.sys_advisory_unlock_shared(integer, integer) OWNER TO system;

--
-- Name: sys_advisory_xact_lock(bigint); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_advisory_xact_lock(bigint) RETURNS void
    LANGUAGE internal STRICT
    AS $$sys_advisory_xact_lock_int8$$;


ALTER FUNCTION sys_catalog.sys_advisory_xact_lock(bigint) OWNER TO system;

--
-- Name: sys_advisory_xact_lock(integer, integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_advisory_xact_lock(integer, integer) RETURNS void
    LANGUAGE internal STRICT
    AS $$sys_advisory_xact_lock_int4$$;


ALTER FUNCTION sys_catalog.sys_advisory_xact_lock(integer, integer) OWNER TO system;

--
-- Name: sys_advisory_xact_lock_shared(bigint); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_advisory_xact_lock_shared(bigint) RETURNS void
    LANGUAGE internal STRICT
    AS $$sys_advisory_xact_lock_shared_int8$$;


ALTER FUNCTION sys_catalog.sys_advisory_xact_lock_shared(bigint) OWNER TO system;

--
-- Name: sys_advisory_xact_lock_shared(integer, integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_advisory_xact_lock_shared(integer, integer) RETURNS void
    LANGUAGE internal STRICT
    AS $$sys_advisory_xact_lock_shared_int4$$;


ALTER FUNCTION sys_catalog.sys_advisory_xact_lock_shared(integer, integer) OWNER TO system;

--
-- Name: sys_available_extension_versions(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_available_extension_versions(OUT name name, OUT version text, OUT superuser boolean, OUT relocatable boolean, OUT schema name, OUT requires name[], OUT comment text) RETURNS SETOF record
    LANGUAGE internal STABLE STRICT COST 10 ROWS 100 PARALLEL SAFE
    AS $$sys_available_extension_versions$$;


ALTER FUNCTION sys_catalog.sys_available_extension_versions(OUT name name, OUT version text, OUT superuser boolean, OUT relocatable boolean, OUT schema name, OUT requires name[], OUT comment text) OWNER TO system;

--
-- Name: sys_available_extensions(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_available_extensions(OUT name name, OUT default_version text, OUT comment text) RETURNS SETOF record
    LANGUAGE internal STABLE STRICT COST 10 ROWS 100 PARALLEL SAFE
    AS $$sys_available_extensions$$;


ALTER FUNCTION sys_catalog.sys_available_extensions(OUT name name, OUT default_version text, OUT comment text) OWNER TO system;

--
-- Name: sys_backend_pid(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_backend_pid() RETURNS integer
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_backend_pid$$;


ALTER FUNCTION sys_catalog.sys_backend_pid() OWNER TO system;

--
-- Name: sys_backup_start_time(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_backup_start_time() RETURNS timestamp with time zone
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_backup_start_time$$;


ALTER FUNCTION sys_catalog.sys_backup_start_time() OWNER TO system;

--
-- Name: sys_blocking_pids(integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_blocking_pids(integer) RETURNS integer[]
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_blocking_pids$$;


ALTER FUNCTION sys_catalog.sys_blocking_pids(integer) OWNER TO system;

--
-- Name: sys_cancel_backend(integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_cancel_backend(integer) RETURNS boolean
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_cancel_backend$$;


ALTER FUNCTION sys_catalog.sys_cancel_backend(integer) OWNER TO system;

--
-- Name: sys_char_to_encoding(name); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_char_to_encoding(name) RETURNS integer
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_char_to_encoding$$;


ALTER FUNCTION sys_catalog.sys_char_to_encoding(name) OWNER TO system;

--
-- Name: sys_client_encoding(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_client_encoding() RETURNS name
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_client_encoding$$;


ALTER FUNCTION sys_catalog.sys_client_encoding() OWNER TO system;

--
-- Name: sys_collation_actual_version(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_collation_actual_version(oid) RETURNS text
    LANGUAGE internal STRICT COST 100 PARALLEL SAFE
    AS $$sys_collation_actual_version$$;


ALTER FUNCTION sys_catalog.sys_collation_actual_version(oid) OWNER TO system;

--
-- Name: sys_collation_for("any"); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_collation_for("any") RETURNS text
    LANGUAGE internal STABLE PARALLEL SAFE
    AS $$sys_collation_for$$;


ALTER FUNCTION sys_catalog.sys_collation_for("any") OWNER TO system;

--
-- Name: sys_collation_is_visible(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_collation_is_visible(oid) RETURNS boolean
    LANGUAGE internal STABLE STRICT COST 10 PARALLEL SAFE
    AS $$sys_collation_is_visible$$;


ALTER FUNCTION sys_catalog.sys_collation_is_visible(oid) OWNER TO system;

--
-- Name: sys_column_is_updatable(regclass, smallint, boolean); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_column_is_updatable(regclass, smallint, boolean) RETURNS boolean
    LANGUAGE internal STABLE STRICT COST 10 PARALLEL SAFE
    AS $$sys_column_is_updatable$$;


ALTER FUNCTION sys_catalog.sys_column_is_updatable(regclass, smallint, boolean) OWNER TO system;

--
-- Name: sys_column_size("any"); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_column_size("any") RETURNS integer
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_column_size$$;


ALTER FUNCTION sys_catalog.sys_column_size("any") OWNER TO system;

--
-- Name: sys_conf_load_time(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_conf_load_time() RETURNS timestamp with time zone
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_conf_load_time$$;


ALTER FUNCTION sys_catalog.sys_conf_load_time() OWNER TO system;

--
-- Name: sys_config(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_config(OUT name text, OUT setting text) RETURNS SETOF record
    LANGUAGE internal STABLE STRICT ROWS 23 PARALLEL RESTRICTED
    AS $$sys_config$$;


ALTER FUNCTION sys_catalog.sys_config(OUT name text, OUT setting text) OWNER TO system;

--
-- Name: sys_control_checkpoint(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_control_checkpoint(OUT checkpoint_lsn pg_lsn, OUT redo_lsn pg_lsn, OUT redo_wal_file text, OUT timeline_id integer, OUT prev_timeline_id integer, OUT full_page_writes boolean, OUT next_xid text, OUT next_oid oid, OUT next_multixact_id xid, OUT next_multi_offset xid, OUT oldest_xid xid, OUT oldest_xid_dbid oid, OUT oldest_active_xid xid, OUT oldest_multi_xid xid, OUT oldest_multi_dbid oid, OUT oldest_commit_ts_xid xid, OUT newest_commit_ts_xid xid, OUT checkpoint_time timestamp with time zone) RETURNS record
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_control_checkpoint$$;


ALTER FUNCTION sys_catalog.sys_control_checkpoint(OUT checkpoint_lsn pg_lsn, OUT redo_lsn pg_lsn, OUT redo_wal_file text, OUT timeline_id integer, OUT prev_timeline_id integer, OUT full_page_writes boolean, OUT next_xid text, OUT next_oid oid, OUT next_multixact_id xid, OUT next_multi_offset xid, OUT oldest_xid xid, OUT oldest_xid_dbid oid, OUT oldest_active_xid xid, OUT oldest_multi_xid xid, OUT oldest_multi_dbid oid, OUT oldest_commit_ts_xid xid, OUT newest_commit_ts_xid xid, OUT checkpoint_time timestamp with time zone) OWNER TO system;

--
-- Name: sys_control_init(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_control_init(OUT max_data_alignment integer, OUT database_block_size integer, OUT blocks_per_segment integer, OUT wal_block_size integer, OUT bytes_per_wal_segment integer, OUT max_identifier_length integer, OUT max_index_columns integer, OUT max_toast_chunk_size integer, OUT large_object_chunk_size integer, OUT float4_pass_by_value boolean, OUT float8_pass_by_value boolean, OUT data_page_checksum_version integer) RETURNS record
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_control_init$$;


ALTER FUNCTION sys_catalog.sys_control_init(OUT max_data_alignment integer, OUT database_block_size integer, OUT blocks_per_segment integer, OUT wal_block_size integer, OUT bytes_per_wal_segment integer, OUT max_identifier_length integer, OUT max_index_columns integer, OUT max_toast_chunk_size integer, OUT large_object_chunk_size integer, OUT float4_pass_by_value boolean, OUT float8_pass_by_value boolean, OUT data_page_checksum_version integer) OWNER TO system;

--
-- Name: sys_control_recovery(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_control_recovery(OUT min_recovery_end_lsn pg_lsn, OUT min_recovery_end_timeline integer, OUT backup_start_lsn pg_lsn, OUT backup_end_lsn pg_lsn, OUT end_of_backup_record_required boolean) RETURNS record
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_control_recovery$$;


ALTER FUNCTION sys_catalog.sys_control_recovery(OUT min_recovery_end_lsn pg_lsn, OUT min_recovery_end_timeline integer, OUT backup_start_lsn pg_lsn, OUT backup_end_lsn pg_lsn, OUT end_of_backup_record_required boolean) OWNER TO system;

--
-- Name: sys_control_system(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_control_system(OUT pg_control_version integer, OUT catalog_version_no integer, OUT system_identifier bigint, OUT pg_control_last_modified timestamp with time zone) RETURNS record
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_control_system$$;


ALTER FUNCTION sys_catalog.sys_control_system(OUT pg_control_version integer, OUT catalog_version_no integer, OUT system_identifier bigint, OUT pg_control_last_modified timestamp with time zone) OWNER TO system;

--
-- Name: sys_conversion_is_visible(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_conversion_is_visible(oid) RETURNS boolean
    LANGUAGE internal STABLE STRICT COST 10 PARALLEL SAFE
    AS $$sys_conversion_is_visible$$;


ALTER FUNCTION sys_catalog.sys_conversion_is_visible(oid) OWNER TO system;

--
-- Name: sys_copy_logical_replication_slot(name, name); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_copy_logical_replication_slot(src_slot_name name, dst_slot_name name, OUT slot_name name, OUT lsn pg_lsn) RETURNS record
    LANGUAGE internal STRICT
    AS $$sys_copy_logical_replication_slot_c$$;


ALTER FUNCTION sys_catalog.sys_copy_logical_replication_slot(src_slot_name name, dst_slot_name name, OUT slot_name name, OUT lsn pg_lsn) OWNER TO system;

--
-- Name: sys_copy_logical_replication_slot(name, name, boolean); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_copy_logical_replication_slot(src_slot_name name, dst_slot_name name, temporary boolean, OUT slot_name name, OUT lsn pg_lsn) RETURNS record
    LANGUAGE internal STRICT
    AS $$sys_copy_logical_replication_slot_b$$;


ALTER FUNCTION sys_catalog.sys_copy_logical_replication_slot(src_slot_name name, dst_slot_name name, temporary boolean, OUT slot_name name, OUT lsn pg_lsn) OWNER TO system;

--
-- Name: sys_copy_logical_replication_slot(name, name, boolean, name); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_copy_logical_replication_slot(src_slot_name name, dst_slot_name name, temporary boolean, plugin name, OUT slot_name name, OUT lsn pg_lsn) RETURNS record
    LANGUAGE internal STRICT
    AS $$sys_copy_logical_replication_slot_a$$;


ALTER FUNCTION sys_catalog.sys_copy_logical_replication_slot(src_slot_name name, dst_slot_name name, temporary boolean, plugin name, OUT slot_name name, OUT lsn pg_lsn) OWNER TO system;

--
-- Name: sys_copy_physical_replication_slot(name, name); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_copy_physical_replication_slot(src_slot_name name, dst_slot_name name, OUT slot_name name, OUT lsn pg_lsn) RETURNS record
    LANGUAGE internal STRICT
    AS $$sys_copy_physical_replication_slot_b$$;


ALTER FUNCTION sys_catalog.sys_copy_physical_replication_slot(src_slot_name name, dst_slot_name name, OUT slot_name name, OUT lsn pg_lsn) OWNER TO system;

--
-- Name: sys_copy_physical_replication_slot(name, name, boolean); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_copy_physical_replication_slot(src_slot_name name, dst_slot_name name, temporary boolean, OUT slot_name name, OUT lsn pg_lsn) RETURNS record
    LANGUAGE internal STRICT
    AS $$sys_copy_physical_replication_slot_a$$;


ALTER FUNCTION sys_catalog.sys_copy_physical_replication_slot(src_slot_name name, dst_slot_name name, temporary boolean, OUT slot_name name, OUT lsn pg_lsn) OWNER TO system;

--
-- Name: sys_create_logical_replication_slot(name, name, boolean); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_create_logical_replication_slot(slot_name name, plugin name, temporary boolean DEFAULT false, OUT slot_name name, OUT lsn pg_lsn) RETURNS record
    LANGUAGE internal STRICT
    AS $$sys_create_logical_replication_slot$$;


ALTER FUNCTION sys_catalog.sys_create_logical_replication_slot(slot_name name, plugin name, temporary boolean, OUT slot_name name, OUT lsn pg_lsn) OWNER TO system;

--
-- Name: sys_create_logical_replication_slot(name, name, pg_lsn); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_create_logical_replication_slot(slot_name name, plugin name, restart_lsn pg_lsn, OUT slot_name name, OUT lsn pg_lsn) RETURNS record
    LANGUAGE internal STRICT
    AS $$sys_create_logical_replication_slot_by_wal_lsn$$;


ALTER FUNCTION sys_catalog.sys_create_logical_replication_slot(slot_name name, plugin name, restart_lsn pg_lsn, OUT slot_name name, OUT lsn pg_lsn) OWNER TO system;

--
-- Name: sys_create_physical_replication_slot(name, boolean, boolean); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_create_physical_replication_slot(slot_name name, immediately_reserve boolean DEFAULT false, temporary boolean DEFAULT false, OUT slot_name name, OUT lsn pg_lsn) RETURNS record
    LANGUAGE internal STRICT
    AS $$sys_create_physical_replication_slot$$;


ALTER FUNCTION sys_catalog.sys_create_physical_replication_slot(slot_name name, immediately_reserve boolean, temporary boolean, OUT slot_name name, OUT lsn pg_lsn) OWNER TO system;

--
-- Name: sys_create_restore_point(text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_create_restore_point(text) RETURNS pg_lsn
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_create_restore_point$$;


ALTER FUNCTION sys_catalog.sys_create_restore_point(text) OWNER TO system;

--
-- Name: sys_current_logfile(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_current_logfile() RETURNS text
    LANGUAGE internal PARALLEL SAFE
    AS $$sys_current_logfile$$;


ALTER FUNCTION sys_catalog.sys_current_logfile() OWNER TO system;

--
-- Name: sys_current_logfile(text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_current_logfile(text) RETURNS text
    LANGUAGE internal PARALLEL SAFE
    AS $$sys_current_logfile_1arg$$;


ALTER FUNCTION sys_catalog.sys_current_logfile(text) OWNER TO system;

--
-- Name: sys_current_wal_flush_lsn(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_current_wal_flush_lsn() RETURNS pg_lsn
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_current_wal_flush_lsn$$;


ALTER FUNCTION sys_catalog.sys_current_wal_flush_lsn() OWNER TO system;

--
-- Name: sys_current_wal_insert_lsn(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_current_wal_insert_lsn() RETURNS pg_lsn
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_current_wal_insert_lsn$$;


ALTER FUNCTION sys_catalog.sys_current_wal_insert_lsn() OWNER TO system;

--
-- Name: sys_current_wal_lsn(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_current_wal_lsn() RETURNS pg_lsn
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_current_wal_lsn$$;


ALTER FUNCTION sys_catalog.sys_current_wal_lsn() OWNER TO system;

--
-- Name: sys_cursor(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_cursor(OUT name text, OUT statement text, OUT is_holdable boolean, OUT is_binary boolean, OUT is_scrollable boolean, OUT creation_time timestamp with time zone) RETURNS SETOF record
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_cursor$$;


ALTER FUNCTION sys_catalog.sys_cursor(OUT name text, OUT statement text, OUT is_holdable boolean, OUT is_binary boolean, OUT is_scrollable boolean, OUT creation_time timestamp with time zone) OWNER TO system;

--
-- Name: sys_database_size(name); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_database_size(name) RETURNS bigint
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_database_size_name$$;


ALTER FUNCTION sys_catalog.sys_database_size(name) OWNER TO system;

--
-- Name: sys_database_size(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_database_size(oid) RETURNS bigint
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_database_size_oid$$;


ALTER FUNCTION sys_catalog.sys_database_size(oid) OWNER TO system;

--
-- Name: sys_ddl_command_in(cstring); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_ddl_command_in(cstring) RETURNS pg_ddl_command
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_ddl_command_in$$;


ALTER FUNCTION sys_catalog.sys_ddl_command_in(cstring) OWNER TO system;

--
-- Name: sys_ddl_command_out(pg_ddl_command); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_ddl_command_out(pg_ddl_command) RETURNS cstring
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_ddl_command_out$$;


ALTER FUNCTION sys_catalog.sys_ddl_command_out(pg_ddl_command) OWNER TO system;

--
-- Name: sys_ddl_command_recv(internal); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_ddl_command_recv(internal) RETURNS pg_ddl_command
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_ddl_command_recv$$;


ALTER FUNCTION sys_catalog.sys_ddl_command_recv(internal) OWNER TO system;

--
-- Name: sys_ddl_command_send(pg_ddl_command); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_ddl_command_send(pg_ddl_command) RETURNS bytea
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_ddl_command_send$$;


ALTER FUNCTION sys_catalog.sys_ddl_command_send(pg_ddl_command) OWNER TO system;

--
-- Name: sys_dependencies_in(cstring); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_dependencies_in(cstring) RETURNS pg_dependencies
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_dependencies_in$$;


ALTER FUNCTION sys_catalog.sys_dependencies_in(cstring) OWNER TO system;

--
-- Name: sys_dependencies_out(pg_dependencies); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_dependencies_out(pg_dependencies) RETURNS cstring
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_dependencies_out$$;


ALTER FUNCTION sys_catalog.sys_dependencies_out(pg_dependencies) OWNER TO system;

--
-- Name: sys_dependencies_recv(internal); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_dependencies_recv(internal) RETURNS pg_dependencies
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_dependencies_recv$$;


ALTER FUNCTION sys_catalog.sys_dependencies_recv(internal) OWNER TO system;

--
-- Name: sys_dependencies_send(pg_dependencies); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_dependencies_send(pg_dependencies) RETURNS bytea
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_dependencies_send$$;


ALTER FUNCTION sys_catalog.sys_dependencies_send(pg_dependencies) OWNER TO system;

--
-- Name: sys_describe_object(oid, oid, integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_describe_object(oid, oid, integer) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_describe_object$$;


ALTER FUNCTION sys_catalog.sys_describe_object(oid, oid, integer) OWNER TO system;

--
-- Name: sys_drop_replication_slot(name); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_drop_replication_slot(name) RETURNS void
    LANGUAGE internal STRICT
    AS $$sys_drop_replication_slot$$;


ALTER FUNCTION sys_catalog.sys_drop_replication_slot(name) OWNER TO system;

--
-- Name: sys_encoding_max_length(integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_encoding_max_length(integer) RETURNS integer
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_encoding_max_length_sql$$;


ALTER FUNCTION sys_catalog.sys_encoding_max_length(integer) OWNER TO system;

--
-- Name: sys_encoding_to_char(integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_encoding_to_char(integer) RETURNS name
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_encoding_to_char$$;


ALTER FUNCTION sys_catalog.sys_encoding_to_char(integer) OWNER TO system;

--
-- Name: sys_event_trigger_ddl_commands(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_event_trigger_ddl_commands(OUT classid oid, OUT objid oid, OUT objsubid integer, OUT command_tag text, OUT object_type text, OUT schema_name text, OUT object_identity text, OUT in_extension boolean, OUT command pg_ddl_command) RETURNS SETOF record
    LANGUAGE internal STABLE STRICT COST 10 ROWS 100 PARALLEL RESTRICTED
    AS $$sys_event_trigger_ddl_commands$$;


ALTER FUNCTION sys_catalog.sys_event_trigger_ddl_commands(OUT classid oid, OUT objid oid, OUT objsubid integer, OUT command_tag text, OUT object_type text, OUT schema_name text, OUT object_identity text, OUT in_extension boolean, OUT command pg_ddl_command) OWNER TO system;

--
-- Name: sys_event_trigger_dropped_objects(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_event_trigger_dropped_objects(OUT classid oid, OUT objid oid, OUT objsubid integer, OUT original boolean, OUT normal boolean, OUT is_temporary boolean, OUT object_type text, OUT schema_name text, OUT object_name text, OUT object_identity text, OUT address_names text[], OUT address_args text[]) RETURNS SETOF record
    LANGUAGE internal STABLE STRICT COST 10 ROWS 100 PARALLEL RESTRICTED
    AS $$sys_event_trigger_dropped_objects$$;


ALTER FUNCTION sys_catalog.sys_event_trigger_dropped_objects(OUT classid oid, OUT objid oid, OUT objsubid integer, OUT original boolean, OUT normal boolean, OUT is_temporary boolean, OUT object_type text, OUT schema_name text, OUT object_name text, OUT object_identity text, OUT address_names text[], OUT address_args text[]) OWNER TO system;

--
-- Name: sys_event_trigger_table_rewrite_oid(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_event_trigger_table_rewrite_oid(OUT oid oid) RETURNS oid
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_event_trigger_table_rewrite_oid$$;


ALTER FUNCTION sys_catalog.sys_event_trigger_table_rewrite_oid(OUT oid oid) OWNER TO system;

--
-- Name: sys_event_trigger_table_rewrite_reason(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_event_trigger_table_rewrite_reason() RETURNS integer
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_event_trigger_table_rewrite_reason$$;


ALTER FUNCTION sys_catalog.sys_event_trigger_table_rewrite_reason() OWNER TO system;

--
-- Name: sys_export_snapshot(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_export_snapshot() RETURNS text
    LANGUAGE internal STRICT
    AS $$sys_export_snapshot$$;


ALTER FUNCTION sys_catalog.sys_export_snapshot() OWNER TO system;

--
-- Name: sys_extension_config_dump(regclass, text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_extension_config_dump(regclass, text) RETURNS void
    LANGUAGE internal STRICT
    AS $$sys_extension_config_dump$$;


ALTER FUNCTION sys_catalog.sys_extension_config_dump(regclass, text) OWNER TO system;

--
-- Name: sys_extension_update_paths(name); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_extension_update_paths(name name, OUT source text, OUT target text, OUT path text) RETURNS SETOF record
    LANGUAGE internal STABLE STRICT COST 10 ROWS 100 PARALLEL SAFE
    AS $$sys_extension_update_paths$$;


ALTER FUNCTION sys_catalog.sys_extension_update_paths(name name, OUT source text, OUT target text, OUT path text) OWNER TO system;

--
-- Name: sys_filenode_relation(oid, oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_filenode_relation(oid, oid) RETURNS regclass
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_filenode_relation$$;


ALTER FUNCTION sys_catalog.sys_filenode_relation(oid, oid) OWNER TO system;

--
-- Name: sys_function_is_visible(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_function_is_visible(oid) RETURNS boolean
    LANGUAGE internal STABLE STRICT COST 10 PARALLEL SAFE
    AS $$sys_function_is_visible$$;


ALTER FUNCTION sys_catalog.sys_function_is_visible(oid) OWNER TO system;

--
-- Name: sys_get_constraintdef(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_constraintdef(oid) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_get_constraintdef$$;


ALTER FUNCTION sys_catalog.sys_get_constraintdef(oid) OWNER TO system;

--
-- Name: sys_get_constraintdef(oid, boolean); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_constraintdef(oid, boolean) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_get_constraintdef_ext$$;


ALTER FUNCTION sys_catalog.sys_get_constraintdef(oid, boolean) OWNER TO system;

--
-- Name: sys_get_expr(pg_node_tree, oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_expr(pg_node_tree, oid) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_get_expr$$;


ALTER FUNCTION sys_catalog.sys_get_expr(pg_node_tree, oid) OWNER TO system;

--
-- Name: sys_get_expr(pg_node_tree, oid, boolean); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_expr(pg_node_tree, oid, boolean) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_get_expr_ext$$;


ALTER FUNCTION sys_catalog.sys_get_expr(pg_node_tree, oid, boolean) OWNER TO system;

--
-- Name: sys_get_function_arg_default(oid, integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_function_arg_default(oid, integer) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_get_function_arg_default$$;


ALTER FUNCTION sys_catalog.sys_get_function_arg_default(oid, integer) OWNER TO system;

--
-- Name: sys_get_function_arguments(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_function_arguments(oid) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_get_function_arguments$$;


ALTER FUNCTION sys_catalog.sys_get_function_arguments(oid) OWNER TO system;

--
-- Name: sys_get_function_identity_arguments(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_function_identity_arguments(oid) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_get_function_identity_arguments$$;


ALTER FUNCTION sys_catalog.sys_get_function_identity_arguments(oid) OWNER TO system;

--
-- Name: sys_get_function_result(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_function_result(oid) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_get_function_result$$;


ALTER FUNCTION sys_catalog.sys_get_function_result(oid) OWNER TO system;

--
-- Name: sys_get_functiondef(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_functiondef(oid) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_get_functiondef$$;


ALTER FUNCTION sys_catalog.sys_get_functiondef(oid) OWNER TO system;

--
-- Name: sys_get_indexdef(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_indexdef(oid) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_get_indexdef$$;


ALTER FUNCTION sys_catalog.sys_get_indexdef(oid) OWNER TO system;

--
-- Name: sys_get_indexdef(oid, integer, boolean); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_indexdef(oid, integer, boolean) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_get_indexdef_ext$$;


ALTER FUNCTION sys_catalog.sys_get_indexdef(oid, integer, boolean) OWNER TO system;

--
-- Name: sys_get_keywords(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_keywords(OUT word text, OUT catcode "char", OUT catdesc text) RETURNS SETOF record
    LANGUAGE internal STABLE STRICT COST 10 ROWS 400 PARALLEL SAFE
    AS $$sys_get_keywords$$;


ALTER FUNCTION sys_catalog.sys_get_keywords(OUT word text, OUT catcode "char", OUT catdesc text) OWNER TO system;

--
-- Name: sys_get_multixact_members(xid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_multixact_members(multixid xid, OUT xid xid, OUT mode text) RETURNS SETOF record
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_get_multixact_members$$;


ALTER FUNCTION sys_catalog.sys_get_multixact_members(multixid xid, OUT xid xid, OUT mode text) OWNER TO system;

--
-- Name: sys_get_object_address(text, text[], text[]); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_object_address(type text, object_names text[], object_args text[], OUT classid oid, OUT objid oid, OUT objsubid integer) RETURNS record
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_get_object_address$$;


ALTER FUNCTION sys_catalog.sys_get_object_address(type text, object_names text[], object_args text[], OUT classid oid, OUT objid oid, OUT objsubid integer) OWNER TO system;

--
-- Name: sys_get_partition_constraintdef(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_partition_constraintdef(oid) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_get_partition_constraintdef$$;


ALTER FUNCTION sys_catalog.sys_get_partition_constraintdef(oid) OWNER TO system;

--
-- Name: sys_get_partkeydef(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_partkeydef(oid) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_get_partkeydef$$;


ALTER FUNCTION sys_catalog.sys_get_partkeydef(oid) OWNER TO system;

--
-- Name: sys_get_publication_tables(text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_publication_tables(pubname text, OUT relid oid) RETURNS SETOF oid
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_get_publication_tables$$;


ALTER FUNCTION sys_catalog.sys_get_publication_tables(pubname text, OUT relid oid) OWNER TO system;

--
-- Name: sys_get_replica_identity_index(regclass); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_replica_identity_index(regclass) RETURNS regclass
    LANGUAGE internal STABLE STRICT COST 10 PARALLEL SAFE
    AS $$sys_get_replica_identity_index$$;


ALTER FUNCTION sys_catalog.sys_get_replica_identity_index(regclass) OWNER TO system;

--
-- Name: sys_get_replication_slots(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_replication_slots(OUT slot_name name, OUT plugin name, OUT slot_type text, OUT datoid oid, OUT temporary boolean, OUT active boolean, OUT active_pid integer, OUT xmin xid, OUT catalog_xmin xid, OUT restart_lsn pg_lsn, OUT confirmed_flush_lsn pg_lsn) RETURNS SETOF record
    LANGUAGE internal STABLE ROWS 10 PARALLEL SAFE
    AS $$sys_get_replication_slots$$;


ALTER FUNCTION sys_catalog.sys_get_replication_slots(OUT slot_name name, OUT plugin name, OUT slot_type text, OUT datoid oid, OUT temporary boolean, OUT active boolean, OUT active_pid integer, OUT xmin xid, OUT catalog_xmin xid, OUT restart_lsn pg_lsn, OUT confirmed_flush_lsn pg_lsn) OWNER TO system;

--
-- Name: sys_get_ruledef(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_ruledef(oid) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_get_ruledef$$;


ALTER FUNCTION sys_catalog.sys_get_ruledef(oid) OWNER TO system;

--
-- Name: sys_get_ruledef(oid, boolean); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_ruledef(oid, boolean) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_get_ruledef_ext$$;


ALTER FUNCTION sys_catalog.sys_get_ruledef(oid, boolean) OWNER TO system;

--
-- Name: sys_get_serial_sequence(text, text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_serial_sequence(text, text) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_get_serial_sequence$$;


ALTER FUNCTION sys_catalog.sys_get_serial_sequence(text, text) OWNER TO system;

--
-- Name: sys_get_shmem_allocations(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_shmem_allocations(OUT name text, OUT off bigint, OUT size bigint, OUT allocated_size bigint) RETURNS SETOF record
    LANGUAGE internal STABLE PARALLEL RESTRICTED
    AS $$sys_get_shmem_allocations$$;


ALTER FUNCTION sys_catalog.sys_get_shmem_allocations(OUT name text, OUT off bigint, OUT size bigint, OUT allocated_size bigint) OWNER TO system;

--
-- Name: sys_get_statisticsobjdef(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_statisticsobjdef(oid) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_get_statisticsobjdef$$;


ALTER FUNCTION sys_catalog.sys_get_statisticsobjdef(oid) OWNER TO system;

--
-- Name: sys_get_triggerdef(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_triggerdef(oid) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_get_triggerdef$$;


ALTER FUNCTION sys_catalog.sys_get_triggerdef(oid) OWNER TO system;

--
-- Name: sys_get_triggerdef(oid, boolean); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_triggerdef(oid, boolean) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_get_triggerdef_ext$$;


ALTER FUNCTION sys_catalog.sys_get_triggerdef(oid, boolean) OWNER TO system;

--
-- Name: sys_get_userbyid(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_userbyid(oid) RETURNS name
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_get_userbyid$$;


ALTER FUNCTION sys_catalog.sys_get_userbyid(oid) OWNER TO system;

--
-- Name: sys_get_viewdef(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_viewdef(oid) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_get_viewdef$$;


ALTER FUNCTION sys_catalog.sys_get_viewdef(oid) OWNER TO system;

--
-- Name: sys_get_viewdef(text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_viewdef(text) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_get_viewdef_name$$;


ALTER FUNCTION sys_catalog.sys_get_viewdef(text) OWNER TO system;

--
-- Name: sys_get_viewdef(oid, boolean); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_viewdef(oid, boolean) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_get_viewdef_ext$$;


ALTER FUNCTION sys_catalog.sys_get_viewdef(oid, boolean) OWNER TO system;

--
-- Name: sys_get_viewdef(oid, integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_viewdef(oid, integer) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_get_viewdef_wrap$$;


ALTER FUNCTION sys_catalog.sys_get_viewdef(oid, integer) OWNER TO system;

--
-- Name: sys_get_viewdef(text, boolean); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_get_viewdef(text, boolean) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_get_viewdef_name_ext$$;


ALTER FUNCTION sys_catalog.sys_get_viewdef(text, boolean) OWNER TO system;

--
-- Name: sys_has_role(name, text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_has_role(name, text) RETURNS boolean
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_has_role_name$$;


ALTER FUNCTION sys_catalog.sys_has_role(name, text) OWNER TO system;

--
-- Name: sys_has_role(oid, text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_has_role(oid, text) RETURNS boolean
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_has_role_id$$;


ALTER FUNCTION sys_catalog.sys_has_role(oid, text) OWNER TO system;

--
-- Name: sys_has_role(name, name, text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_has_role(name, name, text) RETURNS boolean
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_has_role_name_name$$;


ALTER FUNCTION sys_catalog.sys_has_role(name, name, text) OWNER TO system;

--
-- Name: sys_has_role(name, oid, text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_has_role(name, oid, text) RETURNS boolean
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_has_role_name_id$$;


ALTER FUNCTION sys_catalog.sys_has_role(name, oid, text) OWNER TO system;

--
-- Name: sys_has_role(oid, name, text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_has_role(oid, name, text) RETURNS boolean
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_has_role_id_name$$;


ALTER FUNCTION sys_catalog.sys_has_role(oid, name, text) OWNER TO system;

--
-- Name: sys_has_role(oid, oid, text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_has_role(oid, oid, text) RETURNS boolean
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_has_role_id_id$$;


ALTER FUNCTION sys_catalog.sys_has_role(oid, oid, text) OWNER TO system;

--
-- Name: sys_hba_file_rules(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_hba_file_rules(OUT line_number integer, OUT type text, OUT database text[], OUT user_name text[], OUT address text, OUT netmask text, OUT auth_method text, OUT options text[], OUT error text) RETURNS SETOF record
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_hba_file_rules$$;


ALTER FUNCTION sys_catalog.sys_hba_file_rules(OUT line_number integer, OUT type text, OUT database text[], OUT user_name text[], OUT address text, OUT netmask text, OUT auth_method text, OUT options text[], OUT error text) OWNER TO system;

--
-- Name: sys_identify_object(oid, oid, integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_identify_object(classid oid, objid oid, objsubid integer, OUT type text, OUT schema text, OUT name text, OUT identity text) RETURNS record
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_identify_object$$;


ALTER FUNCTION sys_catalog.sys_identify_object(classid oid, objid oid, objsubid integer, OUT type text, OUT schema text, OUT name text, OUT identity text) OWNER TO system;

--
-- Name: sys_identify_object_as_address(oid, oid, integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_identify_object_as_address(classid oid, objid oid, objsubid integer, OUT type text, OUT object_names text[], OUT object_args text[]) RETURNS record
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_identify_object_as_address$$;


ALTER FUNCTION sys_catalog.sys_identify_object_as_address(classid oid, objid oid, objsubid integer, OUT type text, OUT object_names text[], OUT object_args text[]) OWNER TO system;

--
-- Name: sys_import_system_collations(regnamespace); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_import_system_collations(regnamespace) RETURNS integer
    LANGUAGE internal STRICT COST 100
    AS $$sys_import_system_collations$$;


ALTER FUNCTION sys_catalog.sys_import_system_collations(regnamespace) OWNER TO system;

--
-- Name: sys_index_column_has_property(regclass, integer, text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_index_column_has_property(regclass, integer, text) RETURNS boolean
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_index_column_has_property$$;


ALTER FUNCTION sys_catalog.sys_index_column_has_property(regclass, integer, text) OWNER TO system;

--
-- Name: sys_index_has_property(regclass, text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_index_has_property(regclass, text) RETURNS boolean
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_index_has_property$$;


ALTER FUNCTION sys_catalog.sys_index_has_property(regclass, text) OWNER TO system;

--
-- Name: sys_indexam_has_property(oid, text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_indexam_has_property(oid, text) RETURNS boolean
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_indexam_has_property$$;


ALTER FUNCTION sys_catalog.sys_indexam_has_property(oid, text) OWNER TO system;

--
-- Name: sys_indexam_progress_phasename(oid, bigint); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_indexam_progress_phasename(oid, bigint) RETURNS text
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_indexam_progress_phasename$$;


ALTER FUNCTION sys_catalog.sys_indexam_progress_phasename(oid, bigint) OWNER TO system;

--
-- Name: sys_indexes_size(regclass); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_indexes_size(regclass) RETURNS bigint
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_indexes_size$$;


ALTER FUNCTION sys_catalog.sys_indexes_size(regclass) OWNER TO system;

--
-- Name: sys_is_in_backup(boolean); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_is_in_backup(allmode boolean DEFAULT false) RETURNS boolean
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_is_in_backup$$;


ALTER FUNCTION sys_catalog.sys_is_in_backup(allmode boolean) OWNER TO system;

--
-- Name: sys_is_in_recovery(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_is_in_recovery() RETURNS boolean
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_is_in_recovery$$;


ALTER FUNCTION sys_catalog.sys_is_in_recovery() OWNER TO system;

--
-- Name: sys_is_other_temp_schema(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_is_other_temp_schema(oid) RETURNS boolean
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_is_other_temp_schema$$;


ALTER FUNCTION sys_catalog.sys_is_other_temp_schema(oid) OWNER TO system;

--
-- Name: sys_is_wal_replay_paused(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_is_wal_replay_paused() RETURNS boolean
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_is_wal_replay_paused$$;


ALTER FUNCTION sys_catalog.sys_is_wal_replay_paused() OWNER TO system;

--
-- Name: sys_isolation_test_session_is_blocked(integer, integer[]); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_isolation_test_session_is_blocked(integer, integer[]) RETURNS boolean
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_isolation_test_session_is_blocked$$;


ALTER FUNCTION sys_catalog.sys_isolation_test_session_is_blocked(integer, integer[]) OWNER TO system;

--
-- Name: sys_jit_available(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_jit_available() RETURNS boolean
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$KBJustInTimeAvailable$$;


ALTER FUNCTION sys_catalog.sys_jit_available() OWNER TO system;

--
-- Name: sys_last_committed_xact(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_last_committed_xact(OUT xid xid, OUT "timestamp" timestamp with time zone) RETURNS record
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_last_committed_xact$$;


ALTER FUNCTION sys_catalog.sys_last_committed_xact(OUT xid xid, OUT "timestamp" timestamp with time zone) OWNER TO system;

--
-- Name: sys_last_wal_receive_lsn(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_last_wal_receive_lsn() RETURNS pg_lsn
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_last_wal_receive_lsn$$;


ALTER FUNCTION sys_catalog.sys_last_wal_receive_lsn() OWNER TO system;

--
-- Name: sys_last_wal_replay_lsn(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_last_wal_replay_lsn() RETURNS pg_lsn
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_last_wal_replay_lsn$$;


ALTER FUNCTION sys_catalog.sys_last_wal_replay_lsn() OWNER TO system;

--
-- Name: sys_last_xact_replay_timestamp(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_last_xact_replay_timestamp() RETURNS timestamp with time zone
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_last_xact_replay_timestamp$$;


ALTER FUNCTION sys_catalog.sys_last_xact_replay_timestamp() OWNER TO system;

--
-- Name: sys_listening_channels(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_listening_channels() RETURNS SETOF text
    LANGUAGE internal STABLE STRICT ROWS 10 PARALLEL RESTRICTED
    AS $$sys_listening_channels$$;


ALTER FUNCTION sys_catalog.sys_listening_channels() OWNER TO system;

--
-- Name: sys_lock_status(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_lock_status(OUT locktype text, OUT database oid, OUT relation oid, OUT page integer, OUT tuple smallint, OUT virtualxid text, OUT transactionid xid, OUT classid oid, OUT objid oid, OUT objsubid smallint, OUT virtualtransaction text, OUT pid integer, OUT mode text, OUT granted boolean, OUT fastpath boolean) RETURNS SETOF record
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_lock_status$$;


ALTER FUNCTION sys_catalog.sys_lock_status(OUT locktype text, OUT database oid, OUT relation oid, OUT page integer, OUT tuple smallint, OUT virtualxid text, OUT transactionid xid, OUT classid oid, OUT objid oid, OUT objsubid smallint, OUT virtualtransaction text, OUT pid integer, OUT mode text, OUT granted boolean, OUT fastpath boolean) OWNER TO system;

--
-- Name: sys_logical_emit_message(boolean, text, bytea); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_logical_emit_message(boolean, text, bytea) RETURNS pg_lsn
    LANGUAGE internal STRICT
    AS $$sys_logical_emit_message_bytea$$;


ALTER FUNCTION sys_catalog.sys_logical_emit_message(boolean, text, bytea) OWNER TO system;

--
-- Name: sys_logical_emit_message(boolean, text, text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_logical_emit_message(boolean, text, text) RETURNS pg_lsn
    LANGUAGE internal STRICT
    AS $$sys_logical_emit_message_text$$;


ALTER FUNCTION sys_catalog.sys_logical_emit_message(boolean, text, text) OWNER TO system;

--
-- Name: sys_logical_slot_get_binary_changes(name, pg_lsn, integer, text[]); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_logical_slot_get_binary_changes(slot_name name, upto_lsn pg_lsn, upto_nchanges integer, VARIADIC options text[] DEFAULT '{}'::text[], OUT lsn pg_lsn, OUT xid xid, OUT data bytea) RETURNS SETOF record
    LANGUAGE internal COST 1000
    AS $$sys_logical_slot_get_binary_changes$$;


ALTER FUNCTION sys_catalog.sys_logical_slot_get_binary_changes(slot_name name, upto_lsn pg_lsn, upto_nchanges integer, VARIADIC options text[], OUT lsn pg_lsn, OUT xid xid, OUT data bytea) OWNER TO system;

--
-- Name: sys_logical_slot_get_changes(name, pg_lsn, integer, text[]); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_logical_slot_get_changes(slot_name name, upto_lsn pg_lsn, upto_nchanges integer, VARIADIC options text[] DEFAULT '{}'::text[], OUT lsn pg_lsn, OUT xid xid, OUT data text) RETURNS SETOF record
    LANGUAGE internal COST 1000
    AS $$sys_logical_slot_get_changes$$;


ALTER FUNCTION sys_catalog.sys_logical_slot_get_changes(slot_name name, upto_lsn pg_lsn, upto_nchanges integer, VARIADIC options text[], OUT lsn pg_lsn, OUT xid xid, OUT data text) OWNER TO system;

--
-- Name: sys_logical_slot_peek_binary_changes(name, pg_lsn, integer, text[]); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_logical_slot_peek_binary_changes(slot_name name, upto_lsn pg_lsn, upto_nchanges integer, VARIADIC options text[] DEFAULT '{}'::text[], OUT lsn pg_lsn, OUT xid xid, OUT data bytea) RETURNS SETOF record
    LANGUAGE internal COST 1000
    AS $$sys_logical_slot_peek_binary_changes$$;


ALTER FUNCTION sys_catalog.sys_logical_slot_peek_binary_changes(slot_name name, upto_lsn pg_lsn, upto_nchanges integer, VARIADIC options text[], OUT lsn pg_lsn, OUT xid xid, OUT data bytea) OWNER TO system;

--
-- Name: sys_logical_slot_peek_changes(name, pg_lsn, integer, text[]); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_logical_slot_peek_changes(slot_name name, upto_lsn pg_lsn, upto_nchanges integer, VARIADIC options text[] DEFAULT '{}'::text[], OUT lsn pg_lsn, OUT xid xid, OUT data text) RETURNS SETOF record
    LANGUAGE internal COST 1000
    AS $$sys_logical_slot_peek_changes$$;


ALTER FUNCTION sys_catalog.sys_logical_slot_peek_changes(slot_name name, upto_lsn pg_lsn, upto_nchanges integer, VARIADIC options text[], OUT lsn pg_lsn, OUT xid xid, OUT data text) OWNER TO system;

--
-- Name: sys_ls_archive_statusdir(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_ls_archive_statusdir(OUT name text, OUT size bigint, OUT modification timestamp with time zone) RETURNS SETOF record
    LANGUAGE internal STRICT COST 10 ROWS 20 PARALLEL SAFE
    AS $$sys_ls_archive_statusdir$$;


ALTER FUNCTION sys_catalog.sys_ls_archive_statusdir(OUT name text, OUT size bigint, OUT modification timestamp with time zone) OWNER TO system;

--
-- Name: sys_ls_dir(text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_ls_dir(text) RETURNS SETOF text
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_ls_dir_1arg$$;


ALTER FUNCTION sys_catalog.sys_ls_dir(text) OWNER TO system;

--
-- Name: sys_ls_dir(text, boolean, boolean); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_ls_dir(text, boolean, boolean) RETURNS SETOF text
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_ls_dir$$;


ALTER FUNCTION sys_catalog.sys_ls_dir(text, boolean, boolean) OWNER TO system;

--
-- Name: sys_ls_logdir(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_ls_logdir(OUT name text, OUT size bigint, OUT modification timestamp with time zone) RETURNS SETOF record
    LANGUAGE internal STRICT COST 10 ROWS 20 PARALLEL SAFE
    AS $$sys_ls_logdir$$;


ALTER FUNCTION sys_catalog.sys_ls_logdir(OUT name text, OUT size bigint, OUT modification timestamp with time zone) OWNER TO system;

--
-- Name: sys_ls_tmpdir(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_ls_tmpdir(OUT name text, OUT size bigint, OUT modification timestamp with time zone) RETURNS SETOF record
    LANGUAGE internal STRICT COST 10 ROWS 20 PARALLEL SAFE
    AS $$sys_ls_tmpdir_noargs$$;


ALTER FUNCTION sys_catalog.sys_ls_tmpdir(OUT name text, OUT size bigint, OUT modification timestamp with time zone) OWNER TO system;

--
-- Name: sys_ls_tmpdir(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_ls_tmpdir(tablespace oid, OUT name text, OUT size bigint, OUT modification timestamp with time zone) RETURNS SETOF record
    LANGUAGE internal STRICT COST 10 ROWS 20 PARALLEL SAFE
    AS $$sys_ls_tmpdir_1arg$$;


ALTER FUNCTION sys_catalog.sys_ls_tmpdir(tablespace oid, OUT name text, OUT size bigint, OUT modification timestamp with time zone) OWNER TO system;

--
-- Name: sys_ls_waldir(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_ls_waldir(OUT name text, OUT size bigint, OUT modification timestamp with time zone) RETURNS SETOF record
    LANGUAGE internal STRICT COST 10 ROWS 20 PARALLEL SAFE
    AS $$sys_ls_waldir$$;


ALTER FUNCTION sys_catalog.sys_ls_waldir(OUT name text, OUT size bigint, OUT modification timestamp with time zone) OWNER TO system;

--
-- Name: sys_lsn_cmp(pg_lsn, pg_lsn); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_lsn_cmp(pg_lsn, pg_lsn) RETURNS integer
    LANGUAGE internal IMMUTABLE STRICT LEAKPROOF PARALLEL SAFE
    AS $$sys_lsn_cmp$$;


ALTER FUNCTION sys_catalog.sys_lsn_cmp(pg_lsn, pg_lsn) OWNER TO system;

--
-- Name: sys_lsn_eq(pg_lsn, pg_lsn); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_lsn_eq(pg_lsn, pg_lsn) RETURNS boolean
    LANGUAGE internal IMMUTABLE STRICT LEAKPROOF PARALLEL SAFE
    AS $$sys_lsn_eq$$;


ALTER FUNCTION sys_catalog.sys_lsn_eq(pg_lsn, pg_lsn) OWNER TO system;

--
-- Name: sys_lsn_ge(pg_lsn, pg_lsn); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_lsn_ge(pg_lsn, pg_lsn) RETURNS boolean
    LANGUAGE internal IMMUTABLE STRICT LEAKPROOF PARALLEL SAFE
    AS $$sys_lsn_ge$$;


ALTER FUNCTION sys_catalog.sys_lsn_ge(pg_lsn, pg_lsn) OWNER TO system;

--
-- Name: sys_lsn_gt(pg_lsn, pg_lsn); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_lsn_gt(pg_lsn, pg_lsn) RETURNS boolean
    LANGUAGE internal IMMUTABLE STRICT LEAKPROOF PARALLEL SAFE
    AS $$sys_lsn_gt$$;


ALTER FUNCTION sys_catalog.sys_lsn_gt(pg_lsn, pg_lsn) OWNER TO system;

--
-- Name: sys_lsn_hash(pg_lsn); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_lsn_hash(pg_lsn) RETURNS integer
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_lsn_hash$$;


ALTER FUNCTION sys_catalog.sys_lsn_hash(pg_lsn) OWNER TO system;

--
-- Name: sys_lsn_hash_extended(pg_lsn, bigint); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_lsn_hash_extended(pg_lsn, bigint) RETURNS bigint
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_lsn_hash_extended$$;


ALTER FUNCTION sys_catalog.sys_lsn_hash_extended(pg_lsn, bigint) OWNER TO system;

--
-- Name: sys_lsn_in(cstring); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_lsn_in(cstring) RETURNS pg_lsn
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_lsn_in$$;


ALTER FUNCTION sys_catalog.sys_lsn_in(cstring) OWNER TO system;

--
-- Name: sys_lsn_le(pg_lsn, pg_lsn); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_lsn_le(pg_lsn, pg_lsn) RETURNS boolean
    LANGUAGE internal IMMUTABLE STRICT LEAKPROOF PARALLEL SAFE
    AS $$sys_lsn_le$$;


ALTER FUNCTION sys_catalog.sys_lsn_le(pg_lsn, pg_lsn) OWNER TO system;

--
-- Name: sys_lsn_lt(pg_lsn, pg_lsn); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_lsn_lt(pg_lsn, pg_lsn) RETURNS boolean
    LANGUAGE internal IMMUTABLE STRICT LEAKPROOF PARALLEL SAFE
    AS $$sys_lsn_lt$$;


ALTER FUNCTION sys_catalog.sys_lsn_lt(pg_lsn, pg_lsn) OWNER TO system;

--
-- Name: sys_lsn_mi(pg_lsn, pg_lsn); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_lsn_mi(pg_lsn, pg_lsn) RETURNS numeric
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_lsn_mi$$;


ALTER FUNCTION sys_catalog.sys_lsn_mi(pg_lsn, pg_lsn) OWNER TO system;

--
-- Name: sys_lsn_ne(pg_lsn, pg_lsn); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_lsn_ne(pg_lsn, pg_lsn) RETURNS boolean
    LANGUAGE internal IMMUTABLE STRICT LEAKPROOF PARALLEL SAFE
    AS $$sys_lsn_ne$$;


ALTER FUNCTION sys_catalog.sys_lsn_ne(pg_lsn, pg_lsn) OWNER TO system;

--
-- Name: sys_lsn_out(pg_lsn); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_lsn_out(pg_lsn) RETURNS cstring
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_lsn_out$$;


ALTER FUNCTION sys_catalog.sys_lsn_out(pg_lsn) OWNER TO system;

--
-- Name: sys_lsn_recv(internal); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_lsn_recv(internal) RETURNS pg_lsn
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_lsn_recv$$;


ALTER FUNCTION sys_catalog.sys_lsn_recv(internal) OWNER TO system;

--
-- Name: sys_lsn_send(pg_lsn); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_lsn_send(pg_lsn) RETURNS bytea
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_lsn_send$$;


ALTER FUNCTION sys_catalog.sys_lsn_send(pg_lsn) OWNER TO system;

--
-- Name: sys_mcv_list_in(cstring); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_mcv_list_in(cstring) RETURNS pg_mcv_list
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_mcv_list_in$$;


ALTER FUNCTION sys_catalog.sys_mcv_list_in(cstring) OWNER TO system;

--
-- Name: sys_mcv_list_items(pg_mcv_list); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_mcv_list_items(mcv_list pg_mcv_list, OUT index integer, OUT "values" text[], OUT nulls boolean[], OUT frequency double precision, OUT base_frequency double precision) RETURNS SETOF record
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_stats_ext_mcvlist_items$$;


ALTER FUNCTION sys_catalog.sys_mcv_list_items(mcv_list pg_mcv_list, OUT index integer, OUT "values" text[], OUT nulls boolean[], OUT frequency double precision, OUT base_frequency double precision) OWNER TO system;

--
-- Name: sys_mcv_list_out(pg_mcv_list); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_mcv_list_out(pg_mcv_list) RETURNS cstring
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_mcv_list_out$$;


ALTER FUNCTION sys_catalog.sys_mcv_list_out(pg_mcv_list) OWNER TO system;

--
-- Name: sys_mcv_list_recv(internal); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_mcv_list_recv(internal) RETURNS pg_mcv_list
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_mcv_list_recv$$;


ALTER FUNCTION sys_catalog.sys_mcv_list_recv(internal) OWNER TO system;

--
-- Name: sys_mcv_list_send(pg_mcv_list); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_mcv_list_send(pg_mcv_list) RETURNS bytea
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_mcv_list_send$$;


ALTER FUNCTION sys_catalog.sys_mcv_list_send(pg_mcv_list) OWNER TO system;

--
-- Name: sys_my_temp_schema(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_my_temp_schema() RETURNS oid
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_my_temp_schema$$;


ALTER FUNCTION sys_catalog.sys_my_temp_schema() OWNER TO system;

--
-- Name: sys_ndistinct_in(cstring); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_ndistinct_in(cstring) RETURNS pg_ndistinct
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_ndistinct_in$$;


ALTER FUNCTION sys_catalog.sys_ndistinct_in(cstring) OWNER TO system;

--
-- Name: sys_ndistinct_out(pg_ndistinct); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_ndistinct_out(pg_ndistinct) RETURNS cstring
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_ndistinct_out$$;


ALTER FUNCTION sys_catalog.sys_ndistinct_out(pg_ndistinct) OWNER TO system;

--
-- Name: sys_ndistinct_recv(internal); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_ndistinct_recv(internal) RETURNS pg_ndistinct
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_ndistinct_recv$$;


ALTER FUNCTION sys_catalog.sys_ndistinct_recv(internal) OWNER TO system;

--
-- Name: sys_ndistinct_send(pg_ndistinct); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_ndistinct_send(pg_ndistinct) RETURNS bytea
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_ndistinct_send$$;


ALTER FUNCTION sys_catalog.sys_ndistinct_send(pg_ndistinct) OWNER TO system;

--
-- Name: sys_nextoid(regclass, name, regclass); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_nextoid(regclass, name, regclass) RETURNS oid
    LANGUAGE internal STRICT
    AS $$sys_nextoid$$;


ALTER FUNCTION sys_catalog.sys_nextoid(regclass, name, regclass) OWNER TO system;

--
-- Name: sys_node_tree_in(cstring); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_node_tree_in(cstring) RETURNS pg_node_tree
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_node_tree_in$$;


ALTER FUNCTION sys_catalog.sys_node_tree_in(cstring) OWNER TO system;

--
-- Name: sys_node_tree_out(pg_node_tree); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_node_tree_out(pg_node_tree) RETURNS cstring
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_node_tree_out$$;


ALTER FUNCTION sys_catalog.sys_node_tree_out(pg_node_tree) OWNER TO system;

--
-- Name: sys_node_tree_recv(internal); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_node_tree_recv(internal) RETURNS pg_node_tree
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_node_tree_recv$$;


ALTER FUNCTION sys_catalog.sys_node_tree_recv(internal) OWNER TO system;

--
-- Name: sys_node_tree_send(pg_node_tree); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_node_tree_send(pg_node_tree) RETURNS bytea
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_node_tree_send$$;


ALTER FUNCTION sys_catalog.sys_node_tree_send(pg_node_tree) OWNER TO system;

--
-- Name: sys_notification_queue_usage(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_notification_queue_usage() RETURNS double precision
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_notification_queue_usage$$;


ALTER FUNCTION sys_catalog.sys_notification_queue_usage() OWNER TO system;

--
-- Name: sys_notify(text, text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_notify(text, text) RETURNS void
    LANGUAGE internal PARALLEL RESTRICTED
    AS $$sys_notify$$;


ALTER FUNCTION sys_catalog.sys_notify(text, text) OWNER TO system;

--
-- Name: sys_opclass_is_visible(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_opclass_is_visible(oid) RETURNS boolean
    LANGUAGE internal STABLE STRICT COST 10 PARALLEL SAFE
    AS $$sys_opclass_is_visible$$;


ALTER FUNCTION sys_catalog.sys_opclass_is_visible(oid) OWNER TO system;

--
-- Name: sys_operator_is_visible(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_operator_is_visible(oid) RETURNS boolean
    LANGUAGE internal STABLE STRICT COST 10 PARALLEL SAFE
    AS $$sys_operator_is_visible$$;


ALTER FUNCTION sys_catalog.sys_operator_is_visible(oid) OWNER TO system;

--
-- Name: sys_opfamily_is_visible(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_opfamily_is_visible(oid) RETURNS boolean
    LANGUAGE internal STABLE STRICT COST 10 PARALLEL SAFE
    AS $$sys_opfamily_is_visible$$;


ALTER FUNCTION sys_catalog.sys_opfamily_is_visible(oid) OWNER TO system;

--
-- Name: sys_options_to_table(text[]); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_options_to_table(options_array text[], OUT option_name text, OUT option_value text) RETURNS SETOF record
    LANGUAGE internal STABLE STRICT ROWS 3 PARALLEL SAFE
    AS $$sys_options_to_table$$;


ALTER FUNCTION sys_catalog.sys_options_to_table(options_array text[], OUT option_name text, OUT option_value text) OWNER TO system;

--
-- Name: sys_partition_ancestors(regclass); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_partition_ancestors(partitionid regclass, OUT relid regclass) RETURNS SETOF regclass
    LANGUAGE internal STRICT ROWS 10 PARALLEL SAFE
    AS $$sys_partition_ancestors$$;


ALTER FUNCTION sys_catalog.sys_partition_ancestors(partitionid regclass, OUT relid regclass) OWNER TO system;

--
-- Name: sys_partition_root(regclass); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_partition_root(regclass) RETURNS regclass
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_partition_root$$;


ALTER FUNCTION sys_catalog.sys_partition_root(regclass) OWNER TO system;

--
-- Name: sys_partition_tree(regclass); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_partition_tree(rootrelid regclass, OUT relid regclass, OUT parentrelid regclass, OUT isleaf boolean, OUT _level integer) RETURNS SETOF record
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_partition_tree$$;


ALTER FUNCTION sys_catalog.sys_partition_tree(rootrelid regclass, OUT relid regclass, OUT parentrelid regclass, OUT isleaf boolean, OUT _level integer) OWNER TO system;

--
-- Name: sys_postmaster_start_time(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_postmaster_start_time() RETURNS timestamp with time zone
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_postmaster_start_time$$;


ALTER FUNCTION sys_catalog.sys_postmaster_start_time() OWNER TO system;

--
-- Name: sys_prepared_statement(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_prepared_statement(OUT name text, OUT statement text, OUT prepare_time timestamp with time zone, OUT parameter_types regtype[], OUT from_sql boolean) RETURNS SETOF record
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_prepared_statement$$;


ALTER FUNCTION sys_catalog.sys_prepared_statement(OUT name text, OUT statement text, OUT prepare_time timestamp with time zone, OUT parameter_types regtype[], OUT from_sql boolean) OWNER TO system;

--
-- Name: sys_prepared_xact(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_prepared_xact(OUT transaction xid, OUT gid text, OUT prepared timestamp with time zone, OUT ownerid oid, OUT dbid oid) RETURNS SETOF record
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_prepared_xact$$;


ALTER FUNCTION sys_catalog.sys_prepared_xact(OUT transaction xid, OUT gid text, OUT prepared timestamp with time zone, OUT ownerid oid, OUT dbid oid) OWNER TO system;

--
-- Name: sys_promote(boolean, integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_promote(wait boolean DEFAULT true, wait_seconds integer DEFAULT 60) RETURNS boolean
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_promote$$;


ALTER FUNCTION sys_catalog.sys_promote(wait boolean, wait_seconds integer) OWNER TO system;

--
-- Name: sys_read_binary_file(text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_read_binary_file(text) RETURNS bytea
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_read_binary_file_all$$;


ALTER FUNCTION sys_catalog.sys_read_binary_file(text) OWNER TO system;

--
-- Name: sys_read_binary_file(text, bigint, bigint); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_read_binary_file(text, bigint, bigint) RETURNS bytea
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_read_binary_file_off_len$$;


ALTER FUNCTION sys_catalog.sys_read_binary_file(text, bigint, bigint) OWNER TO system;

--
-- Name: sys_read_binary_file(text, bigint, bigint, boolean); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_read_binary_file(text, bigint, bigint, boolean) RETURNS bytea
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_read_binary_file$$;


ALTER FUNCTION sys_catalog.sys_read_binary_file(text, bigint, bigint, boolean) OWNER TO system;

--
-- Name: sys_read_file(text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_read_file(text) RETURNS text
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_read_file_all$$;


ALTER FUNCTION sys_catalog.sys_read_file(text) OWNER TO system;

--
-- Name: sys_read_file(text, bigint, bigint); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_read_file(text, bigint, bigint) RETURNS text
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_read_file_off_len$$;


ALTER FUNCTION sys_catalog.sys_read_file(text, bigint, bigint) OWNER TO system;

--
-- Name: sys_read_file(text, bigint, bigint, boolean); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_read_file(text, bigint, bigint, boolean) RETURNS text
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_read_file_v2$$;


ALTER FUNCTION sys_catalog.sys_read_file(text, bigint, bigint, boolean) OWNER TO system;

--
-- Name: sys_read_file_old(text, bigint, bigint); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_read_file_old(text, bigint, bigint) RETURNS text
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_read_file$$;


ALTER FUNCTION sys_catalog.sys_read_file_old(text, bigint, bigint) OWNER TO system;

--
-- Name: sys_relation_filenode(regclass); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_relation_filenode(regclass) RETURNS oid
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_relation_filenode$$;


ALTER FUNCTION sys_catalog.sys_relation_filenode(regclass) OWNER TO system;

--
-- Name: sys_relation_filepath(regclass); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_relation_filepath(regclass) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_relation_filepath$$;


ALTER FUNCTION sys_catalog.sys_relation_filepath(regclass) OWNER TO system;

--
-- Name: sys_relation_is_publishable(regclass); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_relation_is_publishable(regclass) RETURNS boolean
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_relation_is_publishable$$;


ALTER FUNCTION sys_catalog.sys_relation_is_publishable(regclass) OWNER TO system;

--
-- Name: sys_relation_is_updatable(regclass, boolean); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_relation_is_updatable(regclass, boolean) RETURNS integer
    LANGUAGE internal STABLE STRICT COST 10 PARALLEL SAFE
    AS $$sys_relation_is_updatable$$;


ALTER FUNCTION sys_catalog.sys_relation_is_updatable(regclass, boolean) OWNER TO system;

--
-- Name: sys_relation_size(regclass); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_relation_size(regclass) RETURNS bigint
    LANGUAGE sql STRICT COST 1 PARALLEL SAFE
    AS $_$select pg_relation_size($1, 'main')$_$;


ALTER FUNCTION sys_catalog.sys_relation_size(regclass) OWNER TO system;

--
-- Name: sys_relation_size(regclass, text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_relation_size(regclass, text) RETURNS bigint
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_relation_size$$;


ALTER FUNCTION sys_catalog.sys_relation_size(regclass, text) OWNER TO system;

--
-- Name: sys_reload_conf(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_reload_conf() RETURNS boolean
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_reload_conf$$;


ALTER FUNCTION sys_catalog.sys_reload_conf() OWNER TO system;

--
-- Name: sys_replication_origin_advance(text, pg_lsn); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_replication_origin_advance(text, pg_lsn) RETURNS void
    LANGUAGE internal STRICT
    AS $$sys_replication_origin_advance$$;


ALTER FUNCTION sys_catalog.sys_replication_origin_advance(text, pg_lsn) OWNER TO system;

--
-- Name: sys_replication_origin_create(text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_replication_origin_create(text) RETURNS oid
    LANGUAGE internal STRICT
    AS $$sys_replication_origin_create$$;


ALTER FUNCTION sys_catalog.sys_replication_origin_create(text) OWNER TO system;

--
-- Name: sys_replication_origin_drop(text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_replication_origin_drop(text) RETURNS void
    LANGUAGE internal STRICT
    AS $$sys_replication_origin_drop$$;


ALTER FUNCTION sys_catalog.sys_replication_origin_drop(text) OWNER TO system;

--
-- Name: sys_replication_origin_oid(text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_replication_origin_oid(text) RETURNS oid
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_replication_origin_oid$$;


ALTER FUNCTION sys_catalog.sys_replication_origin_oid(text) OWNER TO system;

--
-- Name: sys_replication_origin_progress(text, boolean); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_replication_origin_progress(text, boolean) RETURNS pg_lsn
    LANGUAGE internal STRICT
    AS $$sys_replication_origin_progress$$;


ALTER FUNCTION sys_catalog.sys_replication_origin_progress(text, boolean) OWNER TO system;

--
-- Name: sys_replication_origin_session_is_setup(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_replication_origin_session_is_setup() RETURNS boolean
    LANGUAGE internal STRICT PARALLEL RESTRICTED
    AS $$sys_replication_origin_session_is_setup$$;


ALTER FUNCTION sys_catalog.sys_replication_origin_session_is_setup() OWNER TO system;

--
-- Name: sys_replication_origin_session_progress(boolean); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_replication_origin_session_progress(boolean) RETURNS pg_lsn
    LANGUAGE internal STRICT
    AS $$sys_replication_origin_session_progress$$;


ALTER FUNCTION sys_catalog.sys_replication_origin_session_progress(boolean) OWNER TO system;

--
-- Name: sys_replication_origin_session_reset(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_replication_origin_session_reset() RETURNS void
    LANGUAGE internal STRICT
    AS $$sys_replication_origin_session_reset$$;


ALTER FUNCTION sys_catalog.sys_replication_origin_session_reset() OWNER TO system;

--
-- Name: sys_replication_origin_session_setup(text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_replication_origin_session_setup(text) RETURNS void
    LANGUAGE internal STRICT
    AS $$sys_replication_origin_session_setup$$;


ALTER FUNCTION sys_catalog.sys_replication_origin_session_setup(text) OWNER TO system;

--
-- Name: sys_replication_origin_xact_reset(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_replication_origin_xact_reset() RETURNS void
    LANGUAGE internal STRICT PARALLEL RESTRICTED
    AS $$sys_replication_origin_xact_reset$$;


ALTER FUNCTION sys_catalog.sys_replication_origin_xact_reset() OWNER TO system;

--
-- Name: sys_replication_origin_xact_setup(pg_lsn, timestamp with time zone); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_replication_origin_xact_setup(pg_lsn, timestamp with time zone) RETURNS void
    LANGUAGE internal STRICT PARALLEL RESTRICTED
    AS $$sys_replication_origin_xact_setup$$;


ALTER FUNCTION sys_catalog.sys_replication_origin_xact_setup(pg_lsn, timestamp with time zone) OWNER TO system;

--
-- Name: sys_replication_slot_advance(name, pg_lsn); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_replication_slot_advance(slot_name name, upto_lsn pg_lsn, OUT slot_name name, OUT end_lsn pg_lsn) RETURNS record
    LANGUAGE internal STRICT
    AS $$sys_replication_slot_advance$$;


ALTER FUNCTION sys_catalog.sys_replication_slot_advance(slot_name name, upto_lsn pg_lsn, OUT slot_name name, OUT end_lsn pg_lsn) OWNER TO system;

--
-- Name: sys_rotate_logfile(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_rotate_logfile() RETURNS boolean
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_rotate_logfile_v2$$;


ALTER FUNCTION sys_catalog.sys_rotate_logfile() OWNER TO system;

--
-- Name: sys_rotate_logfile_old(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_rotate_logfile_old() RETURNS boolean
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_rotate_logfile$$;


ALTER FUNCTION sys_catalog.sys_rotate_logfile_old() OWNER TO system;

--
-- Name: sys_safe_snapshot_blocking_pids(integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_safe_snapshot_blocking_pids(integer) RETURNS integer[]
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_safe_snapshot_blocking_pids$$;


ALTER FUNCTION sys_catalog.sys_safe_snapshot_blocking_pids(integer) OWNER TO system;

--
-- Name: sys_sequence_last_value(regclass); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_sequence_last_value(regclass) RETURNS numeric
    LANGUAGE internal STRICT
    AS $$sys_sequence_last_value$$;


ALTER FUNCTION sys_catalog.sys_sequence_last_value(regclass) OWNER TO system;

--
-- Name: sys_sequence_parameters(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_sequence_parameters(sequence_oid oid, OUT start_value int16, OUT minimum_value int16, OUT maximum_value int16, OUT increment int16, OUT cycle_option boolean, OUT cache_size bigint, OUT data_type oid) RETURNS record
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_sequence_parameters$$;


ALTER FUNCTION sys_catalog.sys_sequence_parameters(sequence_oid oid, OUT start_value int16, OUT minimum_value int16, OUT maximum_value int16, OUT increment int16, OUT cycle_option boolean, OUT cache_size bigint, OUT data_type oid) OWNER TO system;

--
-- Name: sys_show_all_file_settings(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_show_all_file_settings(OUT sourcefile text, OUT sourceline integer, OUT seqno integer, OUT name text, OUT setting text, OUT applied boolean, OUT error text) RETURNS SETOF record
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$show_all_file_settings$$;


ALTER FUNCTION sys_catalog.sys_show_all_file_settings(OUT sourcefile text, OUT sourceline integer, OUT seqno integer, OUT name text, OUT setting text, OUT applied boolean, OUT error text) OWNER TO system;

--
-- Name: sys_show_all_settings(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_show_all_settings(OUT name text, OUT setting text, OUT unit text, OUT category text, OUT short_desc text, OUT extra_desc text, OUT context text, OUT vartype text, OUT source text, OUT min_val text, OUT max_val text, OUT enumvals text[], OUT boot_val text, OUT reset_val text, OUT sourcefile text, OUT sourceline integer, OUT pending_restart boolean) RETURNS SETOF record
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$show_all_settings$$;


ALTER FUNCTION sys_catalog.sys_show_all_settings(OUT name text, OUT setting text, OUT unit text, OUT category text, OUT short_desc text, OUT extra_desc text, OUT context text, OUT vartype text, OUT source text, OUT min_val text, OUT max_val text, OUT enumvals text[], OUT boot_val text, OUT reset_val text, OUT sourcefile text, OUT sourceline integer, OUT pending_restart boolean) OWNER TO system;

--
-- Name: sys_show_replication_origin_status(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_show_replication_origin_status(OUT local_id oid, OUT external_id text, OUT remote_lsn pg_lsn, OUT local_lsn pg_lsn) RETURNS SETOF record
    LANGUAGE internal ROWS 100 PARALLEL RESTRICTED
    AS $$sys_show_replication_origin_status$$;


ALTER FUNCTION sys_catalog.sys_show_replication_origin_status(OUT local_id oid, OUT external_id text, OUT remote_lsn pg_lsn, OUT local_lsn pg_lsn) OWNER TO system;

--
-- Name: sys_size_bytes(text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_size_bytes(text) RETURNS bigint
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_size_bytes$$;


ALTER FUNCTION sys_catalog.sys_size_bytes(text) OWNER TO system;

--
-- Name: sys_size_pretty(bigint); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_size_pretty(bigint) RETURNS text
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_size_pretty$$;


ALTER FUNCTION sys_catalog.sys_size_pretty(bigint) OWNER TO system;

--
-- Name: sys_size_pretty(numeric); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_size_pretty(numeric) RETURNS text
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_size_pretty_numeric$$;


ALTER FUNCTION sys_catalog.sys_size_pretty(numeric) OWNER TO system;

--
-- Name: sys_sleep(double precision); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_sleep(double precision) RETURNS void
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_sleep$$;


ALTER FUNCTION sys_catalog.sys_sleep(double precision) OWNER TO system;

--
-- Name: sys_sleep_for(interval); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_sleep_for(interval) RETURNS void
    LANGUAGE sql STRICT COST 1 PARALLEL SAFE
    AS $_$select pg_sleep_for($1)$_$;


ALTER FUNCTION sys_catalog.sys_sleep_for(interval) OWNER TO system;

--
-- Name: sys_sleep_until(timestamp with time zone); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_sleep_until(timestamp with time zone) RETURNS void
    LANGUAGE sql STRICT COST 1 PARALLEL SAFE
    AS $_$select pg_sleep(extract(epoch from $1) operator(-) extract(epoch from clock_timestamp()))$_$;


ALTER FUNCTION sys_catalog.sys_sleep_until(timestamp with time zone) OWNER TO system;

--
-- Name: sys_start_backup(text, boolean, boolean); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_start_backup(label text, fast boolean DEFAULT false, exclusive boolean DEFAULT true) RETURNS pg_lsn
    LANGUAGE internal STRICT PARALLEL RESTRICTED
    AS $$sys_start_backup$$;


ALTER FUNCTION sys_catalog.sys_start_backup(label text, fast boolean, exclusive boolean) OWNER TO system;

--
-- Name: sys_stat_clear_snapshot(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_clear_snapshot() RETURNS void
    LANGUAGE internal PARALLEL RESTRICTED
    AS $$sys_stat_clear_snapshot$$;


ALTER FUNCTION sys_catalog.sys_stat_clear_snapshot() OWNER TO system;

--
-- Name: sys_stat_file(text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_file(filename text, OUT size bigint, OUT access timestamp with time zone, OUT modification timestamp with time zone, OUT change timestamp with time zone, OUT creation timestamp with time zone, OUT isdir boolean) RETURNS record
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_stat_file_1arg$$;


ALTER FUNCTION sys_catalog.sys_stat_file(filename text, OUT size bigint, OUT access timestamp with time zone, OUT modification timestamp with time zone, OUT change timestamp with time zone, OUT creation timestamp with time zone, OUT isdir boolean) OWNER TO system;

--
-- Name: sys_stat_file(text, boolean); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_file(filename text, missingok boolean, OUT size bigint, OUT access timestamp with time zone, OUT modification timestamp with time zone, OUT change timestamp with time zone, OUT creation timestamp with time zone, OUT isdir boolean) RETURNS record
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_stat_file$$;


ALTER FUNCTION sys_catalog.sys_stat_file(filename text, missingok boolean, OUT size bigint, OUT access timestamp with time zone, OUT modification timestamp with time zone, OUT change timestamp with time zone, OUT creation timestamp with time zone, OUT isdir boolean) OWNER TO system;

--
-- Name: sys_stat_get_activity(integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_activity(pid integer, OUT datid oid, OUT pid integer, OUT usesysid oid, OUT application_name text, OUT state text, OUT query text, OUT wait_event_type text, OUT wait_event text, OUT xact_start timestamp with time zone, OUT query_start timestamp with time zone, OUT backend_start timestamp with time zone, OUT state_change timestamp with time zone, OUT client_addr inet, OUT client_hostname text, OUT client_port integer, OUT backend_xid xid, OUT backend_xmin xid, OUT backend_type text, OUT ssl boolean, OUT sslversion text, OUT sslcipher text, OUT sslbits integer, OUT sslcompression boolean, OUT ssl_client_dn text, OUT ssl_client_serial numeric, OUT ssl_issuer_dn text, OUT gss_auth boolean, OUT gss_princ text, OUT gss_enc boolean) RETURNS SETOF record
    LANGUAGE internal STABLE ROWS 100 PARALLEL RESTRICTED
    AS $$sys_stat_get_activity$$;


ALTER FUNCTION sys_catalog.sys_stat_get_activity(pid integer, OUT datid oid, OUT pid integer, OUT usesysid oid, OUT application_name text, OUT state text, OUT query text, OUT wait_event_type text, OUT wait_event text, OUT xact_start timestamp with time zone, OUT query_start timestamp with time zone, OUT backend_start timestamp with time zone, OUT state_change timestamp with time zone, OUT client_addr inet, OUT client_hostname text, OUT client_port integer, OUT backend_xid xid, OUT backend_xmin xid, OUT backend_type text, OUT ssl boolean, OUT sslversion text, OUT sslcipher text, OUT sslbits integer, OUT sslcompression boolean, OUT ssl_client_dn text, OUT ssl_client_serial numeric, OUT ssl_issuer_dn text, OUT gss_auth boolean, OUT gss_princ text, OUT gss_enc boolean) OWNER TO system;

--
-- Name: sys_stat_get_analyze_count(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_analyze_count(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_analyze_count$$;


ALTER FUNCTION sys_catalog.sys_stat_get_analyze_count(oid) OWNER TO system;

--
-- Name: sys_stat_get_archiver(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_archiver(OUT archived_count bigint, OUT last_archived_wal text, OUT last_archived_time timestamp with time zone, OUT failed_count bigint, OUT last_failed_wal text, OUT last_failed_time timestamp with time zone, OUT stats_reset timestamp with time zone) RETURNS record
    LANGUAGE internal STABLE PARALLEL RESTRICTED
    AS $$sys_stat_get_archiver$$;


ALTER FUNCTION sys_catalog.sys_stat_get_archiver(OUT archived_count bigint, OUT last_archived_wal text, OUT last_archived_time timestamp with time zone, OUT failed_count bigint, OUT last_failed_wal text, OUT last_failed_time timestamp with time zone, OUT stats_reset timestamp with time zone) OWNER TO system;

--
-- Name: sys_stat_get_autoanalyze_count(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_autoanalyze_count(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_autoanalyze_count$$;


ALTER FUNCTION sys_catalog.sys_stat_get_autoanalyze_count(oid) OWNER TO system;

--
-- Name: sys_stat_get_autovacuum_count(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_autovacuum_count(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_autovacuum_count$$;


ALTER FUNCTION sys_catalog.sys_stat_get_autovacuum_count(oid) OWNER TO system;

--
-- Name: sys_stat_get_backend_activity(integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_backend_activity(integer) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_backend_activity$$;


ALTER FUNCTION sys_catalog.sys_stat_get_backend_activity(integer) OWNER TO system;

--
-- Name: sys_stat_get_backend_activity_start(integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_backend_activity_start(integer) RETURNS timestamp with time zone
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_backend_activity_start$$;


ALTER FUNCTION sys_catalog.sys_stat_get_backend_activity_start(integer) OWNER TO system;

--
-- Name: sys_stat_get_backend_client_addr(integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_backend_client_addr(integer) RETURNS inet
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_backend_client_addr$$;


ALTER FUNCTION sys_catalog.sys_stat_get_backend_client_addr(integer) OWNER TO system;

--
-- Name: sys_stat_get_backend_client_port(integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_backend_client_port(integer) RETURNS integer
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_backend_client_port$$;


ALTER FUNCTION sys_catalog.sys_stat_get_backend_client_port(integer) OWNER TO system;

--
-- Name: sys_stat_get_backend_dbid(integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_backend_dbid(integer) RETURNS oid
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_backend_dbid$$;


ALTER FUNCTION sys_catalog.sys_stat_get_backend_dbid(integer) OWNER TO system;

--
-- Name: sys_stat_get_backend_idset(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_backend_idset() RETURNS SETOF integer
    LANGUAGE internal STABLE STRICT ROWS 100 PARALLEL RESTRICTED
    AS $$sys_stat_get_backend_idset$$;


ALTER FUNCTION sys_catalog.sys_stat_get_backend_idset() OWNER TO system;

--
-- Name: sys_stat_get_backend_name(integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_backend_name(pid integer) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_backend_name$$;


ALTER FUNCTION sys_catalog.sys_stat_get_backend_name(pid integer) OWNER TO system;

--
-- Name: sys_stat_get_backend_pid(integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_backend_pid(integer) RETURNS integer
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_backend_pid$$;


ALTER FUNCTION sys_catalog.sys_stat_get_backend_pid(integer) OWNER TO system;

--
-- Name: sys_stat_get_backend_start(integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_backend_start(integer) RETURNS timestamp with time zone
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_backend_start$$;


ALTER FUNCTION sys_catalog.sys_stat_get_backend_start(integer) OWNER TO system;

--
-- Name: sys_stat_get_backend_userid(integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_backend_userid(integer) RETURNS oid
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_backend_userid$$;


ALTER FUNCTION sys_catalog.sys_stat_get_backend_userid(integer) OWNER TO system;

--
-- Name: sys_stat_get_backend_wait_event(integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_backend_wait_event(integer) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_backend_wait_event$$;


ALTER FUNCTION sys_catalog.sys_stat_get_backend_wait_event(integer) OWNER TO system;

--
-- Name: sys_stat_get_backend_wait_event_type(integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_backend_wait_event_type(integer) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_backend_wait_event_type$$;


ALTER FUNCTION sys_catalog.sys_stat_get_backend_wait_event_type(integer) OWNER TO system;

--
-- Name: sys_stat_get_backend_xact_start(integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_backend_xact_start(integer) RETURNS timestamp with time zone
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_backend_xact_start$$;


ALTER FUNCTION sys_catalog.sys_stat_get_backend_xact_start(integer) OWNER TO system;

--
-- Name: sys_stat_get_bgwriter_buf_written_checkpoints(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_bgwriter_buf_written_checkpoints() RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_bgwriter_buf_written_checkpoints$$;


ALTER FUNCTION sys_catalog.sys_stat_get_bgwriter_buf_written_checkpoints() OWNER TO system;

--
-- Name: sys_stat_get_bgwriter_buf_written_clean(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_bgwriter_buf_written_clean() RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_bgwriter_buf_written_clean$$;


ALTER FUNCTION sys_catalog.sys_stat_get_bgwriter_buf_written_clean() OWNER TO system;

--
-- Name: sys_stat_get_bgwriter_maxwritten_clean(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_bgwriter_maxwritten_clean() RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_bgwriter_maxwritten_clean$$;


ALTER FUNCTION sys_catalog.sys_stat_get_bgwriter_maxwritten_clean() OWNER TO system;

--
-- Name: sys_stat_get_bgwriter_requested_checkpoints(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_bgwriter_requested_checkpoints() RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_bgwriter_requested_checkpoints$$;


ALTER FUNCTION sys_catalog.sys_stat_get_bgwriter_requested_checkpoints() OWNER TO system;

--
-- Name: sys_stat_get_bgwriter_stat_reset_time(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_bgwriter_stat_reset_time() RETURNS timestamp with time zone
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_bgwriter_stat_reset_time$$;


ALTER FUNCTION sys_catalog.sys_stat_get_bgwriter_stat_reset_time() OWNER TO system;

--
-- Name: sys_stat_get_bgwriter_timed_checkpoints(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_bgwriter_timed_checkpoints() RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_bgwriter_timed_checkpoints$$;


ALTER FUNCTION sys_catalog.sys_stat_get_bgwriter_timed_checkpoints() OWNER TO system;

--
-- Name: sys_stat_get_blocks_fetched(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_blocks_fetched(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_blocks_fetched$$;


ALTER FUNCTION sys_catalog.sys_stat_get_blocks_fetched(oid) OWNER TO system;

--
-- Name: sys_stat_get_blocks_hit(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_blocks_hit(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_blocks_hit$$;


ALTER FUNCTION sys_catalog.sys_stat_get_blocks_hit(oid) OWNER TO system;

--
-- Name: sys_stat_get_buf_alloc(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_buf_alloc() RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_buf_alloc$$;


ALTER FUNCTION sys_catalog.sys_stat_get_buf_alloc() OWNER TO system;

--
-- Name: sys_stat_get_buf_fsync_backend(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_buf_fsync_backend() RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_buf_fsync_backend$$;


ALTER FUNCTION sys_catalog.sys_stat_get_buf_fsync_backend() OWNER TO system;

--
-- Name: sys_stat_get_buf_written_backend(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_buf_written_backend() RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_buf_written_backend$$;


ALTER FUNCTION sys_catalog.sys_stat_get_buf_written_backend() OWNER TO system;

--
-- Name: sys_stat_get_cached_plans(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_cached_plans(OUT query text, OUT command text, OUT num_params bigint, OUT cursor_options bigint, OUT soft_parse bigint, OUT hard_parse bigint, OUT ref_count bigint, OUT is_oneshot boolean, OUT is_saved boolean, OUT is_valid boolean, OUT generic_cost double precision, OUT total_custom_cost double precision, OUT num_custom_plans bigint) RETURNS SETOF record
    LANGUAGE internal STABLE PARALLEL RESTRICTED
    AS $$sys_stat_get_cached_plans$$;


ALTER FUNCTION sys_catalog.sys_stat_get_cached_plans(OUT query text, OUT command text, OUT num_params bigint, OUT cursor_options bigint, OUT soft_parse bigint, OUT hard_parse bigint, OUT ref_count bigint, OUT is_oneshot boolean, OUT is_saved boolean, OUT is_valid boolean, OUT generic_cost double precision, OUT total_custom_cost double precision, OUT num_custom_plans bigint) OWNER TO system;

--
-- Name: sys_stat_get_checkpoint(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_checkpoint(OUT pid integer, OUT phase text, OUT flags text, OUT buffers_scan bigint, OUT buffers_processed bigint, OUT buffers_written bigint, OUT written_progress text, OUT write_rate text, OUT start_time text) RETURNS SETOF record
    LANGUAGE internal STABLE STRICT ROWS 1 PARALLEL RESTRICTED
    AS $$sys_stat_get_checkpoint$$;


ALTER FUNCTION sys_catalog.sys_stat_get_checkpoint(OUT pid integer, OUT phase text, OUT flags text, OUT buffers_scan bigint, OUT buffers_processed bigint, OUT buffers_written bigint, OUT written_progress text, OUT write_rate text, OUT start_time text) OWNER TO system;

--
-- Name: sys_stat_get_checkpoint_sync_time(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_checkpoint_sync_time() RETURNS double precision
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_checkpoint_sync_time$$;


ALTER FUNCTION sys_catalog.sys_stat_get_checkpoint_sync_time() OWNER TO system;

--
-- Name: sys_stat_get_checkpoint_write_time(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_checkpoint_write_time() RETURNS double precision
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_checkpoint_write_time$$;


ALTER FUNCTION sys_catalog.sys_stat_get_checkpoint_write_time() OWNER TO system;

--
-- Name: sys_stat_get_db_blk_read_time(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_blk_read_time(oid) RETURNS double precision
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_blk_read_time$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_blk_read_time(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_blk_write_time(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_blk_write_time(oid) RETURNS double precision
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_blk_write_time$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_blk_write_time(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_blocks_fetched(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_blocks_fetched(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_blocks_fetched$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_blocks_fetched(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_blocks_hit(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_blocks_hit(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_blocks_hit$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_blocks_hit(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_checksum_failures(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_checksum_failures(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_checksum_failures$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_checksum_failures(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_checksum_last_failure(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_checksum_last_failure(oid) RETURNS timestamp with time zone
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_checksum_last_failure$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_checksum_last_failure(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_conflict_all(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_conflict_all(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_conflict_all$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_conflict_all(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_conflict_bufferpin(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_conflict_bufferpin(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_conflict_bufferpin$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_conflict_bufferpin(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_conflict_lock(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_conflict_lock(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_conflict_lock$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_conflict_lock(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_conflict_snapshot(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_conflict_snapshot(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_conflict_snapshot$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_conflict_snapshot(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_conflict_startup_deadlock(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_conflict_startup_deadlock(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_conflict_startup_deadlock$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_conflict_startup_deadlock(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_conflict_tablespace(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_conflict_tablespace(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_conflict_tablespace$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_conflict_tablespace(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_deadlocks(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_deadlocks(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_deadlocks$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_deadlocks(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_fg_xact_commit(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_fg_xact_commit(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_fg_xact_commit$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_fg_xact_commit(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_fg_xact_rollback(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_fg_xact_rollback(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_fg_xact_rollback$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_fg_xact_rollback(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_numbackends(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_numbackends(oid) RETURNS integer
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_numbackends$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_numbackends(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_stat_reset_time(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_stat_reset_time(oid) RETURNS timestamp with time zone
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_stat_reset_time$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_stat_reset_time(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_temp_bytes(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_temp_bytes(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_temp_bytes$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_temp_bytes(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_temp_files(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_temp_files(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_temp_files$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_temp_files(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_tuples_deleted(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_tuples_deleted(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_tuples_deleted$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_tuples_deleted(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_tuples_fetched(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_tuples_fetched(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_tuples_fetched$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_tuples_fetched(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_tuples_inserted(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_tuples_inserted(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_tuples_inserted$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_tuples_inserted(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_tuples_returned(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_tuples_returned(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_tuples_returned$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_tuples_returned(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_tuples_updated(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_tuples_updated(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_tuples_updated$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_tuples_updated(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_xact_commit(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_xact_commit(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_xact_commit$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_xact_commit(oid) OWNER TO system;

--
-- Name: sys_stat_get_db_xact_rollback(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_db_xact_rollback(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_db_xact_rollback$$;


ALTER FUNCTION sys_catalog.sys_stat_get_db_xact_rollback(oid) OWNER TO system;

--
-- Name: sys_stat_get_dead_tuples(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_dead_tuples(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_dead_tuples$$;


ALTER FUNCTION sys_catalog.sys_stat_get_dead_tuples(oid) OWNER TO system;

--
-- Name: sys_stat_get_dsm_size(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_dsm_size() RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_dsm_size$$;


ALTER FUNCTION sys_catalog.sys_stat_get_dsm_size() OWNER TO system;

--
-- Name: sys_stat_get_function_calls(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_function_calls(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_function_calls$$;


ALTER FUNCTION sys_catalog.sys_stat_get_function_calls(oid) OWNER TO system;

--
-- Name: sys_stat_get_function_self_time(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_function_self_time(oid) RETURNS double precision
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_function_self_time$$;


ALTER FUNCTION sys_catalog.sys_stat_get_function_self_time(oid) OWNER TO system;

--
-- Name: sys_stat_get_function_total_time(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_function_total_time(oid) RETURNS double precision
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_function_total_time$$;


ALTER FUNCTION sys_catalog.sys_stat_get_function_total_time(oid) OWNER TO system;

--
-- Name: sys_stat_get_inst_pids(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_inst_pids(OUT pid integer, OUT name text) RETURNS SETOF record
    LANGUAGE internal STABLE PARALLEL RESTRICTED
    AS $$sys_stat_get_inst_pids$$;


ALTER FUNCTION sys_catalog.sys_stat_get_inst_pids(OUT pid integer, OUT name text) OWNER TO system;

--
-- Name: sys_stat_get_instance_reset_time(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_instance_reset_time(OUT instio timestamp with time zone, OUT instevent timestamp with time zone, OUT instlock timestamp with time zone, OUT sqltime timestamp with time zone, OUT sqlwait timestamp with time zone, OUT sqlio timestamp with time zone) RETURNS record
    LANGUAGE internal STABLE PARALLEL RESTRICTED
    AS $$sys_stat_get_instance_reset_time$$;


ALTER FUNCTION sys_catalog.sys_stat_get_instance_reset_time(OUT instio timestamp with time zone, OUT instevent timestamp with time zone, OUT instlock timestamp with time zone, OUT sqltime timestamp with time zone, OUT sqlwait timestamp with time zone, OUT sqlio timestamp with time zone) OWNER TO system;

--
-- Name: sys_stat_get_instevent(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_instevent(OUT datid oid, OUT event_type text, OUT event_name text, OUT background boolean, OUT calls bigint, OUT times bigint) RETURNS SETOF record
    LANGUAGE internal STABLE PARALLEL RESTRICTED
    AS $$sys_stat_get_instevent$$;


ALTER FUNCTION sys_catalog.sys_stat_get_instevent(OUT datid oid, OUT event_type text, OUT event_name text, OUT background boolean, OUT calls bigint, OUT times bigint) OWNER TO system;

--
-- Name: sys_stat_get_instio(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_instio(OUT backend_type text, OUT datid oid, OUT reltablespace oid, OUT relid oid, OUT io_type text, OUT file_type text, OUT wait_event text, OUT background boolean, OUT calls bigint, OUT times bigint, OUT bytes bigint) RETURNS SETOF record
    LANGUAGE internal STABLE PARALLEL RESTRICTED
    AS $$sys_stat_get_instio$$;


ALTER FUNCTION sys_catalog.sys_stat_get_instio(OUT backend_type text, OUT datid oid, OUT reltablespace oid, OUT relid oid, OUT io_type text, OUT file_type text, OUT wait_event text, OUT background boolean, OUT calls bigint, OUT times bigint, OUT bytes bigint) OWNER TO system;

--
-- Name: sys_stat_get_instlock(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_instlock(OUT datid oid, OUT lock_name text, OUT lock_mode text, OUT acquire_type text, OUT background boolean, OUT calls bigint, OUT nowait_gets bigint, OUT nowait_miss bigint, OUT wait_gets bigint, OUT wait_miss bigint, OUT wait_times bigint) RETURNS SETOF record
    LANGUAGE internal STABLE PARALLEL RESTRICTED
    AS $$sys_stat_get_instlock$$;


ALTER FUNCTION sys_catalog.sys_stat_get_instlock(OUT datid oid, OUT lock_name text, OUT lock_mode text, OUT acquire_type text, OUT background boolean, OUT calls bigint, OUT nowait_gets bigint, OUT nowait_miss bigint, OUT wait_gets bigint, OUT wait_miss bigint, OUT wait_times bigint) OWNER TO system;

--
-- Name: sys_stat_get_last_analyze_time(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_last_analyze_time(oid) RETURNS timestamp with time zone
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_last_analyze_time$$;


ALTER FUNCTION sys_catalog.sys_stat_get_last_analyze_time(oid) OWNER TO system;

--
-- Name: sys_stat_get_last_autoanalyze_time(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_last_autoanalyze_time(oid) RETURNS timestamp with time zone
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_last_autoanalyze_time$$;


ALTER FUNCTION sys_catalog.sys_stat_get_last_autoanalyze_time(oid) OWNER TO system;

--
-- Name: sys_stat_get_last_autovacuum_time(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_last_autovacuum_time(oid) RETURNS timestamp with time zone
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_last_autovacuum_time$$;


ALTER FUNCTION sys_catalog.sys_stat_get_last_autovacuum_time(oid) OWNER TO system;

--
-- Name: sys_stat_get_last_vacuum_time(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_last_vacuum_time(oid) RETURNS timestamp with time zone
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_last_vacuum_time$$;


ALTER FUNCTION sys_catalog.sys_stat_get_last_vacuum_time(oid) OWNER TO system;

--
-- Name: sys_stat_get_live_tuples(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_live_tuples(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_live_tuples$$;


ALTER FUNCTION sys_catalog.sys_stat_get_live_tuples(oid) OWNER TO system;

--
-- Name: sys_stat_get_mod_since_analyze(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_mod_since_analyze(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_mod_since_analyze$$;


ALTER FUNCTION sys_catalog.sys_stat_get_mod_since_analyze(oid) OWNER TO system;

--
-- Name: sys_stat_get_numscans(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_numscans(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_numscans$$;


ALTER FUNCTION sys_catalog.sys_stat_get_numscans(oid) OWNER TO system;

--
-- Name: sys_stat_get_progress_info(text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_progress_info(cmdtype text, OUT pid integer, OUT datid oid, OUT relid oid, OUT param1 bigint, OUT param2 bigint, OUT param3 bigint, OUT param4 bigint, OUT param5 bigint, OUT param6 bigint, OUT param7 bigint, OUT param8 bigint, OUT param9 bigint, OUT param10 bigint, OUT param11 bigint, OUT param12 bigint, OUT param13 bigint, OUT param14 bigint, OUT param15 bigint, OUT param16 bigint, OUT param17 bigint, OUT param18 bigint, OUT param19 bigint, OUT param20 bigint) RETURNS SETOF record
    LANGUAGE internal STABLE STRICT ROWS 100 PARALLEL RESTRICTED
    AS $$sys_stat_get_progress_info$$;


ALTER FUNCTION sys_catalog.sys_stat_get_progress_info(cmdtype text, OUT pid integer, OUT datid oid, OUT relid oid, OUT param1 bigint, OUT param2 bigint, OUT param3 bigint, OUT param4 bigint, OUT param5 bigint, OUT param6 bigint, OUT param7 bigint, OUT param8 bigint, OUT param9 bigint, OUT param10 bigint, OUT param11 bigint, OUT param12 bigint, OUT param13 bigint, OUT param14 bigint, OUT param15 bigint, OUT param16 bigint, OUT param17 bigint, OUT param18 bigint, OUT param19 bigint, OUT param20 bigint) OWNER TO system;

--
-- Name: sys_stat_get_shmem(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_shmem(OUT name text, OUT size bigint) RETURNS SETOF record
    LANGUAGE internal STABLE PARALLEL RESTRICTED
    AS $$sys_stat_get_shmem$$;


ALTER FUNCTION sys_catalog.sys_stat_get_shmem(OUT name text, OUT size bigint) OWNER TO system;

--
-- Name: sys_stat_get_snapshot_timestamp(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_snapshot_timestamp() RETURNS timestamp with time zone
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_snapshot_timestamp$$;


ALTER FUNCTION sys_catalog.sys_stat_get_snapshot_timestamp() OWNER TO system;

--
-- Name: sys_stat_get_sqlio(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_sqlio(OUT userid oid, OUT datid oid, OUT queryid bigint, OUT bgio boolean, OUT wal_records bigint, OUT wal_fpi bigint, OUT wal_bytes bigint, OUT shared_blks_hit bigint, OUT shared_blks_read bigint, OUT shared_blks_dirtied bigint, OUT shared_blks_written bigint, OUT local_blks_hit bigint, OUT local_blks_read bigint, OUT local_blks_dirtied bigint, OUT local_blks_written bigint, OUT temp_blks_read bigint, OUT temp_blks_written bigint, OUT blk_read_time bigint, OUT blk_write_time bigint) RETURNS SETOF record
    LANGUAGE internal STABLE PARALLEL RESTRICTED
    AS $$sys_stat_get_sqlio$$;


ALTER FUNCTION sys_catalog.sys_stat_get_sqlio(OUT userid oid, OUT datid oid, OUT queryid bigint, OUT bgio boolean, OUT wal_records bigint, OUT wal_fpi bigint, OUT wal_bytes bigint, OUT shared_blks_hit bigint, OUT shared_blks_read bigint, OUT shared_blks_dirtied bigint, OUT shared_blks_written bigint, OUT local_blks_hit bigint, OUT local_blks_read bigint, OUT local_blks_dirtied bigint, OUT local_blks_written bigint, OUT temp_blks_read bigint, OUT temp_blks_written bigint, OUT blk_read_time bigint, OUT blk_write_time bigint) OWNER TO system;

--
-- Name: sys_stat_get_sqltime(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_sqltime(OUT userid oid, OUT datid oid, OUT queryid bigint, OUT message text, OUT bgmsg boolean, OUT calls bigint, OUT times bigint) RETURNS SETOF record
    LANGUAGE internal STABLE PARALLEL RESTRICTED
    AS $$sys_stat_get_sqltime$$;


ALTER FUNCTION sys_catalog.sys_stat_get_sqltime(OUT userid oid, OUT datid oid, OUT queryid bigint, OUT message text, OUT bgmsg boolean, OUT calls bigint, OUT times bigint) OWNER TO system;

--
-- Name: sys_stat_get_sqlwait(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_sqlwait(OUT userid oid, OUT datid oid, OUT queryid bigint, OUT wait_event_type text, OUT wait_event text, OUT bgwait boolean, OUT calls bigint, OUT times bigint) RETURNS SETOF record
    LANGUAGE internal STABLE PARALLEL RESTRICTED
    AS $$sys_stat_get_sqlwait$$;


ALTER FUNCTION sys_catalog.sys_stat_get_sqlwait(OUT userid oid, OUT datid oid, OUT queryid bigint, OUT wait_event_type text, OUT wait_event text, OUT bgwait boolean, OUT calls bigint, OUT times bigint) OWNER TO system;

--
-- Name: sys_stat_get_subscription(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_subscription(subid oid, OUT subid oid, OUT relid oid, OUT pid integer, OUT received_lsn pg_lsn, OUT last_msg_send_time timestamp with time zone, OUT last_msg_receipt_time timestamp with time zone, OUT latest_end_lsn pg_lsn, OUT latest_end_time timestamp with time zone) RETURNS record
    LANGUAGE internal STABLE PARALLEL RESTRICTED
    AS $$sys_stat_get_subscription$$;


ALTER FUNCTION sys_catalog.sys_stat_get_subscription(subid oid, OUT subid oid, OUT relid oid, OUT pid integer, OUT received_lsn pg_lsn, OUT last_msg_send_time timestamp with time zone, OUT last_msg_receipt_time timestamp with time zone, OUT latest_end_lsn pg_lsn, OUT latest_end_time timestamp with time zone) OWNER TO system;

--
-- Name: sys_stat_get_tuples_deleted(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_tuples_deleted(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_tuples_deleted$$;


ALTER FUNCTION sys_catalog.sys_stat_get_tuples_deleted(oid) OWNER TO system;

--
-- Name: sys_stat_get_tuples_fetched(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_tuples_fetched(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_tuples_fetched$$;


ALTER FUNCTION sys_catalog.sys_stat_get_tuples_fetched(oid) OWNER TO system;

--
-- Name: sys_stat_get_tuples_hot_updated(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_tuples_hot_updated(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_tuples_hot_updated$$;


ALTER FUNCTION sys_catalog.sys_stat_get_tuples_hot_updated(oid) OWNER TO system;

--
-- Name: sys_stat_get_tuples_inserted(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_tuples_inserted(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_tuples_inserted$$;


ALTER FUNCTION sys_catalog.sys_stat_get_tuples_inserted(oid) OWNER TO system;

--
-- Name: sys_stat_get_tuples_returned(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_tuples_returned(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_tuples_returned$$;


ALTER FUNCTION sys_catalog.sys_stat_get_tuples_returned(oid) OWNER TO system;

--
-- Name: sys_stat_get_tuples_updated(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_tuples_updated(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_tuples_updated$$;


ALTER FUNCTION sys_catalog.sys_stat_get_tuples_updated(oid) OWNER TO system;

--
-- Name: sys_stat_get_vacuum_count(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_vacuum_count(oid) RETURNS bigint
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_vacuum_count$$;


ALTER FUNCTION sys_catalog.sys_stat_get_vacuum_count(oid) OWNER TO system;

--
-- Name: sys_stat_get_wal_buffer(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_wal_buffer(OUT name text, OUT bytes integer, OUT utilization_rate text, OUT copied_to text, OUT copied_to_lsn pg_lsn, OUT coping_data_len integer, OUT written_to text, OUT written_to_lsn pg_lsn, OUT writing_data_len integer, OUT write_rate text) RETURNS record
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_stat_get_wal_buffer$$;


ALTER FUNCTION sys_catalog.sys_stat_get_wal_buffer(OUT name text, OUT bytes integer, OUT utilization_rate text, OUT copied_to text, OUT copied_to_lsn pg_lsn, OUT coping_data_len integer, OUT written_to text, OUT written_to_lsn pg_lsn, OUT writing_data_len integer, OUT write_rate text) OWNER TO system;

--
-- Name: sys_stat_get_wal_receiver(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_wal_receiver(OUT pid integer, OUT status text, OUT receive_start_lsn pg_lsn, OUT receive_start_tli integer, OUT received_lsn pg_lsn, OUT received_tli integer, OUT last_msg_send_time timestamp with time zone, OUT last_msg_receipt_time timestamp with time zone, OUT latest_end_lsn pg_lsn, OUT latest_end_time timestamp with time zone, OUT slot_name text, OUT sender_host text, OUT sender_port integer, OUT conninfo text) RETURNS record
    LANGUAGE internal STABLE PARALLEL RESTRICTED
    AS $$sys_stat_get_wal_receiver$$;


ALTER FUNCTION sys_catalog.sys_stat_get_wal_receiver(OUT pid integer, OUT status text, OUT receive_start_lsn pg_lsn, OUT receive_start_tli integer, OUT received_lsn pg_lsn, OUT received_tli integer, OUT last_msg_send_time timestamp with time zone, OUT last_msg_receipt_time timestamp with time zone, OUT latest_end_lsn pg_lsn, OUT latest_end_time timestamp with time zone, OUT slot_name text, OUT sender_host text, OUT sender_port integer, OUT conninfo text) OWNER TO system;

--
-- Name: sys_stat_get_wal_senders(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_wal_senders(OUT pid integer, OUT state text, OUT sent_lsn pg_lsn, OUT write_lsn pg_lsn, OUT flush_lsn pg_lsn, OUT replay_lsn pg_lsn, OUT write_lag interval, OUT flush_lag interval, OUT replay_lag interval, OUT sync_priority integer, OUT sync_state text, OUT reply_time timestamp with time zone) RETURNS SETOF record
    LANGUAGE internal STABLE ROWS 10 PARALLEL RESTRICTED
    AS $$sys_stat_get_wal_senders$$;


ALTER FUNCTION sys_catalog.sys_stat_get_wal_senders(OUT pid integer, OUT state text, OUT sent_lsn pg_lsn, OUT write_lsn pg_lsn, OUT flush_lsn pg_lsn, OUT replay_lsn pg_lsn, OUT write_lag interval, OUT flush_lag interval, OUT replay_lag interval, OUT sync_priority integer, OUT sync_state text, OUT reply_time timestamp with time zone) OWNER TO system;

--
-- Name: sys_stat_get_xact_blocks_fetched(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_xact_blocks_fetched(oid) RETURNS bigint
    LANGUAGE internal STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_xact_blocks_fetched$$;


ALTER FUNCTION sys_catalog.sys_stat_get_xact_blocks_fetched(oid) OWNER TO system;

--
-- Name: sys_stat_get_xact_blocks_hit(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_xact_blocks_hit(oid) RETURNS bigint
    LANGUAGE internal STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_xact_blocks_hit$$;


ALTER FUNCTION sys_catalog.sys_stat_get_xact_blocks_hit(oid) OWNER TO system;

--
-- Name: sys_stat_get_xact_function_calls(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_xact_function_calls(oid) RETURNS bigint
    LANGUAGE internal STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_xact_function_calls$$;


ALTER FUNCTION sys_catalog.sys_stat_get_xact_function_calls(oid) OWNER TO system;

--
-- Name: sys_stat_get_xact_function_self_time(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_xact_function_self_time(oid) RETURNS double precision
    LANGUAGE internal STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_xact_function_self_time$$;


ALTER FUNCTION sys_catalog.sys_stat_get_xact_function_self_time(oid) OWNER TO system;

--
-- Name: sys_stat_get_xact_function_total_time(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_xact_function_total_time(oid) RETURNS double precision
    LANGUAGE internal STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_xact_function_total_time$$;


ALTER FUNCTION sys_catalog.sys_stat_get_xact_function_total_time(oid) OWNER TO system;

--
-- Name: sys_stat_get_xact_numscans(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_xact_numscans(oid) RETURNS bigint
    LANGUAGE internal STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_xact_numscans$$;


ALTER FUNCTION sys_catalog.sys_stat_get_xact_numscans(oid) OWNER TO system;

--
-- Name: sys_stat_get_xact_tuples_deleted(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_xact_tuples_deleted(oid) RETURNS bigint
    LANGUAGE internal STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_xact_tuples_deleted$$;


ALTER FUNCTION sys_catalog.sys_stat_get_xact_tuples_deleted(oid) OWNER TO system;

--
-- Name: sys_stat_get_xact_tuples_fetched(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_xact_tuples_fetched(oid) RETURNS bigint
    LANGUAGE internal STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_xact_tuples_fetched$$;


ALTER FUNCTION sys_catalog.sys_stat_get_xact_tuples_fetched(oid) OWNER TO system;

--
-- Name: sys_stat_get_xact_tuples_hot_updated(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_xact_tuples_hot_updated(oid) RETURNS bigint
    LANGUAGE internal STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_xact_tuples_hot_updated$$;


ALTER FUNCTION sys_catalog.sys_stat_get_xact_tuples_hot_updated(oid) OWNER TO system;

--
-- Name: sys_stat_get_xact_tuples_inserted(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_xact_tuples_inserted(oid) RETURNS bigint
    LANGUAGE internal STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_xact_tuples_inserted$$;


ALTER FUNCTION sys_catalog.sys_stat_get_xact_tuples_inserted(oid) OWNER TO system;

--
-- Name: sys_stat_get_xact_tuples_returned(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_xact_tuples_returned(oid) RETURNS bigint
    LANGUAGE internal STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_xact_tuples_returned$$;


ALTER FUNCTION sys_catalog.sys_stat_get_xact_tuples_returned(oid) OWNER TO system;

--
-- Name: sys_stat_get_xact_tuples_updated(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_get_xact_tuples_updated(oid) RETURNS bigint
    LANGUAGE internal STRICT PARALLEL RESTRICTED
    AS $$sys_stat_get_xact_tuples_updated$$;


ALTER FUNCTION sys_catalog.sys_stat_get_xact_tuples_updated(oid) OWNER TO system;

--
-- Name: sys_stat_reset(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_reset() RETURNS void
    LANGUAGE internal PARALLEL SAFE
    AS $$sys_stat_reset$$;


ALTER FUNCTION sys_catalog.sys_stat_reset() OWNER TO system;

--
-- Name: sys_stat_reset_shared(text); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_reset_shared(text) RETURNS void
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_stat_reset_shared$$;


ALTER FUNCTION sys_catalog.sys_stat_reset_shared(text) OWNER TO system;

--
-- Name: sys_stat_reset_single_function_counters(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_reset_single_function_counters(oid) RETURNS void
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_stat_reset_single_function_counters$$;


ALTER FUNCTION sys_catalog.sys_stat_reset_single_function_counters(oid) OWNER TO system;

--
-- Name: sys_stat_reset_single_table_counters(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stat_reset_single_table_counters(oid) RETURNS void
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_stat_reset_single_table_counters$$;


ALTER FUNCTION sys_catalog.sys_stat_reset_single_table_counters(oid) OWNER TO system;

--
-- Name: sys_statistics_obj_is_visible(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_statistics_obj_is_visible(oid) RETURNS boolean
    LANGUAGE internal STABLE STRICT COST 10 PARALLEL SAFE
    AS $$sys_statistics_obj_is_visible$$;


ALTER FUNCTION sys_catalog.sys_statistics_obj_is_visible(oid) OWNER TO system;

--
-- Name: sys_stop_backup(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stop_backup() RETURNS pg_lsn
    LANGUAGE internal STRICT PARALLEL RESTRICTED
    AS $$sys_stop_backup$$;


ALTER FUNCTION sys_catalog.sys_stop_backup() OWNER TO system;

--
-- Name: sys_stop_backup(boolean, boolean); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_stop_backup(exclusive boolean, wait_for_archive boolean DEFAULT true, OUT lsn pg_lsn, OUT labelfile text, OUT spcmapfile text) RETURNS SETOF record
    LANGUAGE internal STRICT PARALLEL RESTRICTED
    AS $$sys_stop_backup_v2$$;


ALTER FUNCTION sys_catalog.sys_stop_backup(exclusive boolean, wait_for_archive boolean, OUT lsn pg_lsn, OUT labelfile text, OUT spcmapfile text) OWNER TO system;

--
-- Name: sys_switch_wal(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_switch_wal() RETURNS pg_lsn
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_switch_wal$$;


ALTER FUNCTION sys_catalog.sys_switch_wal() OWNER TO system;

--
-- Name: sys_table_is_visible(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_table_is_visible(oid) RETURNS boolean
    LANGUAGE internal STABLE STRICT COST 10 PARALLEL SAFE
    AS $$sys_table_is_visible$$;


ALTER FUNCTION sys_catalog.sys_table_is_visible(oid) OWNER TO system;

--
-- Name: sys_table_size(regclass); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_table_size(regclass) RETURNS bigint
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_table_size$$;


ALTER FUNCTION sys_catalog.sys_table_size(regclass) OWNER TO system;

--
-- Name: sys_tablespace_databases(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_tablespace_databases(oid) RETURNS SETOF oid
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_tablespace_databases$$;


ALTER FUNCTION sys_catalog.sys_tablespace_databases(oid) OWNER TO system;

--
-- Name: sys_tablespace_location(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_tablespace_location(oid) RETURNS text
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_tablespace_location$$;


ALTER FUNCTION sys_catalog.sys_tablespace_location(oid) OWNER TO system;

--
-- Name: sys_tablespace_size(name); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_tablespace_size(name) RETURNS bigint
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_tablespace_size_name$$;


ALTER FUNCTION sys_catalog.sys_tablespace_size(name) OWNER TO system;

--
-- Name: sys_tablespace_size(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_tablespace_size(oid) RETURNS bigint
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_tablespace_size_oid$$;


ALTER FUNCTION sys_catalog.sys_tablespace_size(oid) OWNER TO system;

--
-- Name: sys_terminate_backend(integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_terminate_backend(integer) RETURNS boolean
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_terminate_backend$$;


ALTER FUNCTION sys_catalog.sys_terminate_backend(integer) OWNER TO system;

--
-- Name: sys_timezone_abbrevs(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_timezone_abbrevs(OUT abbrev text, OUT utc_offset interval, OUT is_dst boolean) RETURNS SETOF record
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_timezone_abbrevs$$;


ALTER FUNCTION sys_catalog.sys_timezone_abbrevs(OUT abbrev text, OUT utc_offset interval, OUT is_dst boolean) OWNER TO system;

--
-- Name: sys_timezone_names(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_timezone_names(OUT name text, OUT abbrev text, OUT utc_offset interval, OUT is_dst boolean) RETURNS SETOF record
    LANGUAGE internal STABLE STRICT PARALLEL SAFE
    AS $$sys_timezone_names$$;


ALTER FUNCTION sys_catalog.sys_timezone_names(OUT name text, OUT abbrev text, OUT utc_offset interval, OUT is_dst boolean) OWNER TO system;

--
-- Name: sys_total_relation_size(regclass); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_total_relation_size(regclass) RETURNS bigint
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_total_relation_size$$;


ALTER FUNCTION sys_catalog.sys_total_relation_size(regclass) OWNER TO system;

--
-- Name: sys_trigger_depth(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_trigger_depth() RETURNS integer
    LANGUAGE internal STABLE STRICT PARALLEL RESTRICTED
    AS $$sys_trigger_depth$$;


ALTER FUNCTION sys_catalog.sys_trigger_depth() OWNER TO system;

--
-- Name: sys_try_advisory_lock(bigint); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_try_advisory_lock(bigint) RETURNS boolean
    LANGUAGE internal STRICT
    AS $$sys_try_advisory_lock_int8$$;


ALTER FUNCTION sys_catalog.sys_try_advisory_lock(bigint) OWNER TO system;

--
-- Name: sys_try_advisory_lock(integer, integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_try_advisory_lock(integer, integer) RETURNS boolean
    LANGUAGE internal STRICT
    AS $$sys_try_advisory_lock_int4$$;


ALTER FUNCTION sys_catalog.sys_try_advisory_lock(integer, integer) OWNER TO system;

--
-- Name: sys_try_advisory_lock_shared(bigint); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_try_advisory_lock_shared(bigint) RETURNS boolean
    LANGUAGE internal STRICT
    AS $$sys_try_advisory_lock_shared_int8$$;


ALTER FUNCTION sys_catalog.sys_try_advisory_lock_shared(bigint) OWNER TO system;

--
-- Name: sys_try_advisory_lock_shared(integer, integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_try_advisory_lock_shared(integer, integer) RETURNS boolean
    LANGUAGE internal STRICT
    AS $$sys_try_advisory_lock_shared_int4$$;


ALTER FUNCTION sys_catalog.sys_try_advisory_lock_shared(integer, integer) OWNER TO system;

--
-- Name: sys_try_advisory_xact_lock(bigint); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_try_advisory_xact_lock(bigint) RETURNS boolean
    LANGUAGE internal STRICT
    AS $$sys_try_advisory_xact_lock_int8$$;


ALTER FUNCTION sys_catalog.sys_try_advisory_xact_lock(bigint) OWNER TO system;

--
-- Name: sys_try_advisory_xact_lock(integer, integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_try_advisory_xact_lock(integer, integer) RETURNS boolean
    LANGUAGE internal STRICT
    AS $$sys_try_advisory_xact_lock_int4$$;


ALTER FUNCTION sys_catalog.sys_try_advisory_xact_lock(integer, integer) OWNER TO system;

--
-- Name: sys_try_advisory_xact_lock_shared(bigint); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_try_advisory_xact_lock_shared(bigint) RETURNS boolean
    LANGUAGE internal STRICT
    AS $$sys_try_advisory_xact_lock_shared_int8$$;


ALTER FUNCTION sys_catalog.sys_try_advisory_xact_lock_shared(bigint) OWNER TO system;

--
-- Name: sys_try_advisory_xact_lock_shared(integer, integer); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_try_advisory_xact_lock_shared(integer, integer) RETURNS boolean
    LANGUAGE internal STRICT
    AS $$sys_try_advisory_xact_lock_shared_int4$$;


ALTER FUNCTION sys_catalog.sys_try_advisory_xact_lock_shared(integer, integer) OWNER TO system;

--
-- Name: sys_ts_config_is_visible(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_ts_config_is_visible(oid) RETURNS boolean
    LANGUAGE internal STABLE STRICT COST 10 PARALLEL SAFE
    AS $$sys_ts_config_is_visible$$;


ALTER FUNCTION sys_catalog.sys_ts_config_is_visible(oid) OWNER TO system;

--
-- Name: sys_ts_dict_is_visible(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_ts_dict_is_visible(oid) RETURNS boolean
    LANGUAGE internal STABLE STRICT COST 10 PARALLEL SAFE
    AS $$sys_ts_dict_is_visible$$;


ALTER FUNCTION sys_catalog.sys_ts_dict_is_visible(oid) OWNER TO system;

--
-- Name: sys_ts_parser_is_visible(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_ts_parser_is_visible(oid) RETURNS boolean
    LANGUAGE internal STABLE STRICT COST 10 PARALLEL SAFE
    AS $$sys_ts_parser_is_visible$$;


ALTER FUNCTION sys_catalog.sys_ts_parser_is_visible(oid) OWNER TO system;

--
-- Name: sys_ts_template_is_visible(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_ts_template_is_visible(oid) RETURNS boolean
    LANGUAGE internal STABLE STRICT COST 10 PARALLEL SAFE
    AS $$sys_ts_template_is_visible$$;


ALTER FUNCTION sys_catalog.sys_ts_template_is_visible(oid) OWNER TO system;

--
-- Name: sys_type_is_visible(oid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_type_is_visible(oid) RETURNS boolean
    LANGUAGE internal STABLE STRICT COST 10 PARALLEL SAFE
    AS $$sys_type_is_visible$$;


ALTER FUNCTION sys_catalog.sys_type_is_visible(oid) OWNER TO system;

--
-- Name: sys_typeof("any"); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_typeof("any") RETURNS regtype
    LANGUAGE internal STABLE PARALLEL SAFE
    AS $$sys_typeof$$;


ALTER FUNCTION sys_catalog.sys_typeof("any") OWNER TO system;

--
-- Name: sys_wal_lsn_diff(pg_lsn, pg_lsn); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_wal_lsn_diff(pg_lsn, pg_lsn) RETURNS numeric
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_wal_lsn_diff$$;


ALTER FUNCTION sys_catalog.sys_wal_lsn_diff(pg_lsn, pg_lsn) OWNER TO system;

--
-- Name: sys_wal_replay_pause(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_wal_replay_pause() RETURNS void
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_wal_replay_pause$$;


ALTER FUNCTION sys_catalog.sys_wal_replay_pause() OWNER TO system;

--
-- Name: sys_wal_replay_resume(); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_wal_replay_resume() RETURNS void
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_wal_replay_resume$$;


ALTER FUNCTION sys_catalog.sys_wal_replay_resume() OWNER TO system;

--
-- Name: sys_walfile_name(pg_lsn); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_walfile_name(pg_lsn) RETURNS text
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_walfile_name$$;


ALTER FUNCTION sys_catalog.sys_walfile_name(pg_lsn) OWNER TO system;

--
-- Name: sys_walfile_name_offset(pg_lsn); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_walfile_name_offset(lsn pg_lsn, OUT file_name text, OUT file_offset integer) RETURNS record
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$sys_walfile_name_offset$$;


ALTER FUNCTION sys_catalog.sys_walfile_name_offset(lsn pg_lsn, OUT file_name text, OUT file_offset integer) OWNER TO system;

--
-- Name: sys_xact_commit_timestamp(xid); Type: FUNCTION; Schema: sys_catalog; Owner: system
--

CREATE FUNCTION sys_catalog.sys_xact_commit_timestamp(xid) RETURNS timestamp with time zone
    LANGUAGE internal STRICT PARALLEL SAFE
    AS $$sys_xact_commit_timestamp$$;


ALTER FUNCTION sys_catalog.sys_xact_commit_timestamp(xid) OWNER TO system;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: dual; Type: TABLE; Schema: public; Owner: system
--

CREATE TABLE public.dual (
    dummy character(1)
);


ALTER TABLE public.dual OWNER TO system;

--
-- Name: tb_course; Type: TABLE; Schema: public; Owner: system
--

CREATE TABLE public.tb_course (
    course_id integer NOT NULL,
    course_no character varying(20) NOT NULL,
    course_name character varying(100) NOT NULL,
    course_type character varying(20),
    credit numeric(4,1),
    period integer,
    dept_id integer NOT NULL,
    tea_id integer NOT NULL,
    term character varying(20) NOT NULL,
    capacity integer NOT NULL,
    selected_num integer DEFAULT 0 NOT NULL,
    course_desc character varying(500),
    status character(1) DEFAULT '1'::bpchar NOT NULL,
    CONSTRAINT ck_course_capacity CHECK ((capacity > 0)),
    CONSTRAINT ck_course_selected CHECK (((selected_num >= 0) AND (selected_num <= capacity))),
    CONSTRAINT ck_course_status CHECK ((status = ANY (ARRAY['1'::bpchar, '0'::bpchar])))
);


ALTER TABLE public.tb_course OWNER TO system;

--
-- Name: tb_course_course_id_seq; Type: SEQUENCE; Schema: public; Owner: system
--

ALTER TABLE public.tb_course ALTER COLUMN course_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tb_course_course_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tb_department; Type: TABLE; Schema: public; Owner: system
--

CREATE TABLE public.tb_department (
    dept_id integer NOT NULL,
    dept_code character varying(20) NOT NULL,
    dept_name character varying(100) NOT NULL,
    status character(1) DEFAULT '1'::bpchar NOT NULL,
    CONSTRAINT ck_dept_status CHECK ((status = ANY (ARRAY['1'::bpchar, '0'::bpchar])))
);


ALTER TABLE public.tb_department OWNER TO system;

--
-- Name: tb_department_dept_id_seq; Type: SEQUENCE; Schema: public; Owner: system
--

ALTER TABLE public.tb_department ALTER COLUMN dept_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tb_department_dept_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tb_major; Type: TABLE; Schema: public; Owner: system
--

CREATE TABLE public.tb_major (
    major_id integer NOT NULL,
    major_code character varying(20) NOT NULL,
    major_name character varying(100) NOT NULL,
    dept_id integer NOT NULL,
    status character(1) DEFAULT '1'::bpchar NOT NULL,
    CONSTRAINT ck_major_status CHECK ((status = ANY (ARRAY['1'::bpchar, '0'::bpchar])))
);


ALTER TABLE public.tb_major OWNER TO system;

--
-- Name: tb_major_major_id_seq; Type: SEQUENCE; Schema: public; Owner: system
--

ALTER TABLE public.tb_major ALTER COLUMN major_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tb_major_major_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tb_student; Type: TABLE; Schema: public; Owner: system
--

CREATE TABLE public.tb_student (
    stu_id integer NOT NULL,
    stu_no character varying(20) NOT NULL,
    stu_name character varying(50) NOT NULL,
    gender character(1),
    birthday date,
    dept_id integer NOT NULL,
    major_id integer NOT NULL,
    grade character varying(10),
    mobile character varying(20),
    email character varying(100),
    user_id integer NOT NULL,
    status character(1) DEFAULT '1'::bpchar NOT NULL,
    CONSTRAINT ck_student_gender CHECK ((gender = ANY (ARRAY['M'::bpchar, 'F'::bpchar]))),
    CONSTRAINT ck_student_status CHECK ((status = ANY (ARRAY['1'::bpchar, '0'::bpchar])))
);


ALTER TABLE public.tb_student OWNER TO system;

--
-- Name: tb_student_course; Type: TABLE; Schema: public; Owner: system
--

CREATE TABLE public.tb_student_course (
    sc_id integer NOT NULL,
    stu_id integer NOT NULL,
    course_id integer NOT NULL,
    term character varying(20) NOT NULL,
    select_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    drop_time timestamp without time zone,
    status character(1) DEFAULT '1'::bpchar NOT NULL,
    grade numeric(5,2),
    CONSTRAINT ck_sc_grade CHECK (((grade IS NULL) OR ((grade >= (0)::numeric) AND (grade <= (100)::numeric)))),
    CONSTRAINT ck_sc_status CHECK ((status = ANY (ARRAY['1'::bpchar, '0'::bpchar])))
);


ALTER TABLE public.tb_student_course OWNER TO system;

--
-- Name: tb_student_course_sc_id_seq; Type: SEQUENCE; Schema: public; Owner: system
--

ALTER TABLE public.tb_student_course ALTER COLUMN sc_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tb_student_course_sc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tb_student_stu_id_seq; Type: SEQUENCE; Schema: public; Owner: system
--

ALTER TABLE public.tb_student ALTER COLUMN stu_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tb_student_stu_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tb_sys_param; Type: TABLE; Schema: public; Owner: system
--

CREATE TABLE public.tb_sys_param (
    param_key character varying(50) NOT NULL,
    param_value character varying(200),
    param_value_ts timestamp without time zone,
    remark character varying(200),
    CONSTRAINT ck_sys_param_value CHECK (((((param_key)::text = ANY ((ARRAY['SELECT_START_TIME'::character varying, 'SELECT_END_TIME'::character varying, 'DROP_END_TIME'::character varying])::text[])) AND (param_value_ts IS NOT NULL)) OR (((param_key)::text <> ALL ((ARRAY['SELECT_START_TIME'::character varying, 'SELECT_END_TIME'::character varying, 'DROP_END_TIME'::character varying])::text[])) AND (param_value IS NOT NULL))))
);


ALTER TABLE public.tb_sys_param OWNER TO system;

--
-- Name: tb_teacher; Type: TABLE; Schema: public; Owner: system
--

CREATE TABLE public.tb_teacher (
    tea_id integer NOT NULL,
    tea_no character varying(20) NOT NULL,
    tea_name character varying(50) NOT NULL,
    gender character(1),
    title character varying(50),
    dept_id integer NOT NULL,
    mobile character varying(20),
    email character varying(100),
    user_id integer NOT NULL,
    status character(1) DEFAULT '1'::bpchar NOT NULL,
    CONSTRAINT ck_teacher_gender CHECK ((gender = ANY (ARRAY['M'::bpchar, 'F'::bpchar]))),
    CONSTRAINT ck_teacher_status CHECK ((status = ANY (ARRAY['1'::bpchar, '0'::bpchar])))
);


ALTER TABLE public.tb_teacher OWNER TO system;

--
-- Name: tb_teacher_tea_id_seq; Type: SEQUENCE; Schema: public; Owner: system
--

ALTER TABLE public.tb_teacher ALTER COLUMN tea_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tb_teacher_tea_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tb_user; Type: TABLE; Schema: public; Owner: system
--

CREATE TABLE public.tb_user (
    user_id integer NOT NULL,
    username character varying(50) NOT NULL,
    password_hash text NOT NULL,
    password_updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    real_name character varying(50),
    role character varying(20) NOT NULL,
    status character(1) DEFAULT '1'::bpchar NOT NULL,
    email character varying(100),
    mobile character varying(20),
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_user_password_hash CHECK ((length(password_hash) > 0)),
    CONSTRAINT ck_user_role CHECK (((role)::text = ANY ((ARRAY['ADMIN'::character varying, 'TEACHER'::character varying, 'STUDENT'::character varying])::text[]))),
    CONSTRAINT ck_user_status CHECK ((status = ANY (ARRAY['1'::bpchar, '0'::bpchar])))
);


ALTER TABLE public.tb_user OWNER TO system;

--
-- Name: tb_user_user_id_seq; Type: SEQUENCE; Schema: public; Owner: system
--

ALTER TABLE public.tb_user ALTER COLUMN user_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tb_user_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tb_waitlist; Type: TABLE; Schema: public; Owner: system
--

CREATE TABLE public.tb_waitlist (
    wl_id integer NOT NULL,
    stu_id integer NOT NULL,
    course_id integer NOT NULL,
    term character varying(20) NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    message character varying(200),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    processed_at timestamp without time zone,
    CONSTRAINT ck_wl_status CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'CONFIRMED'::character varying, 'FAILED'::character varying, 'CANCELLED'::character varying])::text[])))
);


ALTER TABLE public.tb_waitlist OWNER TO system;

--
-- Name: tb_waitlist_wl_id_seq; Type: SEQUENCE; Schema: public; Owner: system
--

ALTER TABLE public.tb_waitlist ALTER COLUMN wl_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tb_waitlist_wl_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: sys_global_chain; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_global_chain AS
 SELECT _globalchain.blocknum,
    _globalchain.username,
    _globalchain.relid,
    _globalchain.relnsp,
    _globalchain.relname,
    _globalchain.relhash,
    _globalchain.globalhash,
    _globalchain.starttime,
    _globalchain.txcommand
   FROM _globalchain;


ALTER VIEW sys_catalog.sys_global_chain OWNER TO system;

--
-- Name: global_chain_seq; Type: SEQUENCE; Schema: sys_catalog; Owner: system
--

CREATE SEQUENCE sys_catalog.global_chain_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE sys_catalog.global_chain_seq OWNER TO system;

--
-- Name: global_chain_seq; Type: SEQUENCE OWNED BY; Schema: sys_catalog; Owner: system
--

ALTER SEQUENCE sys_catalog.global_chain_seq OWNED BY sys_catalog.sys_global_chain.blocknum;


--
-- Name: kdb_ce_col; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.kdb_ce_col AS
 SELECT _ce_col.oid,
    _ce_col.rel_id,
    _ce_col.column_name,
    _ce_col.column_key_id,
    _ce_col.encryption_type,
    _ce_col.data_type_original_oid,
    _ce_col.data_type_original_mod,
    _ce_col.create_date
   FROM _ce_col;


ALTER VIEW sys_catalog.kdb_ce_col OWNER TO system;

--
-- Name: kdb_ce_col_key; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.kdb_ce_col_key AS
 SELECT _ce_col_key.oid,
    _ce_col_key.column_key_name,
    _ce_col_key.column_key_distributed_id,
    _ce_col_key.global_key_id,
    _ce_col_key.key_namespace,
    _ce_col_key.key_owner,
    _ce_col_key.create_date,
    _ce_col_key.key_acl
   FROM _ce_col_key;


ALTER VIEW sys_catalog.kdb_ce_col_key OWNER TO system;

--
-- Name: kdb_ce_col_key_arg; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.kdb_ce_col_key_arg AS
 SELECT _ce_col_key_arg.oid,
    _ce_col_key_arg.column_key_id,
    _ce_col_key_arg.function_name,
    _ce_col_key_arg.key,
    _ce_col_key_arg.value
   FROM _ce_col_key_arg;


ALTER VIEW sys_catalog.kdb_ce_col_key_arg OWNER TO system;

--
-- Name: kdb_ce_mst_key; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.kdb_ce_mst_key AS
 SELECT _ce_mst_key.oid,
    _ce_mst_key.global_key_name,
    _ce_mst_key.key_namespace,
    _ce_mst_key.key_owner,
    _ce_mst_key.create_date,
    _ce_mst_key.key_acl
   FROM _ce_mst_key;


ALTER VIEW sys_catalog.kdb_ce_mst_key OWNER TO system;

--
-- Name: kdb_ce_mst_key_arg; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.kdb_ce_mst_key_arg AS
 SELECT _ce_mst_key_arg.oid,
    _ce_mst_key_arg.global_key_id,
    _ce_mst_key_arg.function_name,
    _ce_mst_key_arg.key,
    _ce_mst_key_arg.value
   FROM _ce_mst_key_arg;


ALTER VIEW sys_catalog.kdb_ce_mst_key_arg OWNER TO system;

--
-- Name: kdb_ce_proc; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.kdb_ce_proc AS
 SELECT _ce_proc.oid,
    _ce_proc.func_id,
    _ce_proc.prorettype_orig,
    _ce_proc.proargcachedcol,
    _ce_proc.proallargtypes_orig
   FROM _ce_proc;


ALTER VIEW sys_catalog.kdb_ce_proc OWNER TO system;

--
-- Name: sys_aggregate; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_aggregate AS
 SELECT _agg.aggfnoid,
    _agg.aggkind,
    _agg.aggnumdirectargs,
    _agg.aggtransfn,
    _agg.aggfinalfn,
    _agg.aggcombinefn,
    _agg.aggserialfn,
    _agg.aggdeserialfn,
    _agg.aggmtransfn,
    _agg.aggminvtransfn,
    _agg.aggmfinalfn,
    _agg.aggfinalextra,
    _agg.aggmfinalextra,
    _agg.aggfinalmodify,
    _agg.aggmfinalmodify,
    _agg.aggsortop,
    _agg.aggtranstype,
    _agg.aggtransspace,
    _agg.aggmtranstype,
    _agg.aggmtransspace,
    _agg.agginitval,
    _agg.aggminitval
   FROM _agg;


ALTER VIEW sys_catalog.sys_aggregate OWNER TO system;

--
-- Name: sys_am; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_am AS
 SELECT _am.oid,
    _am.amname,
    _am.amhandler,
    _am.amtype
   FROM _am;


ALTER VIEW sys_catalog.sys_am OWNER TO system;

--
-- Name: sys_amop; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_amop AS
 SELECT _amop.oid,
    _amop.amopfamily,
    _amop.amoplefttype,
    _amop.amoprighttype,
    _amop.amopstrategy,
    _amop.amoppurpose,
    _amop.amopopr,
    _amop.amopmethod,
    _amop.amopsortfamily
   FROM _amop;


ALTER VIEW sys_catalog.sys_amop OWNER TO system;

--
-- Name: sys_amproc; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_amproc AS
 SELECT _amproc.oid,
    _amproc.amprocfamily,
    _amproc.amproclefttype,
    _amproc.amprocrighttype,
    _amproc.amprocnum,
    _amproc.amproc
   FROM _amproc;


ALTER VIEW sys_catalog.sys_amproc OWNER TO system;

--
-- Name: sys_attrdef; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_attrdef AS
 SELECT _attdef.oid,
    _attdef.adrelid,
    _attdef.adnum,
    _attdef.adbin
   FROM _attdef;


ALTER VIEW sys_catalog.sys_attrdef OWNER TO system;

--
-- Name: sys_attribute; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_attribute AS
 SELECT _att.attrelid,
    _att.attname,
    _att.atttypid,
    _att.attstattarget,
    _att.attlen,
    _att.attnum,
    _att.attndims,
    _att.attcacheoff,
    _att.atttypmod,
    _att.attbyval,
    _att.attstorage,
    _att.attalign,
    _att.attnotnull,
    _att.atthasdef,
    _att.atthasmissing,
    _att.attidentity,
    _att.attgenerated,
    _att.attisdropped,
    _att.attislocal,
    _att.attinhcount,
    _att.attcollation,
    _att.attacl,
    _att.attoptions,
    _att.attfdwoptions,
    _att.attmissingval
   FROM _att;


ALTER VIEW sys_catalog.sys_attribute OWNER TO system;

--
-- Name: sys_auth_members; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_auth_members AS
 SELECT _authmem.roleid,
    _authmem.member,
    _authmem.grantor,
    _authmem.admin_option
   FROM _authmem;


ALTER VIEW sys_catalog.sys_auth_members OWNER TO system;

--
-- Name: sys_authid; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_authid AS
 SELECT _authid.oid,
    _authid.rolname,
    _authid.rolsuper,
    _authid.rolinherit,
    _authid.rolcreaterole,
    _authid.rolcreatedb,
    _authid.rolcanlogin,
    _authid.rolreplication,
    _authid.rolbypassrls,
    _authid.rolconnlimit,
    _authid.rolconntime,
    _authid.rolconninterval,
    _authid.rolpassword,
    _authid.rolvaliduntil
   FROM _authid;


ALTER VIEW sys_catalog.sys_authid OWNER TO system;

--
-- Name: sys_available_extension_versions; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_available_extension_versions AS
 SELECT pg_available_extension_versions.name,
    pg_available_extension_versions.version,
    pg_available_extension_versions.installed,
    pg_available_extension_versions.superuser,
    pg_available_extension_versions.relocatable,
    pg_available_extension_versions.schema,
    pg_available_extension_versions.requires,
    pg_available_extension_versions.comment
   FROM pg_available_extension_versions;


ALTER VIEW sys_catalog.sys_available_extension_versions OWNER TO system;

--
-- Name: sys_available_extensions; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_available_extensions AS
 SELECT pg_available_extensions.name,
    pg_available_extensions.default_version,
    pg_available_extensions.installed_version,
    pg_available_extensions.comment
   FROM pg_available_extensions;


ALTER VIEW sys_catalog.sys_available_extensions OWNER TO system;

--
-- Name: sys_cast; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_cast AS
 SELECT _cast.oid,
    _cast.castsource,
    _cast.casttarget,
    _cast.castfunc,
    _cast.castcontext,
    _cast.castmethod,
    _cast.castflags
   FROM _cast;


ALTER VIEW sys_catalog.sys_cast OWNER TO system;

--
-- Name: sys_class; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_class AS
 SELECT _rel.oid,
    _rel.relname,
    _rel.relnamespace,
    _rel.reltype,
    _rel.reloftype,
    _rel.relowner,
    _rel.relam,
    _rel.relfilenode,
    _rel.reltablespace,
    _rel.relpages,
    _rel.reltuples,
    _rel.relallvisible,
    _rel.reltoastrelid,
    _rel.relhasindex,
    _rel.relisshared,
    _rel.relpersistence,
    _rel.relkind,
    _rel.relnatts,
    _rel.relchecks,
    _rel.relhasrules,
    _rel.relhastriggers,
    _rel.relhassubclass,
    _rel.relrowsecurity,
    _rel.relforcerowsecurity,
    _rel.relispopulated,
    _rel.relreplident,
    _rel.relispartition,
    _rel.relrewrite,
    _rel.relfrozenxid,
    _rel.relminmxid,
    _rel.relacl,
    _rel.reloptions,
    _rel.relpartbound
   FROM _rel;


ALTER VIEW sys_catalog.sys_class OWNER TO system;

--
-- Name: sys_collation; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_collation AS
 SELECT _coll.oid,
    _coll.collname,
    _coll.collnamespace,
    _coll.collowner,
    _coll.collprovider,
    _coll.collisdeterministic,
    _coll.collencoding,
    _coll.collcollate,
    _coll.collctype,
    _coll.colliculocale,
    _coll.collversion
   FROM _coll;


ALTER VIEW sys_catalog.sys_collation OWNER TO system;

--
-- Name: sys_config; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_config AS
 SELECT pg_config.name,
    pg_config.setting
   FROM pg_config;


ALTER VIEW sys_catalog.sys_config OWNER TO system;

--
-- Name: sys_constraint; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_constraint AS
 SELECT c.oid,
    c.conname,
    c.connamespace,
    c.contype,
    c.condeferrable,
    c.condeferred,
    c.convalidated,
    c.conrelid,
    c.contypid,
    c.conindid,
    c.conparentid,
    c.confrelid,
    c.confupdtype,
    c.confdeltype,
    c.confmatchtype,
    c.conislocal,
    c.coninhcount,
    c.conflags,
    c.connoinherit,
    c.constatus,
    c.conrefconoid,
    c.conkey,
    c.confkey,
    c.conpfeqop,
    c.conppeqop,
    c.conffeqop,
    c.conexclop,
    c.conbin
   FROM _con c;


ALTER VIEW sys_catalog.sys_constraint OWNER TO system;

--
-- Name: sys_context; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_context AS
 SELECT _ctx.oid,
    _ctx.conname,
    _ctx.connamespace,
    _ctx.conower,
    _ctx.pkgname,
    _ctx.pkgnamespace,
    _ctx.conacl
   FROM _ctx;


ALTER VIEW sys_catalog.sys_context OWNER TO system;

--
-- Name: sys_conversion; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_conversion AS
 SELECT _conv.oid,
    _conv.conname,
    _conv.connamespace,
    _conv.conowner,
    _conv.conforencoding,
    _conv.contoencoding,
    _conv.conproc,
    _conv.condefault
   FROM _conv;


ALTER VIEW sys_catalog.sys_conversion OWNER TO system;

--
-- Name: sys_cursors; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_cursors AS
 SELECT pg_cursors.name,
    pg_cursors.statement,
    pg_cursors.is_holdable,
    pg_cursors.is_binary,
    pg_cursors.is_scrollable,
    pg_cursors.creation_time
   FROM pg_cursors;


ALTER VIEW sys_catalog.sys_cursors OWNER TO system;

--
-- Name: sys_database; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_database AS
 SELECT _db.oid,
    _db.datname,
    _db.datdba,
    _db.encoding,
    _db.datcollate,
    _db.datctype,
    _db.datistemplate,
    _db.datallowconn,
    _db.datconnlimit,
    _db.datlastsysoid,
    _db.datfrozenxid,
    _db.datminmxid,
    _db.dattablespace,
    _db.datinitlsn,
    _db.datcreatedts,
    _db.datlocprovider,
    _db.daticulocale,
    _db.datcollversion,
    _db.datacl,
    _db.datflashbacklogs
   FROM _db;


ALTER VIEW sys_catalog.sys_database OWNER TO system;

--
-- Name: sys_db_role_setting; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_db_role_setting AS
 SELECT _dbroleset.setdatabase,
    _dbroleset.setrole,
    _dbroleset.setconfig
   FROM _dbroleset;


ALTER VIEW sys_catalog.sys_db_role_setting OWNER TO system;

--
-- Name: sys_default_acl; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_default_acl AS
 SELECT _defacl.oid,
    _defacl.defaclrole,
    _defacl.defaclnamespace,
    _defacl.defaclobjtype,
    _defacl.defaclacl
   FROM _defacl;


ALTER VIEW sys_catalog.sys_default_acl OWNER TO system;

--
-- Name: sys_depend; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_depend AS
 SELECT _dep.classid,
    _dep.objid,
    _dep.objsubid,
    _dep.refclassid,
    _dep.refobjid,
    _dep.refobjsubid,
    _dep.deptype
   FROM _dep;


ALTER VIEW sys_catalog.sys_depend OWNER TO system;

--
-- Name: sys_description; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_description AS
 SELECT _desc.objoid,
    _desc.classoid,
    _desc.objsubid,
    _desc.name,
    _desc.description
   FROM _desc;


ALTER VIEW sys_catalog.sys_description OWNER TO system;

--
-- Name: sys_enum; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_enum AS
 SELECT _enum.oid,
    _enum.enumtypid,
    _enum.enumsortorder,
    _enum.enumlabel
   FROM _enum;


ALTER VIEW sys_catalog.sys_enum OWNER TO system;

--
-- Name: sys_event_trigger; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_event_trigger AS
 SELECT _event_trigger.oid,
    _event_trigger.evtname,
    _event_trigger.evtevent,
    _event_trigger.evtowner,
    _event_trigger.evtfoid,
    _event_trigger.evtenabled,
    _event_trigger.evttags
   FROM _event_trigger;


ALTER VIEW sys_catalog.sys_event_trigger OWNER TO system;

--
-- Name: sys_extension; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_extension AS
 SELECT _ext.oid,
    _ext.extname,
    _ext.extowner,
    _ext.extnamespace,
    _ext.extrelocatable,
    _ext.extversion,
    _ext.extconfig,
    _ext.extcondition
   FROM _ext;


ALTER VIEW sys_catalog.sys_extension OWNER TO system;

--
-- Name: sys_file_settings; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_file_settings AS
 SELECT pg_file_settings.sourcefile,
    pg_file_settings.sourceline,
    pg_file_settings.seqno,
    pg_file_settings.name,
    pg_file_settings.setting,
    pg_file_settings.applied,
    pg_file_settings.error
   FROM pg_file_settings;


ALTER VIEW sys_catalog.sys_file_settings OWNER TO system;

--
-- Name: sys_foreign_data_wrapper; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_foreign_data_wrapper AS
 SELECT _fdw.oid,
    _fdw.fdwname,
    _fdw.fdwowner,
    _fdw.fdwhandler,
    _fdw.fdwvalidator,
    _fdw.fdwacl,
    _fdw.fdwoptions
   FROM _fdw;


ALTER VIEW sys_catalog.sys_foreign_data_wrapper OWNER TO system;

--
-- Name: sys_foreign_server; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_foreign_server AS
 SELECT _fserver.oid,
    _fserver.srvname,
    _fserver.srvowner,
    _fserver.srvfdw,
    _fserver.srvtype,
    _fserver.srvversion,
    _fserver.srvacl,
    _fserver.srvoptions
   FROM _fserver;


ALTER VIEW sys_catalog.sys_foreign_server OWNER TO system;

--
-- Name: sys_foreign_table; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_foreign_table AS
 SELECT _ftab.ftrelid,
    _ftab.ftserver,
    _ftab.ftoptions
   FROM _ftab;


ALTER VIEW sys_catalog.sys_foreign_table OWNER TO system;

--
-- Name: sys_group; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_group AS
 SELECT pg_group.groname,
    pg_group.grosysid,
    pg_group.grolist
   FROM pg_group;


ALTER VIEW sys_catalog.sys_group OWNER TO system;

--
-- Name: sys_hba_file_rules; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_hba_file_rules AS
 SELECT pg_hba_file_rules.line_number,
    pg_hba_file_rules.type,
    pg_hba_file_rules.database,
    pg_hba_file_rules.user_name,
    pg_hba_file_rules.address,
    pg_hba_file_rules.netmask,
    pg_hba_file_rules.auth_method,
    pg_hba_file_rules.options,
    pg_hba_file_rules.error
   FROM pg_hba_file_rules;


ALTER VIEW sys_catalog.sys_hba_file_rules OWNER TO system;

--
-- Name: sys_index; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_index AS
 SELECT _ind.indexrelid,
    _ind.indrelid,
    _ind.indnatts,
    _ind.indnkeyatts,
    _ind.indisunique,
    _ind.indisprimary,
    _ind.indisexclusion,
    _ind.indimmediate,
    _ind.indisclustered,
    _ind.indisvalid,
    _ind.indcheckxmin,
    _ind.indisready,
    _ind.indislive,
    _ind.indisreplident,
    _ind.indflags,
    _ind.indkey,
    _ind.indcollation,
    _ind.indclass,
    _ind.indoption,
    _ind.indexprs,
    _ind.indpred
   FROM _ind;


ALTER VIEW sys_catalog.sys_index OWNER TO system;

--
-- Name: sys_indexes; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_indexes AS
 SELECT pg_indexes.schemaname,
    pg_indexes.tablename,
    pg_indexes.indexname,
    pg_indexes.tablespace,
    pg_indexes.indexdef
   FROM pg_indexes;


ALTER VIEW sys_catalog.sys_indexes OWNER TO system;

--
-- Name: sys_inherits; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_inherits AS
 SELECT _inh.inhrelid,
    _inh.inhparent,
    _inh.inhseqno,
    _inh.inhinterval,
    _inh.inhsubname
   FROM _inh;


ALTER VIEW sys_catalog.sys_inherits OWNER TO system;

--
-- Name: sys_init_privs; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_init_privs AS
 SELECT _initprivs.objoid,
    _initprivs.classoid,
    _initprivs.objsubid,
    _initprivs.privtype,
    _initprivs.initprivs
   FROM _initprivs;


ALTER VIEW sys_catalog.sys_init_privs OWNER TO system;

--
-- Name: sys_language; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_language AS
 SELECT _lang.oid,
    _lang.lanname,
    _lang.lanowner,
    _lang.lanispl,
    _lang.lanpltrusted,
    _lang.lanplcallfoid,
    _lang.laninline,
    _lang.lanvalidator,
    _lang.lanacl
   FROM _lang;


ALTER VIEW sys_catalog.sys_language OWNER TO system;

--
-- Name: sys_largeobject; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_largeobject AS
 SELECT _lob.loid,
    _lob.pageno,
    _lob.data
   FROM _lob;


ALTER VIEW sys_catalog.sys_largeobject OWNER TO system;

--
-- Name: sys_largeobject_metadata; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_largeobject_metadata AS
 SELECT _lob_meta.oid,
    _lob_meta.lomowner,
    _lob_meta.lomacl
   FROM _lob_meta;


ALTER VIEW sys_catalog.sys_largeobject_metadata OWNER TO system;

--
-- Name: sys_locks; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_locks AS
 SELECT pg_locks.locktype,
    pg_locks.database,
    pg_locks.relation,
    pg_locks.page,
    pg_locks.tuple,
    pg_locks.virtualxid,
    pg_locks.transactionid,
    pg_locks.classid,
    pg_locks.objid,
    pg_locks.objsubid,
    pg_locks.virtualtransaction,
    pg_locks.pid,
    pg_locks.mode,
    pg_locks.granted,
    pg_locks.fastpath
   FROM pg_locks;


ALTER VIEW sys_catalog.sys_locks OWNER TO system;

--
-- Name: sys_matviews; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_matviews AS
 SELECT pg_matviews.schemaname,
    pg_matviews.matviewname,
    pg_matviews.matviewowner,
    pg_matviews.tablespace,
    pg_matviews.hasindexes,
    pg_matviews.ispopulated,
    pg_matviews.definition
   FROM pg_matviews;


ALTER VIEW sys_catalog.sys_matviews OWNER TO system;

--
-- Name: sys_namespace; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_namespace AS
 SELECT _nsp.oid,
    _nsp.nspname,
    _nsp.nspowner,
    _nsp.nspflags,
    _nsp.nspacl
   FROM _nsp
  WHERE ((_nsp.nspname !~~ 'pg_toast%'::text) AND (_nsp.nspname !~~ 'pg_temp%'::text));


ALTER VIEW sys_catalog.sys_namespace OWNER TO system;

--
-- Name: sys_object_status; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_object_status AS
 SELECT _obj_status.classid,
    _obj_status.objid,
    _obj_status.objsubid,
    _obj_status.status
   FROM _obj_status;


ALTER VIEW sys_catalog.sys_object_status OWNER TO system;

--
-- Name: sys_objects; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_objects AS
 SELECT _objschemats.objectoid,
    _objschemats.objectkind,
    _objschemats.creator,
    _objschemats.createdxid,
    _objschemats.changedxid,
    _objschemats.createdts,
    _objschemats.changedts,
    _objschemats.createdcsn,
    _objschemats.changedcsn,
    _objschemats.fbqlimited,
    _objschemats.minfbqxid,
    _objschemats.minfbqts,
    _objschemats.minfbqcsn
   FROM _objschemats;


ALTER VIEW sys_catalog.sys_objects OWNER TO system;

--
-- Name: sys_opclass; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_opclass AS
 SELECT _opclass.oid,
    _opclass.opcmethod,
    _opclass.opcname,
    _opclass.opcnamespace,
    _opclass.opcowner,
    _opclass.opcfamily,
    _opclass.opcintype,
    _opclass.opcdefault,
    _opclass.opckeytype
   FROM _opclass;


ALTER VIEW sys_catalog.sys_opclass OWNER TO system;

--
-- Name: sys_operator; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_operator AS
 SELECT _op.oid,
    _op.oprname,
    _op.oprnamespace,
    _op.oprowner,
    _op.oprkind,
    _op.oprcanmerge,
    _op.oprcanhash,
    _op.oprleft,
    _op.oprright,
    _op.oprresult,
    _op.oprcom,
    _op.oprnegate,
    _op.oprflags,
    _op.oprcode,
    _op.oprrest,
    _op.oprjoin
   FROM _op;


ALTER VIEW sys_catalog.sys_operator OWNER TO system;

--
-- Name: sys_opfamily; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_opfamily AS
 SELECT _opfamily.oid,
    _opfamily.opfmethod,
    _opfamily.opfname,
    _opfamily.opfnamespace,
    _opfamily.opfowner
   FROM _opfamily;


ALTER VIEW sys_catalog.sys_opfamily OWNER TO system;

--
-- Name: sys_partitioned_table; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_partitioned_table AS
 SELECT _defpart.partrelid,
    _defpart.partstrat,
    _defpart.partnatts,
    _defpart.partdefid,
    _defpart.partdiffnum,
    _defpart.partattrs,
    _defpart.partclass,
    _defpart.partcollation,
    _defpart.partexprs,
    _defpart.parttablespace,
    _defpart.intervalexpr
   FROM _defpart;


ALTER VIEW sys_catalog.sys_partitioned_table OWNER TO system;

--
-- Name: sys_pltemplate; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_pltemplate AS
 SELECT _pltmpl.tmplname,
    _pltmpl.tmpltrusted,
    _pltmpl.tmpldbacreate,
    _pltmpl.tmplhandler,
    _pltmpl.tmplinline,
    _pltmpl.tmplvalidator,
    _pltmpl.tmpllibrary,
    _pltmpl.tmplacl
   FROM _pltmpl;


ALTER VIEW sys_catalog.sys_pltemplate OWNER TO system;

--
-- Name: sys_policies; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_policies AS
 SELECT pg_policies.schemaname,
    pg_policies.tablename,
    pg_policies.policyname,
    pg_policies.permissive,
    pg_policies.roles,
    pg_policies.cmd,
    pg_policies.qual,
    pg_policies.with_check
   FROM pg_policies;


ALTER VIEW sys_catalog.sys_policies OWNER TO system;

--
-- Name: sys_policy; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_policy AS
 SELECT _policy.oid,
    _policy.polname,
    _policy.polrelid,
    _policy.polcmd,
    _policy.polpermissive,
    _policy.polroles,
    _policy.polqual,
    _policy.polwithcheck
   FROM _policy;


ALTER VIEW sys_catalog.sys_policy OWNER TO system;

--
-- Name: sys_prepared_statements; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_prepared_statements AS
 SELECT pg_prepared_statements.name,
    pg_prepared_statements.statement,
    pg_prepared_statements.prepare_time,
    pg_prepared_statements.parameter_types,
    pg_prepared_statements.from_sql
   FROM pg_prepared_statements;


ALTER VIEW sys_catalog.sys_prepared_statements OWNER TO system;

--
-- Name: sys_prepared_xacts; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_prepared_xacts AS
 SELECT pg_prepared_xacts.transaction,
    pg_prepared_xacts.gid,
    pg_prepared_xacts.prepared,
    pg_prepared_xacts.owner,
    pg_prepared_xacts.database
   FROM pg_prepared_xacts;


ALTER VIEW sys_catalog.sys_prepared_xacts OWNER TO system;

--
-- Name: sys_proc; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_proc AS
 SELECT _proc.oid,
    _proc.proname,
    _proc.pronamespace,
    _proc.proowner,
    _proc.proinvokerid AS proexecuteasprincipalid,
    _proc.prolang,
    _proc.procost,
    _proc.prorows,
    _proc.provariadic,
    _proc.prosupport,
    _proc.prokind,
    _proc.prosecdef,
    _proc.proleakproof,
    _proc.proisstrict,
    _proc.proretset,
    _proc.provolatile,
    _proc.proparallel,
    _proc.pronargs,
    _proc.pronargdefaults,
    _proc.prorettype,
    _proc.proflags,
    _proc.proretname,
    _proc.proargtypes,
    _proc.proallargtypes,
    _proc.proargmodes,
    _proc.proargnames,
    _proc.proargdefaults,
    _proc.protrftypes,
    _proc.prosrc,
    _proc.probin,
    _proc.proconfig,
    _proc.proacl
   FROM _proc;


ALTER VIEW sys_catalog.sys_proc OWNER TO system;

--
-- Name: sys_protect; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_protect AS
 SELECT _protect.objid,
    _protect.nspid,
    _protect.dbid,
    _protect.objkind
   FROM _protect;


ALTER VIEW sys_catalog.sys_protect OWNER TO system;

--
-- Name: sys_publication; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_publication AS
 SELECT _pub.oid,
    _pub.pubname,
    _pub.pubowner,
    _pub.puballtables,
    _pub.pubinsert,
    _pub.pubupdate,
    _pub.pubdelete,
    _pub.pubtruncate
   FROM _pub;


ALTER VIEW sys_catalog.sys_publication OWNER TO system;

--
-- Name: sys_publication_rel; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_publication_rel AS
 SELECT _pubrel.oid,
    _pubrel.prpubid,
    _pubrel.prrelid
   FROM _pubrel;


ALTER VIEW sys_catalog.sys_publication_rel OWNER TO system;

--
-- Name: sys_publication_tables; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_publication_tables AS
 SELECT pg_publication_tables.pubname,
    pg_publication_tables.schemaname,
    pg_publication_tables.tablename
   FROM pg_publication_tables;


ALTER VIEW sys_catalog.sys_publication_tables OWNER TO system;

--
-- Name: sys_range; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_range AS
 SELECT _range.rngtypid,
    _range.rngsubtype,
    _range.rngcollation,
    _range.rngsubopc,
    _range.rngcanonical,
    _range.rngsubdiff
   FROM _range;


ALTER VIEW sys_catalog.sys_range OWNER TO system;

--
-- Name: sys_replication_origin; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_replication_origin AS
 SELECT _reporigin.roident,
    _reporigin.roname
   FROM _reporigin;


ALTER VIEW sys_catalog.sys_replication_origin OWNER TO system;

--
-- Name: sys_replication_origin_status; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_replication_origin_status AS
 SELECT pg_replication_origin_status.local_id,
    pg_replication_origin_status.external_id,
    pg_replication_origin_status.remote_lsn,
    pg_replication_origin_status.local_lsn
   FROM pg_replication_origin_status;


ALTER VIEW sys_catalog.sys_replication_origin_status OWNER TO system;

--
-- Name: sys_replication_slots; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_replication_slots AS
 SELECT pg_replication_slots.slot_name,
    pg_replication_slots.plugin,
    pg_replication_slots.slot_type,
    pg_replication_slots.datoid,
    pg_replication_slots.database,
    pg_replication_slots.temporary,
    pg_replication_slots.active,
    pg_replication_slots.active_pid,
    pg_replication_slots.xmin,
    pg_replication_slots.catalog_xmin,
    pg_replication_slots.restart_lsn,
    pg_replication_slots.confirmed_flush_lsn
   FROM pg_replication_slots;


ALTER VIEW sys_catalog.sys_replication_slots OWNER TO system;

--
-- Name: sys_rewrite; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_rewrite AS
 SELECT _rewrite.oid,
    _rewrite.rulename,
    _rewrite.ev_class,
    _rewrite.ev_type,
    _rewrite.ev_enabled,
    _rewrite.is_instead,
    _rewrite.ev_qual,
    _rewrite.ev_action
   FROM _rewrite;


ALTER VIEW sys_catalog.sys_rewrite OWNER TO system;

--
-- Name: sys_role; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_role AS
 SELECT a.groname AS role_name,
    a.grosysid AS role_oid,
    a.grolist AS role_list
   FROM sys_catalog.sys_group a
  WHERE (NOT (a.grosysid IN ( SELECT sys_privilege.userid
           FROM sys_privilege
          WHERE (sys_privilege.objtype = 'g'::"char"))));


ALTER VIEW sys_catalog.sys_role OWNER TO system;

--
-- Name: sys_roles; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_roles AS
 SELECT pg_roles.rolname,
    pg_roles.rolsuper,
    pg_roles.rolinherit,
    pg_roles.rolcreaterole,
    pg_roles.rolcreatedb,
    pg_roles.rolcanlogin,
    pg_roles.rolreplication,
    pg_roles.rolconnlimit,
    pg_roles.rolpassword,
    pg_roles.rolvaliduntil,
    pg_roles.rolbypassrls,
    pg_roles.rolconfig,
    pg_roles.oid
   FROM pg_roles;


ALTER VIEW sys_catalog.sys_roles OWNER TO system;

--
-- Name: sys_rules; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_rules AS
 SELECT pg_rules.schemaname,
    pg_rules.tablename,
    pg_rules.rulename,
    pg_rules.definition
   FROM pg_rules;


ALTER VIEW sys_catalog.sys_rules OWNER TO system;

--
-- Name: sys_saouser; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_saouser AS
 SELECT show_saosso_user.username,
    show_saosso_user.userid
   FROM show_saosso_user((9)::oid) show_saosso_user(username, userid);


ALTER VIEW sys_catalog.sys_saouser OWNER TO system;

--
-- Name: sys_seclabel; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_seclabel AS
 SELECT _seclabel.objoid,
    _seclabel.classoid,
    _seclabel.objsubid,
    _seclabel.provider,
    _seclabel.label
   FROM _seclabel;


ALTER VIEW sys_catalog.sys_seclabel OWNER TO system;

--
-- Name: sys_seclabels; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_seclabels AS
 SELECT pg_seclabels.objoid,
    pg_seclabels.classoid,
    pg_seclabels.objsubid,
    pg_seclabels.objtype,
    pg_seclabels.objnamespace,
    pg_seclabels.objname,
    pg_seclabels.provider,
    pg_seclabels.label
   FROM pg_seclabels;


ALTER VIEW sys_catalog.sys_seclabels OWNER TO system;

--
-- Name: sys_sequence; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_sequence AS
 SELECT _seq.seqrelid,
    _seq.seqtypid,
    _seq.seqstart,
    _seq.seqincrement,
    _seq.seqmax,
    _seq.seqmin,
    _seq.seqcache,
    _seq.seqcycle
   FROM _seq;


ALTER VIEW sys_catalog.sys_sequence OWNER TO system;

--
-- Name: sys_sequences; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_sequences AS
 SELECT n.nspname AS schemaname,
    c.relname AS sequencename,
    pg_get_userbyid(c.relowner) AS sequenceowner,
    (s.seqtypid)::regtype AS data_type,
    s.seqstart AS start_value,
    s.seqmin AS min_value,
    s.seqmax AS max_value,
    s.seqincrement AS increment_by,
    s.seqcycle AS cycle,
    s.seqcache AS cache_size,
        CASE
            WHEN has_sequence_privilege(c.oid, 'SELECT,USAGE'::text) THEN pg_sequence_last_value((c.oid)::regclass)
            ELSE NULL::numeric
        END AS last_value
   FROM ((_seq s
     JOIN _rel c ON ((c.oid = s.seqrelid)))
     LEFT JOIN _nsp n ON ((n.oid = c.relnamespace)))
  WHERE ((NOT pg_is_other_temp_schema(n.oid)) AND (c.relkind = 'S'::"char") AND (NOT (c.oid IN ( SELECT _recyclebin.reloid
           FROM _recyclebin))));


ALTER VIEW sys_catalog.sys_sequences OWNER TO system;

--
-- Name: sys_settings; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_settings AS
 SELECT pg_settings.name,
    pg_settings.setting,
    pg_settings.unit,
    pg_settings.category,
    pg_settings.short_desc,
    pg_settings.extra_desc,
    pg_settings.context,
    pg_settings.vartype,
    pg_settings.source,
    pg_settings.min_val,
    pg_settings.max_val,
    pg_settings.enumvals,
    pg_settings.boot_val,
    pg_settings.reset_val,
    pg_settings.sourcefile,
    pg_settings.sourceline,
    pg_settings.pending_restart
   FROM pg_settings;


ALTER VIEW sys_catalog.sys_settings OWNER TO system;

--
-- Name: sys_shadow; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_shadow AS
 SELECT pg_shadow.usename,
    pg_shadow.usesysid,
    pg_shadow.usecreatedb,
    pg_shadow.usesuper,
    pg_shadow.userepl,
    pg_shadow.usebypassrls,
    pg_shadow.passwd,
    pg_shadow.valuntil,
    pg_shadow.useconfig
   FROM pg_shadow;


ALTER VIEW sys_catalog.sys_shadow OWNER TO system;

--
-- Name: sys_shdepend; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_shdepend AS
 SELECT _shdep.dbid,
    _shdep.classid,
    _shdep.objid,
    _shdep.objsubid,
    _shdep.refclassid,
    _shdep.refobjid,
    _shdep.deptype
   FROM _shdep;


ALTER VIEW sys_catalog.sys_shdepend OWNER TO system;

--
-- Name: sys_shdescription; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_shdescription AS
 SELECT _shdesc.objoid,
    _shdesc.classoid,
    _shdesc.name,
    _shdesc.description
   FROM _shdesc;


ALTER VIEW sys_catalog.sys_shdescription OWNER TO system;

--
-- Name: sys_shmem_allocation; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_shmem_allocation AS
 SELECT s.name,
    s.off,
    s.size,
    s.allocated_size
   FROM pg_get_shmem_allocations() s(name, off, size, allocated_size);


ALTER VIEW sys_catalog.sys_shmem_allocation OWNER TO system;

--
-- Name: sys_shseclabel; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_shseclabel AS
 SELECT _shseclabel.objoid,
    _shseclabel.classoid,
    _shseclabel.provider,
    _shseclabel.label
   FROM _shseclabel;


ALTER VIEW sys_catalog.sys_shseclabel OWNER TO system;

--
-- Name: sys_ssouser; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_ssouser AS
 SELECT show_saosso_user.username,
    show_saosso_user.userid
   FROM show_saosso_user((8)::oid) show_saosso_user(username, userid);


ALTER VIEW sys_catalog.sys_ssouser OWNER TO system;

--
-- Name: sys_stat_activity; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_activity AS
 SELECT s.datid,
    s.datname,
    s.pid,
    s.usesysid,
    s.usename,
    s.application_name,
    s.client_addr,
    s.client_hostname,
    s.client_port,
    s.backend_start,
    s.xact_start,
    s.query_start,
    s.state_change,
    s.wait_event_type,
    s.wait_event,
    s.state,
    s.backend_xid,
    s.backend_xmin,
    s.query,
    s.backend_type
   FROM pg_stat_activity s;


ALTER VIEW sys_catalog.sys_stat_activity OWNER TO system;

--
-- Name: sys_stat_all_indexes; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_all_indexes AS
 SELECT pg_stat_all_indexes.relid,
    pg_stat_all_indexes.indexrelid,
    pg_stat_all_indexes.schemaname,
    pg_stat_all_indexes.relname,
    pg_stat_all_indexes.indexrelname,
    pg_stat_all_indexes.idx_scan,
    pg_stat_all_indexes.idx_tup_read,
    pg_stat_all_indexes.idx_tup_fetch
   FROM pg_stat_all_indexes;


ALTER VIEW sys_catalog.sys_stat_all_indexes OWNER TO system;

--
-- Name: sys_stat_all_tables; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_all_tables AS
 SELECT pg_stat_all_tables.relid,
    pg_stat_all_tables.schemaname,
    pg_stat_all_tables.relname,
    pg_stat_all_tables.seq_scan,
    pg_stat_all_tables.seq_tup_read,
    pg_stat_all_tables.idx_scan,
    pg_stat_all_tables.idx_tup_fetch,
    pg_stat_all_tables.n_tup_ins,
    pg_stat_all_tables.n_tup_upd,
    pg_stat_all_tables.n_tup_del,
    pg_stat_all_tables.n_tup_hot_upd,
    pg_stat_all_tables.n_live_tup,
    pg_stat_all_tables.n_dead_tup,
    pg_stat_all_tables.n_mod_since_analyze,
    pg_stat_all_tables.last_vacuum,
    pg_stat_all_tables.last_autovacuum,
    pg_stat_all_tables.last_analyze,
    pg_stat_all_tables.last_autoanalyze,
    pg_stat_all_tables.vacuum_count,
    pg_stat_all_tables.autovacuum_count,
    pg_stat_all_tables.analyze_count,
    pg_stat_all_tables.autoanalyze_count
   FROM pg_stat_all_tables;


ALTER VIEW sys_catalog.sys_stat_all_tables OWNER TO system;

--
-- Name: sys_stat_archiver; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_archiver AS
 SELECT pg_stat_archiver.archived_count,
    pg_stat_archiver.last_archived_wal,
    pg_stat_archiver.last_archived_time,
    pg_stat_archiver.failed_count,
    pg_stat_archiver.last_failed_wal,
    pg_stat_archiver.last_failed_time,
    pg_stat_archiver.stats_reset
   FROM pg_stat_archiver;


ALTER VIEW sys_catalog.sys_stat_archiver OWNER TO system;

--
-- Name: sys_stat_bgwriter; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_bgwriter AS
 SELECT pg_stat_bgwriter.checkpoints_timed,
    pg_stat_bgwriter.checkpoints_req,
    pg_stat_bgwriter.checkpoint_write_time,
    pg_stat_bgwriter.checkpoint_sync_time,
    pg_stat_bgwriter.buffers_checkpoint,
    pg_stat_bgwriter.buffers_clean,
    pg_stat_bgwriter.maxwritten_clean,
    pg_stat_bgwriter.buffers_backend,
    pg_stat_bgwriter.buffers_backend_fsync,
    pg_stat_bgwriter.buffers_alloc,
    pg_stat_bgwriter.stats_reset
   FROM pg_stat_bgwriter;


ALTER VIEW sys_catalog.sys_stat_bgwriter OWNER TO system;

--
-- Name: sys_stat_cached_plans; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_cached_plans AS
 SELECT s.query,
    s.command,
    s.num_params,
    s.cursor_options,
    s.soft_parse,
    s.hard_parse,
    s.ref_count,
    s.is_oneshot,
    s.is_saved,
    s.is_valid,
    s.generic_cost,
    s.total_custom_cost,
    s.num_custom_plans
   FROM pg_stat_get_cached_plans() s(query, command, num_params, cursor_options, soft_parse, hard_parse, ref_count, is_oneshot, is_saved, is_valid, generic_cost, total_custom_cost, num_custom_plans);


ALTER VIEW sys_catalog.sys_stat_cached_plans OWNER TO system;

--
-- Name: sys_stat_database; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_database AS
 SELECT pg_stat_database.datid,
    pg_stat_database.datname,
    pg_stat_database.numbackends,
    pg_stat_database.xact_commit,
    pg_stat_database.xact_rollback,
    pg_stat_database.blks_read,
    pg_stat_database.blks_hit,
    pg_stat_database.tup_returned,
    pg_stat_database.tup_fetched,
    pg_stat_database.tup_inserted,
    pg_stat_database.tup_updated,
    pg_stat_database.tup_deleted,
    pg_stat_database.conflicts,
    pg_stat_database.temp_files,
    pg_stat_database.temp_bytes,
    pg_stat_database.deadlocks,
    pg_stat_database.checksum_failures,
    pg_stat_database.checksum_last_failure,
    pg_stat_database.blk_read_time,
    pg_stat_database.blk_write_time,
    pg_stat_database.stats_reset
   FROM pg_stat_database;


ALTER VIEW sys_catalog.sys_stat_database OWNER TO system;

--
-- Name: sys_stat_database_conflicts; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_database_conflicts AS
 SELECT pg_stat_database_conflicts.datid,
    pg_stat_database_conflicts.datname,
    pg_stat_database_conflicts.confl_tablespace,
    pg_stat_database_conflicts.confl_lock,
    pg_stat_database_conflicts.confl_snapshot,
    pg_stat_database_conflicts.confl_bufferpin,
    pg_stat_database_conflicts.confl_deadlock
   FROM pg_stat_database_conflicts;


ALTER VIEW sys_catalog.sys_stat_database_conflicts OWNER TO system;

--
-- Name: sys_stat_dbtime; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_dbtime AS
 SELECT perf_get_dbtime_stats.metric,
    perf_get_dbtime_stats.calls,
    perf_get_dbtime_stats.total_time,
    perf_get_dbtime_stats.avg_time,
    perf_get_dbtime_stats.dbtime_pct
   FROM perf_get_dbtime_stats() perf_get_dbtime_stats(metric, calls, total_time, avg_time, dbtime_pct);


ALTER VIEW sys_catalog.sys_stat_dbtime OWNER TO system;

--
-- Name: sys_stat_instevent; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_instevent AS
 SELECT s.datid,
    s.event_type,
    s.event_name,
    s.background,
    s.calls,
    s.times
   FROM pg_stat_get_instevent() s(datid, event_type, event_name, background, calls, times);


ALTER VIEW sys_catalog.sys_stat_instevent OWNER TO system;

--
-- Name: sys_stat_dmlcount; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_dmlcount AS
 SELECT sys_stat_instevent.datid,
    sys_stat_instevent.event_name AS sql_type,
    sys_stat_instevent.background,
    sys_stat_instevent.calls,
    sys_stat_instevent.times
   FROM sys_catalog.sys_stat_instevent
  WHERE ((sys_stat_instevent.event_type = 'Sql Count'::text) AND (sys_stat_instevent.event_name = ANY (ARRAY['Insert'::text, 'Delete'::text, 'Update'::text, 'Select'::text, 'Merge'::text])));


ALTER VIEW sys_catalog.sys_stat_dmlcount OWNER TO system;

--
-- Name: sys_stat_gssapi; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_gssapi AS
 SELECT pg_stat_gssapi.pid,
    pg_stat_gssapi.gss_authenticated,
    pg_stat_gssapi.principal,
    pg_stat_gssapi.encrypted
   FROM pg_stat_gssapi;


ALTER VIEW sys_catalog.sys_stat_gssapi OWNER TO system;

--
-- Name: sys_stat_instio; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_instio AS
 SELECT s.backend_type,
    s.datid,
    s.reltablespace,
    s.relid,
    s.io_type,
    s.file_type,
    s.wait_event,
    s.background,
    s.calls,
    s.times,
    s.bytes
   FROM pg_stat_get_instio() s(backend_type, datid, reltablespace, relid, io_type, file_type, wait_event, background, calls, times, bytes);


ALTER VIEW sys_catalog.sys_stat_instio OWNER TO system;

--
-- Name: sys_stat_instlock; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_instlock AS
 SELECT s.datid,
    s.lock_name,
    s.lock_mode,
    s.acquire_type,
    s.background,
    s.calls,
    s.nowait_gets,
    s.nowait_miss,
    s.wait_gets,
    s.wait_miss,
    s.wait_times
   FROM pg_stat_get_instlock() s(datid, lock_name, lock_mode, acquire_type, background, calls, nowait_gets, nowait_miss, wait_gets, wait_miss, wait_times);


ALTER VIEW sys_catalog.sys_stat_instlock OWNER TO system;

--
-- Name: sys_stat_metric_name; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_metric_name AS
 SELECT 2 AS group_id,
    'System Metrics Long Duration'::text AS group_name,
    1 AS metric_id,
    'Queries Per Sec'::text AS metric_name,
    'Queries Per Sec'::text AS metric_unit
UNION ALL
 SELECT 3 AS group_id,
    'System Metrics Short Duration'::text AS group_name,
    2 AS metric_id,
    'Queries Per Sec'::text AS metric_name,
    'Queries Per Sec'::text AS metric_unit
UNION ALL
 SELECT 2 AS group_id,
    'System Metrics Long Duration'::text AS group_name,
    3 AS metric_id,
    'Transactions Per Sec'::text AS metric_name,
    'Transactions Per Sec'::text AS metric_unit
UNION ALL
 SELECT 3 AS group_id,
    'System Metrics Short Duration'::text AS group_name,
    4 AS metric_id,
    'Transactions Per Sec'::text AS metric_name,
    'Transactions Per Sec'::text AS metric_unit;


ALTER VIEW sys_catalog.sys_stat_metric_name OWNER TO system;

--
-- Name: sys_stat_metric; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_metric AS
 SELECT m.begin_time,
    m.end_time,
    m.intsize_csec,
    n.group_id,
    m.metric_id,
    n.metric_name,
    n.metric_unit,
    round((m.metric_value)::numeric(30,2), 2) AS metric_value,
    m.rel_value,
    m.abs_value
   FROM sys_stat_get_metric() m(begin_time, end_time, intsize_csec, metric_id, metric_value, rel_value, abs_value, series),
    sys_catalog.sys_stat_metric_name n
  WHERE (m.metric_id = n.metric_id)
  ORDER BY m.series DESC;


ALTER VIEW sys_catalog.sys_stat_metric OWNER TO system;

--
-- Name: sys_stat_metric_group; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_metric_group AS
 SELECT 0 AS group_id,
    'Event Metrics'::text AS group_name,
    60 AS intsize_csec,
    1 AS max_interval
UNION ALL
 SELECT 1 AS group_id,
    'Event Class Metrics'::text AS group_name,
    60 AS intsize_csec,
    60 AS max_interval
UNION ALL
 SELECT 2 AS group_id,
    'System Metrics Long Duration'::text AS group_name,
    60 AS intsize_csec,
    60 AS max_interval
UNION ALL
 SELECT 3 AS group_id,
    'System Metrics Short Duration'::text AS group_name,
    15 AS intsize_csec,
    240 AS max_interval;


ALTER VIEW sys_catalog.sys_stat_metric_group OWNER TO system;

--
-- Name: sys_stat_metric_history; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_metric_history AS
 SELECT sys_stat_metric.begin_time,
    sys_stat_metric.end_time,
    sys_stat_metric.intsize_csec,
    sys_stat_metric.group_id,
    sys_stat_metric.metric_id,
    sys_stat_metric.metric_name,
    sys_stat_metric.metric_unit,
    sys_stat_metric.metric_value,
    sys_stat_metric.rel_value,
    sys_stat_metric.abs_value
   FROM sys_catalog.sys_stat_metric;


ALTER VIEW sys_catalog.sys_stat_metric_history OWNER TO system;

--
-- Name: sys_stat_msgaccum; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_msgaccum AS
 SELECT s.message,
    s.calls,
    s.times
   FROM pg_stat_get_sqltime() s(userid, datid, queryid, message, bgmsg, calls, times);


ALTER VIEW sys_catalog.sys_stat_msgaccum OWNER TO system;

--
-- Name: sys_stat_pre_archivewal; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_pre_archivewal AS
 SELECT s.path,
    s.name,
    s.size,
    s.timeline,
    s.system_id,
    s.start_lsn,
    s.end_lsn,
    s.modification
   FROM sys_stat_pre_archivewal() s(path, name, size, timeline, system_id, start_lsn, end_lsn, modification);


ALTER VIEW sys_catalog.sys_stat_pre_archivewal OWNER TO system;

--
-- Name: sys_stat_progress_checkpoint; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_progress_checkpoint AS
 SELECT s.pid,
    s.phase,
    s.flags,
    s.buffers_scan,
    s.buffers_processed,
    s.buffers_written,
    s.written_progress,
    s.write_rate,
    s.start_time
   FROM pg_stat_get_checkpoint() s(pid, phase, flags, buffers_scan, buffers_processed, buffers_written, written_progress, write_rate, start_time);


ALTER VIEW sys_catalog.sys_stat_progress_checkpoint OWNER TO system;

--
-- Name: sys_stat_progress_cluster; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_progress_cluster AS
 SELECT pg_stat_progress_cluster.pid,
    pg_stat_progress_cluster.datid,
    pg_stat_progress_cluster.datname,
    pg_stat_progress_cluster.relid,
    pg_stat_progress_cluster.command,
    pg_stat_progress_cluster.phase,
    pg_stat_progress_cluster.cluster_index_relid,
    pg_stat_progress_cluster.heap_tuples_scanned,
    pg_stat_progress_cluster.heap_tuples_written,
    pg_stat_progress_cluster.heap_blks_total,
    pg_stat_progress_cluster.heap_blks_scanned,
    pg_stat_progress_cluster.index_rebuild_count
   FROM pg_stat_progress_cluster;


ALTER VIEW sys_catalog.sys_stat_progress_cluster OWNER TO system;

--
-- Name: sys_stat_progress_create_index; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_progress_create_index AS
 SELECT pg_stat_progress_create_index.pid,
    pg_stat_progress_create_index.datid,
    pg_stat_progress_create_index.datname,
    pg_stat_progress_create_index.relid,
    pg_stat_progress_create_index.index_relid,
    pg_stat_progress_create_index.command,
    pg_stat_progress_create_index.phase,
    pg_stat_progress_create_index.lockers_total,
    pg_stat_progress_create_index.lockers_done,
    pg_stat_progress_create_index.current_locker_pid,
    pg_stat_progress_create_index.blocks_total,
    pg_stat_progress_create_index.blocks_done,
    pg_stat_progress_create_index.tuples_total,
    pg_stat_progress_create_index.tuples_done,
    pg_stat_progress_create_index.partitions_total,
    pg_stat_progress_create_index.partitions_done
   FROM pg_stat_progress_create_index;


ALTER VIEW sys_catalog.sys_stat_progress_create_index OWNER TO system;

--
-- Name: sys_stat_progress_vacuum; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_progress_vacuum AS
 SELECT pg_stat_progress_vacuum.pid,
    pg_stat_progress_vacuum.datid,
    pg_stat_progress_vacuum.datname,
    pg_stat_progress_vacuum.relid,
    pg_stat_progress_vacuum.phase,
    pg_stat_progress_vacuum.heap_blks_total,
    pg_stat_progress_vacuum.heap_blks_scanned,
    pg_stat_progress_vacuum.heap_blks_vacuumed,
    pg_stat_progress_vacuum.index_vacuum_count,
    pg_stat_progress_vacuum.max_dead_tuples,
    pg_stat_progress_vacuum.num_dead_tuples
   FROM pg_stat_progress_vacuum;


ALTER VIEW sys_catalog.sys_stat_progress_vacuum OWNER TO system;

--
-- Name: sys_stat_replication; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_replication AS
 SELECT pg_stat_replication.pid,
    pg_stat_replication.usesysid,
    pg_stat_replication.usename,
    pg_stat_replication.application_name,
    pg_stat_replication.client_addr,
    pg_stat_replication.client_hostname,
    pg_stat_replication.client_port,
    pg_stat_replication.backend_start,
    pg_stat_replication.backend_xmin,
    pg_stat_replication.state,
    pg_stat_replication.sent_lsn,
    pg_stat_replication.write_lsn,
    pg_stat_replication.flush_lsn,
    pg_stat_replication.replay_lsn,
    pg_stat_replication.write_lag,
    pg_stat_replication.flush_lag,
    pg_stat_replication.replay_lag,
    pg_stat_replication.sync_priority,
    pg_stat_replication.sync_state,
    pg_stat_replication.reply_time
   FROM pg_stat_replication;


ALTER VIEW sys_catalog.sys_stat_replication OWNER TO system;

--
-- Name: sys_stat_shmem; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_shmem AS
 SELECT s.name,
    s.size
   FROM pg_stat_get_shmem() s(name, size);


ALTER VIEW sys_catalog.sys_stat_shmem OWNER TO system;

--
-- Name: sys_stat_sql; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_sql AS
 SELECT perf_get_topsql_stats.datid,
    perf_get_topsql_stats.datname,
    perf_get_topsql_stats.userid,
    perf_get_topsql_stats.username,
    perf_get_topsql_stats.queryid,
    perf_get_topsql_stats.query,
    perf_get_topsql_stats.calls,
    perf_get_topsql_stats.rows,
    perf_get_topsql_stats.db_time,
    perf_get_topsql_stats.db_cpu,
    perf_get_topsql_stats.db_wait,
    perf_get_topsql_stats.total_db_time_pct,
    perf_get_topsql_stats.cpu_time_pct,
    perf_get_topsql_stats.wait_time_pct,
    perf_get_topsql_stats.wait_event_1,
    perf_get_topsql_stats.wait_calls_1,
    perf_get_topsql_stats.wait_time_1,
    perf_get_topsql_stats.wait_time_pct_1,
    perf_get_topsql_stats.wait_event_2,
    perf_get_topsql_stats.wait_calls_2,
    perf_get_topsql_stats.wait_time_2,
    perf_get_topsql_stats.wait_time_pct_2,
    perf_get_topsql_stats.parse_calls,
    perf_get_topsql_stats.parse_time,
    perf_get_topsql_stats.parse_time_pct,
    perf_get_topsql_stats.plan_calls,
    perf_get_topsql_stats.plan_time,
    perf_get_topsql_stats.plan_time_pct,
    perf_get_topsql_stats.exec_calls,
    perf_get_topsql_stats.exec_time,
    perf_get_topsql_stats.exec_time_pct,
    perf_get_topsql_stats.wal_size,
    perf_get_topsql_stats.shared_blks_read_size,
    perf_get_topsql_stats.shared_blks_write_size,
    perf_get_topsql_stats.local_blks_read_size,
    perf_get_topsql_stats.local_blks_write_size,
    perf_get_topsql_stats.temp_blks_read_size,
    perf_get_topsql_stats.temp_blks_write_size,
    perf_get_topsql_stats.shared_blks_hit,
    perf_get_topsql_stats.local_blks_hit,
    perf_get_topsql_stats.blks_read_time,
    perf_get_topsql_stats.blks_write_time
   FROM perf_get_topsql_stats() perf_get_topsql_stats(datid, datname, userid, username, queryid, query, calls, rows, db_time, db_cpu, db_wait, total_db_time_pct, cpu_time_pct, wait_time_pct, wait_event_1, wait_calls_1, wait_time_1, wait_time_pct_1, wait_event_2, wait_calls_2, wait_time_2, wait_time_pct_2, parse_calls, parse_time, parse_time_pct, plan_calls, plan_time, plan_time_pct, exec_calls, exec_time, exec_time_pct, wal_size, shared_blks_read_size, shared_blks_write_size, local_blks_read_size, local_blks_write_size, temp_blks_read_size, temp_blks_write_size, shared_blks_hit, local_blks_hit, blks_read_time, blks_write_time);


ALTER VIEW sys_catalog.sys_stat_sql OWNER TO system;

--
-- Name: sys_stat_sqlcount; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_sqlcount AS
 SELECT sys_stat_instevent.datid,
    sys_stat_instevent.event_name AS sql_type,
    sys_stat_instevent.background,
    sys_stat_instevent.calls,
    sys_stat_instevent.times
   FROM sys_catalog.sys_stat_instevent
  WHERE ((sys_stat_instevent.event_type = 'Sql Count'::text) AND (sys_stat_instevent.event_name <> ALL (ARRAY['Insert'::text, 'Delete'::text, 'Update'::text, 'Select'::text, 'Merge'::text])));


ALTER VIEW sys_catalog.sys_stat_sqlcount OWNER TO system;

--
-- Name: sys_stat_sqlio; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_sqlio AS
 SELECT s.userid,
    s.datid,
    s.queryid,
    s.bgio,
    s.wal_records,
    s.wal_fpi,
    s.wal_bytes,
    s.shared_blks_hit,
    s.shared_blks_read,
    s.shared_blks_dirtied,
    s.shared_blks_written,
    s.local_blks_hit,
    s.local_blks_read,
    s.local_blks_dirtied,
    s.local_blks_written,
    s.temp_blks_read,
    s.temp_blks_written,
    s.blk_read_time,
    s.blk_write_time
   FROM pg_stat_get_sqlio() s(userid, datid, queryid, bgio, wal_records, wal_fpi, wal_bytes, shared_blks_hit, shared_blks_read, shared_blks_dirtied, shared_blks_written, local_blks_hit, local_blks_read, local_blks_dirtied, local_blks_written, temp_blks_read, temp_blks_written, blk_read_time, blk_write_time);


ALTER VIEW sys_catalog.sys_stat_sqlio OWNER TO system;

--
-- Name: sys_stat_sqltime; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_sqltime AS
 SELECT s.userid,
    s.datid,
    s.queryid,
    s.message,
    s.bgmsg,
    s.calls,
    s.times
   FROM pg_stat_get_sqltime() s(userid, datid, queryid, message, bgmsg, calls, times);


ALTER VIEW sys_catalog.sys_stat_sqltime OWNER TO system;

--
-- Name: sys_stat_sqlwait; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_sqlwait AS
 SELECT s.userid,
    s.datid,
    s.queryid,
    s.wait_event_type,
    s.wait_event,
    s.bgwait,
    s.calls,
    s.times
   FROM pg_stat_get_sqlwait() s(userid, datid, queryid, wait_event_type, wait_event, bgwait, calls, times);


ALTER VIEW sys_catalog.sys_stat_sqlwait OWNER TO system;

--
-- Name: sys_stat_ssl; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_ssl AS
 SELECT pg_stat_ssl.pid,
    pg_stat_ssl.ssl,
    pg_stat_ssl.version,
    pg_stat_ssl.cipher,
    pg_stat_ssl.bits,
    pg_stat_ssl.compression,
    pg_stat_ssl.client_dn,
    pg_stat_ssl.client_serial,
    pg_stat_ssl.issuer_dn
   FROM pg_stat_ssl;


ALTER VIEW sys_catalog.sys_stat_ssl OWNER TO system;

--
-- Name: sys_stat_subscription; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_subscription AS
 SELECT pg_stat_subscription.subid,
    pg_stat_subscription.subname,
    pg_stat_subscription.pid,
    pg_stat_subscription.relid,
    pg_stat_subscription.received_lsn,
    pg_stat_subscription.last_msg_send_time,
    pg_stat_subscription.last_msg_receipt_time,
    pg_stat_subscription.latest_end_lsn,
    pg_stat_subscription.latest_end_time
   FROM pg_stat_subscription;


ALTER VIEW sys_catalog.sys_stat_subscription OWNER TO system;

--
-- Name: sys_stat_sys_indexes; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_sys_indexes AS
 SELECT pg_stat_sys_indexes.relid,
    pg_stat_sys_indexes.indexrelid,
    pg_stat_sys_indexes.schemaname,
    pg_stat_sys_indexes.relname,
    pg_stat_sys_indexes.indexrelname,
    pg_stat_sys_indexes.idx_scan,
    pg_stat_sys_indexes.idx_tup_read,
    pg_stat_sys_indexes.idx_tup_fetch
   FROM pg_stat_sys_indexes;


ALTER VIEW sys_catalog.sys_stat_sys_indexes OWNER TO system;

--
-- Name: sys_stat_sys_tables; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_sys_tables AS
 SELECT pg_stat_sys_tables.relid,
    pg_stat_sys_tables.schemaname,
    pg_stat_sys_tables.relname,
    pg_stat_sys_tables.seq_scan,
    pg_stat_sys_tables.seq_tup_read,
    pg_stat_sys_tables.idx_scan,
    pg_stat_sys_tables.idx_tup_fetch,
    pg_stat_sys_tables.n_tup_ins,
    pg_stat_sys_tables.n_tup_upd,
    pg_stat_sys_tables.n_tup_del,
    pg_stat_sys_tables.n_tup_hot_upd,
    pg_stat_sys_tables.n_live_tup,
    pg_stat_sys_tables.n_dead_tup,
    pg_stat_sys_tables.n_mod_since_analyze,
    pg_stat_sys_tables.last_vacuum,
    pg_stat_sys_tables.last_autovacuum,
    pg_stat_sys_tables.last_analyze,
    pg_stat_sys_tables.last_autoanalyze,
    pg_stat_sys_tables.vacuum_count,
    pg_stat_sys_tables.autovacuum_count,
    pg_stat_sys_tables.analyze_count,
    pg_stat_sys_tables.autoanalyze_count
   FROM pg_stat_sys_tables;


ALTER VIEW sys_catalog.sys_stat_sys_tables OWNER TO system;

--
-- Name: sys_stat_sysmetric; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_sysmetric AS
 SELECT sys_stat_metric.begin_time,
    sys_stat_metric.end_time,
    sys_stat_metric.intsize_csec,
    sys_stat_metric.group_id,
    sys_stat_metric.metric_id,
    sys_stat_metric.metric_name,
    sys_stat_metric.metric_unit,
    sys_stat_metric.metric_value,
    sys_stat_metric.rel_value,
    sys_stat_metric.abs_value
   FROM sys_catalog.sys_stat_metric;


ALTER VIEW sys_catalog.sys_stat_sysmetric OWNER TO system;

--
-- Name: sys_stat_sysmetric_history; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_sysmetric_history AS
 SELECT sys_stat_sysmetric.begin_time,
    sys_stat_sysmetric.end_time,
    sys_stat_sysmetric.intsize_csec,
    sys_stat_sysmetric.group_id,
    sys_stat_sysmetric.metric_id,
    sys_stat_sysmetric.metric_name,
    sys_stat_sysmetric.metric_unit,
    sys_stat_sysmetric.metric_value,
    sys_stat_sysmetric.rel_value,
    sys_stat_sysmetric.abs_value
   FROM sys_catalog.sys_stat_sysmetric;


ALTER VIEW sys_catalog.sys_stat_sysmetric_history OWNER TO system;

--
-- Name: sys_stat_sysmetric_summary; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_sysmetric_summary AS
 SELECT min(sys_stat_sysmetric.begin_time) AS begin_time,
    max(sys_stat_sysmetric.end_time) AS end_time,
    round((date_part('epoch'::text, max(sys_stat_sysmetric.end_time)) - date_part('epoch'::text, min(sys_stat_sysmetric.begin_time)))) AS intsize_csec,
    sys_stat_sysmetric.group_id,
    sys_stat_sysmetric.metric_id,
    sys_stat_sysmetric.metric_name,
    count(sys_stat_sysmetric.begin_time) AS num_interval,
    max(sys_stat_sysmetric.metric_value) AS maxval,
    min(sys_stat_sysmetric.metric_value) AS minval,
    round(avg(sys_stat_sysmetric.metric_value), 2) AS average,
    round(stddev(sys_stat_sysmetric.metric_value), 2) AS standard_devation,
    sys_stat_sysmetric.metric_unit
   FROM sys_catalog.sys_stat_sysmetric
  GROUP BY sys_stat_sysmetric.group_id, sys_stat_sysmetric.metric_id, sys_stat_sysmetric.metric_name, sys_stat_sysmetric.metric_unit
  ORDER BY sys_stat_sysmetric.metric_id;


ALTER VIEW sys_catalog.sys_stat_sysmetric_summary OWNER TO system;

--
-- Name: sys_stat_transaction; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_transaction AS
 SELECT d.oid AS datid,
    d.datname,
    pg_stat_get_db_xact_commit(d.oid) AS xact_commit,
    pg_stat_get_db_xact_rollback(d.oid) AS xact_rollback,
    pg_stat_get_db_fg_xact_commit(d.oid) AS fg_xact_commit,
    pg_stat_get_db_fg_xact_rollback(d.oid) AS fg_xact_rollback,
    (pg_stat_get_db_xact_commit(d.oid) - pg_stat_get_db_fg_xact_commit(d.oid)) AS bg_xact_commit,
    (pg_stat_get_db_xact_rollback(d.oid) - pg_stat_get_db_fg_xact_rollback(d.oid)) AS bg_xact_rollback,
    pg_stat_get_db_stat_reset_time(d.oid) AS stats_reset
   FROM ( SELECT 0 AS oid,
            NULL::name AS datname
        UNION ALL
         SELECT _db.oid,
            _db.datname
           FROM _db) d;


ALTER VIEW sys_catalog.sys_stat_transaction OWNER TO system;

--
-- Name: sys_stat_user_functions; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_user_functions AS
 SELECT pg_stat_user_functions.funcid,
    pg_stat_user_functions.schemaname,
    pg_stat_user_functions.funcname,
    pg_stat_user_functions.calls,
    pg_stat_user_functions.total_time,
    pg_stat_user_functions.self_time
   FROM pg_stat_user_functions;


ALTER VIEW sys_catalog.sys_stat_user_functions OWNER TO system;

--
-- Name: sys_stat_user_indexes; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_user_indexes AS
 SELECT pg_stat_user_indexes.relid,
    pg_stat_user_indexes.indexrelid,
    pg_stat_user_indexes.schemaname,
    pg_stat_user_indexes.relname,
    pg_stat_user_indexes.indexrelname,
    pg_stat_user_indexes.idx_scan,
    pg_stat_user_indexes.idx_tup_read,
    pg_stat_user_indexes.idx_tup_fetch
   FROM pg_stat_user_indexes;


ALTER VIEW sys_catalog.sys_stat_user_indexes OWNER TO system;

--
-- Name: sys_stat_user_tables; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_user_tables AS
 SELECT pg_stat_user_tables.relid,
    pg_stat_user_tables.schemaname,
    pg_stat_user_tables.relname,
    pg_stat_user_tables.seq_scan,
    pg_stat_user_tables.seq_tup_read,
    pg_stat_user_tables.idx_scan,
    pg_stat_user_tables.idx_tup_fetch,
    pg_stat_user_tables.n_tup_ins,
    pg_stat_user_tables.n_tup_upd,
    pg_stat_user_tables.n_tup_del,
    pg_stat_user_tables.n_tup_hot_upd,
    pg_stat_user_tables.n_live_tup,
    pg_stat_user_tables.n_dead_tup,
    pg_stat_user_tables.n_mod_since_analyze,
    pg_stat_user_tables.last_vacuum,
    pg_stat_user_tables.last_autovacuum,
    pg_stat_user_tables.last_analyze,
    pg_stat_user_tables.last_autoanalyze,
    pg_stat_user_tables.vacuum_count,
    pg_stat_user_tables.autovacuum_count,
    pg_stat_user_tables.analyze_count,
    pg_stat_user_tables.autoanalyze_count
   FROM pg_stat_user_tables;


ALTER VIEW sys_catalog.sys_stat_user_tables OWNER TO system;

--
-- Name: sys_stat_wait; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_wait AS
 SELECT perf_get_fgwait_stats.wait_event,
    perf_get_fgwait_stats.calls,
    perf_get_fgwait_stats.total_time,
    perf_get_fgwait_stats.avg_time,
    perf_get_fgwait_stats.dbtime_pct,
    perf_get_fgwait_stats.event_type
   FROM perf_get_fgwait_stats() perf_get_fgwait_stats(wait_event, calls, total_time, avg_time, dbtime_pct, event_type);


ALTER VIEW sys_catalog.sys_stat_wait OWNER TO system;

--
-- Name: sys_stat_waitaccum; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_waitaccum AS
 SELECT s.datid,
    s.queryid,
    s.wait_event_type,
    s.wait_event,
    s.calls,
    s.times
   FROM pg_stat_get_sqlwait() s(userid, datid, queryid, wait_event_type, wait_event, bgwait, calls, times);


ALTER VIEW sys_catalog.sys_stat_waitaccum OWNER TO system;

--
-- Name: sys_stat_wal_buffer; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_wal_buffer AS
 SELECT s.name,
    s.bytes,
    s.utilization_rate,
    s.copied_to,
    s.copied_to_lsn,
    s.coping_data_len,
    s.written_to,
    s.written_to_lsn,
    s.writing_data_len,
    s.write_rate
   FROM pg_stat_get_wal_buffer() s(name, bytes, utilization_rate, copied_to, copied_to_lsn, coping_data_len, written_to, written_to_lsn, writing_data_len, write_rate);


ALTER VIEW sys_catalog.sys_stat_wal_buffer OWNER TO system;

--
-- Name: sys_stat_wal_receiver; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_wal_receiver AS
 SELECT pg_stat_wal_receiver.pid,
    pg_stat_wal_receiver.status,
    pg_stat_wal_receiver.receive_start_lsn,
    pg_stat_wal_receiver.receive_start_tli,
    pg_stat_wal_receiver.received_lsn,
    pg_stat_wal_receiver.received_tli,
    pg_stat_wal_receiver.last_msg_send_time,
    pg_stat_wal_receiver.last_msg_receipt_time,
    pg_stat_wal_receiver.latest_end_lsn,
    pg_stat_wal_receiver.latest_end_time,
    pg_stat_wal_receiver.slot_name,
    pg_stat_wal_receiver.sender_host,
    pg_stat_wal_receiver.sender_port,
    pg_stat_wal_receiver.conninfo
   FROM pg_stat_wal_receiver;


ALTER VIEW sys_catalog.sys_stat_wal_receiver OWNER TO system;

--
-- Name: sys_stat_xact_all_tables; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_xact_all_tables AS
 SELECT pg_stat_xact_all_tables.relid,
    pg_stat_xact_all_tables.schemaname,
    pg_stat_xact_all_tables.relname,
    pg_stat_xact_all_tables.seq_scan,
    pg_stat_xact_all_tables.seq_tup_read,
    pg_stat_xact_all_tables.idx_scan,
    pg_stat_xact_all_tables.idx_tup_fetch,
    pg_stat_xact_all_tables.n_tup_ins,
    pg_stat_xact_all_tables.n_tup_upd,
    pg_stat_xact_all_tables.n_tup_del,
    pg_stat_xact_all_tables.n_tup_hot_upd
   FROM pg_stat_xact_all_tables;


ALTER VIEW sys_catalog.sys_stat_xact_all_tables OWNER TO system;

--
-- Name: sys_stat_xact_sys_tables; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_xact_sys_tables AS
 SELECT pg_stat_xact_sys_tables.relid,
    pg_stat_xact_sys_tables.schemaname,
    pg_stat_xact_sys_tables.relname,
    pg_stat_xact_sys_tables.seq_scan,
    pg_stat_xact_sys_tables.seq_tup_read,
    pg_stat_xact_sys_tables.idx_scan,
    pg_stat_xact_sys_tables.idx_tup_fetch,
    pg_stat_xact_sys_tables.n_tup_ins,
    pg_stat_xact_sys_tables.n_tup_upd,
    pg_stat_xact_sys_tables.n_tup_del,
    pg_stat_xact_sys_tables.n_tup_hot_upd
   FROM pg_stat_xact_sys_tables;


ALTER VIEW sys_catalog.sys_stat_xact_sys_tables OWNER TO system;

--
-- Name: sys_stat_xact_user_functions; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_xact_user_functions AS
 SELECT pg_stat_xact_user_functions.funcid,
    pg_stat_xact_user_functions.schemaname,
    pg_stat_xact_user_functions.funcname,
    pg_stat_xact_user_functions.calls,
    pg_stat_xact_user_functions.total_time,
    pg_stat_xact_user_functions.self_time
   FROM pg_stat_xact_user_functions;


ALTER VIEW sys_catalog.sys_stat_xact_user_functions OWNER TO system;

--
-- Name: sys_stat_xact_user_tables; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stat_xact_user_tables AS
 SELECT pg_stat_xact_user_tables.relid,
    pg_stat_xact_user_tables.schemaname,
    pg_stat_xact_user_tables.relname,
    pg_stat_xact_user_tables.seq_scan,
    pg_stat_xact_user_tables.seq_tup_read,
    pg_stat_xact_user_tables.idx_scan,
    pg_stat_xact_user_tables.idx_tup_fetch,
    pg_stat_xact_user_tables.n_tup_ins,
    pg_stat_xact_user_tables.n_tup_upd,
    pg_stat_xact_user_tables.n_tup_del,
    pg_stat_xact_user_tables.n_tup_hot_upd
   FROM pg_stat_xact_user_tables;


ALTER VIEW sys_catalog.sys_stat_xact_user_tables OWNER TO system;

--
-- Name: sys_statio_all_indexes; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_statio_all_indexes AS
 SELECT pg_statio_all_indexes.relid,
    pg_statio_all_indexes.indexrelid,
    pg_statio_all_indexes.schemaname,
    pg_statio_all_indexes.relname,
    pg_statio_all_indexes.indexrelname,
    pg_statio_all_indexes.idx_blks_read,
    pg_statio_all_indexes.idx_blks_hit
   FROM pg_statio_all_indexes;


ALTER VIEW sys_catalog.sys_statio_all_indexes OWNER TO system;

--
-- Name: sys_statio_all_sequences; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_statio_all_sequences AS
 SELECT pg_statio_all_sequences.relid,
    pg_statio_all_sequences.schemaname,
    pg_statio_all_sequences.relname,
    pg_statio_all_sequences.blks_read,
    pg_statio_all_sequences.blks_hit
   FROM pg_statio_all_sequences;


ALTER VIEW sys_catalog.sys_statio_all_sequences OWNER TO system;

--
-- Name: sys_statio_all_tables; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_statio_all_tables AS
 SELECT pg_statio_all_tables.relid,
    pg_statio_all_tables.schemaname,
    pg_statio_all_tables.relname,
    pg_statio_all_tables.heap_blks_read,
    pg_statio_all_tables.heap_blks_hit,
    pg_statio_all_tables.idx_blks_read,
    pg_statio_all_tables.idx_blks_hit,
    pg_statio_all_tables.toast_blks_read,
    pg_statio_all_tables.toast_blks_hit,
    pg_statio_all_tables.tidx_blks_read,
    pg_statio_all_tables.tidx_blks_hit
   FROM pg_statio_all_tables;


ALTER VIEW sys_catalog.sys_statio_all_tables OWNER TO system;

--
-- Name: sys_statio_sys_indexes; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_statio_sys_indexes AS
 SELECT pg_statio_sys_indexes.relid,
    pg_statio_sys_indexes.indexrelid,
    pg_statio_sys_indexes.schemaname,
    pg_statio_sys_indexes.relname,
    pg_statio_sys_indexes.indexrelname,
    pg_statio_sys_indexes.idx_blks_read,
    pg_statio_sys_indexes.idx_blks_hit
   FROM pg_statio_sys_indexes;


ALTER VIEW sys_catalog.sys_statio_sys_indexes OWNER TO system;

--
-- Name: sys_statio_sys_sequences; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_statio_sys_sequences AS
 SELECT pg_statio_sys_sequences.relid,
    pg_statio_sys_sequences.schemaname,
    pg_statio_sys_sequences.relname,
    pg_statio_sys_sequences.blks_read,
    pg_statio_sys_sequences.blks_hit
   FROM pg_statio_sys_sequences;


ALTER VIEW sys_catalog.sys_statio_sys_sequences OWNER TO system;

--
-- Name: sys_statio_sys_tables; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_statio_sys_tables AS
 SELECT pg_statio_sys_tables.relid,
    pg_statio_sys_tables.schemaname,
    pg_statio_sys_tables.relname,
    pg_statio_sys_tables.heap_blks_read,
    pg_statio_sys_tables.heap_blks_hit,
    pg_statio_sys_tables.idx_blks_read,
    pg_statio_sys_tables.idx_blks_hit,
    pg_statio_sys_tables.toast_blks_read,
    pg_statio_sys_tables.toast_blks_hit,
    pg_statio_sys_tables.tidx_blks_read,
    pg_statio_sys_tables.tidx_blks_hit
   FROM pg_statio_sys_tables;


ALTER VIEW sys_catalog.sys_statio_sys_tables OWNER TO system;

--
-- Name: sys_statio_user_indexes; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_statio_user_indexes AS
 SELECT pg_statio_user_indexes.relid,
    pg_statio_user_indexes.indexrelid,
    pg_statio_user_indexes.schemaname,
    pg_statio_user_indexes.relname,
    pg_statio_user_indexes.indexrelname,
    pg_statio_user_indexes.idx_blks_read,
    pg_statio_user_indexes.idx_blks_hit
   FROM pg_statio_user_indexes;


ALTER VIEW sys_catalog.sys_statio_user_indexes OWNER TO system;

--
-- Name: sys_statio_user_sequences; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_statio_user_sequences AS
 SELECT pg_statio_user_sequences.relid,
    pg_statio_user_sequences.schemaname,
    pg_statio_user_sequences.relname,
    pg_statio_user_sequences.blks_read,
    pg_statio_user_sequences.blks_hit
   FROM pg_statio_user_sequences;


ALTER VIEW sys_catalog.sys_statio_user_sequences OWNER TO system;

--
-- Name: sys_statio_user_tables; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_statio_user_tables AS
 SELECT pg_statio_user_tables.relid,
    pg_statio_user_tables.schemaname,
    pg_statio_user_tables.relname,
    pg_statio_user_tables.heap_blks_read,
    pg_statio_user_tables.heap_blks_hit,
    pg_statio_user_tables.idx_blks_read,
    pg_statio_user_tables.idx_blks_hit,
    pg_statio_user_tables.toast_blks_read,
    pg_statio_user_tables.toast_blks_hit,
    pg_statio_user_tables.tidx_blks_read,
    pg_statio_user_tables.tidx_blks_hit
   FROM pg_statio_user_tables;


ALTER VIEW sys_catalog.sys_statio_user_tables OWNER TO system;

--
-- Name: sys_statistic; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_statistic AS
 SELECT _stat.starelid,
    _stat.staattnum,
    _stat.stainherit,
    _stat.stanullfrac,
    _stat.stawidth,
    _stat.stadistinct,
    _stat.stakind1,
    _stat.stakind2,
    _stat.stakind3,
    _stat.stakind4,
    _stat.stakind5,
    _stat.staop1,
    _stat.staop2,
    _stat.staop3,
    _stat.staop4,
    _stat.staop5,
    _stat.stacoll1,
    _stat.stacoll2,
    _stat.stacoll3,
    _stat.stacoll4,
    _stat.stacoll5,
    _stat.stanumbers1,
    _stat.stanumbers2,
    _stat.stanumbers3,
    _stat.stanumbers4,
    _stat.stanumbers5,
    _stat.stavalues1,
    _stat.stavalues2,
    _stat.stavalues3,
    _stat.stavalues4,
    _stat.stavalues5
   FROM _stat;


ALTER VIEW sys_catalog.sys_statistic OWNER TO system;

--
-- Name: sys_statistic_ext; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_statistic_ext AS
 SELECT _stat_ext.oid,
    _stat_ext.stxrelid,
    _stat_ext.stxname,
    _stat_ext.stxnamespace,
    _stat_ext.stxowner,
    _stat_ext.stxkeys,
    _stat_ext.stxkind
   FROM _stat_ext;


ALTER VIEW sys_catalog.sys_statistic_ext OWNER TO system;

--
-- Name: sys_statistic_ext_data; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_statistic_ext_data AS
 SELECT _statextdat.stxoid,
    _statextdat.stxdndistinct,
    _statextdat.stxddependencies,
    _statextdat.stxdmcv
   FROM _statextdat;


ALTER VIEW sys_catalog.sys_statistic_ext_data OWNER TO system;

--
-- Name: sys_stats; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stats WITH (security_barrier='true') AS
 SELECT n.nspname AS schemaname,
    c.relname AS tablename,
    a.attname,
    s.stainherit AS inherited,
    s.stanullfrac AS null_frac,
    s.stawidth AS avg_width,
    s.stadistinct AS n_distinct,
        CASE
            WHEN (s.stakind1 = 1) THEN s.stavalues1
            WHEN (s.stakind2 = 1) THEN s.stavalues2
            WHEN (s.stakind3 = 1) THEN s.stavalues3
            WHEN (s.stakind4 = 1) THEN s.stavalues4
            WHEN (s.stakind5 = 1) THEN s.stavalues5
            ELSE NULL::anyarray
        END AS most_common_vals,
        CASE
            WHEN (s.stakind1 = 1) THEN s.stanumbers1
            WHEN (s.stakind2 = 1) THEN s.stanumbers2
            WHEN (s.stakind3 = 1) THEN s.stanumbers3
            WHEN (s.stakind4 = 1) THEN s.stanumbers4
            WHEN (s.stakind5 = 1) THEN s.stanumbers5
            ELSE NULL::real[]
        END AS most_common_freqs,
        CASE
            WHEN (s.stakind1 = 2) THEN s.stavalues1
            WHEN (s.stakind2 = 2) THEN s.stavalues2
            WHEN (s.stakind3 = 2) THEN s.stavalues3
            WHEN (s.stakind4 = 2) THEN s.stavalues4
            WHEN (s.stakind5 = 2) THEN s.stavalues5
            ELSE NULL::anyarray
        END AS histogram_bounds,
        CASE
            WHEN (s.stakind1 = 3) THEN s.stanumbers1[1]
            WHEN (s.stakind2 = 3) THEN s.stanumbers2[1]
            WHEN (s.stakind3 = 3) THEN s.stanumbers3[1]
            WHEN (s.stakind4 = 3) THEN s.stanumbers4[1]
            WHEN (s.stakind5 = 3) THEN s.stanumbers5[1]
            ELSE NULL::real
        END AS correlation,
        CASE
            WHEN (s.stakind1 = 4) THEN s.stavalues1
            WHEN (s.stakind2 = 4) THEN s.stavalues2
            WHEN (s.stakind3 = 4) THEN s.stavalues3
            WHEN (s.stakind4 = 4) THEN s.stavalues4
            WHEN (s.stakind5 = 4) THEN s.stavalues5
            ELSE NULL::anyarray
        END AS most_common_elems,
        CASE
            WHEN (s.stakind1 = 4) THEN s.stanumbers1
            WHEN (s.stakind2 = 4) THEN s.stanumbers2
            WHEN (s.stakind3 = 4) THEN s.stanumbers3
            WHEN (s.stakind4 = 4) THEN s.stanumbers4
            WHEN (s.stakind5 = 4) THEN s.stanumbers5
            ELSE NULL::real[]
        END AS most_common_elem_freqs,
        CASE
            WHEN (s.stakind1 = 5) THEN s.stanumbers1
            WHEN (s.stakind2 = 5) THEN s.stanumbers2
            WHEN (s.stakind3 = 5) THEN s.stanumbers3
            WHEN (s.stakind4 = 5) THEN s.stanumbers4
            WHEN (s.stakind5 = 5) THEN s.stanumbers5
            ELSE NULL::real[]
        END AS elem_count_histogram,
        CASE
            WHEN (s.stakind1 = 8) THEN s.stavalues1
            WHEN (s.stakind2 = 8) THEN s.stavalues2
            WHEN (s.stakind3 = 8) THEN s.stavalues3
            WHEN (s.stakind4 = 8) THEN s.stavalues4
            WHEN (s.stakind5 = 8) THEN s.stavalues5
            ELSE NULL::anyarray
        END AS hybrid_histogram_bounds,
        CASE
            WHEN (s.stakind1 = 8) THEN s.stanumbers1
            WHEN (s.stakind2 = 8) THEN s.stanumbers2
            WHEN (s.stakind3 = 8) THEN s.stanumbers3
            WHEN (s.stakind4 = 8) THEN s.stanumbers4
            WHEN (s.stakind5 = 8) THEN s.stanumbers5
            ELSE NULL::real[]
        END AS hybrid_histogram_freqs,
        CASE
            WHEN (s.stakind1 = 9) THEN s.stanumbers1
            WHEN (s.stakind2 = 9) THEN s.stanumbers2
            WHEN (s.stakind3 = 9) THEN s.stanumbers3
            WHEN (s.stakind4 = 9) THEN s.stanumbers4
            WHEN (s.stakind5 = 9) THEN s.stanumbers5
            ELSE NULL::real[]
        END AS hybrid_histogram_bounds_freqs
   FROM (((_stat s
     JOIN _rel c ON ((c.oid = s.starelid)))
     JOIN _att a ON (((c.oid = a.attrelid) AND (a.attnum = s.staattnum))))
     LEFT JOIN _nsp n ON ((n.oid = c.relnamespace)))
  WHERE ((NOT (a.attisdropped AND (a.attname = concat('........kb.dropped.', a.attnum, '........')))) AND has_column_privilege(c.oid, a.attnum, 'select'::text) AND ((c.relrowsecurity = false) OR (NOT row_security_active(c.oid))) AND (NOT (c.oid IN ( SELECT _recyclebin.reloid
           FROM _recyclebin))));


ALTER VIEW sys_catalog.sys_stats OWNER TO system;

--
-- Name: sys_stats_ext; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_stats_ext AS
 SELECT pg_stats_ext.schemaname,
    pg_stats_ext.tablename,
    pg_stats_ext.statistics_schemaname,
    pg_stats_ext.statistics_name,
    pg_stats_ext.statistics_owner,
    pg_stats_ext.attnames,
    pg_stats_ext.kinds,
    pg_stats_ext.n_distinct,
    pg_stats_ext.dependencies,
    pg_stats_ext.most_common_vals,
    pg_stats_ext.most_common_val_nulls,
    pg_stats_ext.most_common_freqs,
    pg_stats_ext.most_common_base_freqs
   FROM pg_stats_ext;


ALTER VIEW sys_catalog.sys_stats_ext OWNER TO system;

--
-- Name: sys_subpartition_table; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_subpartition_table AS
 SELECT _defsubpart.partrelid,
    _defsubpart.partstrat,
    _defsubpart.partnatts,
    _defsubpart.partdefid,
    _defsubpart.partattrs,
    _defsubpart.partclass,
    _defsubpart.partcollation,
    _defsubpart.partexprs,
    _defsubpart.partspec
   FROM _defsubpart;


ALTER VIEW sys_catalog.sys_subpartition_table OWNER TO system;

--
-- Name: sys_subscription; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_subscription AS
 SELECT _subscrpt.oid,
    _subscrpt.subdbid,
    _subscrpt.subname,
    _subscrpt.subowner,
    _subscrpt.subenabled,
    _subscrpt.subconninfo,
    _subscrpt.subslotname,
    _subscrpt.subsynccommit,
    _subscrpt.subpublications
   FROM _subscrpt;


ALTER VIEW sys_catalog.sys_subscription OWNER TO system;

--
-- Name: sys_subscription_rel; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_subscription_rel AS
 SELECT _subscrptrel.srsubid,
    _subscrptrel.srrelid,
    _subscrptrel.srsubstate,
    _subscrptrel.srsublsn
   FROM _subscrptrel;


ALTER VIEW sys_catalog.sys_subscription_rel OWNER TO system;

--
-- Name: sys_tables; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_tables AS
 SELECT pg_tables.schemaname,
    pg_tables.tablename,
    pg_tables.tableowner,
    pg_tables.tablespace,
    pg_tables.hasindexes,
    pg_tables.hasrules,
    pg_tables.hastriggers,
    pg_tables.rowsecurity
   FROM pg_tables;


ALTER VIEW sys_catalog.sys_tables OWNER TO system;

--
-- Name: sys_tablespace; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_tablespace AS
 SELECT _tabspc.oid,
    _tabspc.spcname,
    _tabspc.spcowner,
    _tabspc.spcacl,
    _tabspc.spcoptions
   FROM _tabspc;


ALTER VIEW sys_catalog.sys_tablespace OWNER TO system;

--
-- Name: sys_timezone_abbrevs; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_timezone_abbrevs AS
 SELECT pg_timezone_abbrevs.abbrev,
    pg_timezone_abbrevs.utc_offset,
    pg_timezone_abbrevs.is_dst
   FROM pg_timezone_abbrevs;


ALTER VIEW sys_catalog.sys_timezone_abbrevs OWNER TO system;

--
-- Name: sys_timezone_names; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_timezone_names AS
 SELECT pg_timezone_names.name,
    pg_timezone_names.abbrev,
    pg_timezone_names.utc_offset,
    pg_timezone_names.is_dst
   FROM pg_timezone_names;


ALTER VIEW sys_catalog.sys_timezone_names OWNER TO system;

--
-- Name: sys_transform; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_transform AS
 SELECT _transform.oid,
    _transform.trftype,
    _transform.trflang,
    _transform.trffromsql,
    _transform.trftosql
   FROM _transform;


ALTER VIEW sys_catalog.sys_transform OWNER TO system;

--
-- Name: sys_trigger; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_trigger AS
 SELECT _trigger.oid,
    _trigger.tgrelid,
    _trigger.tgname,
    _trigger.tgfoid,
    _trigger.tgtype,
    _trigger.tgenabled,
    _trigger.tgisinternal,
    _trigger.tgconstrrelid,
    _trigger.tgconstrindid,
    _trigger.tgconstraint,
    _trigger.tgdeferrable,
    _trigger.tginitdeferred,
    _trigger.tgnargs,
    _trigger.tgattr,
    _trigger.tgargs,
    _trigger.tgqual,
    _trigger.tgoldtable,
    _trigger.tgnewtable
   FROM _trigger;


ALTER VIEW sys_catalog.sys_trigger OWNER TO system;

--
-- Name: sys_triggers; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_triggers AS
 SELECT tg.oid AS trioid,
    tg.tgname,
    n.oid AS schemaid,
    n.nspname AS schemaname,
    tg.tgenabled,
    c.relname AS tablename,
    tg.tgtype,
    tg.tgfoid,
    tg.tgconstrrelid,
    tg.tgdeferrable,
    tg.tginitdeferred,
    pg_get_triggerdef(tg.oid) AS tridef,
    pro.prosrc AS tridefbody,
    pg_get_userbyid(c.relowner) AS owner,
    tg.tgisinternal AS isinternal
   FROM ((((_rel c
     JOIN _trigger tg ON ((c.oid = tg.tgrelid)))
     LEFT JOIN _desc des ON (((tg.oid = des.objoid) AND (des.classoid = ('_trigger'::regclass)::oid))))
     JOIN _nsp n ON ((n.oid = c.relnamespace)))
     FULL JOIN _proc pro ON ((tg.tgfoid = pro.oid)))
  WHERE ((des.objoid IS NULL) AND (c.relkind = ANY (ARRAY['r'::"char", 'v'::"char", 'm'::"char"])));


ALTER VIEW sys_catalog.sys_triggers OWNER TO system;

--
-- Name: sys_ts_config; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_ts_config AS
 SELECT _tsconf.oid,
    _tsconf.cfgname,
    _tsconf.cfgnamespace,
    _tsconf.cfgowner,
    _tsconf.cfgparser
   FROM _tsconf;


ALTER VIEW sys_catalog.sys_ts_config OWNER TO system;

--
-- Name: sys_ts_config_map; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_ts_config_map AS
 SELECT _tsconfmap.mapcfg,
    _tsconfmap.maptokentype,
    _tsconfmap.mapseqno,
    _tsconfmap.mapdict
   FROM _tsconfmap;


ALTER VIEW sys_catalog.sys_ts_config_map OWNER TO system;

--
-- Name: sys_ts_dict; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_ts_dict AS
 SELECT _tsdict.oid,
    _tsdict.dictname,
    _tsdict.dictnamespace,
    _tsdict.dictowner,
    _tsdict.dicttemplate,
    _tsdict.dictinitoption
   FROM _tsdict;


ALTER VIEW sys_catalog.sys_ts_dict OWNER TO system;

--
-- Name: sys_ts_parser; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_ts_parser AS
 SELECT _tsparser.oid,
    _tsparser.prsname,
    _tsparser.prsnamespace,
    _tsparser.prsstart,
    _tsparser.prstoken,
    _tsparser.prsend,
    _tsparser.prsheadline,
    _tsparser.prslextype
   FROM _tsparser;


ALTER VIEW sys_catalog.sys_ts_parser OWNER TO system;

--
-- Name: sys_ts_template; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_ts_template AS
 SELECT _tstmpl.oid,
    _tstmpl.tmplname,
    _tstmpl.tmplnamespace,
    _tstmpl.tmplinit,
    _tstmpl.tmpllexize
   FROM _tstmpl;


ALTER VIEW sys_catalog.sys_ts_template OWNER TO system;

--
-- Name: sys_type; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_type AS
 SELECT _typ.oid,
    _typ.typname,
    _typ.typnamespace,
    _typ.typowner,
    _typ.typlen,
    _typ.typbyval,
    _typ.typtype,
    _typ.typcategory,
    _typ.typispreferred,
    _typ.typisdefined,
    _typ.typdelim,
    _typ.typrelid,
    _typ.typelem,
    _typ.typarray,
    _typ.typinput,
    _typ.typoutput,
    _typ.typreceive,
    _typ.typsend,
    _typ.typmodin,
    _typ.typmodout,
    _typ.typanalyze,
    _typ.typalign,
    _typ.typstorage,
    _typ.typnotnull,
    _typ.typbasetype,
    _typ.typtypmod,
    _typ.typndims,
    _typ.typflags,
    _typ.typcollation,
    _typ.typdefaultbin,
    _typ.typdefault,
    _typ.typacl
   FROM _typ;


ALTER VIEW sys_catalog.sys_type OWNER TO system;

--
-- Name: sys_user; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_user AS
 SELECT pg_user.usename,
    pg_user.usesysid,
    pg_user.usecreatedb,
    pg_user.usesuper,
    pg_user.userepl,
    pg_user.usebypassrls,
    pg_user.passwd,
    pg_user.valuntil,
    pg_user.useconfig
   FROM pg_user;


ALTER VIEW sys_catalog.sys_user OWNER TO system;

--
-- Name: sys_user_mapping; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_user_mapping AS
 SELECT _usrmapping.oid,
    _usrmapping.umuser,
    _usrmapping.umserver,
    _usrmapping.umoptions
   FROM _usrmapping;


ALTER VIEW sys_catalog.sys_user_mapping OWNER TO system;

--
-- Name: sys_user_mappings; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_user_mappings AS
 SELECT pg_user_mappings.umid,
    pg_user_mappings.srvid,
    pg_user_mappings.srvname,
    pg_user_mappings.umuser,
    pg_user_mappings.usename,
    pg_user_mappings.umoptions
   FROM pg_user_mappings;


ALTER VIEW sys_catalog.sys_user_mappings OWNER TO system;

--
-- Name: sys_usergroup; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_usergroup AS
 SELECT a.groname AS group_name,
    a.grosysid AS group_oid,
    a.grolist AS group_members
   FROM pg_group a
  WHERE (a.grosysid IN ( SELECT _priv.userid
           FROM _priv
          WHERE (_priv.objtype = 'g'::"char")));


ALTER VIEW sys_catalog.sys_usergroup OWNER TO system;

--
-- Name: sys_users; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_users AS
 SELECT pg_user.usename,
    pg_user.usesysid,
    pg_user.usecreatedb,
    pg_user.usesuper,
    pg_user.userepl,
    pg_user.usebypassrls,
    pg_user.passwd,
    pg_user.valuntil,
    pg_user.useconfig
   FROM pg_user
  WHERE ((CURRENT_USER IN ( SELECT pg_user_1.usename
           FROM pg_user pg_user_1
          WHERE (pg_user_1.usesuper = true))) OR (CURRENT_USER = pg_user.usename));


ALTER VIEW sys_catalog.sys_users OWNER TO system;

--
-- Name: sys_views; Type: VIEW; Schema: sys_catalog; Owner: system
--

CREATE VIEW sys_catalog.sys_views AS
 SELECT n.nspname AS schemaname,
    c.relname AS viewname,
    pg_get_userbyid(c.relowner) AS viewowner,
    pg_get_viewdef(c.oid) AS definition,
    pg_relation_is_updatable((c.oid)::regclass, true) AS isupdatable
   FROM (_rel c
     LEFT JOIN _nsp n ON ((n.oid = c.relnamespace)))
  WHERE (c.relkind = 'v'::"char");


ALTER VIEW sys_catalog.sys_views OWNER TO system;

--
-- Data for Name: dual; Type: TABLE DATA; Schema: public; Owner: system
--

COPY public.dual (dummy) FROM stdin;
X
\.


--
-- Data for Name: tb_course; Type: TABLE DATA; Schema: public; Owner: system
--

COPY public.tb_course (course_id, course_no, course_name, course_type, credit, period, dept_id, tea_id, term, capacity, selected_num, course_desc, status) FROM stdin;
2	C002	Operating Systems	Required	3.0	48	1	2	2024-2025-1	45	0	OS principles	1
3	C003	Python Programming	Elective	2.0	32	1	1	2024-2025-1	60	0	Python development cases	1
4	C004	Data Mining & Visualization	Elective	3.0	48	1	3	2024-2025-1	60	0	Data science toolkit for DS/SE 专业	1
5	C005	Network Security Practices	Required	3.0	48	1	2	2024-2025-1	50	0	Hands-on labs for IS 专业	1
6	C006	Digital Signal Processing	Required	3.0	48	2	4	2024-2025-1	45	0	DSP for Communication Engineering 专业	1
7	C007	Wireless Communication Fundamentals	Elective	2.0	32	2	4	2024-2025-1	40	0	Link budget & RF basics	1
8	C008	FinTech Engineering	Required	3.0	48	3	5	2024-2025-1	55	0	Financial technology for FIN 专业	1
9	C009	Quantitative Risk Management	Elective	2.0	32	3	5	2024-2025-1	45	0	Risk modeling with cases	1
1	C001	Database Systems	Required	3.0	48	1	1	2024-2025-1	50	1	DB fundamentals and practice	1
\.


--
-- Data for Name: tb_department; Type: TABLE DATA; Schema: public; Owner: system
--

COPY public.tb_department (dept_id, dept_code, dept_name, status) FROM stdin;
1	CS	Computer Science	1
2	EE	Electronics & Information	1
3	BUS	Business & Finance	1
\.


--
-- Data for Name: tb_major; Type: TABLE DATA; Schema: public; Owner: system
--

COPY public.tb_major (major_id, major_code, major_name, dept_id, status) FROM stdin;
1	SE	Software Engineering	1	1
2	IS	Information Security	1	1
3	DS	Data Science	1	1
4	CE	Communication Engineering	2	1
5	FIN	Financial Technology	3	1
\.


--
-- Data for Name: tb_student; Type: TABLE DATA; Schema: public; Owner: system
--

COPY public.tb_student (stu_id, stu_no, stu_name, gender, birthday, dept_id, major_id, grade, mobile, email, user_id, status) FROM stdin;
1	2024001	Student A	M	\N	1	1	2024	18800000003	student1@example.com	7	1
2	2024002	Student B	F	\N	1	1	2024	18800000004	student2@example.com	8	1
3	2024003	Student C	M	\N	1	2	2024	18800000005	student3@example.com	9	1
4	2024004	Student D	F	\N	1	2	2023	18800000009	student4@example.com	10	1
5	2024005	Student E	M	\N	1	3	2023	18800000010	student5@example.com	11	1
6	2024006	Student F	F	\N	1	3	2022	18800000011	student6@example.com	12	1
7	2024101	Student G	M	\N	2	4	2024	18800000012	student7@example.com	13	1
8	2024102	Student H	F	\N	2	4	2024	18800000013	student8@example.com	14	1
9	2024201	Student I	M	\N	3	5	2023	18800000014	student9@example.com	15	1
10	2024202	Student J	F	\N	3	5	2023	18800000015	student10@example.com	16	1
\.


--
-- Data for Name: tb_student_course; Type: TABLE DATA; Schema: public; Owner: system
--

COPY public.tb_student_course (sc_id, stu_id, course_id, term, select_time, drop_time, status, grade) FROM stdin;
1	1	1	2024-2025-1	2025-12-11 15:13:40.481649	\N	1	\N
\.


--
-- Data for Name: tb_sys_param; Type: TABLE DATA; Schema: public; Owner: system
--

COPY public.tb_sys_param (param_key, param_value, param_value_ts, remark) FROM stdin;
SELECT_START_TIME	\N	2024-01-01 00:00:00	选课开始时间
SELECT_END_TIME	\N	2030-12-31 23:59:59	选课结束时间
DROP_END_TIME	\N	2030-12-31 23:59:59	退课截止时间
CURRENT_TERM	2024-2025-1	\N	当前学期
\.


--
-- Data for Name: tb_teacher; Type: TABLE DATA; Schema: public; Owner: system
--

COPY public.tb_teacher (tea_id, tea_no, tea_name, gender, title, dept_id, mobile, email, user_id, status) FROM stdin;
1	T1001	Teacher Zhang	M	Associate Professor	1	18800000001	teacher1@example.com	2	1
2	T1002	Teacher Li	F	Lecturer	1	18800000002	teacher2@example.com	3	1
3	T1003	Teacher Wang	M	Professor	1	18800000006	teacher3@example.com	4	1
4	T2001	Teacher Sun	F	Associate Professor	2	18800000007	teacher4@example.com	5	1
5	T3001	Teacher Zhao	M	Associate Professor	3	18800000008	teacher5@example.com	6	1
\.


--
-- Data for Name: tb_user; Type: TABLE DATA; Schema: public; Owner: system
--

COPY public.tb_user (user_id, username, password_hash, password_updated_at, real_name, role, status, email, mobile, create_time) FROM stdin;
1	admin	0192023a7bbd73250516f069df18b500	2025-12-11 15:13:40.481649	Admin	ADMIN	1	admin@example.com	18800000000	2025-12-11 15:13:40.481649
2	t001	a426dcf72ba25d046591f81a5495eab7	2025-12-11 15:13:40.481649	Teacher Zhang	TEACHER	1	teacher1@example.com	18800000001	2025-12-11 15:13:40.481649
3	t002	a426dcf72ba25d046591f81a5495eab7	2025-12-11 15:13:40.481649	Teacher Li	TEACHER	1	teacher2@example.com	18800000002	2025-12-11 15:13:40.481649
4	t003	a426dcf72ba25d046591f81a5495eab7	2025-12-11 15:13:40.481649	Teacher Wang	TEACHER	1	teacher3@example.com	18800000006	2025-12-11 15:13:40.481649
5	t004	a426dcf72ba25d046591f81a5495eab7	2025-12-11 15:13:40.481649	Teacher Sun	TEACHER	1	teacher4@example.com	18800000007	2025-12-11 15:13:40.481649
6	t005	a426dcf72ba25d046591f81a5495eab7	2025-12-11 15:13:40.481649	Teacher Zhao	TEACHER	1	teacher5@example.com	18800000008	2025-12-11 15:13:40.481649
7	s001	ad6a280417a0f533d8b670c61667e1a0	2025-12-11 15:13:40.481649	Student A	STUDENT	1	student1@example.com	18800000003	2025-12-11 15:13:40.481649
8	s002	ad6a280417a0f533d8b670c61667e1a0	2025-12-11 15:13:40.481649	Student B	STUDENT	1	student2@example.com	18800000004	2025-12-11 15:13:40.481649
9	s003	ad6a280417a0f533d8b670c61667e1a0	2025-12-11 15:13:40.481649	Student C	STUDENT	1	student3@example.com	18800000005	2025-12-11 15:13:40.481649
10	s004	ad6a280417a0f533d8b670c61667e1a0	2025-12-11 15:13:40.481649	Student D	STUDENT	1	student4@example.com	18800000009	2025-12-11 15:13:40.481649
11	s005	ad6a280417a0f533d8b670c61667e1a0	2025-12-11 15:13:40.481649	Student E	STUDENT	1	student5@example.com	18800000010	2025-12-11 15:13:40.481649
12	s006	ad6a280417a0f533d8b670c61667e1a0	2025-12-11 15:13:40.481649	Student F	STUDENT	1	student6@example.com	18800000011	2025-12-11 15:13:40.481649
13	s007	ad6a280417a0f533d8b670c61667e1a0	2025-12-11 15:13:40.481649	Student G	STUDENT	1	student7@example.com	18800000012	2025-12-11 15:13:40.481649
14	s008	ad6a280417a0f533d8b670c61667e1a0	2025-12-11 15:13:40.481649	Student H	STUDENT	1	student8@example.com	18800000013	2025-12-11 15:13:40.481649
15	s009	ad6a280417a0f533d8b670c61667e1a0	2025-12-11 15:13:40.481649	Student I	STUDENT	1	student9@example.com	18800000014	2025-12-11 15:13:40.481649
16	s010	ad6a280417a0f533d8b670c61667e1a0	2025-12-11 15:13:40.481649	Student J	STUDENT	1	student10@example.com	18800000015	2025-12-11 15:13:40.481649
\.


--
-- Data for Name: tb_waitlist; Type: TABLE DATA; Schema: public; Owner: system
--

COPY public.tb_waitlist (wl_id, stu_id, course_id, term, status, message, created_at, processed_at) FROM stdin;
\.


--
-- Data for Name: variables; Type: TABLE DATA; Schema: session_variable; Owner: system
--

COPY session_variable.variables (variable_name, created_timestamp, created_by, last_updated_timestamp, last_updated_by, is_constant, variable_type_namespace, variable_type_name, initial_value) FROM stdin;
\.


--
-- Name: tb_course_course_id_seq; Type: SEQUENCE SET; Schema: public; Owner: system
--

SELECT pg_catalog.setval('public.tb_course_course_id_seq', 9, true);


--
-- Name: tb_department_dept_id_seq; Type: SEQUENCE SET; Schema: public; Owner: system
--

SELECT pg_catalog.setval('public.tb_department_dept_id_seq', 3, true);


--
-- Name: tb_major_major_id_seq; Type: SEQUENCE SET; Schema: public; Owner: system
--

SELECT pg_catalog.setval('public.tb_major_major_id_seq', 5, true);


--
-- Name: tb_student_course_sc_id_seq; Type: SEQUENCE SET; Schema: public; Owner: system
--

SELECT pg_catalog.setval('public.tb_student_course_sc_id_seq', 1, true);


--
-- Name: tb_student_stu_id_seq; Type: SEQUENCE SET; Schema: public; Owner: system
--

SELECT pg_catalog.setval('public.tb_student_stu_id_seq', 10, true);


--
-- Name: tb_teacher_tea_id_seq; Type: SEQUENCE SET; Schema: public; Owner: system
--

SELECT pg_catalog.setval('public.tb_teacher_tea_id_seq', 5, true);


--
-- Name: tb_user_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: system
--

SELECT pg_catalog.setval('public.tb_user_user_id_seq', 16, true);


--
-- Name: tb_waitlist_wl_id_seq; Type: SEQUENCE SET; Schema: public; Owner: system
--

SELECT pg_catalog.setval('public.tb_waitlist_wl_id_seq', 1, false);


--
-- Name: global_chain_seq; Type: SEQUENCE SET; Schema: sys_catalog; Owner: system
--

SELECT pg_catalog.setval('sys_catalog.global_chain_seq', 1, false);


--
-- Name: tb_course tb_course_pkey; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_course
    ADD CONSTRAINT tb_course_pkey PRIMARY KEY (course_id);


--
-- Name: tb_department tb_department_pkey; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_department
    ADD CONSTRAINT tb_department_pkey PRIMARY KEY (dept_id);


--
-- Name: tb_major tb_major_pkey; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_major
    ADD CONSTRAINT tb_major_pkey PRIMARY KEY (major_id);


--
-- Name: tb_student_course tb_student_course_pkey; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_student_course
    ADD CONSTRAINT tb_student_course_pkey PRIMARY KEY (sc_id);


--
-- Name: tb_student tb_student_pkey; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_student
    ADD CONSTRAINT tb_student_pkey PRIMARY KEY (stu_id);


--
-- Name: tb_sys_param tb_sys_param_pkey; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_sys_param
    ADD CONSTRAINT tb_sys_param_pkey PRIMARY KEY (param_key);


--
-- Name: tb_teacher tb_teacher_pkey; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_teacher
    ADD CONSTRAINT tb_teacher_pkey PRIMARY KEY (tea_id);


--
-- Name: tb_user tb_user_pkey; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_user
    ADD CONSTRAINT tb_user_pkey PRIMARY KEY (user_id);


--
-- Name: tb_waitlist tb_waitlist_pkey; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_waitlist
    ADD CONSTRAINT tb_waitlist_pkey PRIMARY KEY (wl_id);


--
-- Name: tb_course uq_course_no_term; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_course
    ADD CONSTRAINT uq_course_no_term UNIQUE (course_no, term);


--
-- Name: tb_department uq_dept_code; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_department
    ADD CONSTRAINT uq_dept_code UNIQUE (dept_code);


--
-- Name: tb_major uq_major_code; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_major
    ADD CONSTRAINT uq_major_code UNIQUE (major_code);


--
-- Name: tb_student_course uq_sc; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_student_course
    ADD CONSTRAINT uq_sc UNIQUE (stu_id, course_id, term);


--
-- Name: tb_student uq_student_no; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_student
    ADD CONSTRAINT uq_student_no UNIQUE (stu_no);


--
-- Name: tb_student uq_student_user; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_student
    ADD CONSTRAINT uq_student_user UNIQUE (user_id);


--
-- Name: tb_teacher uq_teacher_no; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_teacher
    ADD CONSTRAINT uq_teacher_no UNIQUE (tea_no);


--
-- Name: tb_teacher uq_teacher_user; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_teacher
    ADD CONSTRAINT uq_teacher_user UNIQUE (user_id);


--
-- Name: tb_user uq_user_username; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_user
    ADD CONSTRAINT uq_user_username UNIQUE (username);


--
-- Name: tb_waitlist uq_wl; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_waitlist
    ADD CONSTRAINT uq_wl UNIQUE (stu_id, course_id, term);


--
-- Name: idx_course_name; Type: INDEX; Schema: public; Owner: system
--

CREATE INDEX idx_course_name ON public.tb_course USING btree (course_name);


--
-- Name: idx_course_no; Type: INDEX; Schema: public; Owner: system
--

CREATE INDEX idx_course_no ON public.tb_course USING btree (course_no);


--
-- Name: idx_course_term; Type: INDEX; Schema: public; Owner: system
--

CREATE INDEX idx_course_term ON public.tb_course USING btree (term);


--
-- Name: idx_sc_course; Type: INDEX; Schema: public; Owner: system
--

CREATE INDEX idx_sc_course ON public.tb_student_course USING btree (course_id);


--
-- Name: idx_sc_stu; Type: INDEX; Schema: public; Owner: system
--

CREATE INDEX idx_sc_stu ON public.tb_student_course USING btree (stu_id);


--
-- Name: idx_sc_term; Type: INDEX; Schema: public; Owner: system
--

CREATE INDEX idx_sc_term ON public.tb_student_course USING btree (term);


--
-- Name: idx_student_name; Type: INDEX; Schema: public; Owner: system
--

CREATE INDEX idx_student_name ON public.tb_student USING btree (stu_name);


--
-- Name: idx_student_no; Type: INDEX; Schema: public; Owner: system
--

CREATE INDEX idx_student_no ON public.tb_student USING btree (stu_no);


--
-- Name: idx_teacher_name; Type: INDEX; Schema: public; Owner: system
--

CREATE INDEX idx_teacher_name ON public.tb_teacher USING btree (tea_name);


--
-- Name: idx_teacher_no; Type: INDEX; Schema: public; Owner: system
--

CREATE INDEX idx_teacher_no ON public.tb_teacher USING btree (tea_no);


--
-- Name: idx_wl_status; Type: INDEX; Schema: public; Owner: system
--

CREATE INDEX idx_wl_status ON public.tb_waitlist USING btree (status, course_id, term);


--
-- Name: idx_wl_stu; Type: INDEX; Schema: public; Owner: system
--

CREATE INDEX idx_wl_stu ON public.tb_waitlist USING btree (stu_id, term);


--
-- Name: tb_student_course trg_sc_dec_course_num; Type: TRIGGER; Schema: public; Owner: system
--

CREATE TRIGGER trg_sc_dec_course_num AFTER UPDATE ON public.tb_student_course FOR EACH ROW EXECUTE FUNCTION public.fn_sc_dec_course_num();


--
-- Name: tb_student_course trg_sc_del_course_num; Type: TRIGGER; Schema: public; Owner: system
--

CREATE TRIGGER trg_sc_del_course_num BEFORE DELETE ON public.tb_student_course FOR EACH ROW EXECUTE FUNCTION public.fn_sc_del_course_num();


--
-- Name: tb_student_course trg_sc_grade_check; Type: TRIGGER; Schema: public; Owner: system
--

CREATE TRIGGER trg_sc_grade_check BEFORE INSERT OR UPDATE ON public.tb_student_course FOR EACH ROW EXECUTE FUNCTION public.fn_sc_grade_check();


--
-- Name: tb_student_course trg_sc_inc_course_num; Type: TRIGGER; Schema: public; Owner: system
--

CREATE TRIGGER trg_sc_inc_course_num AFTER INSERT ON public.tb_student_course FOR EACH ROW EXECUTE FUNCTION public.fn_sc_inc_course_num();


--
-- Name: tb_course fk_course_dept; Type: FK CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_course
    ADD CONSTRAINT fk_course_dept FOREIGN KEY (dept_id) REFERENCES public.tb_department(dept_id);


--
-- Name: tb_course fk_course_tea; Type: FK CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_course
    ADD CONSTRAINT fk_course_tea FOREIGN KEY (tea_id) REFERENCES public.tb_teacher(tea_id);


--
-- Name: tb_major fk_major_dept; Type: FK CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_major
    ADD CONSTRAINT fk_major_dept FOREIGN KEY (dept_id) REFERENCES public.tb_department(dept_id);


--
-- Name: tb_student_course fk_sc_course; Type: FK CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_student_course
    ADD CONSTRAINT fk_sc_course FOREIGN KEY (course_id) REFERENCES public.tb_course(course_id);


--
-- Name: tb_student_course fk_sc_student; Type: FK CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_student_course
    ADD CONSTRAINT fk_sc_student FOREIGN KEY (stu_id) REFERENCES public.tb_student(stu_id);


--
-- Name: tb_student fk_student_dept; Type: FK CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_student
    ADD CONSTRAINT fk_student_dept FOREIGN KEY (dept_id) REFERENCES public.tb_department(dept_id);


--
-- Name: tb_student fk_student_major; Type: FK CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_student
    ADD CONSTRAINT fk_student_major FOREIGN KEY (major_id) REFERENCES public.tb_major(major_id);


--
-- Name: tb_student fk_student_user; Type: FK CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_student
    ADD CONSTRAINT fk_student_user FOREIGN KEY (user_id) REFERENCES public.tb_user(user_id);


--
-- Name: tb_teacher fk_teacher_dept; Type: FK CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_teacher
    ADD CONSTRAINT fk_teacher_dept FOREIGN KEY (dept_id) REFERENCES public.tb_department(dept_id);


--
-- Name: tb_teacher fk_teacher_user; Type: FK CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_teacher
    ADD CONSTRAINT fk_teacher_user FOREIGN KEY (user_id) REFERENCES public.tb_user(user_id);


--
-- Name: tb_waitlist fk_wl_course; Type: FK CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_waitlist
    ADD CONSTRAINT fk_wl_course FOREIGN KEY (course_id) REFERENCES public.tb_course(course_id);


--
-- Name: tb_waitlist fk_wl_student; Type: FK CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public.tb_waitlist
    ADD CONSTRAINT fk_wl_student FOREIGN KEY (stu_id) REFERENCES public.tb_student(stu_id);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: system
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: perf; Owner: system
--

ALTER DEFAULT PRIVILEGES FOR ROLE system IN SCHEMA perf GRANT ALL ON SEQUENCES TO sys_read_all_stats;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: perf; Owner: system
--

ALTER DEFAULT PRIVILEGES FOR ROLE system IN SCHEMA perf GRANT ALL ON FUNCTIONS TO sys_read_all_stats;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: perf; Owner: system
--

ALTER DEFAULT PRIVILEGES FOR ROLE system IN SCHEMA perf GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO sys_read_all_stats;


--
-- PostgreSQL database dump complete
--

\unrestrict AikpdwqMkQQhSPkua7Swysds6K1LIkDcAvcEAAwSH3f0gsIqEchPjGpk1627sMK

