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
const AUTH_SECRET = (process.env.AUTH_SECRET || '').trim();
if (!AUTH_SECRET) {
  throw new Error('[config] missing AUTH_SECRET (copy server/.env.example to server/.env and set a strong secret)');
}
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


// ==================== 管理员 API ====================

// 用户管理：获取用户列表
app.get('/api/users', requireAuth(['ADMIN']), async (req, res) => {
  try {
    const sql = `
      SELECT u.user_id, u.username, u.real_name, u.role, u.status, u.email, u.mobile, u.create_time,
             s.stu_id, s.stu_no, s.stu_name,
             t.tea_id, t.tea_no, t.tea_name
      FROM tb_user u
      LEFT JOIN tb_student s ON u.user_id = s.user_id
      LEFT JOIN tb_teacher t ON u.user_id = t.user_id
      ORDER BY u.user_id;`;
    const { rows } = await pool.query(sql);
    return res.json(rows);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'fetch users failed' });
  }
});

// 用户管理：新增用户
app.post('/api/users', requireAuth(['ADMIN']), async (req, res) => {
  const { username, password, real_name, role, email, mobile } = req.body || {};
  if (!username || !password || !role) {
    return res.status(400).json({ error: 'missing required fields' });
  }
  if (!['ADMIN', 'TEACHER', 'STUDENT'].includes(role)) {
    return res.status(400).json({ error: 'invalid role' });
  }
  try {
    const sql = `
      INSERT INTO tb_user (username, password_hash, real_name, role, status, email, mobile)
      VALUES ($1, FN_HASH_PASSWORD($2), $3, $4, '1', $5, $6)
      RETURNING user_id, username, real_name, role, status, email, mobile;`;
    const { rows } = await pool.query(sql, [username, password, real_name, role, email, mobile]);
    return res.status(201).json(rows[0]);
  } catch (e) {
    console.error(e);
    if (e.code === '23505') {
      return res.status(409).json({ error: 'username already exists' });
    }
    return res.status(500).json({ error: 'create user failed' });
  }
});

// 用户管理：更新用户
app.put('/api/users/:id', requireAuth(['ADMIN']), async (req, res) => {
  const user_id = Number(req.params.id);
  const { real_name, email, mobile, status } = req.body || {};
  if (!user_id) return res.status(400).json({ error: 'invalid user_id' });
  try {
    const updates = [];
    const values = [];
    let idx = 1;
    if (real_name !== undefined) { updates.push(`real_name = $${idx++}`); values.push(real_name); }
    if (email !== undefined) { updates.push(`email = $${idx++}`); values.push(email); }
    if (mobile !== undefined) { updates.push(`mobile = $${idx++}`); values.push(mobile); }
    if (status !== undefined) { updates.push(`status = $${idx++}`); values.push(status); }
    if (!updates.length) return res.status(400).json({ error: 'no fields to update' });
    values.push(user_id);
    const sql = `UPDATE tb_user SET ${updates.join(', ')} WHERE user_id = $${idx} RETURNING *;`;
    const { rows } = await pool.query(sql, values);
    if (!rows.length) return res.status(404).json({ error: 'user not found' });
    return res.json(rows[0]);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'update user failed' });
  }
});

// 用户管理：删除用户（软删除，设置status=0）
app.delete('/api/users/:id', requireAuth(['ADMIN']), async (req, res) => {
  const user_id = Number(req.params.id);
  if (!user_id) return res.status(400).json({ error: 'invalid user_id' });
  try {
    const sql = `UPDATE tb_user SET status = '0' WHERE user_id = $1 RETURNING user_id, username, status;`;
    const { rows } = await pool.query(sql, [user_id]);
    if (!rows.length) return res.status(404).json({ error: 'user not found' });
    return res.json({ message: 'user disabled', user: rows[0] });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'delete user failed' });
  }
});

// 课程管理：获取所有课程
app.get('/api/courses', requireAuth(['ADMIN', 'TEACHER']), async (req, res) => {
  try {
    const term = req.query.term ? await resolveTerm(req.query.term) : null;
    let sql = `
      SELECT c.course_id, c.course_no, c.course_name, c.course_type, c.credit, c.period,
             c.capacity, c.selected_num, c.term, c.status, c.course_desc,
             c.day_of_week, c.start_slot, c.end_slot, c.location,
             d.dept_name, t.tea_name, t.tea_no
      FROM tb_course c
      LEFT JOIN tb_department d ON c.dept_id = d.dept_id
      LEFT JOIN tb_teacher t ON c.tea_id = t.tea_id`;
    const params = [];
    if (term) {
      sql += ' WHERE c.term = $1';
      params.push(term);
    }
    sql += ' ORDER BY c.course_no;';
    const { rows } = await pool.query(sql, params);
    return res.json(rows);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'fetch courses failed' });
  }
});

