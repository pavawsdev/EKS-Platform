const crypto = require("crypto");
const express = require("express");
const helmet = require("helmet");
const cors = require("cors");
const { Pool } = require("pg");
const { SQSClient, SendMessageCommand, GetQueueAttributesCommand } = require("@aws-sdk/client-sqs");

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

// Credentials resolve via the default chain (IRSA - AWS_ROLE_ARN /
// AWS_WEB_IDENTITY_TOKEN_FILE are injected onto the pod's service account).
const sqs = new SQSClient({ region: process.env.AWS_REGION });
const queueUrl = process.env.SQS_QUEUE_URL;

// No migration framework in this repo - idempotent IF NOT EXISTS matches
// the rest of the app's simplicity. worker.js runs the same statement.
async function ensureJobsTable() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS job_runs (
      id text PRIMARY KEY,
      payload jsonb,
      status text NOT NULL,
      received_at timestamptz NOT NULL DEFAULT now(),
      processed_at timestamptz
    )
  `);
}

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

// Enqueues a job and returns immediately - worker.js (a separate
// KEDA-scaled deployment) picks it up asynchronously. Point Postman/curl
// at this repeatedly to build up queue depth and watch KEDA scale workers
// from zero.
app.post("/api/jobs", async (req, res) => {
  const id = crypto.randomUUID();
  const payload = req.body ?? {};
  try {
    await pool.query("INSERT INTO job_runs (id, payload, status) VALUES ($1, $2, 'queued')", [
      id,
      payload,
    ]);
    const result = await sqs.send(
      new SendMessageCommand({
        QueueUrl: queueUrl,
        MessageBody: JSON.stringify({ id, payload }),
      })
    );
    res.status(202).json({ jobId: id, sqsMessageId: result.MessageId });
  } catch (err) {
    res.status(500).json({ error: "Failed to enqueue job", detail: err.message });
  }
});

app.get("/api/jobs/:id", async (req, res) => {
  try {
    const result = await pool.query("SELECT * FROM job_runs WHERE id = $1", [req.params.id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Job not found" });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: "Database query failed" });
  }
});

// Demo hook for watching queue depth rise (as Postman fires jobs) and
// fall (as KEDA-scaled workers drain it).
app.get("/api/queue-stats", async (_req, res) => {
  try {
    const result = await sqs.send(
      new GetQueueAttributesCommand({
        QueueUrl: queueUrl,
        AttributeNames: ["ApproximateNumberOfMessages", "ApproximateNumberOfMessagesNotVisible"],
      })
    );
    res.json({
      visible: Number(result.Attributes.ApproximateNumberOfMessages),
      inFlight: Number(result.Attributes.ApproximateNumberOfMessagesNotVisible),
    });
  } catch (err) {
    res.status(500).json({ error: "Failed to read queue stats", detail: err.message });
  }
});

ensureJobsTable()
  .then(() => {
    app.listen(port, () => {
      console.log(`Backend listening on port ${port}`);
    });
  })
  .catch((err) => {
    console.error("Failed to initialize job_runs table", err);
    process.exit(1);
  });
