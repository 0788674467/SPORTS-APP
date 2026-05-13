-- ============================================================
-- Officials Communication Center — Direct Messaging Table
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. Create the official_messages table
CREATE TABLE IF NOT EXISTS public.official_messages (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sender_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  recipient_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  message      TEXT NOT NULL,
  is_read      BOOLEAN NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Enable RLS
ALTER TABLE public.official_messages ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies: sender or recipient can read/insert their own messages
DROP POLICY IF EXISTS "Officials can read their messages" ON public.official_messages;
CREATE POLICY "Officials can read their messages"
  ON public.official_messages FOR SELECT
  USING (
    auth.uid() = sender_id OR auth.uid() = recipient_id
  );

DROP POLICY IF EXISTS "Officials can send messages" ON public.official_messages;
CREATE POLICY "Officials can send messages"
  ON public.official_messages FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id AND
    -- Only allow messaging between registered officials (admin, coach, referee)
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND role IN ('admin', 'coach', 'referee')
    )
  );

DROP POLICY IF EXISTS "Recipients can mark messages read" ON public.official_messages;
CREATE POLICY "Recipients can mark messages read"
  ON public.official_messages FOR UPDATE
  USING (auth.uid() = recipient_id)
  WITH CHECK (auth.uid() = recipient_id);

-- 4. Enable Realtime for this table (run in Supabase dashboard if needed)
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.official_messages;

-- 5. Index for fast conversation queries
CREATE INDEX IF NOT EXISTS idx_official_messages_sender    ON public.official_messages(sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_official_messages_recipient ON public.official_messages(recipient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_official_messages_thread    ON public.official_messages(
  LEAST(sender_id, recipient_id),
  GREATEST(sender_id, recipient_id),
  created_at DESC
);
