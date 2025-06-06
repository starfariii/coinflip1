/*
  # Simplify match system

  1. Changes
    - Drop match_items table completely
    - Add items_ids (uuid array) to matches table
    - Add member_id to matches table for the joining player
    - Simplify the entire system to be more reliable

  2. New Structure
    - matches table stores everything:
      - creator_id: who created the match
      - member_id: who joined the match
      - items_ids: all items in the match (from both players)
      - selected_side: creator's chosen side
      - result: coin flip result
      - status: active/completed/cancelled
*/

-- Drop the problematic match_items table and its triggers
DROP TRIGGER IF EXISTS match_items_changes ON match_items;
DROP TRIGGER IF EXISTS on_match_completion ON matches;
DROP FUNCTION IF EXISTS handle_match_item_changes();
DROP FUNCTION IF EXISTS handle_match_completion();
DROP TABLE IF EXISTS match_items CASCADE;

-- Add new columns to matches table
ALTER TABLE matches 
ADD COLUMN IF NOT EXISTS member_id uuid REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS items_ids uuid[] DEFAULT '{}';

-- Create simple function to handle match completion
CREATE OR REPLACE FUNCTION handle_match_completion()
RETURNS TRIGGER AS $$
DECLARE
  winner_id uuid;
  loser_id uuid;
BEGIN
  -- Only when match becomes completed
  IF NEW.status = 'completed' AND OLD.status = 'active' THEN
    
    -- Determine winner and loser based on result
    IF NEW.result = NEW.selected_side THEN
      -- Creator won
      winner_id := NEW.creator_id;
      loser_id := NEW.member_id;
    ELSE
      -- Member won
      winner_id := NEW.member_id;
      loser_id := NEW.creator_id;
    END IF;
    
    -- Transfer ALL items to winner
    IF winner_id IS NOT NULL AND NEW.items_ids IS NOT NULL THEN
      
      -- Remove items from loser's inventory
      IF loser_id IS NOT NULL THEN
        UPDATE user_inventory 
        SET items_ids = (
          SELECT array_agg(item) 
          FROM unnest(items_ids) AS item 
          WHERE item != ALL(NEW.items_ids)
        )
        WHERE user_id = loser_id;
      END IF;
      
      -- Add ALL items to winner's inventory
      INSERT INTO user_inventory (user_id, items_ids)
      VALUES (winner_id, NEW.items_ids)
      ON CONFLICT (user_id) 
      DO UPDATE SET items_ids = user_inventory.items_ids || NEW.items_ids;
      
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER on_match_completion
  AFTER UPDATE ON matches
  FOR EACH ROW
  EXECUTE FUNCTION handle_match_completion();

-- Update policies for the new structure
DROP POLICY IF EXISTS "Users can create matches" ON matches;
DROP POLICY IF EXISTS "Anyone can read matches" ON matches;
DROP POLICY IF EXISTS "Users can delete their own active matches" ON matches;
DROP POLICY IF EXISTS "Users can update their own active matches" ON matches;

CREATE POLICY "Users can create matches"
  ON matches
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "Anyone can read matches"
  ON matches
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can delete their own active matches"
  ON matches
  FOR DELETE
  TO authenticated
  USING (auth.uid() = creator_id AND status = 'active');

CREATE POLICY "Users can update matches they participate in"
  ON matches
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = creator_id OR auth.uid() = member_id)
  WITH CHECK (auth.uid() = creator_id OR auth.uid() = member_id);

-- Clean up existing data
DELETE FROM matches;

-- Remove the in_match column from items since we don't need it anymore
ALTER TABLE items DROP COLUMN IF EXISTS in_match;