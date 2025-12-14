--
-- Kingbase database dump
--

-- Dumped from database version 12.1
-- Dumped by sys_dump version 12.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', 'public', false);
SET exclude_reserved_words = '';
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;
SET default_with_oids = off;
SET default_with_rowid = off;

--
-- Name: http; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA public CASCADE;


--
-- Name: EXTENSION http; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION http IS 'HTTP client for KingbaseES,allows access to the web server';


--
-- Name: wmsys; Type: SCHEMA; Schema: -; Owner: system
--

CREATE SCHEMA IF NOT EXISTS wmsys;


ALTER SCHEMA wmsys OWNER TO system;

--
-- Name: plsql_check; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plsql_check WITH SCHEMA public CASCADE;


--
-- Name: EXTENSION plsql_check; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plsql_check IS 'extended check for plsql functions';


--
-- Name: FN_DROP_COURSE(integer, integer, varchar); Type: FUNCTION; Schema: public; Owner: system
--

\set SQLTERM /
CREATE FUNCTION public."FN_DROP_COURSE"(p_stu_id integer, p_course_id integer, p_term varchar) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql
    AS $KES_$
DECLARE v_success BOOLEAN; v_msg TEXT;
BEGIN
    CALL PROC_DROP_COURSE(p_stu_id, p_course_id, p_term, v_success, v_msg);
    RETURN QUERY SELECT v_success, v_msg;
END;
$KES_$;

/
\set SQLTERM ;


ALTER FUNCTION public."FN_DROP_COURSE"(p_stu_id integer, p_course_id integer, p_term varchar) OWNER TO system;

--
-- Name: FN_HASH_PASSWORD(text); Type: FUNCTION; Schema: public; Owner: system
--

\set SQLTERM /
CREATE FUNCTION public."FN_HASH_PASSWORD"(p_plain_password text) RETURNS text
    LANGUAGE plpgsql
    AS $KES_$
DECLARE
    v_salt TEXT := substr(md5(random()::text || clock_timestamp()::text), 1, 16);
BEGIN
    IF p_plain_password IS NULL OR LENGTH(TRIM(p_plain_password)) = 0 THEN
        RETURN NULL;
    END IF;
    RETURN v_salt || ':' || md5(v_salt || '|' || TRIM(p_plain_password));
END;
$KES_$;

/
\set SQLTERM ;


ALTER FUNCTION public."FN_HASH_PASSWORD"(p_plain_password text) OWNER TO system;

--
-- Name: FN_LOGIN(text, text); Type: FUNCTION; Schema: public; Owner: system
--

\set SQLTERM /
CREATE FUNCTION public."FN_LOGIN"(p_username text, p_plain_password text) RETURNS TABLE(USER_ID integer, USERNAME varchar, ROLE varchar, STATUS bpchar, STU_ID integer, TEA_ID integer)
    LANGUAGE plpgsql
    AS $KES_$
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
$KES_$;

/
\set SQLTERM ;


ALTER FUNCTION public."FN_LOGIN"(p_username text, p_plain_password text) OWNER TO system;

--
-- Name: FN_SC_DEC_COURSE_NUM(); Type: FUNCTION; Schema: public; Owner: system
--

\set SQLTERM /
CREATE FUNCTION public."FN_SC_DEC_COURSE_NUM"() RETURNS trigger
    LANGUAGE plpgsql
    AS $KES_$
DECLARE
    v_capacity INT;
    v_selected INT;
BEGIN
    IF OLD.STATUS = '1' AND NEW.STATUS = '0' THEN
        UPDATE TB_COURSE
        SET SELECTED_NUM = GREATEST(SELECTED_NUM - 1, 0)
        WHERE COURSE_ID = NEW.COURSE_ID;
    ELSIF OLD.STATUS = '0' AND NEW.STATUS = '1' THEN
        -- 允许从退课恢复到选课,保持人数一致
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
$KES_$;

/
\set SQLTERM ;


ALTER FUNCTION public."FN_SC_DEC_COURSE_NUM"() OWNER TO system;

--
-- Name: FN_SC_DEL_COURSE_NUM(); Type: FUNCTION; Schema: public; Owner: system
--

\set SQLTERM /
CREATE FUNCTION public."FN_SC_DEL_COURSE_NUM"() RETURNS trigger
    LANGUAGE plpgsql
    AS $KES_$
BEGIN
    IF OLD.STATUS = '1' THEN
        UPDATE TB_COURSE
        SET SELECTED_NUM = GREATEST(SELECTED_NUM - 1, 0)
        WHERE COURSE_ID = OLD.COURSE_ID;
    END IF;
    RETURN OLD;
END;
$KES_$;

/
\set SQLTERM ;


ALTER FUNCTION public."FN_SC_DEL_COURSE_NUM"() OWNER TO system;

--
-- Name: FN_SC_GRADE_CHECK(); Type: FUNCTION; Schema: public; Owner: system
--

\set SQLTERM /
CREATE FUNCTION public."FN_SC_GRADE_CHECK"() RETURNS trigger
    LANGUAGE plpgsql
    AS $KES_$
BEGIN
    IF NEW.GRADE IS NOT NULL AND (NEW.GRADE < 0 OR NEW.GRADE > 100) THEN
        RAISE EXCEPTION '成绩必须在0到100之间';
    END IF;
    RETURN NEW;
END;
$KES_$;

/
\set SQLTERM ;


ALTER FUNCTION public."FN_SC_GRADE_CHECK"() OWNER TO system;

--
-- Name: FN_SC_INC_COURSE_NUM(); Type: FUNCTION; Schema: public; Owner: system
--

\set SQLTERM /
CREATE FUNCTION public."FN_SC_INC_COURSE_NUM"() RETURNS trigger
    LANGUAGE plpgsql
    AS $KES_$
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
$KES_$;

/
\set SQLTERM ;


ALTER FUNCTION public."FN_SC_INC_COURSE_NUM"() OWNER TO system;

--
-- Name: FN_SELECT_COURSE(integer, integer, varchar); Type: FUNCTION; Schema: public; Owner: system
--

\set SQLTERM /
CREATE FUNCTION public."FN_SELECT_COURSE"(p_stu_id integer, p_course_id integer, p_term varchar) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql
    AS $KES_$
DECLARE v_success BOOLEAN; v_msg TEXT;
BEGIN
    CALL PROC_SELECT_COURSE(p_stu_id, p_course_id, p_term, v_success, v_msg);
    RETURN QUERY SELECT v_success, v_msg;
END;
$KES_$;

/
\set SQLTERM ;


ALTER FUNCTION public."FN_SELECT_COURSE"(p_stu_id integer, p_course_id integer, p_term varchar) OWNER TO system;

--
-- Name: FN_VERIFY_PASSWORD(text, text); Type: FUNCTION; Schema: public; Owner: system
--

\set SQLTERM /
CREATE FUNCTION public."FN_VERIFY_PASSWORD"(p_username text, p_plain_password text) RETURNS boolean
    LANGUAGE plpgsql
    AS $KES_$
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
$KES_$;

/
\set SQLTERM ;


ALTER FUNCTION public."FN_VERIFY_PASSWORD"(p_username text, p_plain_password text) OWNER TO system;

--
-- Name: PROC_DROP_COURSE(integer, integer, varchar, boolean, text); Type: PROCEDURE; Schema: public; Owner: system
--

\set SQLTERM /
CREATE PROCEDURE public."PROC_DROP_COURSE"(p_stu_id integer, p_course_id integer, p_term varchar, p_success INOUT boolean, p_message INOUT text)
    LANGUAGE plpgsql
    AS $KES_$
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
EXCEPTION WHEN OTHERS THEN
    p_success := FALSE;
    p_message := COALESCE(SQLERRM, 'drop failed');
END;
$KES_$;

/
\set SQLTERM ;


ALTER PROCEDURE public."PROC_DROP_COURSE"(p_stu_id integer, p_course_id integer, p_term varchar, p_success INOUT boolean, p_message INOUT text) OWNER TO system;

--
-- Name: PROC_SELECT_COURSE(integer, integer, varchar, boolean, text); Type: PROCEDURE; Schema: public; Owner: system
--

\set SQLTERM /
CREATE PROCEDURE public."PROC_SELECT_COURSE"(p_stu_id integer, p_course_id integer, p_term varchar, p_success INOUT boolean, p_message INOUT text)
    LANGUAGE plpgsql
    AS $KES_$
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
            p_message := 'course already selected';
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
$KES_$;

/
\set SQLTERM ;


ALTER PROCEDURE public."PROC_SELECT_COURSE"(p_stu_id integer, p_course_id integer, p_term varchar, p_success INOUT boolean, p_message INOUT text) OWNER TO system;

--
-- Name: PROC_SET_PASSWORD(integer, text, boolean, text); Type: PROCEDURE; Schema: public; Owner: system
--

\set SQLTERM /
CREATE PROCEDURE public."PROC_SET_PASSWORD"(p_user_id integer, p_plain_password text, p_success INOUT boolean, p_message INOUT text)
    LANGUAGE plpgsql
    AS $KES_$
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
$KES_$;

/
\set SQLTERM ;


