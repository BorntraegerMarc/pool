import axios from "axios";
import { createServer } from "node:http";

const server = createServer(async (req, res) => {
  console.log("MS-1 Request received");
  const ms2Res = await axios.get("http://service-ms2.pool.svc.cluster.local");
  res.writeHead(200, { "Content-Type": "text/plain" });
  res.end(ms2Res.data);
});

const port = process.env.PORT || 8000;

server.listen(port, () => {
  console.log(`MS1 Listening on 127.0.0.1:${port}`);
});
