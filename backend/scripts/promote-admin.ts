import { supabaseAdmin } from '../src/config/db';

async function promoteToAdmin(email: string) {
    if (!email) {
        console.error('❌ Please provide an email address.');
        process.exit(1);
    }

    console.log(`🚀 Promoting ${email} to admin...`);

    // Get the user by email
    const { data: { users }, error: fetchError } = await supabaseAdmin.auth.admin.listUsers();

    if (fetchError) {
        console.error('❌ Error fetching users:', fetchError.message);
        if (fetchError.message.includes('service_role')) {
            console.error('📝 Note: Ensure your SUPABASE_SERVICE_ROLE_KEY is set in backend/.env');
        }
        process.exit(1);
    }

    const user = users.find(u => u.email === email);

    if (!user) {
        console.error(`❌ User with email ${email} not found.`);
        process.exit(1);
    }

    // Update the user's role in metadata
    const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
        user.id,
        { user_metadata: { ...user.user_metadata, role: 'admin' } }
    );

    if (updateError) {
        console.error('❌ Error updating user:', updateError);
        process.exit(1);
    }

    console.log(`✅ Success! ${email} is now an administrator.`);
}

const email = process.argv[2];
promoteToAdmin(email);
