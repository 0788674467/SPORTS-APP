import { Response, NextFunction } from 'express';
import { playersService } from './players.service';
import { AuthRequest } from '../../middleware/auth.middleware';

export const playersController = {
    async getAll(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const data = await playersService.getAll(req.query.teamId as string);
            res.json({ success: true, data });
        } catch (err) { next(err); }
    },

    async getById(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const data = await playersService.getById(req.params.id);
            res.json({ success: true, data });
        } catch (err) { next(err); }
    },

    async create(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const data = await playersService.create(req.body);
            res.status(201).json({ success: true, data });
        } catch (err) { next(err); }
    },

    async update(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const data = await playersService.update(req.params.id, req.body);
            res.json({ success: true, data });
        } catch (err) { next(err); }
    },

    async delete(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const data = await playersService.delete(req.params.id);
            res.json({ success: true, data });
        } catch (err) { next(err); }
    },

    async getStats(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const data = await playersService.getStats(req.params.id);
            res.json({ success: true, data });
        } catch (err) { next(err); }
    },
};
