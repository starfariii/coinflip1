/*
  # Create atomic join match function

  1. New Functions
    - `join_match_atomic` - Atomically joins a match ensuring no race conditions
      - Checks if match exists and is active
      - Checks if match has no member yet
      - Updates match with member_id and combined items_ids
      - Returns success status

  2. Security
    - Function uses security definer to ensure proper access
    - Validates user permissions and match state
*/

CREATE OR REPLACE FUNCTION join_match_atomic(
  match_id uuid,
  user_id uuid,
  new_items uuid[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  match_record matches%ROWTYPE;
  combined_items uuid[];
  update_count integer;
BEGIN
  -- Lock the match row for update to prevent race conditions
  SELECT * INTO match_record
  FROM matches
  WHERE id = match_id
  FOR UPDATE;

  -- Check if match exists
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Match not found');
  END IF;

  -- Check if match is active
  IF match_record.status != 'active' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Match is not active');
  END IF;

  -- Check if match already has a member
  IF match_record.member_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Match already has a member');
  END IF;

  -- Check if user is trying to join their own match
  IF match_record.creator_id = user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot join own match');
  END IF;

  -- Combine items
  combined_items := match_record.items_ids || new_items;

  -- Update the match
  UPDATE matches
  SET 
    member_id = user_id,
    items_ids = combined_items
  WHERE id = match_id
    AND status = 'active'
    AND member_id IS NULL;

  GET DIAGNOSTICS update_count = ROW_COUNT;

  -- Check if update was successful
  IF update_count = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to update match - may have been taken by another player');
  END IF;

  RETURN jsonb_build_object('success', true, 'match_id', match_id);
END;
$$;