ALTER PROCEDURE public."PROC_SET_PASSWORD"(p_user_id integer, p_plain_password text, p_success INOUT boolean, p_message INOUT text) OWNER TO system;

--
-- Name: PROC_STAT_COURSE_SELECT(varchar); Type: FUNCTION; Schema: public; Owner: system
--

\set SQLTERM /
CREATE FUNCTION public."PROC_STAT_COURSE_SELECT"(p_term varchar) RETURNS TABLE(COURSE_NO varchar, COURSE_NAME varchar, TEACHER_NAME varchar, CAPACITY integer, SELECTED_NUM integer, REMAINING integer)
    LANGUAGE plpgsql
    AS $KES_$
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
$KES_$;

/
\set SQLTERM ;


ALTER FUNCTION public."PROC_STAT_COURSE_SELECT"(p_term varchar) OWNER TO system;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: TB_COURSE; Type: TABLE; Schema: public; Owner: system
--

SET escape = off;


CREATE TABLE public."TB_COURSE" (
    "COURSE_ID" integer NOT NULL,
    "COURSE_NO" character varying(20 char) NOT NULL,
    "COURSE_NAME" character varying(100 char) NOT NULL,
    "COURSE_TYPE" character varying(20 char),
    "CREDIT" numeric(4,1),
    "PERIOD" integer,
    "DEPT_ID" integer NOT NULL,
    "TEA_ID" integer NOT NULL,
    "TERM" character varying(20 char) NOT NULL,
    "CAPACITY" integer NOT NULL,
    "SELECTED_NUM" integer DEFAULT 0 NOT NULL,
    "COURSE_DESC" character varying(500 char),
    "STATUS" character(1 char) DEFAULT '1'::bpchar NOT NULL,
    CONSTRAINT "CK_COURSE_CAPACITY" CHECK ((CAPACITY > 0)),
    CONSTRAINT "CK_COURSE_SELECTED" CHECK (((SELECTED_NUM >= 0) AND (SELECTED_NUM <= CAPACITY))),
    CONSTRAINT "CK_COURSE_STATUS" CHECK ((STATUS = ANY (ARRAY['1'::bpchar, '0'::bpchar])))
);


ALTER TABLE public."TB_COURSE" OWNER TO system;

--
-- Name: TB_COURSE_COURSE_ID_seq; Type: SEQUENCE; Schema: public; Owner: system
--

ALTER TABLE public."TB_COURSE" ALTER COLUMN "COURSE_ID" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public."TB_COURSE_COURSE_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: TB_DEPARTMENT; Type: TABLE; Schema: public; Owner: system
--

SET escape = off;


CREATE TABLE public."TB_DEPARTMENT" (
    "DEPT_ID" integer NOT NULL,
    "DEPT_CODE" character varying(20 char) NOT NULL,
    "DEPT_NAME" character varying(100 char) NOT NULL,
    "STATUS" character(1 char) DEFAULT '1'::bpchar NOT NULL,
    CONSTRAINT "CK_DEPT_STATUS" CHECK ((STATUS = ANY (ARRAY['1'::bpchar, '0'::bpchar])))
);


ALTER TABLE public."TB_DEPARTMENT" OWNER TO system;

--
-- Name: TB_DEPARTMENT_DEPT_ID_seq; Type: SEQUENCE; Schema: public; Owner: system
--

ALTER TABLE public."TB_DEPARTMENT" ALTER COLUMN "DEPT_ID" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public."TB_DEPARTMENT_DEPT_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: TB_MAJOR; Type: TABLE; Schema: public; Owner: system
--

SET escape = off;


CREATE TABLE public."TB_MAJOR" (
    "MAJOR_ID" integer NOT NULL,
    "MAJOR_CODE" character varying(20 char) NOT NULL,
    "MAJOR_NAME" character varying(100 char) NOT NULL,
    "DEPT_ID" integer NOT NULL,
    "STATUS" character(1 char) DEFAULT '1'::bpchar NOT NULL,
    CONSTRAINT "CK_MAJOR_STATUS" CHECK ((STATUS = ANY (ARRAY['1'::bpchar, '0'::bpchar])))
);


ALTER TABLE public."TB_MAJOR" OWNER TO system;

--
-- Name: TB_MAJOR_MAJOR_ID_seq; Type: SEQUENCE; Schema: public; Owner: system
--

ALTER TABLE public."TB_MAJOR" ALTER COLUMN "MAJOR_ID" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public."TB_MAJOR_MAJOR_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: TB_STUDENT; Type: TABLE; Schema: public; Owner: system
--

SET escape = off;


CREATE TABLE public."TB_STUDENT" (
    "STU_ID" integer NOT NULL,
    "STU_NO" character varying(20 char) NOT NULL,
    "STU_NAME" character varying(50 char) NOT NULL,
    "GENDER" character(1 char),
    "BIRTHDAY" date,
    "DEPT_ID" integer NOT NULL,
    "MAJOR_ID" integer NOT NULL,
    "GRADE" character varying(10 char),
    "MOBILE" character varying(20 char),
    "EMAIL" character varying(100 char),
    "USER_ID" integer NOT NULL,
    "STATUS" character(1 char) DEFAULT '1'::bpchar NOT NULL,
    CONSTRAINT "CK_STUDENT_GENDER" CHECK ((GENDER = ANY (ARRAY['M'::bpchar, 'F'::bpchar]))),
    CONSTRAINT "CK_STUDENT_STATUS" CHECK ((STATUS = ANY (ARRAY['1'::bpchar, '0'::bpchar])))
);


ALTER TABLE public."TB_STUDENT" OWNER TO system;

--
-- Name: TB_STUDENT_COURSE; Type: TABLE; Schema: public; Owner: system
--

SET escape = off;


CREATE TABLE public."TB_STUDENT_COURSE" (
    "SC_ID" integer NOT NULL,
    "STU_ID" integer NOT NULL,
    "COURSE_ID" integer NOT NULL,
    "TERM" character varying(20 char) NOT NULL,
    "SELECT_TIME" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "DROP_TIME" timestamp without time zone,
    "STATUS" character(1 char) DEFAULT '1'::bpchar NOT NULL,
    "GRADE" numeric(5,2),
    CONSTRAINT "CK_SC_GRADE" CHECK (((GRADE IS NULL) OR ((GRADE >= (0)::numeric) AND (GRADE <= (100)::numeric)))),
    CONSTRAINT "CK_SC_STATUS" CHECK ((STATUS = ANY (ARRAY['1'::bpchar, '0'::bpchar])))
);


ALTER TABLE public."TB_STUDENT_COURSE" OWNER TO system;

--
-- Name: TB_STUDENT_COURSE_SC_ID_seq; Type: SEQUENCE; Schema: public; Owner: system
--

ALTER TABLE public."TB_STUDENT_COURSE" ALTER COLUMN "SC_ID" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public."TB_STUDENT_COURSE_SC_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: TB_STUDENT_STU_ID_seq; Type: SEQUENCE; Schema: public; Owner: system
--

ALTER TABLE public."TB_STUDENT" ALTER COLUMN "STU_ID" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public."TB_STUDENT_STU_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: TB_SYS_PARAM; Type: TABLE; Schema: public; Owner: system
--

SET escape = off;


CREATE TABLE public."TB_SYS_PARAM" (
    "PARAM_KEY" character varying(50 char) NOT NULL,
    "PARAM_VALUE" character varying(200 char),
    "PARAM_VALUE_TS" timestamp without time zone,
    "REMARK" character varying(200 char),
    CONSTRAINT "CK_SYS_PARAM_VALUE" CHECK (((((PARAM_KEY)::text = ANY ((ARRAY['SELECT_START_TIME'::varchar, 'SELECT_END_TIME'::varchar, 'DROP_END_TIME'::varchar])::text[])) AND (PARAM_VALUE_TS IS NOT NULL)) OR (((PARAM_KEY)::text <> ALL ((ARRAY['SELECT_START_TIME'::varchar, 'SELECT_END_TIME'::varchar, 'DROP_END_TIME'::varchar])::text[])) AND (PARAM_VALUE IS NOT NULL))))
);


ALTER TABLE public."TB_SYS_PARAM" OWNER TO system;

--
-- Name: TB_TEACHER; Type: TABLE; Schema: public; Owner: system
--

SET escape = off;


CREATE TABLE public."TB_TEACHER" (
    "TEA_ID" integer NOT NULL,
    "TEA_NO" character varying(20 char) NOT NULL,
    "TEA_NAME" character varying(50 char) NOT NULL,
    "GENDER" character(1 char),
    "TITLE" character varying(50 char),
    "DEPT_ID" integer NOT NULL,
    "MOBILE" character varying(20 char),
    "EMAIL" character varying(100 char),
    "USER_ID" integer NOT NULL,
    "STATUS" character(1 char) DEFAULT '1'::bpchar NOT NULL,
    CONSTRAINT "CK_TEACHER_GENDER" CHECK ((GENDER = ANY (ARRAY['M'::bpchar, 'F'::bpchar]))),
    CONSTRAINT "CK_TEACHER_STATUS" CHECK ((STATUS = ANY (ARRAY['1'::bpchar, '0'::bpchar])))
);


