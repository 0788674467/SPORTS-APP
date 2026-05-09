import { Request, Response, NextFunction } from 'express';
import { supabase } from '../config/db';
import { AuthUser } from '../types';

/**
 * Extended Express Request with authenticated user information.
 */
export interface AuthRequest extends Request {
    /** Authenticated user (populated by authenticate middleware) */
    user?: AuthUser;
}

/**
 * Verifies the Supabase JWT token from the Authorization header.
 * Attaches the user payload to req.user on success.
 */
export const authenticate = async (
    req: AuthRequest,
    res: Response,
    next: NextFunction
) => {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Missing or invalid Authorization header' });
    }

    const token = authHeader.split(' ')[1];

    const { data, error } = await supabase.auth.getUser(token);
    if (error || !data.user) {
        return res.status(401).json({ error: 'Invalid or expired token' });
    }

    req.user = {
        id: data.user.id,
        email: data.user.email ?? '',
        role: (data.user.user_metadata?.role as string) ?? 'spectator',
    };

    next();
};

/**
 * Role-based access guard. Use AFTER authenticate middleware.
 * Example: requireRole('admin', 'referee')
 */
export const requireRole = (...roles: string[]) => {
    return (req: AuthRequest, res: Response, next: NextFunction) => {
        if (!req.user) {
            return res.status(401).json({ error: 'Not authenticated' });
        }
        if (!roles.includes(req.user.role)) {
            return res.status(403).json({ error: `Access denied. Required role: ${roles.join(' or ')}` });
        }
        next();
    };
};
