import { Server as HttpServer } from 'http';
import { Server as SocketIOServer } from 'socket.io';
import { registerMatchEvents } from './match.events';
import { registerSubstitutionEvents } from './substitution.events';

export let io: SocketIOServer;

export const initSocket = (httpServer: HttpServer) => {
    io = new SocketIOServer(httpServer, {
        cors: { origin: '*', methods: ['GET', 'POST'] },
    });

    io.on('connection', (socket) => {
        console.log(`⚡ Socket connected: ${socket.id}`);

        registerMatchEvents(io, socket);
        registerSubstitutionEvents(io, socket);

        socket.on('disconnect', () => {
            console.log(`❌ Socket disconnected: ${socket.id}`);
        });
    });

    return io;
};
