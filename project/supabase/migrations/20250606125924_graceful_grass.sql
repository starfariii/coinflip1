/*
  # Fix match completion function

  1. Changes
    - Fix the handle_match_completion function to properly transfer items to winner
    - Add better logging to debug the issue
    - Ensure items are correctly transferred when match completes

  2. Security
    - Function runs with SECURITY DEFINER to bypass RLS
    - Proper validation of match state
*/

-- Drop the trigger first
DROP TRIGGER IF EXISTS on_match_completion ON matches;

-- Drop and recreate the function with better logic
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
  items_count integer;
BEGIN
  -- Only process if match was just completed
  IF NEW.status = 'completed' AND OLD.status = 'active' AND NEW.result IS NOT NULL THEN
    
    -- Log the match completion details
    RAISE NOTICE 'Processing match completion: ID=%, Result=%, Selected_side=%, Creator=%, Member=%', 
      NEW.id, NEW.result, NEW.selected_side, NEW.creator_id, NEW.member_id;
    
    -- Determine winner and loser based on the result and selected_side
    IF NEW.result = NEW.selected_side THEN
      -- Creator won (their selected side came up)
      winner_id := NEW.creator_id;
      loser_id := NEW.member_id;
      RAISE NOTICE 'Creator won the match';
    ELSE
      -- Member won (opposite side came up)
      winner_id := NEW.member_id;
      loser_id := NEW.creator_id;
      RAISE NOTICE 'Member won the match';
    END IF;

    -- Get all items from the match (both creator's and member's items)
    all_match_items := NEW.items_ids;
    items_count := array_length(all_match_items, 1);
    
    RAISE NOTICE 'Items to transfer: % (count: %)', all_match_items, items_count;

    -- Get winner's current inventory
    SELECT items_ids INTO winner_inventory_items
    FROM user_inventory
    WHERE user_id = winner_id;

    RAISE NOTICE 'Winner current inventory: %', winner_inventory_items;

    -- If winner has no inventory record, create one
    IF winner_inventory_items IS NULL THEN
      RAISE NOTICE 'Creating new inventory for winner';
      INSERT INTO user_inventory (user_id, items_ids)
      VALUES (winner_id, all_match_items)
      ON CONFLICT (user_id) DO UPDATE SET items_ids = all_match_items;
    ELSE
      -- Add all match items to winner's inventory
      RAISE NOTICE 'Adding items to existing inventory';
      UPDATE user_inventory
      SET items_ids = winner_inventory_items || all_match_items
      WHERE user_id = winner_id;
    END IF;

    -- Verify the update worked
    SELECT items_ids INTO winner_inventory_items
    FROM user_inventory
    WHERE user_id = winner_id;
    
    RAISE NOTICE 'Winner final inventory: % (count: %)', 
      winner_inventory_items, array_length(winner_inventory_items, 1);

    -- Log the completion for debugging
    RAISE NOTICE 'Match % completed successfully. Winner: %, Loser: %, Items transferred: %', 
      NEW.id, winner_id, loser_id, items_count;

  END IF;

  RETURN NEW;
END;
$$;

-- Recreate the trigger
CREATE TRIGGER on_match_completion
  AFTER UPDATE ON matches
  FOR EACH ROW
  EXECUTE FUNCTION handle_match_completion();

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION handle_match_completion() TO authenticated;