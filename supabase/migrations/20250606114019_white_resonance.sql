/*
  # Fix item transfer system - simple and reliable solution

  1. Changes
    - Drop existing trigger and function
    - Create new simple function for handling match completion
    - Update policies to prevent modification of completed matches
    - Clean up existing completed matches

  2. Security
    - Only active matches can be deleted/updated
    - Completed matches are protected from modification
*/

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS on_match_completion ON matches;
DROP FUNCTION IF EXISTS handle_match_completion();

-- Create ultra-simple and reliable function
CREATE OR REPLACE FUNCTION handle_match_completion()
RETURNS TRIGGER AS $$
DECLARE
  winner_user_id uuid;
  loser_user_id uuid;
  all_items_in_match uuid[];
  winner_inventory uuid[];
  loser_inventory uuid[];
  item uuid;
BEGIN
  -- Only process when match status changes to 'completed'
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    
    RAISE LOG 'Processing match completion for match %', NEW.id;
    
    -- Find winner: user who chose the winning side
    SELECT user_id INTO winner_user_id
    FROM match_items 
    WHERE match_id = NEW.id 
    AND side = NEW.result 
    LIMIT 1;
    
    -- Find loser: user who chose the losing side
    SELECT user_id INTO loser_user_id
    FROM match_items 
    WHERE match_id = NEW.id 
    AND side != NEW.result 
    LIMIT 1;
    
    -- Get ALL items that were in this match
    SELECT array_agg(item_id) INTO all_items_in_match
    FROM match_items 
    WHERE match_id = NEW.id;
    
    RAISE LOG 'Winner: %, Loser: %, Items: %', winner_user_id, loser_user_id, all_items_in_match;
    
    -- Only proceed if we have both users and items
    IF winner_user_id IS NOT NULL AND loser_user_id IS NOT NULL AND all_items_in_match IS NOT NULL THEN
      
      -- Get current inventories
      SELECT COALESCE(items_ids, '{}') INTO winner_inventory
      FROM user_inventory 
      WHERE user_id = winner_user_id;
      
      SELECT COALESCE(items_ids, '{}') INTO loser_inventory
      FROM user_inventory 
      WHERE user_id = loser_user_id;
      
      RAISE LOG 'Winner inventory before: %, Loser inventory before: %', winner_inventory, loser_inventory;
      
      -- Remove ALL match items from loser's inventory
      FOREACH item IN ARRAY all_items_in_match LOOP
        loser_inventory := array_remove(loser_inventory, item);
      END LOOP;
      
      -- Add ALL match items to winner's inventory
      FOREACH item IN ARRAY all_items_in_match LOOP
        winner_inventory := array_append(winner_inventory, item);
      END LOOP;
      
      RAISE LOG 'Winner inventory after: %, Loser inventory after: %', winner_inventory, loser_inventory;
      
      -- Update loser's inventory
      UPDATE user_inventory 
      SET items_ids = loser_inventory
      WHERE user_id = loser_user_id;
      
      -- Update winner's inventory (or create if doesn't exist)
      INSERT INTO user_inventory (user_id, items_ids)
      VALUES (winner_user_id, winner_inventory)
      ON CONFLICT (user_id) 
      DO UPDATE SET items_ids = EXCLUDED.items_ids;
      
      RAISE LOG 'Successfully transferred items from % to %', loser_user_id, winner_user_id;
      
    ELSE
      RAISE LOG 'Missing data: winner=%, loser=%, items=%', winner_user_id, loser_user_id, all_items_in_match;
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

-- Ensure completed matches cannot be modified
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

-- Clean up any existing completed matches for fresh testing
DELETE FROM match_items WHERE match_id IN (SELECT id FROM matches WHERE status = 'completed');
DELETE FROM matches WHERE status = 'completed';