import { createServer } from "node:http";

const server = createServer(async (req, res) => {
  console.log("MS-2 Request received");
  res.writeHead(200, { "Content-Type": "text/plain" });
  res.end("Hello World from MS-2!");
});

const port = process.env.PORT || 8000;

server.listen(port, () => {
  console.log(`MS2 Listening on 127.0.0.1:${port}`);
});
