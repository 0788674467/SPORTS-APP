import { supabaseAdmin } from '../../config/db';

/**
 * Payload for creating a new team.
 */
export interface CreateTeamDto {
    /** Team name */
    name: string;
    /** URL to team logo image */
    logo_url?: string;
    /** Coach user ID */
    coach_id?: string;
}

/**
 * Payload for updating an existing team.
 */
export interface UpdateTeamDto {
    /** Team name */
    name?: string;
    /** URL to team logo image */
    logo_url?: string;
    /** Coach user ID */
    coach_id?: string;
}

/**
 * Team service for managing team records.
 * Handles CRUD operations for teams and retrieves team details with players.
 */

export const teamsService = {
    async getAll() {
        const { data, error } = await supabaseAdmin.from('teams').select('*').order('name');
        if (error) throw new Error(error.message);
        return data;
    },

    async getById(id: string) {
        const { data, error } = await supabaseAdmin
            .from('teams')
            .select('*, players(*)')
            .eq('id', id)
            .single();
        if (error) throw new Error(error.message);
        return data;
    },

    async create(payload: CreateTeamDto) {
        const { data, error } = await supabaseAdmin.from('teams').insert(payload).select().single();
        if (error) throw new Error(error.message);
        return data;
    },

    async update(id: string, payload: UpdateTeamDto) {
        const { data, error } = await supabaseAdmin
            .from('teams')
            .update(payload)
            .eq('id', id)
            .select()
            .single();
        if (error) throw new Error(error.message);
        return data;
    },

    async delete(id: string) {
        const { error } = await supabaseAdmin.from('teams').delete().eq('id', id);
        if (error) throw new Error(error.message);
        return { message: 'Team deleted' };
    },
};
