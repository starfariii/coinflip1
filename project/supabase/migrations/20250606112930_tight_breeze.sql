/*
  # Fix match winner logic and prevent completed match cancellation

  1. Changes
    - Add trigger to handle match completion and item transfer
    - Prevent cancellation of completed matches
    - Ensure proper item transfer to winner

  2. Security
    - Update policies to prevent manipulation of completed matches
*/

-- Function to handle match completion and item transfer
CREATE OR REPLACE FUNCTION handle_match_completion()
RETURNS TRIGGER AS $$
DECLARE
  winner_user_id uuid;
  all_match_items uuid[];
BEGIN
  -- Only process when match status changes to 'completed'
  IF NEW.status = 'completed' AND OLD.status = 'active' THEN
    -- Get all items from this match
    SELECT array_agg(item_id) INTO all_match_items
    FROM match_items 
    WHERE match_id = NEW.id;
    
    -- Determine winner based on result
    SELECT user_id INTO winner_user_id
    FROM match_items 
    WHERE match_id = NEW.id 
    AND side = NEW.result 
    LIMIT 1;
    
    -- Transfer all items to winner
    IF winner_user_id IS NOT NULL AND all_match_items IS NOT NULL THEN
      -- Get winner's current inventory
      INSERT INTO user_inventory (user_id, items_ids)
      VALUES (winner_user_id, all_match_items)
      ON CONFLICT (user_id) 
      DO UPDATE SET items_ids = user_inventory.items_ids || all_match_items;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for match completion
DROP TRIGGER IF EXISTS on_match_completion ON matches;
CREATE TRIGGER on_match_completion
  AFTER UPDATE ON matches
  FOR EACH ROW
  EXECUTE FUNCTION handle_match_completion();

-- Update match deletion policy to prevent deletion of completed matches
DROP POLICY IF EXISTS "Users can delete their own matches" ON matches;

CREATE POLICY "Users can delete their own active matches"
  ON matches
  FOR DELETE
  TO authenticated
  USING (auth.uid() = creator_id AND status = 'active');

-- Add policy to prevent updates to completed matches
DROP POLICY IF EXISTS "Users can update their own matches" ON matches;

CREATE POLICY "Users can update their own active matches"
  ON matches
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = creator_id AND status = 'active')
  WITH CHECK (auth.uid() = creator_id);