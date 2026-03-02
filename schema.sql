--
-- PostgreSQL database dump
--

-- Dumped from database version 16.2 (Debian 16.2-1.pgdg120+2)
-- Dumped by pg_dump version 16.2 (Debian 16.2-1.pgdg120+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: behavior_type; Type: TYPE; Schema: public; Owner: apollo_junior
--

CREATE TYPE public.behavior_type AS ENUM (
    'MAZE',
    'PIXEL_ART',
    'MUSIC'
);


ALTER TYPE public.behavior_type OWNER TO apollo_junior;

--
-- Name: difficulty_type; Type: TYPE; Schema: public; Owner: apollo_junior
--

CREATE TYPE public.difficulty_type AS ENUM (
    'EASY',
    'MEDIUM',
    'HARD'
);


ALTER TYPE public.difficulty_type OWNER TO apollo_junior;

--
-- Name: target_grade; Type: TYPE; Schema: public; Owner: apollo_junior
--

CREATE TYPE public.target_grade AS ENUM (
    'SD_1_2',
    'SD_3_6',
    'SMP',
    'SMA'
);


ALTER TYPE public.target_grade OWNER TO apollo_junior;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: auth_images; Type: TABLE; Schema: public; Owner: apollo_junior
--

CREATE TABLE public.auth_images (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(50) NOT NULL,
    image_url text NOT NULL,
    is_active boolean DEFAULT true
);


ALTER TABLE public.auth_images OWNER TO apollo_junior;

--
-- Name: classroom_modules; Type: TABLE; Schema: public; Owner: apollo_junior
--

CREATE TABLE public.classroom_modules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    classroom_id uuid NOT NULL,
    module_id uuid NOT NULL,
    "order" integer NOT NULL
);


ALTER TABLE public.classroom_modules OWNER TO apollo_junior;

--
-- Name: TABLE classroom_modules; Type: COMMENT; Schema: public; Owner: apollo_junior
--

COMMENT ON TABLE public.classroom_modules IS 'Associates modules with classrooms';


--
-- Name: COLUMN classroom_modules."order"; Type: COMMENT; Schema: public; Owner: apollo_junior
--

COMMENT ON COLUMN public.classroom_modules."order" IS 'Order of the module within the classroom';


--
-- Name: classroom_students; Type: TABLE; Schema: public; Owner: apollo_junior
--

