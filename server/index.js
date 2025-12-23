import express from 'express';
import cors from 'cors';
import morgan from 'morgan';
import path from 'path';
import crypto from 'crypto';
import { fileURLToPath } from 'url';
import 'dotenv/config';
import { pool, testConnection } from './db.js';

const app = express();
const PORT = process.env.PORT || 3000;
const DEFAULT_TERM = (process.env.DEFAULT_TERM || '').trim() || null;
const AUTH_SECRET = (process.env.AUTH_SECRET || 'dev-secret-change-me').trim();
const ALLOWED_PROCEDURES = new Set(['FN_SELECT_COURSE', 'FN_DROP_COURSE']);
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const webDir = path.join(__dirname, '..', 'web');

app.use(cors({ origin: ['http://localhost:3000', 'http://127.0.0.1:3000', 'http://localhost:5173', 'http://127.0.0.1:5173'] }));
app.use(express.json());
app.use(morgan('dev'));
app.use('/res', express.static(path.join(__dirname, '..', 'res')));
app.use(express.static(webDir));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

function signToken(payload) {
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const sig = crypto.createHmac('sha256', AUTH_SECRET).update(body).digest('base64url');
  return `${body}.${sig}`;
}

function verifyToken(token) {
  if (!token || typeof token !== 'string' || !token.includes('.')) {
    throw new Error('invalid token');
  }
  const [body, sig] = token.split('.');
  const expected = crypto.createHmac('sha256', AUTH_SECRET).update(body).digest('base64url');
  if (expected !== sig) {
    throw new Error('invalid signature');
  }
  const json = Buffer.from(body, 'base64url').toString('utf8');
  return JSON.parse(json);
}

function requireAuth(roles = []) {
  return (req, res, next) => {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) return res.status(401).json({ error: 'unauthorized' });
    try {
      const payload = verifyToken(token);
      if (roles.length && !roles.includes(payload.role)) {
        return res.status(403).json({ error: 'forbidden' });
      }
      req.auth = payload;
      next();
    } catch (err) {
      return res.status(401).json({ error: 'unauthorized' });
    }
  };
}

async function getCurrentTerm() {
  try {
    const { rows } = await pool.query("SELECT param_value AS term FROM tb_sys_param WHERE param_key = 'CURRENT_TERM' LIMIT 1;");
    return rows[0]?.term || null;
  } catch (err) {
    console.error('[term] failed to load CURRENT_TERM', err);
    throw new Error('failed to load current term');
  }
}

async function resolveTerm(providedTerm) {
  const term = (providedTerm ?? '').toString().trim();
  if (term) return term;

  const current = await getCurrentTerm();
  if (current) return current;

  if (DEFAULT_TERM) {
    console.warn('[term] CURRENT_TERM missing, using DEFAULT_TERM fallback');
    return DEFAULT_TERM;
  }

  throw new Error('current term not configured');
}

app.get('/api/config/term', async (_req, res) => {
  try {
    const term = await resolveTerm();
    return res.json({ term });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message || 'failed to fetch term' });
  }
});

// Login: use FN_LOGIN (status checked in DB)
app.post('/api/login', async (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) {
    return res.status(400).json({ error: 'missing credentials' });
  }
  try {
    const { rows } = await pool.query(
      'SELECT user_id, username, role, status, stu_id, tea_id FROM FN_LOGIN($1,$2);',
      [username, password]
    );
    if (!rows.length || rows[0].status !== '1') {
      return res.status(401).json({ error: 'invalid credentials or disabled' });
    }
    const { user_id, role, stu_id, tea_id } = rows[0];
    const term = await resolveTerm();
    const token = signToken({ user_id, role, stu_id, tea_id, username, term, ts: Date.now() });
    const extra = {};
    if (role === 'STUDENT' && stu_id) {
      try {
        const { rows: stuRows } = await pool.query(
          'SELECT stu_name, stu_no FROM tb_student WHERE stu_id = $1;',
          [stu_id]
        );
        if (stuRows[0]) {
          extra.stu_name = stuRows[0].stu_name;
          extra.stu_no = stuRows[0].stu_no;
          extra.real_name = stuRows[0].stu_name;
        }
      } catch (err) {
        console.warn('[login] failed to load student profile', err?.message || err);
      }
    }
    return res.json({ user_id, role, stu_id, tea_id, term, token, ...extra });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'login failed' });
  }
});

