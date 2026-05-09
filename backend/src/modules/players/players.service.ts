import { supabaseAdmin } from '../../config/db';

/**
 * Payload for creating a new player.
 */
export interface CreatePlayerDto {
    /** Player's full name */
    name: string;
    /** Team the player belongs to */
    team_id: string;
    /** Player's position */
    position: string;
    /** Player's jersey number */
    jersey_number: number;
    /** Player's date of birth (ISO 8601 format) */
    date_of_birth?: string;
    /** URL to player's photo */
    photo_url?: string;
}

/**
 * Payload for updating an existing player.
 */
export interface UpdatePlayerDto {
    /** Player's full name */
    name?: string;
    /** Team the player belongs to */
    team_id?: string;
    /** Player's position */
    position?: string;
    /** Player's jersey number */
    jersey_number?: number;
    /** Player's date of birth (ISO 8601 format) */
    date_of_birth?: string;
    /** URL to player's photo */
    photo_url?: string;
}

/**
 * Player service for managing player records.
 * Handles CRUD operations for players and retrieves player statistics.
 */

export const playersService = {
    async getAll(teamId?: string) {
        let query = supabaseAdmin.from('players').select('*, teams(name)').order('name');
        if (teamId) query = query.eq('team_id', teamId);
        const { data, error } = await query;
        if (error) throw new Error(error.message);
        return data;
    },

    async getById(id: string) {
        const { data, error } = await supabaseAdmin
            .from('players')
            .select('*, teams(name)')
            .eq('id', id)
            .single();
        if (error) throw new Error(error.message);
        return data;
    },

    async create(payload: CreatePlayerDto) {
        const { data, error } = await supabaseAdmin.from('players').insert(payload).select().single();
        if (error) throw new Error(error.message);
        return data;
    },

    async update(id: string, payload: UpdatePlayerDto) {
        const { data, error } = await supabaseAdmin
            .from('players')
            .update(payload)
            .eq('id', id)
            .select()
            .single();
        if (error) throw new Error(error.message);
        return data;
    },

    async delete(id: string) {
        const { error } = await supabaseAdmin.from('players').delete().eq('id', id);
        if (error) throw new Error(error.message);
        return { message: 'Player deleted' };
    },

    async getStats(playerId: string) {
        const { data, error } = await supabaseAdmin
            .from('match_events')
            .select('event_type, count:id.count()')
            .eq('player_id', playerId);
        if (error) throw new Error(error.message);
        return data;
    },
};
