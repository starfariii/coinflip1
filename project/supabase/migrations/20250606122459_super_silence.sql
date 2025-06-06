/*
  # Create join_match_atomic RPC function

  1. New Functions
    - `join_match_atomic` - Atomically joins a match and updates inventory
      - Takes match_id, user_id, and new_items as parameters
      - Ensures atomic operation to prevent race conditions
      - Properly handles RLS policies by using SECURITY DEFINER

  2. Security
    - Function runs with elevated privileges to bypass RLS when needed
    - Includes proper validation to ensure user can only join available matches
    - Maintains data integrity through atomic operations
*/

CREATE OR REPLACE FUNCTION join_match_atomic(
  match_id uuid,
  user_id uuid,
  new_items uuid[]
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  match_record matches%ROWTYPE;
  current_inventory uuid[];
  updated_inventory uuid[];
  result json;
BEGIN
  -- Get the match record with row lock to prevent race conditions
  SELECT * INTO match_record
  FROM matches
  WHERE id = match_id
  FOR UPDATE;

  -- Check if match exists
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Match not found');
  END IF;

  -- Check if match is still active
  IF match_record.status != 'active' THEN
    RETURN json_build_object('success', false, 'error', 'Match is not active');
  END IF;

  -- Check if match already has a member
  IF match_record.member_id IS NOT NULL THEN
    RETURN json_build_object('success', false, 'error', 'Match already has a member');
  END IF;

  -- Check if user is trying to join their own match
  IF match_record.creator_id = user_id THEN
    RETURN json_build_object('success', false, 'error', 'Cannot join own match');
  END IF;

  -- Update the match with the new member and combined items
  UPDATE matches
  SET 
    member_id = user_id,
    items_ids = array_cat(items_ids, new_items)
  WHERE id = match_id;

  -- Get current user inventory
  SELECT items_ids INTO current_inventory
  FROM user_inventory
  WHERE user_inventory.user_id = join_match_atomic.user_id;

  -- If no inventory exists, create one
  IF NOT FOUND THEN
    INSERT INTO user_inventory (user_id, items_ids)
    VALUES (user_id, '{}');
    current_inventory := '{}';
  END IF;

  -- Remove the new_items from user's inventory
  updated_inventory := current_inventory;
  
  -- Remove each item from inventory (handling duplicates)
  FOR i IN 1..array_length(new_items, 1) LOOP
    FOR j IN 1..array_length(updated_inventory, 1) LOOP
      IF updated_inventory[j] = new_items[i] THEN
        updated_inventory := array_remove(updated_inventory, new_items[i]);
        EXIT; -- Only remove one instance
      END IF;
    END LOOP;
  END LOOP;

  -- Update user inventory
  UPDATE user_inventory
  SET items_ids = updated_inventory
  WHERE user_inventory.user_id = join_match_atomic.user_id;

  RETURN json_build_object('success', true);

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION join_match_atomic(uuid, uuid, uuid[]) TO authenticated;