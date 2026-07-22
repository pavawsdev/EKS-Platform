const express = require("express");
const helmet = require("helmet");
const cors = require("cors");
const { Pool } = require("pg");

const app = express();
const port = process.env.PORT || 8080;

app.use(helmet());
app.use(cors());
app.use(express.json());

// DB credentials are injected via a Kubernetes secret (synced from
// AWS Secrets Manager, see rds module output), never hardcoded here.
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl: { rejectUnauthorized: true },
});

app.get("/health", (_req, res) => {
  res.status(200).json({ status: "ok" });
});

app.get("/ready", async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    res.status(200).json({ status: "ready" });
  } catch (err) {
    res.status(503).json({ status: "not-ready", error: err.message });
  }
});

app.get("/api/items", async (_req, res) => {
  try {
    const result = await pool.query("SELECT NOW() as server_time");
    res.json({ message: "Hello from the backend", serverTime: result.rows[0].server_time });
  } catch (err) {
    res.status(500).json({ error: "Database query failed" });
  }
});

app.listen(port, () => {
  console.log(`Backend listening on port ${port}`);
});
