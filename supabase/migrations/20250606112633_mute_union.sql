/*
  # Fix user_inventory RLS policies

  1. Security Updates
    - Drop existing problematic policies on user_inventory table
    - Create new, properly configured RLS policies for user_inventory
    - Ensure authenticated users can INSERT, SELECT, and UPDATE their own inventory records
    - Fix policy conditions to properly reference auth.uid()

  2. Changes
    - Remove duplicate and conflicting INSERT policies
    - Simplify policy structure for better reliability
    - Ensure proper user_id matching with auth.uid()
*/

-- Drop existing policies that might be causing conflicts
DROP POLICY IF EXISTS "Users can add items to their inventory" ON user_inventory;
DROP POLICY IF EXISTS "Users can insert their inventory" ON user_inventory;
DROP POLICY IF EXISTS "Users can read their own inventory" ON user_inventory;
DROP POLICY IF EXISTS "Users can update their own inventory" ON user_inventory;

-- Create new, simplified policies
CREATE POLICY "Users can manage their own inventory - SELECT"
  ON user_inventory
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own inventory - INSERT"
  ON user_inventory
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can manage their own inventory - UPDATE"
  ON user_inventory
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can manage their own inventory - DELETE"
  ON user_inventory
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);