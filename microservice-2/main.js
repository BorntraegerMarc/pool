import { GetSecretValueCommand, SecretsManagerClient } from "@aws-sdk/client-secrets-manager";
import { createServer } from "node:http";

const client = new SecretsManagerClient({ region: process.env.AWS_REGION });
const command = new GetSecretValueCommand({
  SecretId: process.env.DB_SECRET_ARN,
});
const response = await client.send(command);

console.log("DB Secrets: ", response.SecretString);
const secret = JSON.parse(response.SecretString);
console.log("DB username: ", secret.username);
console.log("DB password: ", secret.password);

const server = createServer(async (req, res) => {
  console.log("MS-2 Request received");
  res.writeHead(200, { "Content-Type": "text/plain" });
  res.end("Hello World from MS-2!");
});

const port = process.env.PORT || 8000;

server.listen(port, () => {
  console.log(`MS2 Listening on 127.0.0.1:${port}`);
});
