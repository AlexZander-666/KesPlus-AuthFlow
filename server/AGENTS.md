# Repository Guidelines

## Project Structure & Module Organization
- `index.js`: Express API server with CORS, JSON parsing, morgan logging, and static assets served from `../web`. Exposes health check (`/health`), authentication (`/api/login`), course selection (`/api/select`, `/api/drop`), course queries (`/api/courses/*`), and stats (`/api/stat`).
- `db.js`: PostgreSQL pool setup plus `testConnection()`. Reads `DB_*` vars; warns if missing.
- `.env`: Local development defaults for database and `PORT`. Keep credentials local and rotate when shared.
- `package.json`: Script entrypoints (`start`, `dev`, `test`) and dependency manifest. `node_modules/` is generated.

## Build, Test, and Development Commands
- Install dependencies: `npm install`.
- Run with auto-reload: `npm run dev` (nodemon on `index.js`).
- Run once: `npm start` (Express on `PORT`, default 3000).
- Smoke test: `curl http://localhost:3000/health` (expects `{ "status": "ok" }`).
- Current `npm test` is a placeholder; use manual API calls (curl/Postman) until real tests are added.

## Coding Style & Naming Conventions
- ES modules only (`import/export`). Use 2-space indentation, semicolons, and `const`/`let` appropriately.
- Keep route handlers async/await, return JSON errors with HTTP status codes, and validate inputs early.
- Environment variable names stay UPPER_SNAKE_CASE; avoid hard-coding secrets or ports.
- Keep SQL in parameterized queries; prefer helper functions like `callProcedure` for shared patterns.

## Testing Guidelines
- Automated tests are absent; when adding, prefer Jest + Supertest. Name files `*.test.js` under `tests/` or `__tests__/`.
- Cover route status codes, payload validation, and DB interaction with a test database or mocked pool.
- For manual checks, example: `curl -X POST http://localhost:3000/api/login -H "Content-Type: application/json" -d "{\"username\":\"u\",\"password\":\"p\"}"`.
- Track coverage with `--coverage` when Jest is added; aim for critical-path handlers first.

## Commit & Pull Request Guidelines
- Commits: short, imperative subjects (e.g., `Add course stat endpoint`) and include context in the body (DB changes, new env vars, manual test notes).
- PRs: describe behavior changes, affected endpoints, and how to verify (commands or curl examples). Link issues/tasks when available and include screenshots only if UI in `../web` is impacted.
- Keep sensitive files (`.env`, dumps) out of commits; prefer `.env.example` if sharing configuration.

## Configuration & Security Tips
- Required env vars: `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `PORT`. Confirm connectivity with `npm start` then watch for `[db] connected` log.
- Stored procedures/functions (`FN_LOGIN`, `FN_SELECT_COURSE`, `FN_DROP_COURSE`, `PROC_STAT_COURSE_SELECT`) live in the database; align API behavior with their contracts and avoid logging returned secrets.