ALTER TABLE public."TB_TEACHER" OWNER TO system;

--
-- Name: TB_TEACHER_TEA_ID_seq; Type: SEQUENCE; Schema: public; Owner: system
--

ALTER TABLE public."TB_TEACHER" ALTER COLUMN "TEA_ID" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public."TB_TEACHER_TEA_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: TB_USER; Type: TABLE; Schema: public; Owner: system
--

SET escape = off;


CREATE TABLE public."TB_USER" (
    "USER_ID" integer NOT NULL,
    "USERNAME" character varying(50 char) NOT NULL,
    "PASSWORD_HASH" text NOT NULL,
    "PASSWORD_UPDATED_AT" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "REAL_NAME" character varying(50 char),
    "ROLE" character varying(20 char) NOT NULL,
    "STATUS" character(1 char) DEFAULT '1'::bpchar NOT NULL,
    "EMAIL" character varying(100 char),
    "MOBILE" character varying(20 char),
    "CREATE_TIME" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT "CK_USER_PASSWORD_HASH" CHECK ((length(PASSWORD_HASH) > 0)),
    CONSTRAINT "CK_USER_ROLE" CHECK (((ROLE)::text = ANY ((ARRAY['ADMIN'::varchar, 'TEACHER'::varchar, 'STUDENT'::varchar])::text[]))),
    CONSTRAINT "CK_USER_STATUS" CHECK ((STATUS = ANY (ARRAY['1'::bpchar, '0'::bpchar])))
);


ALTER TABLE public."TB_USER" OWNER TO system;

--
-- Name: TB_USER_USER_ID_seq; Type: SEQUENCE; Schema: public; Owner: system
--

ALTER TABLE public."TB_USER" ALTER COLUMN "USER_ID" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public."TB_USER_USER_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Data for Name: TB_COURSE; Type: TABLE DATA; Schema: public; Owner: system
--

COPY public."TB_COURSE" ("COURSE_ID", "COURSE_NO", "COURSE_NAME", "COURSE_TYPE", "CREDIT", "PERIOD", "DEPT_ID", "TEA_ID", "TERM", "CAPACITY", "SELECTED_NUM", "COURSE_DESC", "STATUS") FROM stdin;
2	C002	Operating Systems	Required	3.0	48	1	2	2024-2025-1	45	0	OS principles	1
3	C003	Python Programming	Elective	2.0	32	1	1	2024-2025-1	60	0	Python development cases	1
7	C007	Wireless Communication Fundamentals	Elective	2.0	32	2	4	2024-2025-1	40	0	Link budget & RF basics	1
8	C008	FinTech Engineering	Required	3.0	48	3	5	2024-2025-1	55	0	Financial technology for FIN 涓撲笟	1
9	C009	Quantitative Risk Management	Elective	2.0	32	3	5	2024-2025-1	45	0	Risk modeling with cases	1
5	C005	Network Security Practices	Required	3.0	48	1	2	2024-2025-1	50	0	Hands-on labs for IS 涓撲笟	1
4	C004	Data Mining & Visualization	Elective	3.0	48	1	3	2024-2025-1	60	0	Data science toolkit for DS/SE 涓撲笟	1
1	C001	Database Systems	Required	3.0	48	1	1	2024-2025-1	50	0	DB fundamentals and practice	1
6	C006	Digital Signal Processing	Required	3.0	48	2	4	2024-2025-1	45	1	DSP for Communication Engineering 涓撲笟	1
\.


--
-- Data for Name: TB_DEPARTMENT; Type: TABLE DATA; Schema: public; Owner: system
--

COPY public."TB_DEPARTMENT" ("DEPT_ID", "DEPT_CODE", "DEPT_NAME", "STATUS") FROM stdin;
1	CS	Computer Science	1
2	EE	Electronics & Information	1
3	BUS	Business & Finance	1
\.


--
-- Data for Name: TB_MAJOR; Type: TABLE DATA; Schema: public; Owner: system
--

COPY public."TB_MAJOR" ("MAJOR_ID", "MAJOR_CODE", "MAJOR_NAME", "DEPT_ID", "STATUS") FROM stdin;
1	SE	Software Engineering	1	1
2	IS	Information Security	1	1
3	DS	Data Science	1	1
4	CE	Communication Engineering	2	1
5	FIN	Financial Technology	3	1
\.


--
-- Data for Name: TB_STUDENT; Type: TABLE DATA; Schema: public; Owner: system
--

COPY public."TB_STUDENT" ("STU_ID", "STU_NO", "STU_NAME", "GENDER", "BIRTHDAY", "DEPT_ID", "MAJOR_ID", "GRADE", "MOBILE", "EMAIL", "USER_ID", "STATUS") FROM stdin;
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
-- Data for Name: TB_STUDENT_COURSE; Type: TABLE DATA; Schema: public; Owner: system
--

COPY public."TB_STUDENT_COURSE" ("SC_ID", "STU_ID", "COURSE_ID", "TERM", "SELECT_TIME", "DROP_TIME", "STATUS", "GRADE") FROM stdin;
2	1	5	2024-2025-1	2025-12-14 14:58:22.435331	2025-12-14 14:58:23.890345	0	\N
3	1	4	2024-2025-1	2025-12-14 14:58:23.062507	2025-12-14 14:58:24.237167	0	\N
1	1	1	2024-2025-1	2025-12-14 14:42:00.618548	2025-12-14 14:58:24.544628	0	\N
4	1	6	2024-2025-1	2025-12-14 14:58:25.220284	\N	1	\N
\.


--
-- Data for Name: TB_SYS_PARAM; Type: TABLE DATA; Schema: public; Owner: system
--

COPY public."TB_SYS_PARAM" ("PARAM_KEY", "PARAM_VALUE", "PARAM_VALUE_TS", "REMARK") FROM stdin;
SELECT_START_TIME	\N	2024-01-01 00:00:00	閫夎?寮??鏃堕棿
SELECT_END_TIME	\N	2030-12-31 23:59:59	閫夎?缁撴潫鏃堕棿
DROP_END_TIME	\N	2030-12-31 23:59:59	閫??鎴??鏃堕棿
CURRENT_TERM	2024-2025-1	\N	褰撳墠瀛︽湡
\.


--
-- Data for Name: TB_TEACHER; Type: TABLE DATA; Schema: public; Owner: system
--

COPY public."TB_TEACHER" ("TEA_ID", "TEA_NO", "TEA_NAME", "GENDER", "TITLE", "DEPT_ID", "MOBILE", "EMAIL", "USER_ID", "STATUS") FROM stdin;
1	T1001	Teacher Zhang	M	Associate Professor	1	18800000001	teacher1@example.com	2	1
2	T1002	Teacher Li	F	Lecturer	1	18800000002	teacher2@example.com	3	1
3	T1003	Teacher Wang	M	Professor	1	18800000006	teacher3@example.com	4	1
4	T2001	Teacher Sun	F	Associate Professor	2	18800000007	teacher4@example.com	5	1
5	T3001	Teacher Zhao	M	Associate Professor	3	18800000008	teacher5@example.com	6	1
\.


--
-- Data for Name: TB_USER; Type: TABLE DATA; Schema: public; Owner: system
--

