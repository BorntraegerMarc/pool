import { GetSecretValueCommand, SecretsManagerClient } from "@aws-sdk/client-secrets-manager";
import { createServer } from "node:http";
import pg from "pg";
const { Client } = pg;

const secretsManagerClient = new SecretsManagerClient({ region: process.env.AWS_REGION });
const secretsManagerCmd = new GetSecretValueCommand({
  SecretId: process.env.DB_SECRET_ARN,
});

console.log("Requesting Secrets Manager");
const secretsManagerRes = await secretsManagerClient.send(secretsManagerCmd);
const dbSecrets = JSON.parse(secretsManagerRes.SecretString);

console.log("Init DB Client");

const dbclient = new Client({
  user: dbSecrets.username,
  password: dbSecrets.password,
  database: "pooldb",
  host: "pooldb.cluster-cak9debc6yeq.us-east-1.rds.amazonaws.com",
});
await dbclient.connect();

console.log("DB Connected!!!");

// Always initialize and seed the DB on container startup. This is for dev purposes only. In prod use a DB migration tool like Flyway.
await dbclient.query(
  "CREATE TABLE IF NOT EXISTS pool_data (id bigint GENERATED ALWAYS AS IDENTITY, data text NOT NULL);"
);
await dbclient.query(
  `INSERT INTO pool_data (data) VALUES ('Default string in DB created at ${new Date().toISOString()}')`
);

console.log("Starting server...");

const server = createServer(async (req, res) => {
  console.log("MS-2 Request received");
  const row = await dbclient.query("SELECT * FROM pool_data LIMIT 1;");

  res.writeHead(200, { "Content-Type": "text/plain" });
  res.end(row.rows[0].data);
});

const port = process.env.PORT || 8000;

server.listen(port, () => {
  console.log(`MS2 Listening on 127.0.0.1:${port}`);
});
