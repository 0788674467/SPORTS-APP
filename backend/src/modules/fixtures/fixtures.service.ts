import { supabaseAdmin } from '../../config/db';
import { fixtureEngine } from './fixture.engine';

/**
 * Payload for generating a new fixture.
 */
export interface GenerateFixtureDto {
    /** Fixture name/title */
    name: string;
    /** Season identifier (e.g., "2025/2026") */
    season: string;
    /** Array of team IDs participating in the fixture */
    teamIds: string[];
    /** Start date for the fixture (ISO 8601 format) */
    startDate: string;
    /** Days between match days (default: 7) */
    matchDayIntervalDays?: number;
    /** Venue name or location */
    venue?: string;
}

/**
 * Fixture service for managing fixtures and match schedules.
 * Handles fixture generation using round-robin algorithm and fixture retrieval.
 */

export const fixturesService = {
    async getAll() {
        const { data, error } = await supabaseAdmin
            .from('fixtures')
            .select('*, matches(count)')
            .order('created_at', { ascending: false });
        if (error) throw new Error(error.message);
        return data;
    },

    async getById(id: string) {
        const { data, error } = await supabaseAdmin
            .from('fixtures')
            .select('*, matches(*, home_team:teams!home_team_id(name), away_team:teams!away_team_id(name))')
            .eq('id', id)
            .single();
        if (error) throw new Error(error.message);
        return data;
    },

    async generate(payload: GenerateFixtureDto) {
        // 1. Create fixture record
        const { data: fixture, error } = await supabaseAdmin
            .from('fixtures')
            .insert({ name: payload.name, season: payload.season })
            .select()
            .single();
        if (error) throw new Error(error.message);

        // 2. Generate round-robin schedule
        const schedule = fixtureEngine.generateRoundRobin(
            payload.teamIds,
            payload.startDate,
            payload.matchDayIntervalDays ?? 7
        );

        // 3. Insert matches
        const matchRows = schedule.map((m) => ({
            fixture_id: fixture.id,
            home_team_id: m.homeTeamId,
            away_team_id: m.awayTeamId,
            scheduled_at: m.scheduledAt,
            venue: payload.venue ?? null,
            status: 'scheduled',
        }));

        const { data: matches, error: matchErr } = await supabaseAdmin
            .from('matches')
            .insert(matchRows)
            .select();
        if (matchErr) throw new Error(matchErr.message);

        return { fixture, matches };
    },

    async delete(id: string) {
        const { error } = await supabaseAdmin.from('fixtures').delete().eq('id', id);
        if (error) throw new Error(error.message);
        return { message: 'Fixture deleted' };
    },
};
