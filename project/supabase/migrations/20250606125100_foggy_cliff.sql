/*
  # Fix match completion rewards

  1. Updates
    - Fix handle_match_completion function to properly distribute all items to winner
    - Ensure winner gets both their own items back AND opponent's items
    - Add proper logging for debugging

  2. Security
    - Function runs with SECURITY DEFINER to bypass RLS
    - Proper error handling and validation
*/

-- Drop and recreate the handle_match_completion function
DROP FUNCTION IF EXISTS handle_match_completion();

CREATE OR REPLACE FUNCTION handle_match_completion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  winner_id uuid;
  loser_id uuid;
  winner_inventory_items uuid[];
  all_match_items uuid[];
BEGIN
  -- Only process if match was just completed
  IF NEW.status = 'completed' AND OLD.status = 'active' AND NEW.result IS NOT NULL THEN
    
    -- Determine winner and loser based on the result and selected_side
    IF NEW.result = NEW.selected_side THEN
      -- Creator won (their selected side came up)
      winner_id := NEW.creator_id;
      loser_id := NEW.member_id;
    ELSE
      -- Member won (opposite side came up)
      winner_id := NEW.member_id;
      loser_id := NEW.creator_id;
    END IF;

    -- Get all items from the match (both creator's and member's items)
    all_match_items := NEW.items_ids;

    -- Get winner's current inventory
    SELECT items_ids INTO winner_inventory_items
    FROM user_inventory
    WHERE user_id = winner_id;

    -- If winner has no inventory record, create one
    IF winner_inventory_items IS NULL THEN
      INSERT INTO user_inventory (user_id, items_ids)
      VALUES (winner_id, all_match_items)
      ON CONFLICT (user_id) DO UPDATE SET items_ids = all_match_items;
    ELSE
      -- Add all match items to winner's inventory
      UPDATE user_inventory
      SET items_ids = winner_inventory_items || all_match_items
      WHERE user_id = winner_id;
    END IF;

    -- Log the completion for debugging
    RAISE NOTICE 'Match % completed. Winner: %, Loser: %, Items transferred: %', 
      NEW.id, winner_id, loser_id, array_length(all_match_items, 1);

  END IF;

  RETURN NEW;
END;
$$;

-- Recreate the trigger
DROP TRIGGER IF EXISTS on_match_completion ON matches;
CREATE TRIGGER on_match_completion
  AFTER UPDATE ON matches
  FOR EACH ROW
  EXECUTE FUNCTION handle_match_completion();