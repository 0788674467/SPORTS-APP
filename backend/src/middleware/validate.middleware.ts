import { Request, Response, NextFunction } from 'express';
import { ZodSchema, ZodError } from 'zod';

/**
 * Zod validation middleware factory.
 * Usage: router.post('/', validate(mySchema), controller.create)
 */
export const validate = (schema: ZodSchema) => {
    return (req: Request, res: Response, next: NextFunction) => {
        try {
            req.body = schema.parse(req.body);
            next();
        } catch (err) {
            if (err instanceof ZodError) {
                return res.status(422).json({
                    error: 'Validation failed',
                    details: err.errors.map((e) => ({
                        field: e.path.join('.'),
                        message: e.message,
                    })),
                });
            }
            next(err);
        }
    };
};
