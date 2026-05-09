import { supabaseAdmin } from '../src/config/db';

async function checkProfiles() {
    console.log('🔍 Fetching all profiles from public.profiles...');
    const { data, error } = await supabaseAdmin.from('profiles').select('*');

    if (error) {
        console.error('❌ Error fetching profiles:', error);
        return;
    }

    console.log(`✅ Found ${data?.length || 0} profiles:`);
    console.table(data?.map(p => ({
        id: p.id.substring(0, 8) + '...',
        name: p.full_name,
        email: p.email,
        role: p.role,
        status: p.approval_status
    })));
}

checkProfiles();