// Selectable courses
app.get('/api/courses/selectable', async (req, res) => {
  try {
    const term = await resolveTerm(req.query.term);
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
app.get('/api/courses/my', requireAuth(['STUDENT']), async (req, res) => {
  const stu_id = Number(req.query.stu_id);
  if (!stu_id) return res.status(400).json({ error: 'missing stu_id' });
  if (!req.auth || req.auth.role !== 'STUDENT' || req.auth.stu_id !== stu_id) {
    return res.status(403).json({ error: 'forbidden' });
  }
  try {
    const term = await resolveTerm(req.query.term);
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

// Timetable (per student)
app.get('/api/courses/timetable', requireAuth(['STUDENT']), async (req, res) => {
  const stu_id = Number(req.query.stu_id);
  if (!stu_id) return res.status(400).json({ error: 'missing stu_id' });
  if (!req.auth || req.auth.role !== 'STUDENT' || req.auth.stu_id !== stu_id) {
    return res.status(403).json({ error: 'forbidden' });
  }
  try {
    const term = await resolveTerm(req.query.term);
    const { rows } = await pool.query('SELECT * FROM FN_STUDENT_TIMETABLE($1, $2);', [stu_id, term]);
    return res.json(rows);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'fetch timetable failed' });
  }
});

// Time conflict check before selection
app.get('/api/courses/conflict', requireAuth(['STUDENT']), async (req, res) => {
  const stu_id = Number(req.query.stu_id);
  const course_id = Number(req.query.course_id);
  if (!stu_id || !course_id) return res.status(400).json({ error: 'missing stu_id or course_id' });
  if (!req.auth || req.auth.role !== 'STUDENT' || req.auth.stu_id !== stu_id) {
    return res.status(403).json({ error: 'forbidden' });
  }
  try {
    const term = await resolveTerm(req.query.term);
    const { rows } = await pool.query('SELECT * FROM FN_CHECK_TIME_CONFLICT($1, $2, $3);', [stu_id, course_id, term]);
    return res.json(rows);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'conflict check failed' });
  }
});

// Student profile (basic)
app.get('/api/students/:stu_id', requireAuth(['STUDENT']), async (req, res) => {
  const stu_id = Number(req.params.stu_id);
  if (!stu_id) return res.status(400).json({ error: 'invalid stu_id' });
  if (!req.auth || req.auth.role !== 'STUDENT' || req.auth.stu_id !== stu_id) {
    return res.status(403).json({ error: 'forbidden' });
  }
  try {
    const sql = `
      SELECT s.stu_id,
             s.stu_no,
             s.stu_name,
             s.status AS stu_status,
             u.user_id,
             u.username,
             u.real_name,
             u.status AS user_status
      FROM tb_student s
      JOIN tb_user u ON s.user_id = u.user_id
      WHERE s.stu_id = $1;
    `;
    const { rows } = await pool.query(sql, [stu_id]);
    if (!rows.length) return res.status(404).json({ error: 'student not found' });
    const row = rows[0];
    if (row.stu_status !== '1' || row.user_status !== '1') {
      return res.status(403).json({ error: 'student disabled' });
    }
    return res.json({
      stu_id: row.stu_id,
      stu_no: row.stu_no,
      stu_name: row.stu_name,
      username: row.username,
      real_name: row.real_name,
      user_id: row.user_id,
    });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'fetch student failed' });
  }
});

async function callProcedure(procName, args = []) {
  const normalizedName = (procName || '').toString().toUpperCase();
  if (!ALLOWED_PROCEDURES.has(normalizedName)) {
    throw new Error('procedure not allowed');
  }
  const placeholders = args.map((_, i) => `$${i + 1}`).join(',');
  const sql = `SELECT * FROM ${normalizedName}(${placeholders});`;
  const { rows } = await pool.query(sql, args);
  return rows[0] || { success: false, message: 'no response' };
}

// Select course
app.post('/api/select', requireAuth(['STUDENT']), async (req, res) => {
  const { stu_id, course_id, term } = req.body || {};
  if (!stu_id || !course_id) return res.status(400).json({ error: 'missing stu_id or course_id' });
  if (!req.auth || req.auth.role !== 'STUDENT' || req.auth.stu_id !== stu_id) {
    return res.status(403).json({ error: 'forbidden' });
  }
  try {
    const resolvedTerm = await resolveTerm(term);
    const result = await callProcedure('FN_SELECT_COURSE', [stu_id, course_id, resolvedTerm]);
    return res.status(result.success ? 200 : 400).json(result);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: e.message });
  }
});

// Join waitlist when course is full
app.post('/api/waitlist/join', requireAuth(['STUDENT']), async (req, res) => {
  const { stu_id, course_id, term } = req.body || {};
  if (!stu_id || !course_id) return res.status(400).json({ error: 'missing stu_id or course_id' });
  if (!req.auth || req.auth.role !== 'STUDENT' || req.auth.stu_id !== Number(stu_id)) {
    return res.status(403).json({ error: 'forbidden' });
  }
  try {
    const resolvedTerm = await resolveTerm(term);
    const { rows } = await pool.query('SELECT * FROM FN_JOIN_WAITLIST($1, $2, $3);', [stu_id, course_id, resolvedTerm]);
    const result = rows[0] || { success: false, message: 'join waitlist failed' };
    return res.status(result.success ? 200 : 400).json(result);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: e.message });
  }
});