COPY public."TB_USER" ("USER_ID", "USERNAME", "PASSWORD_HASH", "PASSWORD_UPDATED_AT", "REAL_NAME", "ROLE", "STATUS", "EMAIL", "MOBILE", "CREATE_TIME") FROM stdin;
1	admin	07049b22da186578:e1985ec7694d21c709f86838e42a675b	2025-12-14 14:42:00.570703	Admin	ADMIN	1	admin@example.com	18800000000	2025-12-14 14:42:00.570703
2	t001	1cc34e5974a514b5:5466709c273de7d64b899818c759a08b	2025-12-14 14:42:00.570703	Teacher Zhang	TEACHER	1	teacher1@example.com	18800000001	2025-12-14 14:42:00.570703
3	t002	332de6285166f0f1:fb1f6d5698f11083c6d8f5a6338e9b99	2025-12-14 14:42:00.570703	Teacher Li	TEACHER	1	teacher2@example.com	18800000002	2025-12-14 14:42:00.570703
4	t003	3fd3569ff345177a:8610a5bd199031e07ef74e373aed2a95	2025-12-14 14:42:00.570703	Teacher Wang	TEACHER	1	teacher3@example.com	18800000006	2025-12-14 14:42:00.570703
5	t004	a76f7ff2b25d0cc6:7ad31d1189ba334c87144d472c9eeee1	2025-12-14 14:42:00.570703	Teacher Sun	TEACHER	1	teacher4@example.com	18800000007	2025-12-14 14:42:00.570703
6	t005	eb022be8805ca820:41b05b6d59c64747268305cebc698d71	2025-12-14 14:42:00.570703	Teacher Zhao	TEACHER	1	teacher5@example.com	18800000008	2025-12-14 14:42:00.570703
7	s001	a76e1c90f268be7a:6b803f809381aa60716e2fecbf2adffc	2025-12-14 14:42:00.570703	Student A	STUDENT	1	student1@example.com	18800000003	2025-12-14 14:42:00.570703
8	s002	a9da9141741691a9:7a9da09bc659847de7dbabc77ecdb052	2025-12-14 14:42:00.570703	Student B	STUDENT	1	student2@example.com	18800000004	2025-12-14 14:42:00.570703
9	s003	4471aff4442001e3:3b454eae89ebeb2a8e529f186e405d85	2025-12-14 14:42:00.570703	Student C	STUDENT	1	student3@example.com	18800000005	2025-12-14 14:42:00.570703
10	s004	2153b77c02c4e5dc:171a655d035821dcfb6791a6dc9c025e	2025-12-14 14:42:00.570703	Student D	STUDENT	1	student4@example.com	18800000009	2025-12-14 14:42:00.570703
11	s005	be1bef9903a988af:9ee653b29b5e9a904d51cf80e271b839	2025-12-14 14:42:00.570703	Student E	STUDENT	1	student5@example.com	18800000010	2025-12-14 14:42:00.570703
12	s006	8bb95b526fd6ff94:1b8a455fb9e68579074bbe9272e0542b	2025-12-14 14:42:00.570703	Student F	STUDENT	1	student6@example.com	18800000011	2025-12-14 14:42:00.570703
13	s007	fcf7a90a0681b488:33bd1154e94f1da5fae6c7c3d6476d25	2025-12-14 14:42:00.570703	Student G	STUDENT	1	student7@example.com	18800000012	2025-12-14 14:42:00.570703
14	s008	13621e313ceed234:ad99a459e3be51504a9bad4e190d9fdd	2025-12-14 14:42:00.570703	Student H	STUDENT	1	student8@example.com	18800000013	2025-12-14 14:42:00.570703
15	s009	95b02748566e5388:6842570f54848a1547ed610d20953a8a	2025-12-14 14:42:00.570703	Student I	STUDENT	1	student9@example.com	18800000014	2025-12-14 14:42:00.570703
16	s010	eb94248762678534:128af5c12f97e43ef49ec309a694fd0e	2025-12-14 14:42:00.570703	Student J	STUDENT	1	student10@example.com	18800000015	2025-12-14 14:42:00.570703
\.


--
-- Name: TB_COURSE_COURSE_ID_seq; Type: SEQUENCE SET; Schema: public; Owner: system
--

SELECT pg_catalog.setval('public."TB_COURSE_COURSE_ID_seq"', 9, true);


--
-- Name: TB_DEPARTMENT_DEPT_ID_seq; Type: SEQUENCE SET; Schema: public; Owner: system
--

SELECT pg_catalog.setval('public."TB_DEPARTMENT_DEPT_ID_seq"', 3, true);


--
-- Name: TB_MAJOR_MAJOR_ID_seq; Type: SEQUENCE SET; Schema: public; Owner: system
--

SELECT pg_catalog.setval('public."TB_MAJOR_MAJOR_ID_seq"', 5, true);


--
-- Name: TB_STUDENT_COURSE_SC_ID_seq; Type: SEQUENCE SET; Schema: public; Owner: system
--

SELECT pg_catalog.setval('public."TB_STUDENT_COURSE_SC_ID_seq"', 4, true);


--
-- Name: TB_STUDENT_STU_ID_seq; Type: SEQUENCE SET; Schema: public; Owner: system
--

SELECT pg_catalog.setval('public."TB_STUDENT_STU_ID_seq"', 10, true);


--
-- Name: TB_TEACHER_TEA_ID_seq; Type: SEQUENCE SET; Schema: public; Owner: system
--

SELECT pg_catalog.setval('public."TB_TEACHER_TEA_ID_seq"', 5, true);


--
-- Name: TB_USER_USER_ID_seq; Type: SEQUENCE SET; Schema: public; Owner: system
--

SELECT pg_catalog.setval('public."TB_USER_USER_ID_seq"', 16, true);


--
-- Name: TB_COURSE TB_COURSE_pkey; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_COURSE"
    ADD CONSTRAINT "TB_COURSE_pkey" PRIMARY KEY ("COURSE_ID");


--
-- Name: TB_DEPARTMENT TB_DEPARTMENT_pkey; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_DEPARTMENT"
    ADD CONSTRAINT "TB_DEPARTMENT_pkey" PRIMARY KEY ("DEPT_ID");


--
-- Name: TB_MAJOR TB_MAJOR_pkey; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_MAJOR"
    ADD CONSTRAINT "TB_MAJOR_pkey" PRIMARY KEY ("MAJOR_ID");


--
-- Name: TB_STUDENT_COURSE TB_STUDENT_COURSE_pkey; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_STUDENT_COURSE"
    ADD CONSTRAINT "TB_STUDENT_COURSE_pkey" PRIMARY KEY ("SC_ID");


--
-- Name: TB_STUDENT TB_STUDENT_pkey; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_STUDENT"
    ADD CONSTRAINT "TB_STUDENT_pkey" PRIMARY KEY ("STU_ID");


--
-- Name: TB_SYS_PARAM TB_SYS_PARAM_pkey; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_SYS_PARAM"
    ADD CONSTRAINT "TB_SYS_PARAM_pkey" PRIMARY KEY ("PARAM_KEY");


--
-- Name: TB_TEACHER TB_TEACHER_pkey; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_TEACHER"
    ADD CONSTRAINT "TB_TEACHER_pkey" PRIMARY KEY ("TEA_ID");


--
-- Name: TB_USER TB_USER_pkey; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_USER"
    ADD CONSTRAINT "TB_USER_pkey" PRIMARY KEY ("USER_ID");


--
-- Name: TB_COURSE UQ_COURSE_NO_TERM; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_COURSE"
    ADD CONSTRAINT "UQ_COURSE_NO_TERM" UNIQUE ("COURSE_NO", "TERM");


--
-- Name: TB_DEPARTMENT UQ_DEPT_CODE; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_DEPARTMENT"
    ADD CONSTRAINT "UQ_DEPT_CODE" UNIQUE ("DEPT_CODE");


--
-- Name: TB_MAJOR UQ_MAJOR_CODE; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_MAJOR"
    ADD CONSTRAINT "UQ_MAJOR_CODE" UNIQUE ("MAJOR_CODE");


--
-- Name: TB_STUDENT_COURSE UQ_SC; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_STUDENT_COURSE"
    ADD CONSTRAINT "UQ_SC" UNIQUE ("STU_ID", "COURSE_ID", "TERM");


--
-- Name: TB_STUDENT UQ_STUDENT_NO; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_STUDENT"
    ADD CONSTRAINT "UQ_STUDENT_NO" UNIQUE ("STU_NO");


--
-- Name: TB_STUDENT UQ_STUDENT_USER; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_STUDENT"
    ADD CONSTRAINT "UQ_STUDENT_USER" UNIQUE ("USER_ID");


--
-- Name: TB_TEACHER UQ_TEACHER_NO; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_TEACHER"
    ADD CONSTRAINT "UQ_TEACHER_NO" UNIQUE ("TEA_NO");


--
-- Name: TB_TEACHER UQ_TEACHER_USER; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_TEACHER"
    ADD CONSTRAINT "UQ_TEACHER_USER" UNIQUE ("USER_ID");


--
-- Name: TB_USER UQ_USER_USERNAME; Type: CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_USER"
    ADD CONSTRAINT "UQ_USER_USERNAME" UNIQUE ("USERNAME");


--
-- Name: IDX_COURSE_NAME; Type: INDEX; Schema: public; Owner: system
--

CREATE INDEX IDX_COURSE_NAME ON public.TB_COURSE USING btree (COURSE_NAME);


--
-- Name: IDX_COURSE_NO; Type: INDEX; Schema: public; Owner: system
--

CREATE INDEX IDX_COURSE_NO ON public.TB_COURSE USING btree (COURSE_NO);


--
-- Name: IDX_COURSE_TERM; Type: INDEX; Schema: public; Owner: system
--

CREATE INDEX IDX_COURSE_TERM ON public.TB_COURSE USING btree (TERM);


--
-- Name: IDX_SC_COURSE; Type: INDEX; Schema: public; Owner: system
--

CREATE INDEX IDX_SC_COURSE ON public.TB_STUDENT_COURSE USING btree (COURSE_ID);


--
-- Name: IDX_SC_STU; Type: INDEX; Schema: public; Owner: system
--

CREATE INDEX IDX_SC_STU ON public.TB_STUDENT_COURSE USING btree (STU_ID);


--
-- Name: IDX_SC_TERM; Type: INDEX; Schema: public; Owner: system
--

CREATE INDEX IDX_SC_TERM ON public.TB_STUDENT_COURSE USING btree (TERM);


--
-- Name: IDX_STUDENT_NAME; Type: INDEX; Schema: public; Owner: system
--

CREATE INDEX IDX_STUDENT_NAME ON public.TB_STUDENT USING btree (STU_NAME);


--
-- Name: IDX_STUDENT_NO; Type: INDEX; Schema: public; Owner: system
--

CREATE INDEX IDX_STUDENT_NO ON public.TB_STUDENT USING btree (STU_NO);


--
-- Name: IDX_TEACHER_NAME; Type: INDEX; Schema: public; Owner: system
--

