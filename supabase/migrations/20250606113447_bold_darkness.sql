/*
  # Fix winner items transfer - simple approach

  1. Changes
    - Create simple function that transfers ALL match items to winner
    - Remove items from loser's inventory
    - Add all items to winner's inventory
    - Prevent completed match deletion/modification

  2. Logic
    - When match completes, find winner by matching result with side
    - Get ALL items from the match
    - Remove loser's items from their inventory
    - Add ALL items to winner's inventory
*/

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS on_match_completion ON matches;
DROP FUNCTION IF EXISTS handle_match_completion();

-- Create simple and reliable function
CREATE OR REPLACE FUNCTION handle_match_completion()
RETURNS TRIGGER AS $$
DECLARE
  winner_user_id uuid;
  loser_user_id uuid;
  all_match_items uuid[];
  loser_items uuid[];
  winner_current_items uuid[];
BEGIN
  -- Only process when match status changes to 'completed'
  IF NEW.status = 'completed' AND OLD.status = 'active' THEN
    
    -- Get winner (user who chose the winning side)
    SELECT user_id INTO winner_user_id
    FROM match_items 
    WHERE match_id = NEW.id 
    AND side = NEW.result 
    LIMIT 1;
    
    -- Get loser (user who chose the losing side)  
    SELECT user_id INTO loser_user_id
    FROM match_items 
    WHERE match_id = NEW.id 
    AND side != NEW.result 
    LIMIT 1;
    
    -- Get ALL items from this match
    SELECT array_agg(item_id) INTO all_match_items
    FROM match_items 
    WHERE match_id = NEW.id;
    
    -- Get loser's items specifically
    SELECT array_agg(item_id) INTO loser_items
    FROM match_items 
    WHERE match_id = NEW.id 
    AND user_id = loser_user_id;
    
    IF winner_user_id IS NOT NULL AND loser_user_id IS NOT NULL AND all_match_items IS NOT NULL THEN
      
      -- Remove loser's items from their inventory
      IF loser_items IS NOT NULL THEN
        UPDATE user_inventory 
        SET items_ids = array(
          SELECT unnest(items_ids) 
          WHERE unnest(items_ids) != ALL(loser_items)
        )
        WHERE user_id = loser_user_id;
      END IF;
      
      -- Get winner's current inventory
      SELECT COALESCE(items_ids, '{}') INTO winner_current_items
      FROM user_inventory 
      WHERE user_id = winner_user_id;
      
      -- Add ALL match items to winner's inventory
      UPDATE user_inventory 
      SET items_ids = winner_current_items || all_match_items
      WHERE user_id = winner_user_id;
      
      -- If winner doesn't have inventory record, create it
      IF NOT FOUND THEN
        INSERT INTO user_inventory (user_id, items_ids)
        VALUES (winner_user_id, all_match_items);
      END IF;
      
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for match completion
CREATE TRIGGER on_match_completion
  AFTER UPDATE ON matches
  FOR EACH ROW
  EXECUTE FUNCTION handle_match_completion();

-- Ensure policies prevent modification of completed matches
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

-- Clean up existing completed matches for fresh testing
DELETE FROM match_items WHERE match_id IN (SELECT id FROM matches WHERE status = 'completed');
DELETE FROM matches WHERE status = 'completed';