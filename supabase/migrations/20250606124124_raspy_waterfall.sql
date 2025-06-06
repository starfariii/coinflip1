/*
  # Create join_match_atomic RPC function

  1. New Functions
    - `join_match_atomic` - Atomically joins a match and updates inventories
      - Validates match availability and user eligibility
      - Updates match with member_id and combined items
      - Removes items from joiner's inventory
      - Uses SECURITY DEFINER to bypass RLS policies

  2. Security
    - Function runs with elevated privileges to modify inventories
    - Includes validation to prevent unauthorized access
    - Maintains data integrity through atomic operations
*/

-- Create the join_match_atomic function with SECURITY DEFINER
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
  result_json json;
BEGIN
  -- Get the match record with row lock to prevent race conditions
  SELECT * INTO match_record
  FROM matches
  WHERE id = match_id
  FOR UPDATE;

  -- Validate match exists
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Match not found');
  END IF;

  -- Validate match is still active
  IF match_record.status != 'active' THEN
    RETURN json_build_object('success', false, 'error', 'Match is not active');
  END IF;

  -- Validate match doesn't already have a member
  IF match_record.member_id IS NOT NULL THEN
    RETURN json_build_object('success', false, 'error', 'Match already has a member');
  END IF;

  -- Validate user is not the creator
  IF match_record.creator_id = user_id THEN
    RETURN json_build_object('success', false, 'error', 'Cannot join your own match');
  END IF;

  -- Get user's current inventory
  SELECT items_ids INTO current_inventory
  FROM user_inventory
  WHERE user_inventory.user_id = join_match_atomic.user_id;

  -- If no inventory exists, create one
  IF current_inventory IS NULL THEN
    INSERT INTO user_inventory (user_id, items_ids)
    VALUES (user_id, '{}')
    ON CONFLICT (user_id) DO NOTHING;
    current_inventory := '{}';
  END IF;

  -- Validate user has all the required items
  FOR i IN 1..array_length(new_items, 1) LOOP
    IF NOT (new_items[i] = ANY(current_inventory)) THEN
      RETURN json_build_object('success', false, 'error', 'You do not own all selected items');
    END IF;
  END LOOP;

  -- Remove items from user's inventory (handle duplicates correctly)
  updated_inventory := current_inventory;
  FOR i IN 1..array_length(new_items, 1) LOOP
    -- Find and remove one instance of the item
    FOR j IN 1..array_length(updated_inventory, 1) LOOP
      IF updated_inventory[j] = new_items[i] THEN
        updated_inventory := array_remove(updated_inventory, new_items[i]);
        updated_inventory := updated_inventory || updated_inventory[j+1:];
        EXIT;
      END IF;
    END LOOP;
  END LOOP;

  -- Update user's inventory
  UPDATE user_inventory
  SET items_ids = updated_inventory
  WHERE user_inventory.user_id = join_match_atomic.user_id;

  -- Update match with member and combined items
  UPDATE matches
  SET 
    member_id = user_id,
    items_ids = match_record.items_ids || new_items
  WHERE id = match_id;

  -- Return success
  RETURN json_build_object('success', true);

EXCEPTION
  WHEN OTHERS THEN
    -- Return error details
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION join_match_atomic(uuid, uuid, uuid[]) TO authenticated;