// 课程管理：新增课程
app.post('/api/courses', requireAuth(['ADMIN']), async (req, res) => {
  const { course_no, course_name, course_type, credit, period, dept_id, tea_id, term, capacity, course_desc, day_of_week, start_slot, end_slot, location } = req.body || {};
  if (!course_no || !course_name || !dept_id || !tea_id || !term || !capacity) {
    return res.status(400).json({ error: 'missing required fields' });
  }
  try {
    const sql = `
      INSERT INTO tb_course (course_no, course_name, course_type, credit, period, dept_id, tea_id, term, capacity, selected_num, course_desc, status, day_of_week, start_slot, end_slot, location)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 0, $10, '1', $11, $12, $13, $14)
      RETURNING *;`;
    const { rows } = await pool.query(sql, [course_no, course_name, course_type, credit, period, dept_id, tea_id, term, capacity, course_desc, day_of_week, start_slot, end_slot, location]);
    
    // 如果有时间信息，同时插入到 TB_COURSE_TIME
    if (rows[0] && day_of_week && start_slot && end_slot) {
      await pool.query(
        'INSERT INTO tb_course_time (course_id, term, day_of_week, start_slot, end_slot, location) VALUES ($1, $2, $3, $4, $5, $6);',
        [rows[0].course_id, term, day_of_week, start_slot, end_slot, location]
      );
    }
    
    return res.status(201).json(rows[0]);
  } catch (e) {
    console.error(e);
    if (e.code === '23505') {
      return res.status(409).json({ error: 'course already exists' });
    }
    return res.status(500).json({ error: 'create course failed' });
  }
});

// 课程管理：更新课程
app.put('/api/courses/:id', requireAuth(['ADMIN']), async (req, res) => {
  const course_id = Number(req.params.id);
  const { course_name, course_type, credit, period, capacity, course_desc, status, day_of_week, start_slot, end_slot, location } = req.body || {};
  if (!course_id) return res.status(400).json({ error: 'invalid course_id' });
  try {
    const updates = [];
    const values = [];
    let idx = 1;
    if (course_name !== undefined) { updates.push(`course_name = $${idx++}`); values.push(course_name); }
    if (course_type !== undefined) { updates.push(`course_type = $${idx++}`); values.push(course_type); }
    if (credit !== undefined) { updates.push(`credit = $${idx++}`); values.push(credit); }
    if (period !== undefined) { updates.push(`period = $${idx++}`); values.push(period); }
    if (capacity !== undefined) { updates.push(`capacity = $${idx++}`); values.push(capacity); }
    if (course_desc !== undefined) { updates.push(`course_desc = $${idx++}`); values.push(course_desc); }
    if (status !== undefined) { updates.push(`status = $${idx++}`); values.push(status); }
    if (day_of_week !== undefined) { updates.push(`day_of_week = $${idx++}`); values.push(day_of_week); }
    if (start_slot !== undefined) { updates.push(`start_slot = $${idx++}`); values.push(start_slot); }
    if (end_slot !== undefined) { updates.push(`end_slot = $${idx++}`); values.push(end_slot); }
    if (location !== undefined) { updates.push(`location = $${idx++}`); values.push(location); }
    if (!updates.length) return res.status(400).json({ error: 'no fields to update' });
    values.push(course_id);
    const sql = `UPDATE tb_course SET ${updates.join(', ')} WHERE course_id = $${idx} RETURNING *;`;
    const { rows } = await pool.query(sql, values);
    if (!rows.length) return res.status(404).json({ error: 'course not found' });
    return res.json(rows[0]);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'update course failed' });
  }
});

// 课程管理：删除课程（软删除）
app.delete('/api/courses/:id', requireAuth(['ADMIN']), async (req, res) => {
  const course_id = Number(req.params.id);
  if (!course_id) return res.status(400).json({ error: 'invalid course_id' });
  try {
    const sql = `UPDATE tb_course SET status = '0' WHERE course_id = $1 RETURNING course_id, course_no, course_name, status;`;
    const { rows } = await pool.query(sql, [course_id]);
    if (!rows.length) return res.status(404).json({ error: 'course not found' });
    return res.json({ message: 'course disabled', course: rows[0] });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'delete course failed' });
  }
});

// 学院管理：获取学院列表
app.get('/api/departments', async (_req, res) => {
  try {
    const sql = `SELECT dept_id, dept_code, dept_name, status FROM tb_department ORDER BY dept_id;`;
    const { rows } = await pool.query(sql);
    return res.json(rows);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'fetch departments failed' });
  }
});

// 专业管理：获取专业列表
app.get('/api/majors', async (req, res) => {
  try {
    const dept_id = req.query.dept_id ? Number(req.query.dept_id) : null;
    let sql = `
      SELECT m.major_id, m.major_code, m.major_name, m.dept_id, m.status, d.dept_name
      FROM tb_major m
      LEFT JOIN tb_department d ON m.dept_id = d.dept_id`;
    const params = [];
    if (dept_id) {
      sql += ' WHERE m.dept_id = $1';
      params.push(dept_id);
    }
    sql += ' ORDER BY m.major_id;';
    const { rows } = await pool.query(sql, params);
    return res.json(rows);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'fetch majors failed' });
  }
});

