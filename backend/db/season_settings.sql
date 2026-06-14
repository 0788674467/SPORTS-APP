CREATE TABLE IF NOT EXISTS public.season_settings (
    id integer PRIMARY KEY DEFAULT 1,
    name text NOT NULL,
    start_date text NOT NULL,
    end_date text NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

-- Ensure only one row exists
ALTER TABLE public.season_settings ADD CONSTRAINT single_row CHECK (id = 1);

-- Set up Row Level Security (RLS)
ALTER TABLE public.season_settings ENABLE ROW LEVEL SECURITY;

-- Allow anyone to read season settings
CREATE POLICY "Allow public read access" ON public.season_settings FOR SELECT USING (true);

-- Allow authenticated users (admins) to update season settings
CREATE POLICY "Allow authenticated update access" ON public.season_settings FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated insert access" ON public.season_settings FOR INSERT WITH CHECK (auth.role() = 'authenticated');
