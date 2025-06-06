/*
  # Fix inventory item removal logic

  1. Problem
    - Current function uses array_remove() which removes ALL instances of an item
    - When user has multiple identical items, all get removed instead of just selected ones

  2. Solution
    - Replace array_remove() with proper logic to remove only one instance per item
    - Use array indexing to remove items one by one
*/

-- Drop and recreate the join_match_atomic function with correct item removal logic
DROP FUNCTION IF EXISTS join_match_atomic(uuid, uuid, uuid[]);

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
  joiner_inventory_record user_inventory%ROWTYPE;
  updated_joiner_items uuid[];
  item_to_remove uuid;
  item_index integer;
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

  -- Check if joiner has inventory
  IF joiner_inventory_record.items_ids IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'User inventory not found');
  END IF;

  -- Start with current inventory
  updated_joiner_items := joiner_inventory_record.items_ids;

  -- Remove each item one by one (to handle duplicates correctly)
  FOREACH item_to_remove IN ARRAY new_items
  LOOP
    -- Find the first occurrence of this item in the inventory
    SELECT array_position(updated_joiner_items, item_to_remove) INTO item_index;
    
    -- If item not found, return error
    IF item_index IS NULL THEN
      RETURN json_build_object('success', false, 'error', 'Item not found in inventory: ' || item_to_remove);
    END IF;
    
    -- Remove only this one instance by reconstructing the array without this element
    updated_joiner_items := 
      updated_joiner_items[1:item_index-1] || 
      updated_joiner_items[item_index+1:array_length(updated_joiner_items, 1)];
  END LOOP;

  -- Update the match with the new member and combined items
  UPDATE matches
  SET 
    member_id = user_id,
    items_ids = array_cat(items_ids, new_items)
  WHERE id = match_id;

  -- Update joiner's inventory (remove only the selected items)
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
GRANT EXECUTE ON FUNCTION join_match_atomic(uuid, uuid, uuid[]) TO anon;