import { supabaseAdmin } from '../../config/db';
import { MatchStatus, MatchEventType } from '../../types';

/**
 * Payload for recording a match event.
 */
export interface RecordEventPayload {
    /** Match identifier */
    match_id: string;
    /** Player involved in the event */
    player_id: string;
    /** Team the player belongs to */
    team_id: string;
    /** Type of event */
    event_type: MatchEventType;
    /** Minute when the event occurred */
    minute: number;
    /** Additional notes or details */
    notes?: string;
}

/**
 * Match service for managing matches and match events.
 * Handles match retrieval, score updates, status changes, and event recording.
 */

export const matchesService = {
    async getAll(status?: MatchStatus) {
        let query = supabaseAdmin
            .from('matches')
            .select('*, home_team:teams!home_team_id(name, logo_url), away_team:teams!away_team_id(name, logo_url), fixtures(name)')
            .order('scheduled_at');
        if (status) query = query.eq('status', status);
        const { data, error } = await query;
        if (error) throw new Error(error.message);
        return data;
    },

    async getById(id: string) {
        const { data, error } = await supabaseAdmin
            .from('matches')
            .select('*, home_team:teams!home_team_id(*), away_team:teams!away_team_id(*), match_events(*)')
            .eq('id', id)
            .single();
        if (error) throw new Error(error.message);
        return data;
    },

    async updateScore(id: string, homeScore: number, awayScore: number) {
        const { data, error } = await supabaseAdmin
            .from('matches')
            .update({ home_score: homeScore, away_score: awayScore })
            .eq('id', id)
            .select()
            .single();
        if (error) throw new Error(error.message);
        return data;
    },

    async updateStatus(id: string, status: MatchStatus) {
        const { data, error } = await supabaseAdmin
            .from('matches')
            .update({ status })
            .eq('id', id)
            .select()
            .single();
        if (error) throw new Error(error.message);
        return data;
    },

    async recordEvent(payload: RecordEventPayload) {
        const { data, error } = await supabaseAdmin
            .from('match_events')
            .insert(payload)
            .select()
            .single();
        if (error) throw new Error(error.message);
        return data;
    },

    async getLiveMatches() {
        return this.getAll('live');
    },
};
