import { createServer } from "http";
const port = process.env.PORT || 8000;

createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/plain" });
  res.write("Hello, world!");
  res.end();
}).listen(port, () => {
  console.log(`App is running on port ${port}`);
});
