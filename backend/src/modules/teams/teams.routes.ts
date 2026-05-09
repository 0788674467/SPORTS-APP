import { Router } from 'express';
import { teamsController } from './teams.controller';
import { authenticate, requireRole } from '../../middleware/auth.middleware';

const router = Router();

router.get('/', teamsController.getAll);
router.get('/:id', teamsController.getById);
router.post('/', authenticate, requireRole('admin'), teamsController.create);
router.put('/:id', authenticate, requireRole('admin'), teamsController.update);
router.delete('/:id', authenticate, requireRole('admin'), teamsController.delete);

export default router;