CREATE INDEX IDX_TEACHER_NAME ON public.TB_TEACHER USING btree (TEA_NAME);


--
-- Name: IDX_TEACHER_NO; Type: INDEX; Schema: public; Owner: system
--

CREATE INDEX IDX_TEACHER_NO ON public.TB_TEACHER USING btree (TEA_NO);


--
-- Name: TB_STUDENT_COURSE TRG_SC_DEC_COURSE_NUM; Type: TRIGGER; Schema: public; Owner: system
--

\set SQLTERM /
CREATE OR REPLACE TRIGGER TRG_SC_DEC_COURSE_NUM AFTER UPDATE ON public.TB_STUDENT_COURSE FOR EACH ROW EXECUTE FUNCTION public.FN_SC_DEC_COURSE_NUM();

/
\set SQLTERM ;


--
-- Name: TB_STUDENT_COURSE TRG_SC_DEL_COURSE_NUM; Type: TRIGGER; Schema: public; Owner: system
--

\set SQLTERM /
CREATE OR REPLACE TRIGGER TRG_SC_DEL_COURSE_NUM BEFORE DELETE ON public.TB_STUDENT_COURSE FOR EACH ROW EXECUTE FUNCTION public.FN_SC_DEL_COURSE_NUM();

/
\set SQLTERM ;


--
-- Name: TB_STUDENT_COURSE TRG_SC_GRADE_CHECK; Type: TRIGGER; Schema: public; Owner: system
--

\set SQLTERM /
CREATE OR REPLACE TRIGGER TRG_SC_GRADE_CHECK BEFORE INSERT OR UPDATE ON public.TB_STUDENT_COURSE FOR EACH ROW EXECUTE FUNCTION public.FN_SC_GRADE_CHECK();

/
\set SQLTERM ;


--
-- Name: TB_STUDENT_COURSE TRG_SC_INC_COURSE_NUM; Type: TRIGGER; Schema: public; Owner: system
--

\set SQLTERM /
CREATE OR REPLACE TRIGGER TRG_SC_INC_COURSE_NUM AFTER INSERT ON public.TB_STUDENT_COURSE FOR EACH ROW EXECUTE FUNCTION public.FN_SC_INC_COURSE_NUM();

/
\set SQLTERM ;


--
-- Name: TB_COURSE FK_COURSE_DEPT; Type: FK CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_COURSE"
    ADD CONSTRAINT "FK_COURSE_DEPT" FOREIGN KEY (DEPT_ID) REFERENCES public.TB_DEPARTMENT(DEPT_ID);


--
-- Name: TB_COURSE FK_COURSE_TEA; Type: FK CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_COURSE"
    ADD CONSTRAINT "FK_COURSE_TEA" FOREIGN KEY (TEA_ID) REFERENCES public.TB_TEACHER(TEA_ID);


--
-- Name: TB_MAJOR FK_MAJOR_DEPT; Type: FK CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_MAJOR"
    ADD CONSTRAINT "FK_MAJOR_DEPT" FOREIGN KEY (DEPT_ID) REFERENCES public.TB_DEPARTMENT(DEPT_ID);


--
-- Name: TB_STUDENT_COURSE FK_SC_COURSE; Type: FK CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_STUDENT_COURSE"
    ADD CONSTRAINT "FK_SC_COURSE" FOREIGN KEY (COURSE_ID) REFERENCES public.TB_COURSE(COURSE_ID);


--
-- Name: TB_STUDENT_COURSE FK_SC_STUDENT; Type: FK CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_STUDENT_COURSE"
    ADD CONSTRAINT "FK_SC_STUDENT" FOREIGN KEY (STU_ID) REFERENCES public.TB_STUDENT(STU_ID);


--
-- Name: TB_STUDENT FK_STUDENT_DEPT; Type: FK CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_STUDENT"
    ADD CONSTRAINT "FK_STUDENT_DEPT" FOREIGN KEY (DEPT_ID) REFERENCES public.TB_DEPARTMENT(DEPT_ID);


--
-- Name: TB_STUDENT FK_STUDENT_MAJOR; Type: FK CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_STUDENT"
    ADD CONSTRAINT "FK_STUDENT_MAJOR" FOREIGN KEY (MAJOR_ID) REFERENCES public.TB_MAJOR(MAJOR_ID);


--
-- Name: TB_STUDENT FK_STUDENT_USER; Type: FK CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_STUDENT"
    ADD CONSTRAINT "FK_STUDENT_USER" FOREIGN KEY (USER_ID) REFERENCES public.TB_USER(USER_ID);


--
-- Name: TB_TEACHER FK_TEACHER_DEPT; Type: FK CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_TEACHER"
    ADD CONSTRAINT "FK_TEACHER_DEPT" FOREIGN KEY (DEPT_ID) REFERENCES public.TB_DEPARTMENT(DEPT_ID);


--
-- Name: TB_TEACHER FK_TEACHER_USER; Type: FK CONSTRAINT; Schema: public; Owner: system
--

ALTER TABLE ONLY public."TB_TEACHER"
    ADD CONSTRAINT "FK_TEACHER_USER" FOREIGN KEY (USER_ID) REFERENCES public.TB_USER(USER_ID);


--
-- Name: SCHEMA sys; Type: ACL; Schema: -; Owner: system
--

GRANT IF EXISTS USAGE ON SCHEMA sys TO PUBLIC;


--
-- Name: SCHEMA sys_catalog; Type: ACL; Schema: -; Owner: system
--

GRANT IF EXISTS USAGE ON SCHEMA sys_catalog TO PUBLIC;


--
-- Name: SCHEMA wmsys; Type: ACL; Schema: -; Owner: system
--

GRANT IF EXISTS ALL ON SCHEMA wmsys TO PUBLIC;


--
-- Name: FUNCTION metric_update_timer(); Type: ACL; Schema: pg_catalog; Owner: system
--

REVOKE ALL ON FUNCTION pg_catalog.metric_update_timer() FROM PUBLIC;


GRANT IF EXISTS ALL ON FUNCTION pg_catalog.metric_update_timer() TO pg_monitor;


--
-- Name: FUNCTION qps(); Type: ACL; Schema: pg_catalog; Owner: system
--

REVOKE ALL ON FUNCTION pg_catalog.qps() FROM PUBLIC;


GRANT IF EXISTS ALL ON FUNCTION pg_catalog.qps() TO pg_monitor;


--
-- Name: FUNCTION tps(); Type: ACL; Schema: pg_catalog; Owner: system
--

REVOKE ALL ON FUNCTION pg_catalog.tps() FROM PUBLIC;


GRANT IF EXISTS ALL ON FUNCTION pg_catalog.tps() TO pg_monitor;


--
-- Name: FUNCTION sys_config(name OUT text, setting OUT text); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_config(name OUT text, setting OUT text) FROM PUBLIC;


--
-- Name: FUNCTION sys_create_restore_point(text); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_create_restore_point(text) FROM PUBLIC;


--
-- Name: FUNCTION sys_current_logfile(); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_current_logfile() FROM PUBLIC;


--
-- Name: FUNCTION sys_current_logfile(text); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_current_logfile(text) FROM PUBLIC;


--
-- Name: FUNCTION sys_hba_file_rules(line_number OUT integer, type OUT text, database OUT text[], user_name OUT text[], address OUT text, netmask OUT text, auth_method OUT text, options OUT text[], error OUT text); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_hba_file_rules(line_number OUT integer, type OUT text, database OUT text[], user_name OUT text[], address OUT text, netmask OUT text, auth_method OUT text, options OUT text[], error OUT text) FROM PUBLIC;


--
-- Name: FUNCTION sys_ls_archive_statusdir(name OUT text, size OUT bigint, modification OUT timestamp with time zone); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_ls_archive_statusdir(name OUT text, size OUT bigint, modification OUT timestamp with time zone) FROM PUBLIC;


GRANT IF EXISTS ALL ON FUNCTION sys_catalog.sys_ls_archive_statusdir(name OUT text, size OUT bigint, modification OUT timestamp with time zone) TO pg_monitor;


--
-- Name: FUNCTION sys_ls_dir(text); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_ls_dir(text) FROM PUBLIC;


--
-- Name: FUNCTION sys_ls_dir(text, boolean, boolean); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_ls_dir(text, boolean, boolean) FROM PUBLIC;


--
-- Name: FUNCTION sys_ls_logdir(name OUT text, size OUT bigint, modification OUT timestamp with time zone); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_ls_logdir(name OUT text, size OUT bigint, modification OUT timestamp with time zone) FROM PUBLIC;


GRANT IF EXISTS ALL ON FUNCTION sys_catalog.sys_ls_logdir(name OUT text, size OUT bigint, modification OUT timestamp with time zone) TO pg_monitor;


--
-- Name: FUNCTION sys_ls_tmpdir(name OUT text, size OUT bigint, modification OUT timestamp with time zone); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_ls_tmpdir(name OUT text, size OUT bigint, modification OUT timestamp with time zone) FROM PUBLIC;


GRANT IF EXISTS ALL ON FUNCTION sys_catalog.sys_ls_tmpdir(name OUT text, size OUT bigint, modification OUT timestamp with time zone) TO pg_monitor;


