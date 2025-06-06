/*
  # Ultra-simple item transfer system

  1. Changes
    - Drop existing complex trigger
    - Create dead-simple function that just transfers ALL items to winner
    - No complex array operations, just basic logic

  2. Logic
    - Find winner by matching result with side
    - Get ALL items from match
    - Give ALL items to winner
    - Remove items from loser
*/

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS on_match_completion ON matches;
DROP FUNCTION IF EXISTS handle_match_completion();

-- Create ultra-simple function
CREATE OR REPLACE FUNCTION handle_match_completion()
RETURNS TRIGGER AS $$
DECLARE
  winner_id uuid;
  loser_id uuid;
  match_items_list uuid[];
BEGIN
  -- Only when match becomes completed
  IF NEW.status = 'completed' AND OLD.status = 'active' THEN
    
    -- Step 1: Find winner (user who chose the winning side)
    SELECT user_id INTO winner_id
    FROM match_items 
    WHERE match_id = NEW.id 
    AND side = NEW.result 
    LIMIT 1;
    
    -- Step 2: Find loser (user who chose the losing side)
    SELECT user_id INTO loser_id
    FROM match_items 
    WHERE match_id = NEW.id 
    AND side != NEW.result 
    LIMIT 1;
    
    -- Step 3: Get ALL items from this match
    SELECT array_agg(item_id) INTO match_items_list
    FROM match_items 
    WHERE match_id = NEW.id;
    
    -- Step 4: Transfer items if we have everything
    IF winner_id IS NOT NULL AND match_items_list IS NOT NULL THEN
      
      -- Remove ALL match items from loser's inventory
      IF loser_id IS NOT NULL THEN
        UPDATE user_inventory 
        SET items_ids = (
          SELECT array_agg(item) 
          FROM unnest(items_ids) AS item 
          WHERE item != ALL(match_items_list)
        )
        WHERE user_id = loser_id;
      END IF;
      
      -- Add ALL match items to winner's inventory
      INSERT INTO user_inventory (user_id, items_ids)
      VALUES (winner_id, match_items_list)
      ON CONFLICT (user_id) 
      DO UPDATE SET items_ids = user_inventory.items_ids || match_items_list;
      
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

-- Prevent modification of completed matches
DROP POLICY IF EXISTS "Users can delete their own active matches" ON matches;
DROP POLICY IF EXISTS "Users can update their own active matches" ON matches;

CREATE POLICY "Users can delete their own active matches"
  ON matches
  FOR DELETE
  TO authenticated
  USING (auth.uid() = creator_id AND status = 'active');

CREATE POLICY "Users can update their own active matches"
  ON matches
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = creator_id AND status = 'active')
  WITH CHECK (auth.uid() = creator_id);

-- Clean up for testing
DELETE FROM match_items WHERE match_id IN (SELECT id FROM matches WHERE status = 'completed');
DELETE FROM matches WHERE status = 'completed';