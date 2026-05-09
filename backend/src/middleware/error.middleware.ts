import { Request, Response, NextFunction } from 'express';

export class AppError extends Error {
    statusCode: number;
    constructor(message: string, statusCode = 500) {
        super(message);
        this.statusCode = statusCode;
        Error.captureStackTrace(this, this.constructor);
    }
}

export const errorMiddleware = (
    err: AppError,
    _req: Request,
    res: Response,
    _next: NextFunction
) => {
    const statusCode = err.statusCode || 500;
    console.error(`[ERROR] ${statusCode} — ${err.message}`);

    res.status(statusCode).json({
        error: {
            message: err.message || 'Internal Server Error',
            ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
        },
    });
};
