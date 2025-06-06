/*
  # Fix user inventory creation

  1. Changes
    - Drop existing triggers and functions
    - Create new function with proper error handling
    - Create new trigger with proper permissions
    - Add missing RLS policies
*/

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.initialize_user_inventory();

-- Create new function with proper error handling
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.user_inventory (user_id, items_ids)
  VALUES (
    NEW.id,
    ARRAY[
      'e52d4345-a5e6-4ccd-9a8e-923a0ec11775'::uuid,
      'f67d7e9b-cf3d-4ae8-9f41-9c6b3d74f714'::uuid
    ]
  )
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE LOG 'Error in handle_new_user: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Create new trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Ensure RLS is enabled
ALTER TABLE public.user_inventory ENABLE ROW LEVEL SECURITY;

-- Recreate policies
DROP POLICY IF EXISTS "Users can read their own inventory" ON public.user_inventory;
DROP POLICY IF EXISTS "Users can insert their inventory" ON public.user_inventory;
DROP POLICY IF EXISTS "Users can update their own inventory" ON public.user_inventory;

CREATE POLICY "Users can read their own inventory"
  ON public.user_inventory
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their inventory"
  ON public.user_inventory
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own inventory"
  ON public.user_inventory
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON public.user_inventory TO authenticated;
GRANT ALL ON public.user_inventory TO service_role;