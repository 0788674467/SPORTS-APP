import { Router } from 'express';
import { analyticsController } from './analytics.controller';

const router = Router();

// All analytics are public (read-only)
router.get('/standings/:fixtureId', analyticsController.getStandings);
router.get('/top-scorers/:fixtureId', analyticsController.getTopScorers);
router.get('/match/:matchId', analyticsController.getMatchStats);

export default router;
