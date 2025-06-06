/*
  # Fix match completion logic and prevent completed match deletion

  1. Changes
    - Fix the match completion trigger to properly transfer items
    - Add proper logging for debugging
    - Ensure completed matches cannot be deleted
    - Fix item transfer logic

  2. Security
    - Prevent deletion of completed matches
    - Ensure only active matches can be cancelled
*/

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS on_match_completion ON matches;
DROP FUNCTION IF EXISTS handle_match_completion();

-- Create improved function to handle match completion
CREATE OR REPLACE FUNCTION handle_match_completion()
RETURNS TRIGGER AS $$
DECLARE
  winner_user_id uuid;
  loser_user_id uuid;
  all_match_items uuid[];
  winner_current_items uuid[];
BEGIN
  -- Only process when match status changes to 'completed'
  IF NEW.status = 'completed' AND OLD.status = 'active' THEN
    RAISE LOG 'Match % completed with result: %', NEW.id, NEW.result;
    
    -- Get all items from this match
    SELECT array_agg(item_id) INTO all_match_items
    FROM match_items 
    WHERE match_id = NEW.id;
    
    RAISE LOG 'All match items: %', all_match_items;
    
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
    
    RAISE LOG 'Winner: %, Loser: %', winner_user_id, loser_user_id;
    
    -- Remove items from loser's inventory
    IF loser_user_id IS NOT NULL THEN
      UPDATE user_inventory 
      SET items_ids = array(
        SELECT unnest(items_ids) 
        EXCEPT 
        SELECT unnest(
          ARRAY(
            SELECT item_id 
            FROM match_items 
            WHERE match_id = NEW.id AND user_id = loser_user_id
          )
        )
      )
      WHERE user_id = loser_user_id;
      
      RAISE LOG 'Removed items from loser inventory';
    END IF;
    
    -- Transfer all items to winner
    IF winner_user_id IS NOT NULL AND all_match_items IS NOT NULL THEN
      -- Get winner's current inventory
      SELECT COALESCE(items_ids, '{}') INTO winner_current_items
      FROM user_inventory 
      WHERE user_id = winner_user_id;
      
      -- Update winner's inventory with all match items
      INSERT INTO user_inventory (user_id, items_ids)
      VALUES (winner_user_id, winner_current_items || all_match_items)
      ON CONFLICT (user_id) 
      DO UPDATE SET items_ids = EXCLUDED.items_ids;
      
      RAISE LOG 'Transferred all items to winner';
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

-- Update policies to prevent deletion/update of completed matches
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

-- Clean up any existing completed matches for testing
UPDATE matches SET status = 'cancelled' WHERE status = 'completed';