/*
  # Add items table and initial data
  
  1. New Tables
    - `items` table with columns:
      - `id` (uuid, primary key)
      - `name` (text)
      - `value` (integer)
      - `rarity` (text)
      - `image_url` (text)
      - `created_at` (timestamptz)
  
  2. Security
    - Enable RLS on `items` table
    - Add policy for authenticated users to read items
  
  3. Data
    - Insert initial items (Golden Coin and Mystery Box)
*/

-- Create items table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  value integer NOT NULL,
  rarity text NOT NULL,
  image_url text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;

-- Create policy for reading items if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'items' 
    AND policyname = 'Anyone can read items'
  ) THEN
    CREATE POLICY "Anyone can read items"
      ON public.items
      FOR SELECT
      TO authenticated
      USING (true);
  END IF;
END
$$;

-- Insert initial items if they don't exist
INSERT INTO public.items (id, name, value, rarity, image_url)
VALUES 
  ('e52d4345-a5e6-4ccd-9a8e-923a0ec11775', 'Golden Coin', 100, 'rare', 'https://images.pexels.com/photos/106152/euro-coins-currency-money-106152.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1'),
  ('f67d7e9b-cf3d-4ae8-9f41-9c6b3d74f714', 'Mystery Box', 200, 'epic', 'https://images.pexels.com/photos/821718/pexels-photo-821718.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1')
ON CONFLICT (id) DO NOTHING;