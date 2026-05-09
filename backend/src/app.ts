import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { errorMiddleware } from './middleware/error.middleware';

// Route imports
import authRoutes from './modules/auth/auth.routes';
import teamRoutes from './modules/teams/teams.routes';
import playerRoutes from './modules/players/players.routes';
import fixtureRoutes from './modules/fixtures/fixtures.routes';
import matchRoutes from './modules/matches/matches.routes';
import analyticsRoutes from './modules/analytics/analytics.routes';
import notificationRoutes from './modules/notifications/notifications.routes';

const app = express();

// ── Global Middleware ────────────────────────────────────────────────
app.use(helmet());
app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }));
app.use(express.json());

// ── Health Check ─────────────────────────────────────────────────────
app.get('/health', (_req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ── Routes ────────────────────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/teams', teamRoutes);
app.use('/api/players', playerRoutes);
app.use('/api/fixtures', fixtureRoutes);
app.use('/api/matches', matchRoutes);
app.use('/api/analytics', analyticsRoutes);
app.use('/api/notifications', notificationRoutes);

// ── Global Error Handler ──────────────────────────────────────────────
app.use(errorMiddleware);

export default app;
