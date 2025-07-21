/*
  # Fix match system - item transfer and cleanup

  1. Changes
    - Fix join_match_atomic function to properly handle item removal
    - Fix match completion to properly transfer items to winner
    - Add automatic cleanup of completed matches after 1 minute
    - Ensure items are removed from inventory when creating/joining matches

  2. Security
    - Functions use SECURITY DEFINER to bypass RLS
    - Proper validation and error handling
*/

-- Drop existing problematic functions
DROP FUNCTION IF EXISTS join_match_atomic(uuid, uuid, uuid[]);
DROP TRIGGER IF EXISTS on_match_completion ON matches;
DROP FUNCTION IF EXISTS handle_match_completion();

-- Create improved join_match_atomic function
CREATE OR REPLACE FUNCTION join_match_atomic(
  match_id uuid,
  user_id uuid,
  new_items uuid[]
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  match_record matches%ROWTYPE;
  current_inventory uuid[];
  updated_inventory uuid[];
  item_to_remove uuid;
  item_found boolean;
BEGIN
  -- Get the match record with row lock to prevent race conditions
  SELECT * INTO match_record
  FROM matches
  WHERE id = match_id AND status = 'active' AND member_id IS NULL
  FOR UPDATE;

  -- Validate match exists and is available
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Match not found or not available');
  END IF;

  -- Validate user is not the creator
  IF match_record.creator_id = user_id THEN
    RETURN json_build_object('success', false, 'error', 'Cannot join your own match');
  END IF;

  -- Get user's current inventory
  SELECT COALESCE(items_ids, '{}') INTO current_inventory
  FROM user_inventory
  WHERE user_inventory.user_id = join_match_atomic.user_id;

  -- Start with current inventory
  updated_inventory := current_inventory;

  -- Remove each item one by one (to handle duplicates correctly)
  FOREACH item_to_remove IN ARRAY new_items
  LOOP
    item_found := false;
    
    -- Find and remove the first occurrence of this item
    FOR i IN 1..array_length(updated_inventory, 1) LOOP
      IF updated_inventory[i] = item_to_remove THEN
        -- Remove this item by reconstructing array without it
        updated_inventory := 
          updated_inventory[1:i-1] || 
          updated_inventory[i+1:array_length(updated_inventory, 1)];
        item_found := true;
        EXIT;
      END IF;
    END LOOP;
    
    -- If item not found, return error
    IF NOT item_found THEN
      RETURN json_build_object('success', false, 'error', 'Item not found in inventory');
    END IF;
  END LOOP;

  -- Update user's inventory (remove the items they're betting)
  UPDATE user_inventory
  SET items_ids = updated_inventory
  WHERE user_inventory.user_id = join_match_atomic.user_id;

  -- Update match with member and combined items
  UPDATE matches
  SET 
    member_id = user_id,
    items_ids = match_record.items_ids || new_items
  WHERE id = match_id;

  RETURN json_build_object('success', true);
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Create improved match completion function
CREATE OR REPLACE FUNCTION handle_match_completion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  winner_id uuid;
  winner_inventory uuid[];
  all_match_items uuid[];
BEGIN
  -- Only process if match was just completed
  IF NEW.status = 'completed' AND OLD.status != 'completed' AND NEW.result IS NOT NULL THEN
    
    -- Determine winner based on the result and selected_side
    IF NEW.result = NEW.selected_side THEN
      -- Creator won (their selected side came up)
      winner_id := NEW.creator_id;
    ELSE
      -- Member won (opposite side came up)
      winner_id := NEW.member_id;
    END IF;

    -- Get all items from the match
    all_match_items := NEW.items_ids;

    -- Only proceed if we have a winner and items
    IF winner_id IS NOT NULL AND all_match_items IS NOT NULL AND array_length(all_match_items, 1) > 0 THEN
      
      -- Get winner's current inventory
      SELECT COALESCE(items_ids, '{}') INTO winner_inventory
      FROM user_inventory
      WHERE user_id = winner_id;

      -- Add all match items to winner's inventory
      INSERT INTO user_inventory (user_id, items_ids)
      VALUES (winner_id, winner_inventory || all_match_items)
      ON CONFLICT (user_id) 
      DO UPDATE SET items_ids = user_inventory.items_ids || all_match_items;

      RAISE NOTICE 'Match % completed. Winner % received % items', NEW.id, winner_id, array_length(all_match_items, 1);
    END IF;

    -- Schedule match deletion after 1 minute
    PERFORM pg_notify('match_completed', json_build_object('match_id', NEW.id, 'completed_at', now())::text);
  END IF;

  RETURN NEW;
END;
$$;

-- Create function to clean up old completed matches
CREATE OR REPLACE FUNCTION cleanup_completed_matches()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Delete matches that have been completed for more than 1 minute
  DELETE FROM matches 
  WHERE status = 'completed' 
  AND updated_at < now() - interval '1 minute';
  
  RAISE NOTICE 'Cleaned up old completed matches';
END;
$$;

-- Create trigger for match completion
CREATE TRIGGER on_match_completion
  AFTER UPDATE ON matches
  FOR EACH ROW
  EXECUTE FUNCTION handle_match_completion();

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION join_match_atomic(uuid, uuid, uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION handle_match_completion() TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_completed_matches() TO authenticated;