import { supabaseAdmin } from '../src/config/db';

async function setupAdmin(email: string, pass: string) {
    if (!email || !pass) {
        console.error('❌ Usage: npx ts-node scripts/setup-admin.ts <email> <password>');
        process.exit(1);
    }

    console.log(`🚀 Setting up Admin account for ${email}...`);

    // 1. Create or Update user with password
    const { data: { user }, error: createError } = await supabaseAdmin.auth.admin.createUser({
        email: email,
        password: pass,
        email_confirm: true,
        user_metadata: { role: 'admin' }
    });

    if (createError) {
        if (createError.message.includes('already registered')) {
            console.log(`🔍 User already exists. Updating password and role instead...`);

            // Get user ID first
            const { data: { users } } = await supabaseAdmin.auth.admin.listUsers();
            const existingUser = users.find(u => u.email === email);

            if (!existingUser) {
                console.error('❌ Failed to find existing user.');
                process.exit(1);
            }

            const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
                existingUser.id,
                {
                    password: pass,
                    user_metadata: { ...existingUser.user_metadata, role: 'admin' }
                }
            );

            if (updateError) {
                console.error('❌ Update failed:', updateError.message);
                process.exit(1);
            }
        } else {
            console.error('❌ Creation failed:', createError.message);
            process.exit(1);
        }
    }

    console.log(`✅ Success! Log in with:`);
    console.log(`📧 Email: ${email}`);
    console.log(`🔑 Password: ${pass}`);
    console.log(`🛡️  Role: Administrator`);
}

setupAdmin(process.argv[2], process.argv[3]);
