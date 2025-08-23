const http = require('http');
const version = process.env.PLACEHOLDER_VERSION || 'v0.0.0';
const started = new Date();

const server = http.createServer((req, res) => {
	if (req.url === '/version.txt') {
		res.writeHead(200, { 'Content-Type': 'text/plain' });
		res.end(version + '\n');
		return;
	}
	res.writeHead(200, { 'Content-Type': 'text/plain' });
	res.end(`[placeholder] Central backend absent. Uptime: ${Math.round((Date.now()-started.getTime())/1000)}s\n`);
});

server.listen(8383, () => {
	console.log('[placeholder server] listening on 8383, version', version);
});
