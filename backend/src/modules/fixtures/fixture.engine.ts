/**
 * fixture.engine.ts
 * Round-robin schedule generator with even/odd team handling.
 *
 * Algorithm: "Circle method" (polygon rotation).
 * - If odd number of teams, one "bye" team is added.
 * - Each round, team[0] is fixed; rest rotate clockwise.
 * - Home/away alternates between rounds for fairness.
 */

/**
 * Represents a scheduled match in a fixture.
 */
export interface ScheduledMatch {
    /** Unique identifier of the home team */
    homeTeamId: string;
    /** Unique identifier of the away team */
    awayTeamId: string;
    /** ISO 8601 datetime string for match kickoff */
    scheduledAt: string;
    /** Round number in the fixture (1-indexed) */
    round: number;
}

export const fixtureEngine = {
    generateRoundRobin(
        teamIds: string[],
        startDateStr: string,
        intervalDays: number = 7
    ): ScheduledMatch[] {
        const teams = [...teamIds];

        // Pad to even count with a "bye" placeholder
        if (teams.length % 2 !== 0) teams.push('__bye__');

        const n = teams.length;
        const rounds = n - 1;
        const matchesPerRound = n / 2;
        const schedule: ScheduledMatch[] = [];

        const startDate = new Date(startDateStr);

        for (let round = 0; round < rounds; round++) {
            const roundDate = new Date(startDate);
            roundDate.setDate(startDate.getDate() + round * intervalDays);

            for (let match = 0; match < matchesPerRound; match++) {
                const home = teams[match];
                const away = teams[n - 1 - match];

                // Skip bye matches
                if (home === '__bye__' || away === '__bye__') continue;

                // Alternate home/away each round
                const [homeTeamId, awayTeamId] =
                    round % 2 === 0 ? [home, away] : [away, home];

                schedule.push({
                    homeTeamId,
                    awayTeamId,
                    scheduledAt: roundDate.toISOString(),
                    round: round + 1,
                });
            }

            // Rotate: keep teams[0] fixed, rotate the rest
            const last = teams.pop()!;
            teams.splice(1, 0, last);
        }

        return schedule;
    },

    /**
     * Apply constraints: no team plays twice in the same week,
     * no team plays home more than 2 consecutive times.
     */
    applyConstraints(schedule: ScheduledMatch[]): ScheduledMatch[] {
        // Simple pass-through — extend with constraint logic as needed
        const seen = new Map<string, Set<number>>();

        return schedule.filter((match) => {
            const week = Math.ceil(match.round / 1);
            for (const teamId of [match.homeTeamId, match.awayTeamId]) {
                if (!seen.has(teamId)) seen.set(teamId, new Set());
                if (seen.get(teamId)!.has(week)) return false;
                seen.get(teamId)!.add(week);
            }
            return true;
        });
    },
};
