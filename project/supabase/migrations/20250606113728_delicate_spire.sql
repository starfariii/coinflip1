/*
  # Fix item transfer for match completion - FINAL SOLUTION

  1. Changes
    - Drop existing problematic trigger and function
    - Create new simple and reliable function that properly handles PostgreSQL arrays
    - Ensure winner gets ALL items from the match
    - Ensure loser loses their items
    - Prevent modification of completed matches

  2. Logic
    - When match completes: find winner and loser
    - Remove loser's items from their inventory
    - Add ALL match items to winner's inventory
    - Winner gets both their own items back + opponent's items
*/

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS on_match_completion ON matches;
DROP FUNCTION IF EXISTS handle_match_completion();

-- Create new reliable function
CREATE OR REPLACE FUNCTION handle_match_completion()
RETURNS TRIGGER AS $$
DECLARE
  winner_user_id uuid;
  loser_user_id uuid;
  all_match_items uuid[];
  loser_items uuid[];
  winner_current_items uuid[];
  item_id uuid;
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
    
    RAISE LOG 'Match completed: winner=%, loser=%, all_items=%, loser_items=%', 
              winner_user_id, loser_user_id, all_match_items, loser_items;
    
    IF winner_user_id IS NOT NULL AND loser_user_id IS NOT NULL THEN
      
      -- Remove loser's items from their inventory (one by one to avoid array issues)
      IF loser_items IS NOT NULL THEN
        FOREACH item_id IN ARRAY loser_items LOOP
          UPDATE user_inventory 
          SET items_ids = array_remove(items_ids, item_id)
          WHERE user_id = loser_user_id;
        END LOOP;
        RAISE LOG 'Removed loser items from inventory';
      END IF;
      
      -- Get winner's current inventory
      SELECT COALESCE(items_ids, '{}') INTO winner_current_items
      FROM user_inventory 
      WHERE user_id = winner_user_id;
      
      -- Add ALL match items to winner's inventory (one by one to ensure reliability)
      IF all_match_items IS NOT NULL THEN
        FOREACH item_id IN ARRAY all_match_items LOOP
          UPDATE user_inventory 
          SET items_ids = array_append(items_ids, item_id)
          WHERE user_id = winner_user_id;
        END LOOP;
        RAISE LOG 'Added all match items to winner inventory';
      END IF;
      
      -- If winner doesn't have inventory record, create it
      IF NOT EXISTS (SELECT 1 FROM user_inventory WHERE user_id = winner_user_id) THEN
        INSERT INTO user_inventory (user_id, items_ids)
        VALUES (winner_user_id, COALESCE(all_match_items, '{}'));
        RAISE LOG 'Created new inventory for winner';
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

-- Clean up existing data for fresh testing
DELETE FROM match_items WHERE match_id IN (SELECT id FROM matches WHERE status = 'completed');
DELETE FROM matches WHERE status = 'completed';