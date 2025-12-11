import pkg from 'pg';

const { Pool } = pkg;

const requiredEnv = ['DB_HOST', 'DB_PORT', 'DB_USER', 'DB_PASSWORD', 'DB_NAME'];
requiredEnv.forEach((key) => {
  if (!process.env[key]) {
    console.warn(`[config] missing env ${key}, check .env`);
  }
});

export const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 54321),
  user: process.env.DB_USER || 'system',
  password: process.env.DB_PASSWORD || '123456',
  database: process.env.DB_NAME || 'course_selection_db',
});

export async function testConnection() {
  const client = await pool.connect();
  try {
    const { rows } = await client.query('SELECT current_database() AS db, current_user AS user');
    console.log(`[db] connected to ${rows[0].db} as ${rows[0].user}`);
  } finally {
    client.release();
  }
}
