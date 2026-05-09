import { Request, Response, NextFunction } from 'express';
import { authService } from './auth.service';
import { AuthRequest } from '../../middleware/auth.middleware';

export const authController = {
    async signUp(req: Request, res: Response, next: NextFunction) {
        try {
            const data = await authService.signUp(req.body);
            res.status(201).json({ success: true, data });
        } catch (err) {
            next(err);
        }
    },

    async signIn(req: Request, res: Response, next: NextFunction) {
        try {
            const data = await authService.signIn(req.body);
            res.json({ success: true, data });
        } catch (err) {
            next(err);
        }
    },

    async signOut(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const token = req.headers.authorization?.split(' ')[1] ?? '';
            const data = await authService.signOut(token);
            res.json({ success: true, data });
        } catch (err) {
            next(err);
        }
    },

    async resetPassword(req: Request, res: Response, next: NextFunction) {
        try {
            const { email } = req.body;
            const data = await authService.resetPassword(email);
            res.json({ success: true, data });
        } catch (err) {
            next(err);
        }
    },

    async getProfile(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const data = await authService.getProfile(req.user!.id);
            res.json({ success: true, data });
        } catch (err) {
            next(err);
        }
    },
};
