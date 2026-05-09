import { Router } from 'express';
import { fixturesController } from './fixtures.controller';
import { authenticate, requireRole } from '../../middleware/auth.middleware';

const router = Router();

router.get('/', fixturesController.getAll);
router.get('/:id', fixturesController.getById);
router.post('/generate', authenticate, requireRole('admin'), fixturesController.generate);
router.delete('/:id', authenticate, requireRole('admin'), fixturesController.delete);

export default router;
