/*
  # Update user inventory structure and add initial items trigger

  1. Changes
    - Rename item_id to items_ids and change type to UUID array
    - Drop existing foreign key constraint
    - Add trigger to initialize new user inventory

  2. Security
    - Maintain existing RLS policies
*/

-- Drop existing foreign key constraint and column
ALTER TABLE user_inventory
DROP CONSTRAINT IF EXISTS user_inventory_item_id_fkey,
DROP COLUMN IF EXISTS item_id;

-- Add new items_ids column as UUID array
ALTER TABLE user_inventory
ADD COLUMN items_ids UUID[] DEFAULT '{}';

-- Create function to handle new user initialization
CREATE OR REPLACE FUNCTION initialize_user_inventory()
RETURNS TRIGGER AS $$
BEGIN
  -- Get two random items from the items table
  WITH random_items AS (
    SELECT id 
    FROM items 
    ORDER BY RANDOM() 
    LIMIT 2
  )
  INSERT INTO user_inventory (user_id, items_ids)
  VALUES (NEW.id, ARRAY(SELECT id FROM random_items))
  ON CONFLICT (user_id) DO NOTHING;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to initialize inventory for new users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION initialize_user_inventory();

-- Add unique constraint on user_id if it doesn't exist
ALTER TABLE user_inventory
DROP CONSTRAINT IF EXISTS user_inventory_user_id_key;

ALTER TABLE user_inventory
ADD CONSTRAINT user_inventory_user_id_key UNIQUE (user_id);