// 系统参数：获取所有参数
app.get('/api/config', requireAuth(['ADMIN']), async (_req, res) => {
  try {
    const sql = `SELECT param_key, param_value, param_value_ts, remark FROM tb_sys_param ORDER BY param_key;`;
    const { rows } = await pool.query(sql);
    return res.json(rows);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'fetch config failed' });
  }
});

// 系统参数：更新参数
app.put('/api/config/:key', requireAuth(['ADMIN']), async (req, res) => {
  const param_key = req.params.key;
  const { param_value, param_value_ts } = req.body || {};
  if (!param_key) return res.status(400).json({ error: 'invalid param_key' });
  try {
    const sql = `
      UPDATE tb_sys_param 
      SET param_value = $1, param_value_ts = $2
      WHERE param_key = $3
      RETURNING *;`;
    const { rows } = await pool.query(sql, [param_value, param_value_ts, param_key]);
    if (!rows.length) {
      // 如果不存在则插入
      const insertSql = `INSERT INTO tb_sys_param (param_key, param_value, param_value_ts) VALUES ($1, $2, $3) RETURNING *;`;
      const { rows: insertRows } = await pool.query(insertSql, [param_key, param_value, param_value_ts]);
      return res.status(201).json(insertRows[0]);
    }
    return res.json(rows[0]);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'update config failed' });
  }
});

// ==================== 教师 API ====================

// 教师：获取课程选课学生名单
app.get('/api/courses/:id/students', requireAuth(['TEACHER', 'ADMIN']), async (req, res) => {
  const course_id = Number(req.params.id);
  if (!course_id) return res.status(400).json({ error: 'invalid course_id' });
  try {
    const term = await resolveTerm(req.query.term);
    const sql = `
      SELECT sc.sc_id, sc.stu_id, sc.select_time, sc.grade, sc.status,
             s.stu_no, s.stu_name, s.gender, s.grade AS stu_grade,
             d.dept_name, m.major_name
      FROM tb_student_course sc
      JOIN tb_student s ON sc.stu_id = s.stu_id
      LEFT JOIN tb_department d ON s.dept_id = d.dept_id
      LEFT JOIN tb_major m ON s.major_id = m.major_id
      WHERE sc.course_id = $1 AND sc.term = $2 AND sc.status = '1'
      ORDER BY s.stu_no;`;
    const { rows } = await pool.query(sql, [course_id, term]);
    return res.json(rows);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'fetch students failed' });
  }
});

// 教师：录入/更新成绩
app.put('/api/grades/:sc_id', requireAuth(['TEACHER', 'ADMIN']), async (req, res) => {
  const sc_id = Number(req.params.sc_id);
  const { grade } = req.body || {};
  if (!sc_id) return res.status(400).json({ error: 'invalid sc_id' });
  if (grade === undefined || grade === null) return res.status(400).json({ error: 'missing grade' });
  if (grade < 0 || grade > 100) return res.status(400).json({ error: 'grade must be between 0 and 100' });
  try {
    const sql = `UPDATE tb_student_course SET grade = $1 WHERE sc_id = $2 RETURNING *;`;
    const { rows } = await pool.query(sql, [grade, sc_id]);
    if (!rows.length) return res.status(404).json({ error: 'record not found' });
    return res.json(rows[0]);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'update grade failed' });
  }
});

// 教师：获取教师信息
app.get('/api/teachers/:id', requireAuth(['TEACHER', 'ADMIN']), async (req, res) => {
  const tea_id = Number(req.params.id);
  if (!tea_id) return res.status(400).json({ error: 'invalid tea_id' });
  try {
    const sql = `
      SELECT t.tea_id, t.tea_no, t.tea_name, t.gender, t.title, t.mobile, t.email, t.status,
             d.dept_name, u.username, u.real_name
      FROM tb_teacher t
      LEFT JOIN tb_department d ON t.dept_id = d.dept_id
      LEFT JOIN tb_user u ON t.user_id = u.user_id
      WHERE t.tea_id = $1;`;
    const { rows } = await pool.query(sql, [tea_id]);
    if (!rows.length) return res.status(404).json({ error: 'teacher not found' });
    return res.json(rows[0]);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'fetch teacher failed' });
  }
});

// 教师：获取我的授课课程
app.get('/api/teachers/:id/courses', requireAuth(['TEACHER', 'ADMIN']), async (req, res) => {
  const tea_id = Number(req.params.id);
  if (!tea_id) return res.status(400).json({ error: 'invalid tea_id' });
  try {
    const term = req.query.term ? await resolveTerm(req.query.term) : null;
    let sql = `
      SELECT c.course_id, c.course_no, c.course_name, c.course_type, c.credit,
             c.capacity, c.selected_num, c.term, c.status
      FROM tb_course c
      WHERE c.tea_id = $1`;
    const params = [tea_id];
    if (term) {
      sql += ' AND c.term = $2';
      params.push(term);
    }
    sql += ' ORDER BY c.course_no;';
    const { rows } = await pool.query(sql, params);
    return res.json(rows);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'fetch teacher courses failed' });
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
