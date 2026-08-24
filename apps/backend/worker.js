const http = require("http");
const { Pool } = require("pg");
const { SQSClient, ReceiveMessageCommand, DeleteMessageCommand } = require("@aws-sdk/client-sqs");

// Same DB connection pattern as index.js - DB credentials are injected via
// a Kubernetes secret (synced from AWS Secrets Manager), never hardcoded.
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl: { rejectUnauthorized: true },
});

const sqs = new SQSClient({ region: process.env.AWS_REGION });
const queueUrl = process.env.SQS_QUEUE_URL;

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

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function processMessage(message) {
  const body = JSON.parse(message.Body);
  console.log(`Processing job ${body.id}`);

  // Simulated work - deliberately slow enough (1-3s) to make KEDA's
  // scale-up visible when a burst of jobs lands at once.
  await sleep(1000 + Math.random() * 2000);

  await pool.query("UPDATE job_runs SET status = 'done', processed_at = now() WHERE id = $1", [
    body.id,
  ]);

  await sqs.send(
    new DeleteMessageCommand({
      QueueUrl: queueUrl,
      ReceiptHandle: message.ReceiptHandle,
    })
  );

  console.log(`Completed job ${body.id}`);
}

async function pollLoop() {
  for (;;) {
    try {
      const result = await sqs.send(
        new ReceiveMessageCommand({
          QueueUrl: queueUrl,
          MaxNumberOfMessages: 5,
          WaitTimeSeconds: 20,
        })
      );

      const messages = result.Messages || [];
      for (const message of messages) {
        // Failures here are deliberately left unhandled beyond the log -
        // the message is not deleted, so SQS redelivers it after the
        // visibility timeout (and eventually routes it to the DLQ after
        // maxReceiveCount). No dead-letter consumption logic for this
        // demo-grade worker.
        await processMessage(message).catch((err) =>
          console.error(`Failed to process message ${message.MessageId}`, err)
        );
      }
    } catch (err) {
      console.error("Poll loop error, retrying", err);
      await sleep(5000);
    }
  }
}

// A bare poll loop gives Kubernetes no way to detect a hung worker - this
// tiny server exists solely so the Deployment has something to point a
// liveness probe at.
function startHealthServer() {
  const server = http.createServer((req, res) => {
    if (req.url === "/health") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ status: "ok" }));
      return;
    }
    res.writeHead(404);
    res.end();
  });
  server.listen(process.env.PORT || 8081, () => {
    console.log(`Worker health server listening on port ${process.env.PORT || 8081}`);
  });
}

ensureJobsTable()
  .then(() => {
    startHealthServer();
    console.log("Worker started, polling for jobs");
    return pollLoop();
  })
  .catch((err) => {
    console.error("Failed to initialize worker", err);
    process.exit(1);
  });
