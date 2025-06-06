/*
  # Create user inventory table

  1. New Tables
    - `user_inventory`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references auth.users)
      - `item_id` (uuid, references items)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on `user_inventory` table
    - Add policies for users to:
      - Read their own inventory items
      - Insert items into their inventory
*/

-- Create user inventory table
CREATE TABLE IF NOT EXISTS user_inventory (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) NOT NULL,
  item_id uuid REFERENCES items(id) NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, item_id)
);

-- Enable RLS
ALTER TABLE user_inventory ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can read their own inventory"
ON user_inventory
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can add items to their inventory"
ON user_inventory
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Add some sample items to the authenticated user's inventory
INSERT INTO user_inventory (user_id, item_id)
SELECT auth.uid(), id
FROM items
WHERE user_id = auth.uid();