-- Create spectator_chats table
CREATE TABLE IF NOT EXISTS public.spectator_chats (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    profile_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    user_name TEXT NOT NULL,
    message TEXT NOT NULL
);

-- Enable RLS
ALTER TABLE public.spectator_chats ENABLE ROW LEVEL SECURITY;

-- Policies
DROP POLICY IF EXISTS "Anyone can view chat messages" ON public.spectator_chats;
CREATE POLICY "Anyone can view chat messages" ON public.spectator_chats
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Authenticated users can insert chat messages" ON public.spectator_chats;
DROP POLICY IF EXISTS "Anyone can insert chat messages" ON public.spectator_chats;
CREATE POLICY "Anyone can insert chat messages" ON public.spectator_chats
    FOR INSERT WITH CHECK (true);

-- Enable Realtime
-- (Note: If this error repeats, ignore it, it means the table is already in the publication)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'spectator_chats'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE spectator_chats;
    END IF;
END $$;