CREATE TABLE public.classroom_students (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    classroom_id uuid NOT NULL,
    user_id uuid NOT NULL,
    joined_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.classroom_students OWNER TO apollo_junior;

--
-- Name: TABLE classroom_students; Type: COMMENT; Schema: public; Owner: apollo_junior
--

COMMENT ON TABLE public.classroom_students IS 'Associates students (users) with classrooms';


--
-- Name: classrooms; Type: TABLE; Schema: public; Owner: apollo_junior
--

CREATE TABLE public.classrooms (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    alias character varying(100),
    grade_type character varying(20),
    grade_level integer,
    created_by uuid,
    tenant_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.classrooms OWNER TO apollo_junior;

--
-- Name: TABLE classrooms; Type: COMMENT; Schema: public; Owner: apollo_junior
--

COMMENT ON TABLE public.classrooms IS 'Stores classroom entities for the junior application';


--
-- Name: COLUMN classrooms.alias; Type: COMMENT; Schema: public; Owner: apollo_junior
--

COMMENT ON COLUMN public.classrooms.alias IS 'Short alias or code for the classroom';


--
-- Name: COLUMN classrooms.grade_type; Type: COMMENT; Schema: public; Owner: apollo_junior
--

COMMENT ON COLUMN public.classrooms.grade_type IS 'Target grade type: SD, SMP, SMA';


--
-- Name: module_lessons; Type: TABLE; Schema: public; Owner: apollo_junior
--

CREATE TABLE public.module_lessons (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    module_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    step integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.module_lessons OWNER TO apollo_junior;

--
-- Name: TABLE module_lessons; Type: COMMENT; Schema: public; Owner: apollo_junior
--

COMMENT ON TABLE public.module_lessons IS 'Stores lessons within a module';


--
-- Name: COLUMN module_lessons.step; Type: COMMENT; Schema: public; Owner: apollo_junior
--

COMMENT ON COLUMN public.module_lessons.step IS 'Order of the lesson within the module';


--
-- Name: modules; Type: TABLE; Schema: public; Owner: apollo_junior
--

CREATE TABLE public.modules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    difficulty character varying(20),
    behavior_type character varying(20),
    grade_type character varying(20),
    grade_level integer,
    is_official boolean DEFAULT true NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.modules OWNER TO apollo_junior;

--
-- Name: TABLE modules; Type: COMMENT; Schema: public; Owner: apollo_junior
--

COMMENT ON TABLE public.modules IS 'Stores learning modules for junior application';


--
-- Name: COLUMN modules.difficulty; Type: COMMENT; Schema: public; Owner: apollo_junior
--

COMMENT ON COLUMN public.modules.difficulty IS 'Module difficulty: EASY, MEDIUM, HARD';


--
-- Name: COLUMN modules.behavior_type; Type: COMMENT; Schema: public; Owner: apollo_junior
--

COMMENT ON COLUMN public.modules.behavior_type IS 'Module behavior type: MAZE, PIXEL_ART, MUSIC';


--
-- Name: COLUMN modules.grade_type; Type: COMMENT; Schema: public; Owner: apollo_junior
--

COMMENT ON COLUMN public.modules.grade_type IS 'Target grade type: SD, SMP, SMA';


--
-- Name: mst_junior_modules; Type: TABLE; Schema: public; Owner: apollo_junior
--

CREATE TABLE public.mst_junior_modules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    difficulty public.difficulty_type,
    target_grade public.target_grade,
    behavior_type public.behavior_type,
    is_official boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.mst_junior_modules OWNER TO apollo_junior;

--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: apollo_junior
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    dirty boolean NOT NULL
);


ALTER TABLE public.schema_migrations OWNER TO apollo_junior;

--
-- Name: student_lesson_progress; Type: TABLE; Schema: public; Owner: apollo_junior
--

CREATE TABLE public.student_lesson_progress (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    classroom_id uuid NOT NULL,
    module_id uuid NOT NULL,
    lesson_id uuid NOT NULL,
    user_id uuid NOT NULL,
    status character varying(20) DEFAULT 'NOT_STARTED'::character varying NOT NULL,
    progress_percent integer DEFAULT 0 NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.student_lesson_progress OWNER TO apollo_junior;

--
-- Name: TABLE student_lesson_progress; Type: COMMENT; Schema: public; Owner: apollo_junior
--

COMMENT ON TABLE public.student_lesson_progress IS 'Tracks student progress within individual lessons';


--
-- Name: COLUMN student_lesson_progress.status; Type: COMMENT; Schema: public; Owner: apollo_junior
--

COMMENT ON COLUMN public.student_lesson_progress.status IS 'Lesson status: NOT_STARTED, IN_PROGRESS, COMPLETED';


--
-- Name: COLUMN student_lesson_progress.progress_percent; Type: COMMENT; Schema: public; Owner: apollo_junior
--

COMMENT ON COLUMN public.student_lesson_progress.progress_percent IS 'Percentage of lesson completion (0-100)';


--
-- Name: student_module_progress; Type: TABLE; Schema: public; Owner: apollo_junior
--

CREATE TABLE public.student_module_progress (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    classroom_id uuid NOT NULL,
    module_id uuid NOT NULL,
    user_id uuid NOT NULL,
    total_lessons integer NOT NULL,
    completed_lessons integer DEFAULT 0 NOT NULL,
    progress_percent integer DEFAULT 0 NOT NULL,
    is_completed boolean DEFAULT false NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.student_module_progress OWNER TO apollo_junior;

--
-- Name: TABLE student_module_progress; Type: COMMENT; Schema: public; Owner: apollo_junior
--

COMMENT ON TABLE public.student_module_progress IS 'Tracks student progress within a module in a classroom';


--
-- Name: COLUMN student_module_progress.total_lessons; Type: COMMENT; Schema: public; Owner: apollo_junior
--

COMMENT ON COLUMN public.student_module_progress.total_lessons IS 'Total number of lessons in the module';


--
-- Name: COLUMN student_module_progress.completed_lessons; Type: COMMENT; Schema: public; Owner: apollo_junior
--

COMMENT ON COLUMN public.student_module_progress.completed_lessons IS 'Number of lessons completed by the student';


--
-- Name: COLUMN student_module_progress.progress_percent; Type: COMMENT; Schema: public; Owner: apollo_junior
--

COMMENT ON COLUMN public.student_module_progress.progress_percent IS 'Percentage of module completion (0-100)';


--
-- Name: COLUMN student_module_progress.is_completed; Type: COMMENT; Schema: public; Owner: apollo_junior
--

COMMENT ON COLUMN public.student_module_progress.is_completed IS 'Whether the student has completed all lessons';


--
-- Name: user_passwords; Type: TABLE; Schema: public; Owner: apollo_junior
--

CREATE TABLE public.user_passwords (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    password_hash character varying(255) NOT NULL,
    password_salt character varying(64) NOT NULL,
    failed_attempts integer DEFAULT 0 NOT NULL,
    locked_until timestamp with time zone,
    last_failed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.user_passwords OWNER TO apollo_junior;

--
-- Name: TABLE user_passwords; Type: COMMENT; Schema: public; Owner: apollo_junior
--

COMMENT ON TABLE public.user_passwords IS 'Stores hashed passwords for user authentication';


--
-- Name: COLUMN user_passwords.password_hash; Type: COMMENT; Schema: public; Owner: apollo_junior
--

COMMENT ON COLUMN public.user_passwords.password_hash IS 'Bcrypt hash of the user password';


--
-- Name: COLUMN user_passwords.password_salt; Type: COMMENT; Schema: public; Owner: apollo_junior
--

COMMENT ON COLUMN public.user_passwords.password_salt IS 'Random salt used for password hashing';


--
-- Name: user_pins; Type: TABLE; Schema: public; Owner: apollo_junior
--

CREATE TABLE public.user_pins (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    pin_hash character varying(64) NOT NULL,
    pin_salt character varying(32) NOT NULL,
    pin_length integer DEFAULT 3 NOT NULL,
    failed_attempts integer DEFAULT 0 NOT NULL,
    locked_until timestamp with time zone,
    last_failed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.user_pins OWNER TO apollo_junior;

--
-- Name: users; Type: TABLE; Schema: public; Owner: apollo_junior
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    username character varying(100) NOT NULL,
    display_name character varying(255),
    avatar_url text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted_at timestamp with time zone
);


ALTER TABLE public.users OWNER TO apollo_junior;

--
-- Name: auth_images auth_images_code_key; Type: CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.auth_images
    ADD CONSTRAINT auth_images_code_key UNIQUE (code);


--
-- Name: auth_images auth_images_pkey; Type: CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.auth_images
    ADD CONSTRAINT auth_images_pkey PRIMARY KEY (id);


--
-- Name: classroom_modules classroom_modules_pkey; Type: CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.classroom_modules
    ADD CONSTRAINT classroom_modules_pkey PRIMARY KEY (id);


--
-- Name: classroom_students classroom_students_pkey; Type: CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.classroom_students
    ADD CONSTRAINT classroom_students_pkey PRIMARY KEY (id);


--
-- Name: classrooms classrooms_pkey; Type: CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.classrooms
    ADD CONSTRAINT classrooms_pkey PRIMARY KEY (id);


--
-- Name: module_lessons module_lessons_pkey; Type: CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.module_lessons
    ADD CONSTRAINT module_lessons_pkey PRIMARY KEY (id);


--
-- Name: modules modules_pkey; Type: CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.modules
    ADD CONSTRAINT modules_pkey PRIMARY KEY (id);


--
-- Name: mst_junior_modules mst_junior_modules_pkey; Type: CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.mst_junior_modules
    ADD CONSTRAINT mst_junior_modules_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: student_lesson_progress student_lesson_progress_pkey; Type: CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.student_lesson_progress
    ADD CONSTRAINT student_lesson_progress_pkey PRIMARY KEY (id);


--
-- Name: student_module_progress student_module_progress_pkey; Type: CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.student_module_progress
    ADD CONSTRAINT student_module_progress_pkey PRIMARY KEY (id);


--
-- Name: classroom_modules uq_classroom_modules_classroom_module; Type: CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.classroom_modules
    ADD CONSTRAINT uq_classroom_modules_classroom_module UNIQUE (classroom_id, module_id);


--
-- Name: classroom_students uq_classroom_students_classroom_user; Type: CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.classroom_students
    ADD CONSTRAINT uq_classroom_students_classroom_user UNIQUE (classroom_id, user_id);


--
-- Name: module_lessons uq_module_lessons_module_step; Type: CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.module_lessons
    ADD CONSTRAINT uq_module_lessons_module_step UNIQUE (module_id, step);


--
-- Name: student_lesson_progress uq_student_lesson_progress_classroom_lesson_user; Type: CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.student_lesson_progress
    ADD CONSTRAINT uq_student_lesson_progress_classroom_lesson_user UNIQUE (classroom_id, lesson_id, user_id);


--
-- Name: student_module_progress uq_student_module_progress_classroom_module_user; Type: CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.student_module_progress
    ADD CONSTRAINT uq_student_module_progress_classroom_module_user UNIQUE (classroom_id, module_id, user_id);


--
-- Name: user_passwords uq_user_passwords_user; Type: CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.user_passwords
    ADD CONSTRAINT uq_user_passwords_user UNIQUE (user_id);


--
-- Name: user_pins uq_user_pins_user; Type: CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.user_pins
    ADD CONSTRAINT uq_user_pins_user UNIQUE (user_id);


--
-- Name: users uq_users_tenant_username; Type: CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT uq_users_tenant_username UNIQUE (tenant_id, username);


--
-- Name: user_passwords user_passwords_pkey; Type: CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.user_passwords
    ADD CONSTRAINT user_passwords_pkey PRIMARY KEY (id);


--
-- Name: user_pins user_pins_pkey; Type: CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.user_pins
    ADD CONSTRAINT user_pins_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_classroom_modules_classroom_id; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE INDEX idx_classroom_modules_classroom_id ON public.classroom_modules USING btree (classroom_id);


--
-- Name: idx_classroom_students_classroom_id; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE INDEX idx_classroom_students_classroom_id ON public.classroom_students USING btree (classroom_id);


--
-- Name: idx_classrooms_created_by; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE INDEX idx_classrooms_created_by ON public.classrooms USING btree (created_by);


--
-- Name: idx_classrooms_tenant_id; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE INDEX idx_classrooms_tenant_id ON public.classrooms USING btree (tenant_id);


--
-- Name: idx_module_lessons_module_id; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE INDEX idx_module_lessons_module_id ON public.module_lessons USING btree (module_id);


--
-- Name: idx_modules_behavior_type; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE INDEX idx_modules_behavior_type ON public.modules USING btree (behavior_type);


--
-- Name: idx_modules_created_by; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE INDEX idx_modules_created_by ON public.modules USING btree (created_by);


--
-- Name: idx_modules_difficulty; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE INDEX idx_modules_difficulty ON public.modules USING btree (difficulty);


--
-- Name: idx_modules_grade_type; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE INDEX idx_modules_grade_type ON public.modules USING btree (grade_type);


--
-- Name: idx_modules_id; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE UNIQUE INDEX idx_modules_id ON public.modules USING btree (id);


--
-- Name: idx_student_lesson_progress_classroom_id; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE INDEX idx_student_lesson_progress_classroom_id ON public.student_lesson_progress USING btree (classroom_id);


--
-- Name: idx_student_lesson_progress_module_id; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE INDEX idx_student_lesson_progress_module_id ON public.student_lesson_progress USING btree (module_id);


--
-- Name: idx_student_lesson_progress_user_id; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE INDEX idx_student_lesson_progress_user_id ON public.student_lesson_progress USING btree (user_id);


--
-- Name: idx_student_module_progress_classroom_id; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE INDEX idx_student_module_progress_classroom_id ON public.student_module_progress USING btree (classroom_id);


--
-- Name: idx_student_module_progress_module_id; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE INDEX idx_student_module_progress_module_id ON public.student_module_progress USING btree (module_id);


--
-- Name: idx_student_module_progress_user_id; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE INDEX idx_student_module_progress_user_id ON public.student_module_progress USING btree (user_id);


--
-- Name: idx_user_passwords_locked_until; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE INDEX idx_user_passwords_locked_until ON public.user_passwords USING btree (locked_until) WHERE (locked_until IS NOT NULL);


--
-- Name: idx_user_passwords_user_id; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE INDEX idx_user_passwords_user_id ON public.user_passwords USING btree (user_id);


--
-- Name: idx_user_pins_locked_until; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE INDEX idx_user_pins_locked_until ON public.user_pins USING btree (locked_until) WHERE (locked_until IS NOT NULL);


--
-- Name: idx_user_pins_user_id; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE INDEX idx_user_pins_user_id ON public.user_pins USING btree (user_id);


--
-- Name: idx_users_deleted_at; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE INDEX idx_users_deleted_at ON public.users USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- Name: idx_users_is_active; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE INDEX idx_users_is_active ON public.users USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_users_tenant_id; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE INDEX idx_users_tenant_id ON public.users USING btree (tenant_id);


--
-- Name: idx_users_username; Type: INDEX; Schema: public; Owner: apollo_junior
--

CREATE INDEX idx_users_username ON public.users USING btree (username);


--
-- Name: classroom_modules fk_classroom_modules_classroom_id; Type: FK CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.classroom_modules
    ADD CONSTRAINT fk_classroom_modules_classroom_id FOREIGN KEY (classroom_id) REFERENCES public.classrooms(id) ON DELETE CASCADE;


--
-- Name: classroom_modules fk_classroom_modules_module_id; Type: FK CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.classroom_modules
    ADD CONSTRAINT fk_classroom_modules_module_id FOREIGN KEY (module_id) REFERENCES public.modules(id) ON DELETE CASCADE;


--
-- Name: classroom_students fk_classroom_students_classroom_id; Type: FK CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.classroom_students
    ADD CONSTRAINT fk_classroom_students_classroom_id FOREIGN KEY (classroom_id) REFERENCES public.classrooms(id) ON DELETE CASCADE;


--
-- Name: classroom_students fk_classroom_students_user_id; Type: FK CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.classroom_students
    ADD CONSTRAINT fk_classroom_students_user_id FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: module_lessons fk_module_lessons_module_id; Type: FK CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.module_lessons
    ADD CONSTRAINT fk_module_lessons_module_id FOREIGN KEY (module_id) REFERENCES public.modules(id) ON DELETE CASCADE;


--
-- Name: student_lesson_progress fk_student_lesson_progress_classroom_id; Type: FK CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.student_lesson_progress
    ADD CONSTRAINT fk_student_lesson_progress_classroom_id FOREIGN KEY (classroom_id) REFERENCES public.classrooms(id) ON DELETE CASCADE;


--
-- Name: student_lesson_progress fk_student_lesson_progress_lesson_id; Type: FK CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.student_lesson_progress
    ADD CONSTRAINT fk_student_lesson_progress_lesson_id FOREIGN KEY (lesson_id) REFERENCES public.module_lessons(id) ON DELETE CASCADE;


--
-- Name: student_lesson_progress fk_student_lesson_progress_module_id; Type: FK CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.student_lesson_progress
    ADD CONSTRAINT fk_student_lesson_progress_module_id FOREIGN KEY (module_id) REFERENCES public.modules(id) ON DELETE CASCADE;


--
-- Name: student_lesson_progress fk_student_lesson_progress_user_id; Type: FK CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.student_lesson_progress
    ADD CONSTRAINT fk_student_lesson_progress_user_id FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: student_module_progress fk_student_module_progress_classroom_id; Type: FK CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.student_module_progress
    ADD CONSTRAINT fk_student_module_progress_classroom_id FOREIGN KEY (classroom_id) REFERENCES public.classrooms(id) ON DELETE CASCADE;


--
-- Name: student_module_progress fk_student_module_progress_module_id; Type: FK CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.student_module_progress
    ADD CONSTRAINT fk_student_module_progress_module_id FOREIGN KEY (module_id) REFERENCES public.modules(id) ON DELETE CASCADE;


--
-- Name: student_module_progress fk_student_module_progress_user_id; Type: FK CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.student_module_progress
    ADD CONSTRAINT fk_student_module_progress_user_id FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_passwords user_passwords_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.user_passwords
    ADD CONSTRAINT user_passwords_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_pins user_pins_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: apollo_junior
--

ALTER TABLE ONLY public.user_pins
    ADD CONSTRAINT user_pins_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

