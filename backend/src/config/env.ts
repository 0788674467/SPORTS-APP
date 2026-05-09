import dotenv from 'dotenv';
dotenv.config();

function requireEnv(key: string): string {
    const val = process.env[key];
    if (!val) throw new Error(`Missing required env variable: ${key}`);
    return val;
}

export const env = {
    port: Number(process.env.PORT) || 3000,
    nodeEnv: process.env.NODE_ENV || 'development',

    supabaseUrl: requireEnv('NEXT_PUBLIC_SUPABASE_URL'),
    supabasePublishableKey: requireEnv('NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY'),
    supabaseServiceRoleKey: requireEnv('SUPABASE_SERVICE_ROLE_KEY'),

    jwtSecret: requireEnv('JWT_SECRET'),
    jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
};
