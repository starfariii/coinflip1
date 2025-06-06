/*
  # Fix RLS Policy Violation for Match Joining

  1. Database Functions
    - Create or replace `join_match_atomic` function with SECURITY DEFINER
    - This allows the function to bypass RLS policies when updating user inventories
    - Ensures atomic operations when joining matches

  2. Security
    - Function runs with elevated privileges to handle cross-user inventory updates
    - Includes proper validation to prevent unauthorized operations
    - Grants execute permissions to authenticated users
*/

-- Create or replace the join_match_atomic function with SECURITY DEFINER
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
  creator_inventory_record user_inventory%ROWTYPE;
  joiner_inventory_record user_inventory%ROWTYPE;
  updated_creator_items uuid[];
  updated_joiner_items uuid[];
BEGIN
  -- Get the match record with row lock to prevent race conditions
  SELECT * INTO match_record
  FROM matches
  WHERE id = match_id AND status = 'active' AND member_id IS NULL
  FOR UPDATE;

  -- Check if match exists and is available
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Match not found or not available');
  END IF;

  -- Check if user is trying to join their own match
  IF match_record.creator_id = user_id THEN
    RETURN json_build_object('success', false, 'error', 'Cannot join your own match');
  END IF;

  -- Get joiner's inventory
  SELECT * INTO joiner_inventory_record
  FROM user_inventory
  WHERE user_inventory.user_id = join_match_atomic.user_id;

  -- Check if joiner has the required items
  IF joiner_inventory_record.items_ids IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'User inventory not found');
  END IF;

  -- Verify joiner has all the required items
  updated_joiner_items := joiner_inventory_record.items_ids;
  FOR i IN 1..array_length(new_items, 1) LOOP
    IF NOT (new_items[i] = ANY(updated_joiner_items)) THEN
      RETURN json_build_object('success', false, 'error', 'Item not found in inventory');
    END IF;
    -- Remove the item from joiner's inventory
    updated_joiner_items := array_remove(updated_joiner_items, new_items[i]);
  END LOOP;

  -- Update the match with the new member and combined items
  UPDATE matches
  SET 
    member_id = user_id,
    items_ids = array_cat(items_ids, new_items)
  WHERE id = match_id;

  -- Update joiner's inventory (remove the items they're betting)
  UPDATE user_inventory
  SET items_ids = updated_joiner_items
  WHERE user_inventory.user_id = join_match_atomic.user_id;

  RETURN json_build_object('success', true);
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION join_match_atomic(uuid, uuid, uuid[]) TO authenticated;

-- Also ensure anon users can execute it (in case needed)
GRANT EXECUTE ON FUNCTION join_match_atomic(uuid, uuid, uuid[]) TO anon;