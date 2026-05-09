import { Response, NextFunction } from 'express';
import { analyticsService } from './analytics.service';
import { AuthRequest } from '../../middleware/auth.middleware';

export const analyticsController = {
    async getStandings(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const data = await analyticsService.getStandings(req.params.fixtureId);
            res.json({ success: true, data });
        } catch (err) { next(err); }
    },

    async getTopScorers(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const limit = req.query.limit ? parseInt(req.query.limit as string) : 10;
            const data = await analyticsService.getTopScorers(req.params.fixtureId, limit);
            res.json({ success: true, data });
        } catch (err) { next(err); }
    },

    async getMatchStats(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const data = await analyticsService.getMatchStats(req.params.matchId);
            res.json({ success: true, data });
        } catch (err) { next(err); }
    },
};
