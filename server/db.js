import pkg from 'pg';

const { Pool } = pkg;

const requiredEnv = ['DB_HOST', 'DB_PORT', 'DB_USER', 'DB_PASSWORD', 'DB_NAME'];
const missingEnv = requiredEnv.filter((key) => !process.env[key] || !process.env[key].toString().trim());
if (missingEnv.length) {
  throw new Error(`[config] missing env: ${missingEnv.join(', ')} (copy server/.env.example to server/.env and fill in values)`);
}

const port = Number(process.env.DB_PORT);
if (!Number.isFinite(port) || port <= 0) {
  throw new Error('[config] DB_PORT must be a positive number');
}

export const pool = new Pool({
  host: process.env.DB_HOST,
  port,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
});

export async function testConnection() {
  let client;
  try {
    client = await pool.connect();
    const { rows } = await client.query('SELECT current_database() AS db, current_user AS user');
    console.log(`[db] connected to ${rows[0].db} as ${rows[0].user}`);
  } catch (err) {
    console.error('[db] connection test failed', err?.message || err);
    throw err;
  } finally {
    if (client) client.release();
  }
}
