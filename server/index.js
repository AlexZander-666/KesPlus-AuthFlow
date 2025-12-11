import express from 'express';
import cors from 'cors';
import morgan from 'morgan';
import path from 'path';
import { fileURLToPath } from 'url';
import 'dotenv/config';
import { pool, testConnection } from './db.js';

const app = express();
const PORT = process.env.PORT || 3000;
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const webDir = path.join(__dirname, '..', 'web');

app.use(cors({ origin: ['http://localhost:3000', 'http://127.0.0.1:3000', 'http://localhost:5173', 'http://127.0.0.1:5173'] }));
app.use(express.json());
app.use(morgan('dev'));
app.use(express.static(webDir));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

// Login: use FN_LOGIN (status checked in DB)
app.post('/api/login', async (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) {
    return res.status(400).json({ error: 'missing credentials' });
  }
  try {
    const { rows } = await pool.query('SELECT * FROM FN_LOGIN($1,$2);', [username, password]);
    if (!rows.length || rows[0].status !== '1') {
      return res.status(401).json({ error: 'invalid credentials or disabled' });
    }
    const { user_id, role, stu_id, tea_id } = rows[0];
    return res.json({ user_id, role, stu_id, tea_id });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'login failed' });
  }
});

// Selectable courses
app.get('/api/courses/selectable', async (req, res) => {
  const term = req.query.term || '2024-2025-1';
  try {
    const sql = `
      SELECT c.course_id, c.course_no, c.course_name, c.credit, c.capacity, c.selected_num, c.term, t.tea_name
      FROM tb_course c
      LEFT JOIN tb_teacher t ON c.tea_id = t.tea_id
      WHERE c.status='1' AND c.selected_num < c.capacity AND c.term = $1
      ORDER BY c.course_no;`;
    const { rows } = await pool.query(sql, [term]);
    return res.json(rows);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'fetch selectable failed' });
  }
});

// My courses
app.get('/api/courses/my', async (req, res) => {
  const stu_id = Number(req.query.stu_id);
  const term = req.query.term || '2024-2025-1';
  if (!stu_id) return res.status(400).json({ error: 'missing stu_id' });
  try {
    const sql = `
      SELECT sc.course_id, c.course_no, c.course_name, c.credit, sc.status, sc.select_time, sc.drop_time
      FROM tb_student_course sc
      JOIN tb_course c ON sc.course_id = c.course_id
      WHERE sc.stu_id = $1 AND sc.term = $2 AND sc.status = '1';`;
    const { rows } = await pool.query(sql, [stu_id, term]);
    return res.json(rows);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'fetch my courses failed' });
  }
});

async function callProcedure(procName, args = []) {
  const placeholders = args.map((_, i) => `$${i + 1}`).join(',');
  const sql = `SELECT * FROM ${procName}(${placeholders});`;
  const { rows } = await pool.query(sql, args);
  return rows[0] || { success: false, message: 'no response' };
}

// Select course
app.post('/api/select', async (req, res) => {
  const { stu_id, course_id, term } = req.body || {};
  if (!stu_id || !course_id) return res.status(400).json({ error: 'missing stu_id or course_id' });
  try {
    const result = await callProcedure('FN_SELECT_COURSE', [stu_id, course_id, term || null]);
    return res.status(result.success ? 200 : 400).json(result);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: e.message });
  }
});

// Drop course
app.post('/api/drop', async (req, res) => {
  const { stu_id, course_id, term } = req.body || {};
  if (!stu_id || !course_id) return res.status(400).json({ error: 'missing stu_id or course_id' });
  try {
    const result = await callProcedure('FN_DROP_COURSE', [stu_id, course_id, term || null]);
    return res.status(result.success ? 200 : 400).json(result);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: e.message });
  }
});

// Statistics
app.get('/api/stat', async (req, res) => {
  const term = req.query.term || '2024-2025-1';
  try {
    const { rows } = await pool.query('SELECT * FROM PROC_STAT_COURSE_SELECT($1);', [term]);
    return res.json(rows);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'stat failed' });
  }
});

app.get('/', (_req, res) => {
  res.sendFile(path.join(webDir, 'index.html'));
});

app.use((req, res) => res.status(404).json({ error: 'not found' }));

app.listen(PORT, async () => {
  console.log(`[api] listening on http://localhost:${PORT}`);
  await testConnection();
});
