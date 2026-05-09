import { Router } from 'express';
import { matchesController } from './matches.controller';
import { authenticate, requireRole } from '../../middleware/auth.middleware';

const router = Router();

router.get('/', matchesController.getAll);
router.get('/live', matchesController.getLive);
router.get('/:id', matchesController.getById);
router.patch('/:id/score', authenticate, requireRole('referee'), matchesController.updateScore);
router.patch('/:id/status', authenticate, requireRole('referee', 'admin'), matchesController.updateStatus);
router.post('/:id/events', authenticate, requireRole('referee'), matchesController.recordEvent);

export default router;
