/*
  # Reset matches and items state

  This migration:
  1. Sets all items' in_match status to false
  2. Updates all active matches to cancelled
  3. Ensures data consistency
*/

-- Reset all items to not be in matches
UPDATE items SET in_match = false;

-- Cancel all active matches
UPDATE matches SET status = 'cancelled' WHERE status = 'active';