--
-- Name: FUNCTION sys_ls_tmpdir(tablespace oid, name OUT text, size OUT bigint, modification OUT timestamp with time zone); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_ls_tmpdir(tablespace oid, name OUT text, size OUT bigint, modification OUT timestamp with time zone) FROM PUBLIC;


GRANT IF EXISTS ALL ON FUNCTION sys_catalog.sys_ls_tmpdir(tablespace oid, name OUT text, size OUT bigint, modification OUT timestamp with time zone) TO pg_monitor;


--
-- Name: FUNCTION sys_ls_waldir(name OUT text, size OUT bigint, modification OUT timestamp with time zone); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_ls_waldir(name OUT text, size OUT bigint, modification OUT timestamp with time zone) FROM PUBLIC;


GRANT IF EXISTS ALL ON FUNCTION sys_catalog.sys_ls_waldir(name OUT text, size OUT bigint, modification OUT timestamp with time zone) TO pg_monitor;


--
-- Name: FUNCTION sys_promote(wait boolean, wait_seconds integer); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_promote(wait boolean, wait_seconds integer) FROM PUBLIC;


--
-- Name: FUNCTION sys_read_binary_file(text); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_read_binary_file(text) FROM PUBLIC;


--
-- Name: FUNCTION sys_read_binary_file(text, bigint, bigint); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_read_binary_file(text, bigint, bigint) FROM PUBLIC;


--
-- Name: FUNCTION sys_read_binary_file(text, bigint, bigint, boolean); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_read_binary_file(text, bigint, bigint, boolean) FROM PUBLIC;


--
-- Name: FUNCTION sys_read_file(text); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_read_file(text) FROM PUBLIC;


--
-- Name: FUNCTION sys_read_file(text, bigint, bigint); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_read_file(text, bigint, bigint) FROM PUBLIC;


--
-- Name: FUNCTION sys_read_file(text, bigint, bigint, boolean); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_read_file(text, bigint, bigint, boolean) FROM PUBLIC;


--
-- Name: FUNCTION sys_rotate_logfile(); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_rotate_logfile() FROM PUBLIC;


--
-- Name: FUNCTION sys_show_all_file_settings(sourcefile OUT text, sourceline OUT integer, seqno OUT integer, name OUT text, setting OUT text, applied OUT boolean, error OUT text); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_show_all_file_settings(sourcefile OUT text, sourceline OUT integer, seqno OUT integer, name OUT text, setting OUT text, applied OUT boolean, error OUT text) FROM PUBLIC;


--
-- Name: FUNCTION sys_start_backup(label text, fast boolean, exclusive boolean); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_start_backup(label text, fast boolean, exclusive boolean) FROM PUBLIC;


--
-- Name: FUNCTION sys_stat_file(filename text, size OUT bigint, access OUT timestamp with time zone, modification OUT timestamp with time zone, change OUT timestamp with time zone, creation OUT timestamp with time zone, isdir OUT boolean); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_stat_file(filename text, size OUT bigint, access OUT timestamp with time zone, modification OUT timestamp with time zone, change OUT timestamp with time zone, creation OUT timestamp with time zone, isdir OUT boolean) FROM PUBLIC;


--
-- Name: FUNCTION sys_stat_file(filename text, missing_ok boolean, size OUT bigint, access OUT timestamp with time zone, modification OUT timestamp with time zone, change OUT timestamp with time zone, creation OUT timestamp with time zone, isdir OUT boolean); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_stat_file(filename text, missing_ok boolean, size OUT bigint, access OUT timestamp with time zone, modification OUT timestamp with time zone, change OUT timestamp with time zone, creation OUT timestamp with time zone, isdir OUT boolean) FROM PUBLIC;


--
-- Name: FUNCTION sys_stat_reset(); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_stat_reset() FROM PUBLIC;


--
-- Name: FUNCTION sys_stat_reset_shared(text); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_stat_reset_shared(text) FROM PUBLIC;


--
-- Name: FUNCTION sys_stat_reset_single_function_counters(oid); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_stat_reset_single_function_counters(oid) FROM PUBLIC;


--
-- Name: FUNCTION sys_stat_reset_single_table_counters(oid); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_stat_reset_single_table_counters(oid) FROM PUBLIC;


--
-- Name: FUNCTION sys_stop_backup(); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_stop_backup() FROM PUBLIC;


--
-- Name: FUNCTION sys_stop_backup(exclusive boolean, wait_for_archive boolean, lsn OUT pg_lsn, labelfile OUT text, spcmapfile OUT text); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_stop_backup(exclusive boolean, wait_for_archive boolean, lsn OUT pg_lsn, labelfile OUT text, spcmapfile OUT text) FROM PUBLIC;


--
-- Name: FUNCTION sys_switch_wal(); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_switch_wal() FROM PUBLIC;


--
-- Name: TABLE sys_user; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_user TO PUBLIC;


--
-- Name: FUNCTION sys_wal_replay_pause(); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_wal_replay_pause() FROM PUBLIC;


--
-- Name: FUNCTION sys_wal_replay_resume(); Type: ACL; Schema: sys_catalog; Owner: system
--

REVOKE ALL ON FUNCTION sys_catalog.sys_wal_replay_resume() FROM PUBLIC;


--
-- Name: TABLE all_arguments; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.all_arguments TO PUBLIC;


--
-- Name: TABLE kdb_job; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.kdb_job TO PUBLIC;


--
-- Name: TABLE pg_stat_metric_name; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.pg_stat_metric_name TO PUBLIC;


--
-- Name: TABLE pg_stat_metric; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.pg_stat_metric TO PUBLIC;


--
-- Name: TABLE pg_stat_metric_group; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.pg_stat_metric_group TO PUBLIC;


--
-- Name: TABLE pg_stat_metric_history; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.pg_stat_metric_history TO PUBLIC;


--
-- Name: TABLE pg_stat_sysmetric; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.pg_stat_sysmetric TO PUBLIC;


--
-- Name: TABLE pg_stat_sysmetric_history; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.pg_stat_sysmetric_history TO PUBLIC;


--
-- Name: TABLE pg_stat_sysmetric_summary; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.pg_stat_sysmetric_summary TO PUBLIC;


--
-- Name: TABLE pg_triggers; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.pg_triggers TO PUBLIC;


--
-- Name: TABLE recyclebin; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.recyclebin TO PUBLIC;


--
-- Name: TABLE sys_anon_policy; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.sys_anon_policy TO PUBLIC;


--
-- Name: TABLE sys_audit_blocklog; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.sys_audit_blocklog TO PUBLIC;


--
-- Name: TABLE sys_audit_userlog; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.sys_audit_userlog TO PUBLIC;


--
-- Name: TABLE sys_database_link; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.sys_database_link TO PUBLIC;


--
-- Name: TABLE sys_depends; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.sys_depends TO PUBLIC;


--
-- Name: TABLE sys_directory; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.sys_directory TO PUBLIC;


--
-- Name: TABLE sys_package; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.sys_package TO PUBLIC;


--
-- Name: TABLE sys_pkgitem; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.sys_pkgitem TO PUBLIC;


--
-- Name: TABLE sys_privilege; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.sys_privilege TO PUBLIC;


--
-- Name: TABLE sys_protect; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.sys_protect TO PUBLIC;


--
-- Name: TABLE sys_pwdht_shadow; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.sys_pwdht_shadow TO PUBLIC;


--
-- Name: TABLE sys_query_mapping; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.sys_query_mapping TO PUBLIC;


--
-- Name: TABLE sys_recyclebin; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.sys_recyclebin TO PUBLIC;


--
-- Name: TABLE sys_resgroup; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.sys_resgroup TO PUBLIC;


--
-- Name: TABLE sys_resource_groups; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.sys_resource_groups TO PUBLIC;


--
-- Name: TABLE sys_role_disable; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.sys_role_disable TO PUBLIC;


--
-- Name: TABLE sys_synonym; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.sys_synonym TO PUBLIC;


--
-- Name: TABLE sys_sysaudit_ids_setting; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.sys_sysaudit_ids_setting TO PUBLIC;


--
-- Name: TABLE sys_sysaudit_setting; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.sys_sysaudit_setting TO PUBLIC;


--
-- Name: TABLE sys_sysprivilege; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.sys_sysprivilege TO PUBLIC;


--
-- Name: TABLE user_any_privs; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE pg_catalog.user_any_privs TO PUBLIC;


--
-- Name: TABLE user_arguments; Type: ACL; Schema: pg_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE pg_catalog.user_arguments TO PUBLIC;


--
-- Name: TABLE "ALL_CONSTRAINTS"; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys."ALL_CONSTRAINTS" TO PUBLIC;


--
-- Name: TABLE "ALL_INDEXES"; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys."ALL_INDEXES" TO PUBLIC;


--
-- Name: TABLE "USER_INDEXES"; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys."USER_INDEXES" TO PUBLIC;


--
-- Name: TABLE all_all_tables; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.all_all_tables TO PUBLIC;


--
-- Name: TABLE all_col_comments; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.all_col_comments TO PUBLIC;


