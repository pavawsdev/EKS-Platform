const { Pool } = require("pg");

// Same DB connection pattern as index.js/worker.js - DB credentials are
// injected via a Kubernetes secret (synced from AWS Secrets Manager),
// never hardcoded.
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl: { rejectUnauthorized: true },
});

// Runs as a Kubernetes CronJob, not a long-lived process - unlike
// worker.js's poll loop, this must exit (process.exit(0)) for the Job to
// reach Complete. No SQS interaction here at all, so it needs no SQS IAM
// permissions - just the same Postgres access backend/worker already have.
async function run() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS heartbeats (
      id serial PRIMARY KEY,
      ran_at timestamptz NOT NULL DEFAULT now()
    )
  `);

  await pool.query("INSERT INTO heartbeats (ran_at) VALUES (now())");

  const cleanup = await pool.query(
    "DELETE FROM job_runs WHERE status = 'done' AND processed_at < now() - interval '1 hour'"
  );

  console.log(`Heartbeat recorded, cleaned up ${cleanup.rowCount} old job_runs rows`);
}

run()
  .then(() => pool.end())
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("Cron run failed", err);
    process.exit(1);
  });
