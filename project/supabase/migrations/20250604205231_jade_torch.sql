/*
  # Reset data and update trigger function
  
  1. Changes
    - Clean up existing matches and items
    - Add initial items for users
    - Update trigger function to handle item status
*/

-- First, clean up existing data
DELETE FROM match_items;
DELETE FROM matches;
DELETE FROM items;

-- Add initial items
INSERT INTO items (name, value, rarity, image_url, user_id, in_match)
VALUES 
  ('Golden Coin', 100, 'rare', 'https://images.pexels.com/photos/106152/euro-coins-currency-money-106152.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1', auth.uid(), false),
  ('Mystery Box', 200, 'epic', 'https://images.pexels.com/photos/821718/pexels-photo-821718.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1', auth.uid(), false),
  ('Lucky Charm', 50, 'uncommon', 'https://images.pexels.com/photos/4588036/pexels-photo-4588036.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1', auth.uid(), false);

-- Drop existing trigger and function with CASCADE
DROP TRIGGER IF EXISTS match_items_changes ON match_items;
DROP FUNCTION IF EXISTS handle_match_item_changes() CASCADE;

-- Create function to handle match item changes
CREATE OR REPLACE FUNCTION handle_match_item_changes()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Mark item as in match when added to a match
    UPDATE items SET in_match = true WHERE id = NEW.item_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    -- Mark item as not in match when removed from a match
    UPDATE items SET in_match = false WHERE id = OLD.item_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER match_items_changes
AFTER INSERT OR DELETE ON match_items
FOR EACH ROW
EXECUTE FUNCTION handle_match_item_changes();