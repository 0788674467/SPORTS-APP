import { Response, NextFunction } from 'express';
import { fixturesService } from './fixtures.service';
import { AuthRequest } from '../../middleware/auth.middleware';

export const fixturesController = {
    async getAll(_req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const data = await fixturesService.getAll();
            res.json({ success: true, data });
        } catch (err) { next(err); }
    },

    async getById(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const data = await fixturesService.getById(req.params.id);
            res.json({ success: true, data });
        } catch (err) { next(err); }
    },

    async generate(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const data = await fixturesService.generate(req.body);
            res.status(201).json({ success: true, data });
        } catch (err) { next(err); }
    },

    async delete(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const data = await fixturesService.delete(req.params.id);
            res.json({ success: true, data });
        } catch (err) { next(err); }
    },
};