--
-- Name: TABLE all_col_privs; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.all_col_privs TO PUBLIC;


--
-- Name: TABLE all_cons_columns; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.all_cons_columns TO PUBLIC;


--
-- Name: TABLE all_db_links; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.all_db_links TO PUBLIC;


--
-- Name: TABLE all_directories; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.all_directories TO PUBLIC;


--
-- Name: TABLE all_ind_columns; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.all_ind_columns TO PUBLIC;


--
-- Name: TABLE all_objects; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.all_objects TO PUBLIC;


--
-- Name: TABLE all_part_tables; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.all_part_tables TO PUBLIC;


--
-- Name: TABLE all_sequences; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.all_sequences TO PUBLIC;


--
-- Name: TABLE all_source; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.all_source TO PUBLIC;


--
-- Name: TABLE sys_class; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_class TO PUBLIC;


--
-- Name: TABLE sys_proc; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_proc TO PUBLIC;


--
-- Name: TABLE sys_type; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_type TO PUBLIC;


--
-- Name: TABLE all_synonyms; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.all_synonyms TO PUBLIC;


--
-- Name: TABLE all_tab_cols; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.all_tab_cols TO PUBLIC;


--
-- Name: TABLE all_tab_columns; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.all_tab_columns TO PUBLIC;


--
-- Name: TABLE all_tab_comments; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.all_tab_comments TO PUBLIC;


--
-- Name: TABLE all_tab_partitions; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.all_tab_partitions TO PUBLIC;


--
-- Name: TABLE all_tab_privs; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.all_tab_privs TO PUBLIC;


--
-- Name: TABLE all_tables; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.all_tables TO PUBLIC;


--
-- Name: TABLE all_trigger_cols; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.all_trigger_cols TO PUBLIC;


--
-- Name: TABLE all_triggers; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.all_triggers TO PUBLIC;


--
-- Name: TABLE all_types; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.all_types TO PUBLIC;


--
-- Name: TABLE all_users; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.all_users TO PUBLIC;


--
-- Name: TABLE all_views; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.all_views TO PUBLIC;


--
-- Name: TABLE dual; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.dual TO PUBLIC;


--
-- Name: TABLE sys_session; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.sys_session TO PUBLIC;


--
-- Name: TABLE user_all_tables; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_all_tables TO PUBLIC;


--
-- Name: TABLE user_col_comments; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_col_comments TO PUBLIC;


--
-- Name: TABLE user_col_privs; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_col_privs TO PUBLIC;


--
-- Name: TABLE user_cons_columns; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_cons_columns TO PUBLIC;


--
-- Name: TABLE user_constraints; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_constraints TO PUBLIC;


--
-- Name: TABLE user_db_links; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_db_links TO PUBLIC;


--
-- Name: TABLE user_directories; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_directories TO PUBLIC;


--
-- Name: TABLE user_ind_columns; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_ind_columns TO PUBLIC;


--
-- Name: TABLE user_objects; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_objects TO PUBLIC;


--
-- Name: TABLE user_part_tables; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_part_tables TO PUBLIC;


--
-- Name: TABLE user_role_privs; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_role_privs TO PUBLIC;


--
-- Name: TABLE user_sequences; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_sequences TO PUBLIC;


--
-- Name: TABLE user_source; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_source TO PUBLIC;


--
-- Name: TABLE user_synonyms; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_synonyms TO PUBLIC;


--
-- Name: TABLE user_tab_cols; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_tab_cols TO PUBLIC;


--
-- Name: TABLE user_tab_columns; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_tab_columns TO PUBLIC;


--
-- Name: TABLE user_tab_comments; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_tab_comments TO PUBLIC;


--
-- Name: TABLE user_tab_partitions; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_tab_partitions TO PUBLIC;


--
-- Name: TABLE user_tab_privs; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_tab_privs TO PUBLIC;


--
-- Name: TABLE user_table_cols; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_table_cols TO PUBLIC;


--
-- Name: TABLE user_tables; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_tables TO PUBLIC;


--
-- Name: TABLE user_tablespace; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_tablespace TO PUBLIC;


--
-- Name: TABLE user_tablespaces; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_tablespaces TO PUBLIC;


--
-- Name: TABLE user_trigger_cols; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_trigger_cols TO PUBLIC;


--
-- Name: TABLE user_triggers; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_triggers TO PUBLIC;


--
-- Name: TABLE user_types; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_types TO PUBLIC;


--
-- Name: TABLE user_users; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_users TO PUBLIC;


--
-- Name: TABLE user_views; Type: ACL; Schema: sys; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys.user_views TO PUBLIC;


--
-- Name: TABLE kdb_ce_col; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.kdb_ce_col TO PUBLIC;


--
-- Name: TABLE kdb_ce_col_key; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.kdb_ce_col_key TO PUBLIC;


--
-- Name: TABLE kdb_ce_col_key_arg; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.kdb_ce_col_key_arg TO PUBLIC;


--
-- Name: TABLE kdb_ce_mst_key; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.kdb_ce_mst_key TO PUBLIC;


--
-- Name: TABLE kdb_ce_mst_key_arg; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.kdb_ce_mst_key_arg TO PUBLIC;


--
-- Name: TABLE kdb_ce_proc; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.kdb_ce_proc TO PUBLIC;


--
-- Name: TABLE sys_aggregate; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_aggregate TO PUBLIC;


--
-- Name: TABLE sys_am; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_am TO PUBLIC;


--
-- Name: TABLE sys_amop; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_amop TO PUBLIC;


--
-- Name: TABLE sys_amproc; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_amproc TO PUBLIC;


--
-- Name: TABLE sys_attrdef; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_attrdef TO PUBLIC;


--
-- Name: TABLE sys_attribute; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_attribute TO PUBLIC;


--
-- Name: TABLE sys_auth_members; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_auth_members TO PUBLIC;


--
-- Name: TABLE sys_available_extension_versions; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_available_extension_versions TO PUBLIC;


--
-- Name: TABLE sys_available_extensions; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_available_extensions TO PUBLIC;


--
-- Name: TABLE sys_cast; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_cast TO PUBLIC;


--
-- Name: TABLE sys_collation; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_collation TO PUBLIC;


--
-- Name: TABLE sys_constraint; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_constraint TO PUBLIC;


--
-- Name: TABLE sys_constraint_status; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_constraint_status TO PUBLIC;


--
-- Name: TABLE sys_context; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_context TO PUBLIC;


--
-- Name: TABLE sys_conversion; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_conversion TO PUBLIC;


--
-- Name: TABLE sys_cursors; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_cursors TO PUBLIC;


--
-- Name: TABLE sys_database; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_database TO PUBLIC;


--
-- Name: TABLE sys_default_acl; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_default_acl TO PUBLIC;


--
-- Name: TABLE sys_depend; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_depend TO PUBLIC;


--
-- Name: TABLE sys_description; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_description TO PUBLIC;


--
-- Name: TABLE sys_enum; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_enum TO PUBLIC;


--
-- Name: TABLE sys_event_trigger; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_event_trigger TO PUBLIC;


--
-- Name: TABLE sys_extension; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_extension TO PUBLIC;


--
-- Name: TABLE sys_foreign_data_wrapper; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_foreign_data_wrapper TO PUBLIC;


--
-- Name: TABLE sys_foreign_server; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_foreign_server TO PUBLIC;


--
-- Name: TABLE sys_foreign_table; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_foreign_table TO PUBLIC;


--
-- Name: TABLE sys_group; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_group TO PUBLIC;


--
-- Name: TABLE sys_index; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_index TO PUBLIC;


--
-- Name: TABLE sys_indexes; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_indexes TO PUBLIC;


--
-- Name: TABLE sys_inherits; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_inherits TO PUBLIC;


--
-- Name: TABLE sys_init_privs; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_init_privs TO PUBLIC;


--
-- Name: TABLE sys_language; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_language TO PUBLIC;


--
-- Name: TABLE sys_largeobject_metadata; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_largeobject_metadata TO PUBLIC;


--
-- Name: TABLE sys_locks; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_locks TO PUBLIC;


--
-- Name: TABLE sys_matviews; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_matviews TO PUBLIC;


--
-- Name: TABLE sys_namespace; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_namespace TO PUBLIC;


--
-- Name: TABLE sys_object_status; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_object_status TO PUBLIC;


--
-- Name: TABLE sys_objects; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_objects TO PUBLIC;


--
-- Name: TABLE sys_opclass; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_opclass TO PUBLIC;


--
-- Name: TABLE sys_operator; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_operator TO PUBLIC;


--
-- Name: TABLE sys_opfamily; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_opfamily TO PUBLIC;


--
-- Name: TABLE sys_partitioned_table; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_partitioned_table TO PUBLIC;


--
-- Name: TABLE sys_pltemplate; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_pltemplate TO PUBLIC;


--
-- Name: TABLE sys_policies; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_policies TO PUBLIC;


--
-- Name: TABLE sys_policy; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_policy TO PUBLIC;


--
-- Name: TABLE sys_prepared_statements; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_prepared_statements TO PUBLIC;


--
-- Name: TABLE sys_prepared_xacts; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_prepared_xacts TO PUBLIC;


