# Repository Guidelines

## Platform
- 本项目基于 KES Plus 平台运行，后端连接的是 KES Plus 提供的服务与数据库，务必在部署或联调时保持与该数据库的对接。

## Project Structure & Module Organization
- `server/`: Express API (`index.js`) and Postgres pool (`db.js`). Serves `web/` statics; `.env` holds DB/PORT overrides; `package.json` owns scripts and deps.
- `web/`: Static HTML/CSS/JS for login, student, teacher, admin views. Inline assets; requests hit `/api/*`.
- `db/`: Ordered SQL (`01_schema_*.sql`, `02_triggers_*.sql`, `03_procedures_*.sql`, `04_seed_data_*.sql`). Run in order to create + seed the course-selection schema.
- `tests/`: `db_trigger_procedure_tests.sql` exercises passwords, triggers, and procedures inside one transaction (psql exit → rollback).
- `docs/`: Reference notes (accounts, page plans). Keep credentials elsewhere.

## Build, Test, and Development Commands
- Install backend deps: `cd server && npm install`.
- Run with reload: `npm run dev` (nodemon on `PORT` or 3000); prod-like: `npm start`.
- Health check: `curl http://localhost:3000/health`.
- Provision DB: `psql -f db/01_schema_course_selection.sql -d course_selection_db` then 02/03/04 sequentially.
- DB regression: `psql -d course_selection_db -f tests/db_trigger_procedure_tests.sql`.
- Frontend preview: start server then open `http://localhost:3000/`.

## Coding Style & Naming Conventions
- JavaScript: ES modules, 2-space indent, semicolons, `const`/`let`; async route handlers returning JSON with proper HTTP codes.
- SQL: uppercase object names, snake_case columns, prefixes (`PROC_*`, `FN_*`), new scripts with two-digit numeric prefixes.
- Config: no hard-coded secrets or ports; use `process.env.DB_*` and `PORT`. Always parameterize queries.
- Frontend: keep to existing CSS variables/typography; factor repeated fetch/DOM helpers.

## Testing Guidelines
- JS tests are currently stubbed; prefer Jest + Supertest under `server/` (`*.test.js`) when adding routes or middleware.
- Use `tests/db_trigger_procedure_tests.sql` after schema/procedure changes; add cases with clear step labels.
- Manual checks: curl/Postman against `/api/login`, `/api/select`, `/api/drop`, `/api/courses/*`, `/api/stat` on a seeded DB.

## Workflow & Execution
- Self-verify after each task: complete implementation → run relevant tests → confirm success → proceed to next task.
- Continue autonomously through all tasks until the full objective is achieved.

## Commit & Pull Request Guidelines
- Commits: short imperative subjects (`Add selectable course endpoint`), bodies noting DB migrations, env changes, and manual test commands.
- PRs: describe behavior changes, affected endpoints/SQL objects, verification steps, and UI impact (screenshots if `web/` changes). Link tasks/issues; never commit `.env`, dumps, or `node_modules/`.

## Security & Configuration Tips
- Required env vars: `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` (plus optional `PORT`). Add `.env.example` for new keys; keep real `.env` local.
- Start the DB before the API; expect `[db] connected` on boot. Avoid logging credentials or raw passwords.
