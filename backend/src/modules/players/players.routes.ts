import { Router } from 'express';
import { playersController } from './players.controller';
import { authenticate, requireRole } from '../../middleware/auth.middleware';

const router = Router();

router.get('/', playersController.getAll);
router.get('/:id', playersController.getById);
router.get('/:id/stats', playersController.getStats);
router.post('/', authenticate, requireRole('admin', 'coach'), playersController.create);
router.put('/:id', authenticate, requireRole('admin', 'coach'), playersController.update);
router.delete('/:id', authenticate, requireRole('admin'), playersController.delete);

export default router;
