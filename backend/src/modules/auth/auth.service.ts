import { supabase, supabaseAdmin } from '../../config/db';
import { UserRole } from '../../types';

/**
 * Data transfer object for user registration.
 */
export interface SignUpDto {
    /** User's email address (must be unique) */
    email: string;
    /** User's password (min 6 characters) */
    password: string;
    /** User's full name */
    fullName: string;
    /** User's role in the system */
    role: UserRole;
}

/**
 * Data transfer object for user authentication.
 */
export interface SignInDto {
    /** User's email address */
    email: string;
    /** User's password */
    password: string;
}

/**
 * Authentication service for user management.
 * Handles sign-up, sign-in, sign-out, password reset, and profile operations.
 */

export const authService = {
    async signUp({ email, password, fullName, role }: SignUpDto) {
        const { data, error } = await supabase.auth.signUp({
            email,
            password,
            options: {
                data: { full_name: fullName, role },
            },
        });
        if (error) throw new Error(error.message);
        return data;
    },

    async signIn({ email, password }: SignInDto) {
        const { data, error } = await supabase.auth.signInWithPassword({
            email,
            password,
        });
        if (error) throw new Error(error.message);
        return data;
    },

    async signOut(jwt: string) {
        // Set the user's session token so we sign out the correct user
        const { error } = await supabase.auth.admin.signOut(jwt);
        if (error) throw new Error(error.message);
        return { message: 'Signed out successfully' };
    },

    async resetPassword(email: string) {
        const { error } = await supabase.auth.resetPasswordForEmail(email);
        if (error) throw new Error(error.message);
        return { message: 'Password reset email sent' };
    },

    async getProfile(userId: string) {
        const { data, error } = await supabaseAdmin.auth.admin.getUserById(userId);
        if (error) throw new Error(error.message);
        return data.user;
    },

    async updateRole(userId: string, role: string) {
        const { data, error } = await supabaseAdmin.auth.admin.updateUserById(userId, {
            user_metadata: { role },
        });
        if (error) throw new Error(error.message);
        return data.user;
    },
};
