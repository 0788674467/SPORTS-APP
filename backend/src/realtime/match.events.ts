import { Server, Socket } from 'socket.io';

export const registerMatchEvents = (io: Server, socket: Socket) => {
    // Join a match room to receive live updates
    socket.on('match:join', (matchId: string) => {
        socket.join(`match:${matchId}`);
        console.log(`Socket ${socket.id} joined match room: match:${matchId}`);
    });

    // Leave a match room
    socket.on('match:leave', (matchId: string) => {
        socket.leave(`match:${matchId}`);
    });

    // Broadcast a goal event to a match room
    socket.on('match:goal', (data: { matchId: string; teamId: string; playerId: string; minute: number }) => {
        io.to(`match:${data.matchId}`).emit('match:goal', data);
    });

    // Broadcast a card event
    socket.on('match:card', (data: { matchId: string; playerId: string; type: 'yellow' | 'red'; minute: number }) => {
        io.to(`match:${data.matchId}`).emit('match:card', data);
    });

    // Broadcast score update
    socket.on('match:score_update', (data: { matchId: string; homeScore: number; awayScore: number }) => {
        io.to(`match:${data.matchId}`).emit('match:score_update', data);
    });
};
