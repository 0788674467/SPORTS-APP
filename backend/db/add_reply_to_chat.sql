-- Add reply support to spectator_chats
ALTER TABLE public.spectator_chats
  ADD COLUMN IF NOT EXISTS reply_to_id UUID REFERENCES public.spectator_chats(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reply_to_preview TEXT; -- cached snippet of the original message

-- Index for fast parent lookups
CREATE INDEX IF NOT EXISTS idx_spectator_chats_reply_to_id
  ON public.spectator_chats(reply_to_id);
