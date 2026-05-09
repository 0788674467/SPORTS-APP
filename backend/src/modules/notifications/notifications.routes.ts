import { Router } from 'express';
import { notificationsService } from './notifications.service';
import { authenticate, requireRole } from '../../middleware/auth.middleware';
import { AuthRequest } from '../../middleware/auth.middleware';
import { Response, NextFunction } from 'express';

const router = Router();

router.get('/', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
    try {
        const unreadOnly = req.query.unread === 'true';
        const data = await notificationsService.getUserNotifications(req.user!.id, unreadOnly);
        res.json({ success: true, data });
    } catch (err) { next(err); }
});

router.patch('/:id/read', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
    try {
        const data = await notificationsService.markAsRead(req.params.id, req.user!.id);
        res.json({ success: true, data });
    } catch (err) { next(err); }
});

router.patch('/read-all', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
    try {
        const data = await notificationsService.markAllAsRead(req.user!.id);
        res.json({ success: true, data });
    } catch (err) { next(err); }
});

// Admin-only: send a broadcast notification
router.post('/send', authenticate, requireRole('admin'), async (req: AuthRequest, res: Response, next: NextFunction) => {
    try {
        const data = await notificationsService.send(req.body);
        res.status(201).json({ success: true, data });
    } catch (err) { next(err); }
});

export default router;
