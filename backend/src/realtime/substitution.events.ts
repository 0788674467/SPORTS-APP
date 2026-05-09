import { Server, Socket } from 'socket.io';

export const registerSubstitutionEvents = (io: Server, socket: Socket) => {
    // Coach requests a substitution
    socket.on(
        'sub:request',
        (data: { matchId: string; playerOutId: string; playerInId: string; minute: number }) => {
            // Broadcast to the match room and to referees monitoring the match
            io.to(`match:${data.matchId}`).emit('sub:request', data);
        }
    );

    // Referee approves / confirms the substitution
    socket.on(
        'sub:confirm',
        (data: { matchId: string; playerOutId: string; playerInId: string; minute: number }) => {
            io.to(`match:${data.matchId}`).emit('sub:confirm', data);
        }
    );
};