// My waitlist entries
app.get('/api/waitlist/my', requireAuth(['STUDENT']), async (req, res) => {
  const stu_id = Number(req.query.stu_id);
  if (!stu_id) return res.status(400).json({ error: 'missing stu_id' });
  if (!req.auth || req.auth.role !== 'STUDENT' || req.auth.stu_id !== stu_id) {
    return res.status(403).json({ error: 'forbidden' });
  }
  try {
    const term = await resolveTerm(req.query.term);
    const { rows } = await pool.query('SELECT * FROM FN_WAITLIST_BY_STUDENT($1, $2);', [stu_id, term]);
    return res.json(rows);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'fetch waitlist failed' });
  }
});

// Admin: process waitlist for a course
app.post('/api/waitlist/process', requireAuth(['ADMIN']), async (req, res) => {
  const { course_id, term } = req.body || {};
  if (!course_id) return res.status(400).json({ error: 'missing course_id' });
  try {
    const resolvedTerm = await resolveTerm(term);
    const { rows } = await pool.query('SELECT * FROM FN_PROCESS_WAITLIST($1, $2);', [course_id, resolvedTerm]);
    const result = rows[0] || { success: false, message: 'process failed', processed: 0 };
    return res.status(result.success ? 200 : 400).json(result);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: e.message });
  }
});

// Drop course
app.post('/api/drop', requireAuth(['STUDENT']), async (req, res) => {
  const { stu_id, course_id, term } = req.body || {};
  if (!stu_id || !course_id) return res.status(400).json({ error: 'missing stu_id or course_id' });
  if (!req.auth || req.auth.role !== 'STUDENT' || req.auth.stu_id !== stu_id) {
    return res.status(403).json({ error: 'forbidden' });
  }
  try {
    const resolvedTerm = await resolveTerm(term);
    const result = await callProcedure('FN_DROP_COURSE', [stu_id, course_id, resolvedTerm]);
    return res.status(result.success ? 200 : 400).json(result);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: e.message });
  }
});

// Statistics
app.get('/api/stat', requireAuth(['TEACHER', 'ADMIN']), async (req, res) => {
  try {
    const term = await resolveTerm(req.query.term);
    const { rows } = await pool.query('SELECT * FROM PROC_STAT_COURSE_SELECT($1);', [term]);
    return res.json(rows);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'stat failed' });
  }
});

// Statistics: Top N courses
app.get('/api/stat/top', requireAuth(['TEACHER', 'ADMIN']), async (req, res) => {
  try {
    const term = await resolveTerm(req.query.term);
    const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 10, 1), 50);
    const { rows } = await pool.query('SELECT * FROM FN_STAT_COURSE_TOPN($1, $2);', [term, limit]);
    return res.json(rows);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'stat top failed' });
  }
});

// Statistics: Department distribution
app.get('/api/stat/dept', requireAuth(['TEACHER', 'ADMIN']), async (req, res) => {
  try {
    const term = await resolveTerm(req.query.term);
    const { rows } = await pool.query('SELECT * FROM FN_STAT_DEPT_DISTRIBUTION($1);', [term]);
    return res.json(rows);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'stat dept failed' });
  }
});

// Statistics: selection trend (day/hour)
app.get('/api/stat/trend', requireAuth(['TEACHER', 'ADMIN']), async (req, res) => {
  try {
    const term = await resolveTerm(req.query.term);
    const bucket = (req.query.bucket || 'day').toString().trim().toLowerCase() || 'day';
    const { rows } = await pool.query('SELECT * FROM FN_STAT_SELECT_TREND($1, $2);', [term, bucket]);
    return res.json(rows);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'stat trend failed' });
  }
});

// Export statistics as CSV
app.get('/api/export/stat', requireAuth(['TEACHER', 'ADMIN']), async (req, res) => {
  try {
    const term = await resolveTerm(req.query.term);
    const { rows } = await pool.query('SELECT * FROM PROC_STAT_COURSE_SELECT($1);', [term]);
    const header = ['course_no', 'course_name', 'teacher_name', 'capacity', 'selected_num', 'remaining'];
    const csv = [
      header.join(','),
      ...rows.map(r => header.map(k => {
        const val = r[k] ?? r[k.toUpperCase()];
        if (val === null || val === undefined) return '';
        const str = val.toString().replace(/"/g, '""');
        return `"${str}"`;
      }).join(','))
    ].join('\n');
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="stat_${term || 'current'}.csv"`);
    return res.send(csv);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'export failed' });
  }
});

app.get('/', (_req, res) => {
  res.sendFile(path.join(webDir, 'index.html'));
});

app.use((req, res) => res.status(404).json({ error: 'not found' }));

app.listen(PORT, async () => {
  console.log(`[api] listening on http://localhost:${PORT}`);
  try {
    await testConnection();
  } catch (err) {
    console.error('[db] connection test failed', err?.message || err);
    process.exit(1);
  }
});
