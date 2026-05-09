import { Response, NextFunction } from 'express';
import { matchesService } from './matches.service';
import { AuthRequest } from '../../middleware/auth.middleware';
import { io } from '../../realtime/socket.server';

export const matchesController = {
    async getAll(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const data = await matchesService.getAll(req.query.status as any);
            res.json({ success: true, data });
        } catch (err) { next(err); }
    },

    async getById(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const data = await matchesService.getById(req.params.id);
            res.json({ success: true, data });
        } catch (err) { next(err); }
    },

    async getLive(_req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const data = await matchesService.getLiveMatches();
            res.json({ success: true, data });
        } catch (err) { next(err); }
    },

    async updateScore(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const { homeScore, awayScore } = req.body;
            const data = await matchesService.updateScore(req.params.id, homeScore, awayScore);
            // Broadcast via Socket.IO
            io?.to(`match:${req.params.id}`).emit('match:score_update', {
                matchId: req.params.id, homeScore, awayScore,
            });
            res.json({ success: true, data });
        } catch (err) { next(err); }
    },

    async updateStatus(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const data = await matchesService.updateStatus(req.params.id, req.body.status);
            io?.to(`match:${req.params.id}`).emit('match:status_update', {
                matchId: req.params.id, status: req.body.status,
            });
            res.json({ success: true, data });
        } catch (err) { next(err); }
    },

    async recordEvent(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const data = await matchesService.recordEvent({ match_id: req.params.id, ...req.body });
            io?.to(`match:${req.params.id}`).emit(`match:${req.body.event_type}`, data);
            res.status(201).json({ success: true, data });
        } catch (err) { next(err); }
    },
};
