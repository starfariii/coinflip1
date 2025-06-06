/*
  # User Inventory System

  1. Tables
    - `user_inventory`: Stores user's item inventory
      - `id` (uuid, primary key)
      - `user_id` (uuid, unique, references auth.users)
      - `items_ids` (uuid array)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS
    - Add policies for reading and inserting inventory
    
  3. Automation
    - Create trigger for new user registration
    - Automatically add default items to new users
*/

-- Create user_inventory table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.user_inventory (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id),
  items_ids uuid[] DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.user_inventory ENABLE ROW LEVEL SECURITY;

-- Policies (with existence checks)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'user_inventory' 
    AND policyname = 'Users can read their own inventory'
  ) THEN
    CREATE POLICY "Users can read their own inventory"
      ON public.user_inventory
      FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'user_inventory' 
    AND policyname = 'Users can insert their inventory'
  ) THEN
    CREATE POLICY "Users can insert their inventory"
      ON public.user_inventory
      FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- Function to handle new user registration
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.user_inventory (user_id, items_ids)
  VALUES (new.id, ARRAY[
    'e52d4345-a5e6-4ccd-9a8e-923a0ec11775'::uuid,
    'f67d7e9b-cf3d-4ae8-9f41-9c6b3d74f714'::uuid
  ]::uuid[])
  ON CONFLICT (user_id) DO NOTHING;
  RETURN new;
END;
$$ language plpgsql security definer;

-- Create trigger for handling new user registration
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();