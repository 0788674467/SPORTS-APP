import { Response, NextFunction } from 'express';
import { teamsService } from './teams.service';
import { AuthRequest } from '../../middleware/auth.middleware';

export const teamsController = {
    async getAll(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const data = await teamsService.getAll();
            res.json({ success: true, data });
        } catch (err) { next(err); }
    },

    async getById(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const data = await teamsService.getById(req.params.id);
            res.json({ success: true, data });
        } catch (err) { next(err); }
    },

    async create(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const data = await teamsService.create(req.body);
            res.status(201).json({ success: true, data });
        } catch (err) { next(err); }
    },

    async update(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const data = await teamsService.update(req.params.id, req.body);
            res.json({ success: true, data });
        } catch (err) { next(err); }
    },

    async delete(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const data = await teamsService.delete(req.params.id);
            res.json({ success: true, data });
        } catch (err) { next(err); }
    },
};