--
-- Name: TABLE sys_protect; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_protect TO PUBLIC;


--
-- Name: TABLE sys_publication; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_publication TO PUBLIC;


--
-- Name: TABLE sys_publication_rel; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_publication_rel TO PUBLIC;


--
-- Name: TABLE sys_publication_tables; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_publication_tables TO PUBLIC;


--
-- Name: TABLE sys_range; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_range TO PUBLIC;


--
-- Name: TABLE sys_replication_origin; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_replication_origin TO PUBLIC;


--
-- Name: TABLE sys_replication_slots; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_replication_slots TO PUBLIC;


--
-- Name: TABLE sys_rewrite; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_rewrite TO PUBLIC;


--
-- Name: TABLE sys_role; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_role TO PUBLIC;


--
-- Name: TABLE sys_roles; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_roles TO PUBLIC;


--
-- Name: TABLE sys_rules; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_rules TO PUBLIC;


--
-- Name: TABLE sys_seclabel; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_seclabel TO PUBLIC;


--
-- Name: TABLE sys_seclabels; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_seclabels TO PUBLIC;


--
-- Name: TABLE sys_sequence; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_sequence TO PUBLIC;


--
-- Name: TABLE sys_sequences; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_sequences TO PUBLIC;


--
-- Name: TABLE sys_settings; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_settings TO PUBLIC;


--
-- Name: TABLE sys_shdepend; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_shdepend TO PUBLIC;


--
-- Name: TABLE sys_shdescription; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_shdescription TO PUBLIC;


--
-- Name: TABLE sys_shseclabel; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_shseclabel TO PUBLIC;


--
-- Name: TABLE sys_space_quota; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_space_quota TO PUBLIC;


--
-- Name: TABLE sys_stat_activity; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_activity TO PUBLIC;


--
-- Name: TABLE sys_stat_all_indexes; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_all_indexes TO PUBLIC;


--
-- Name: TABLE sys_stat_all_tables; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_all_tables TO PUBLIC;


--
-- Name: TABLE sys_stat_archiver; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_archiver TO PUBLIC;


--
-- Name: TABLE sys_stat_bgwriter; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_bgwriter TO PUBLIC;


--
-- Name: TABLE sys_stat_cached_plans; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_cached_plans TO PUBLIC;


--
-- Name: TABLE sys_stat_database; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_database TO PUBLIC;


--
-- Name: TABLE sys_stat_database_conflicts; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_database_conflicts TO PUBLIC;


--
-- Name: TABLE sys_stat_dmlcount; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_dmlcount TO PUBLIC;


--
-- Name: TABLE sys_stat_gssapi; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_gssapi TO PUBLIC;


--
-- Name: TABLE sys_stat_instevent; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_instevent TO PUBLIC;


--
-- Name: TABLE sys_stat_instio; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_instio TO PUBLIC;


--
-- Name: TABLE sys_stat_instlock; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_instlock TO PUBLIC;


--
-- Name: TABLE sys_stat_metric; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_metric TO PUBLIC;


--
-- Name: TABLE sys_stat_metric_group; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_metric_group TO PUBLIC;


--
-- Name: TABLE sys_stat_metric_history; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_metric_history TO PUBLIC;


--
-- Name: TABLE sys_stat_metric_name; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_metric_name TO PUBLIC;


--
-- Name: TABLE sys_stat_msgaccum; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_msgaccum TO PUBLIC;


--
-- Name: TABLE sys_stat_pre_archivewal; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_pre_archivewal TO PUBLIC;


--
-- Name: TABLE sys_stat_progress_cluster; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_progress_cluster TO PUBLIC;


--
-- Name: TABLE sys_stat_progress_create_index; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_progress_create_index TO PUBLIC;


--
-- Name: TABLE sys_stat_progress_vacuum; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_progress_vacuum TO PUBLIC;


--
-- Name: TABLE sys_stat_replication; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_replication TO PUBLIC;


--
-- Name: TABLE sys_stat_shmem; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_shmem TO PUBLIC;


--
-- Name: TABLE sys_stat_sqlcount; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_sqlcount TO PUBLIC;


--
-- Name: TABLE sys_stat_sqlio; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_sqlio TO PUBLIC;


--
-- Name: TABLE sys_stat_sqltime; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_sqltime TO PUBLIC;


--
-- Name: TABLE sys_stat_sqlwait; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_sqlwait TO PUBLIC;


--
-- Name: TABLE sys_stat_ssl; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_ssl TO PUBLIC;


--
-- Name: TABLE sys_stat_subscription; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_subscription TO PUBLIC;


--
-- Name: TABLE sys_stat_sys_indexes; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_sys_indexes TO PUBLIC;


--
-- Name: TABLE sys_stat_sys_tables; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_sys_tables TO PUBLIC;


--
-- Name: TABLE sys_stat_sysmetric; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_sysmetric TO PUBLIC;


--
-- Name: TABLE sys_stat_sysmetric_history; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_sysmetric_history TO PUBLIC;


--
-- Name: TABLE sys_stat_sysmetric_summary; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_sysmetric_summary TO PUBLIC;


--
-- Name: TABLE sys_stat_transaction; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_transaction TO PUBLIC;


--
-- Name: TABLE sys_stat_user_functions; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_user_functions TO PUBLIC;


--
-- Name: TABLE sys_stat_user_indexes; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_user_indexes TO PUBLIC;


--
-- Name: TABLE sys_stat_user_tables; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_user_tables TO PUBLIC;


--
-- Name: TABLE sys_stat_waitaccum; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_waitaccum TO PUBLIC;


--
-- Name: TABLE sys_stat_wal_buffer; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_wal_buffer TO PUBLIC;


--
-- Name: TABLE sys_stat_wal_receiver; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_wal_receiver TO PUBLIC;


--
-- Name: TABLE sys_stat_xact_all_tables; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_xact_all_tables TO PUBLIC;


--
-- Name: TABLE sys_stat_xact_sys_tables; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_xact_sys_tables TO PUBLIC;


--
-- Name: TABLE sys_stat_xact_user_functions; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_xact_user_functions TO PUBLIC;


--
-- Name: TABLE sys_stat_xact_user_tables; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stat_xact_user_tables TO PUBLIC;


--
-- Name: TABLE sys_statio_all_indexes; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_statio_all_indexes TO PUBLIC;


--
-- Name: TABLE sys_statio_all_sequences; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_statio_all_sequences TO PUBLIC;


--
-- Name: TABLE sys_statio_all_tables; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_statio_all_tables TO PUBLIC;


--
-- Name: TABLE sys_statio_sys_indexes; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_statio_sys_indexes TO PUBLIC;


--
-- Name: TABLE sys_statio_sys_sequences; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_statio_sys_sequences TO PUBLIC;


--
-- Name: TABLE sys_statio_sys_tables; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_statio_sys_tables TO PUBLIC;


--
-- Name: TABLE sys_statio_user_indexes; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_statio_user_indexes TO PUBLIC;


--
-- Name: TABLE sys_statio_user_sequences; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_statio_user_sequences TO PUBLIC;


--
-- Name: TABLE sys_statio_user_tables; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_statio_user_tables TO PUBLIC;


--
-- Name: TABLE sys_statistic_ext; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_statistic_ext TO PUBLIC;


--
-- Name: TABLE sys_stats; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stats TO PUBLIC;


--
-- Name: TABLE sys_stats_ext; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_stats_ext TO PUBLIC;


--
-- Name: TABLE sys_subpartition_table; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_subpartition_table TO PUBLIC;


--
-- Name: TABLE sys_subscription_rel; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_subscription_rel TO PUBLIC;


--
-- Name: TABLE sys_tables; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_tables TO PUBLIC;


--
-- Name: TABLE sys_tablespace; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_tablespace TO PUBLIC;


--
-- Name: TABLE sys_timezone_abbrevs; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_timezone_abbrevs TO PUBLIC;


--
-- Name: TABLE sys_timezone_names; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_timezone_names TO PUBLIC;


--
-- Name: TABLE sys_transform; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_transform TO PUBLIC;


--
-- Name: TABLE sys_trigger; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_trigger TO PUBLIC;


--
-- Name: TABLE sys_triggers; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_triggers TO PUBLIC;


--
-- Name: TABLE sys_ts_config; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_ts_config TO PUBLIC;


--
-- Name: TABLE sys_ts_config_map; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_ts_config_map TO PUBLIC;


--
-- Name: TABLE sys_ts_dict; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_ts_dict TO PUBLIC;


--
-- Name: TABLE sys_ts_parser; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_ts_parser TO PUBLIC;


--
-- Name: TABLE sys_ts_template; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_ts_template TO PUBLIC;


--
-- Name: TABLE sys_user_mappings; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_user_mappings TO PUBLIC;


--
-- Name: TABLE sys_usergroup; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_usergroup TO PUBLIC;


--
-- Name: TABLE sys_users; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_users TO PUBLIC;


--
-- Name: TABLE sys_views; Type: ACL; Schema: sys_catalog; Owner: system
--

GRANT IF EXISTS SELECT ON TABLE sys_catalog.sys_views TO PUBLIC;


--
-- Kingbase database dump complete
--

