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

const res2 = await dbclient.query("select * from information_schema.tables;");

console.log("DB Query nr. of rows: ", res2.rowCount);

console.log("Starting server...");
const server = createServer(async (req, res) => {
  console.log("MS-2 Request received");
  res.writeHead(200, { "Content-Type": "text/plain" });
  res.end("Hello World from MS-2!");
});

const port = process.env.PORT || 8000;

server.listen(port, () => {
  console.log(`MS2 Listening on 127.0.0.1:${port}`);
});
