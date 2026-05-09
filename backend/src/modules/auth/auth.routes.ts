import { Router } from 'express';
import { authController } from './auth.controller';
import { authenticate } from '../../middleware/auth.middleware';

const router = Router();

// Public
router.post('/signup', authController.signUp);
router.post('/signin', authController.signIn);
router.post('/reset-password', authController.resetPassword);

// Protected
router.post('/signout', authenticate, authController.signOut);
router.get('/profile', authenticate, authController.getProfile);

export default router;
