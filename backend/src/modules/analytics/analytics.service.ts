import { supabaseAdmin } from '../../config/db';
import { StandingEntry } from '../../types';

/**
 * Analytics service for generating match and league statistics.
 * Provides standings tables, top scorers, and match-specific statistics.
 */

export const analyticsService = {
    async getStandings(fixtureId: string): Promise<StandingEntry[]> {
        const { data: matches, error } = await supabaseAdmin
            .from('matches')
            .select('home_team_id, away_team_id, home_score, away_score, status')
            .eq('fixture_id', fixtureId)
            .eq('status', 'completed');
        if (error) throw new Error(error.message);

        const table = new Map<
            string,
            { played: number; won: number; drawn: number; lost: number; gf: number; ga: number; points: number }
        >();

        const getRow = (teamId: string) => {
            if (!table.has(teamId))
                table.set(teamId, { played: 0, won: 0, drawn: 0, lost: 0, gf: 0, ga: 0, points: 0 });
            return table.get(teamId)!;
        };

        for (const m of matches ?? []) {
            const home = getRow(m.home_team_id);
            const away = getRow(m.away_team_id);
            const hs = m.home_score ?? 0;
            const as = m.away_score ?? 0;

            home.played++;
            away.played++;
            home.gf += hs; home.ga += as;
            away.gf += as; away.ga += hs;

            if (hs > as) { home.won++; home.points += 3; away.lost++; }
            else if (hs < as) { away.won++; away.points += 3; home.lost++; }
            else { home.drawn++; away.drawn++; home.points++; away.points++; }
        }

        return Array.from(table.entries())
            .map(([teamId, stats]) => ({ teamId, ...stats, gd: stats.gf - stats.ga }))
            .sort((a, b) => b.points - a.points || b.gd - a.gd || b.gf - a.gf);
    },

    async getTopScorers(fixtureId: string, limit = 10) {
        const { data, error } = await supabaseAdmin
            .from('match_events')
            .select('player_id, players(name, team_id, teams(name)), count:id.count()')
            .eq('event_type', 'goal')
            .eq('matches.fixture_id', fixtureId)
            .order('count', { ascending: false })
            .limit(limit);
        if (error) throw new Error(error.message);
        return data;
    },

    async getMatchStats(matchId: string) {
        const { data, error } = await supabaseAdmin
            .from('match_events')
            .select('event_type, team_id, count:id.count()')
            .eq('match_id', matchId);
        if (error) throw new Error(error.message);
        return data;
    },
};
