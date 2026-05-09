import http from 'http';
import app from './app';
import { env } from './config/env';
import { initSocket } from './realtime/socket.server';

const server = http.createServer(app);

// Attach Socket.IO
initSocket(server);

server.listen(env.port, () => {
    console.log(`🚀 Server running on http://localhost:${env.port}`);
    console.log(`📦 Environment: ${env.nodeEnv}`);
});
