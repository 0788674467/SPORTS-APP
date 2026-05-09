-- Add guest_id column to spectator_chats to differentiate guest users
ALTER TABLE public.spectator_chats 
ADD COLUMN IF NOT EXISTS guest_id TEXT;
