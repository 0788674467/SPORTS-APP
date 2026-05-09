import { supabaseAdmin } from '../../src/config/db';

async function main() {
    console.log('🌱 Seeding database...');

    // 1. Create Teams
    const { data: teams, error: teamError } = await supabaseAdmin.from('teams').upsert([
        { name: 'Red Dragons', logo_url: 'https://via.placeholder.com/150' },
        { name: 'Blue Sharks', logo_url: 'https://via.placeholder.com/150' },
        { name: 'Green Eagles', logo_url: 'https://via.placeholder.com/150' },
        { name: 'Yellow Tigers', logo_url: 'https://via.placeholder.com/150' },
    ]).select();

    if (teamError) {
        console.error('Error seeding teams:', teamError);
        return;
    }

    console.log(`✅ Seeded ${teams.length} teams.`);

    // 2. Create Players for each team
    for (const team of teams) {
        const players = [
            { name: `${team.name} Captain`, team_id: team.id, position: 'Forward', jersey_number: 10 },
            { name: `${team.name} Keeper`, team_id: team.id, position: 'Goalkeeper', jersey_number: 1 },
            { name: `${team.name} Defender`, team_id: team.id, position: 'Defender', jersey_number: 4 },
            { name: `${team.name} Midfielder`, team_id: team.id, position: 'Midfielder', jersey_number: 8 },
        ];

        const { error: playerError } = await supabaseAdmin.from('players').upsert(players);
        if (playerError) {
            console.error(`Error seeding players for team ${team.name}:`, playerError);
        } else {
            console.log(`✅ Seeded players for team ${team.name}.`);
        }
    }

    console.log('🎉 Seeding complete!');
}

main().catch((err) => {
    console.error('Fatal error during seeding:', err);
    process.exit(1);
});
