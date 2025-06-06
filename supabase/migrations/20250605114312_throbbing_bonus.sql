/*
  # Update match deletion cascade

  1. Changes
    - Add ON DELETE CASCADE to match_items foreign key reference to matches
    - This ensures match_items are automatically deleted when a match is deleted
    - The existing trigger will then update the items.in_match status
*/

-- First remove the existing foreign key
ALTER TABLE match_items
DROP CONSTRAINT IF EXISTS match_items_match_id_fkey;

-- Add it back with CASCADE
ALTER TABLE match_items
ADD CONSTRAINT match_items_match_id_fkey
FOREIGN KEY (match_id)
REFERENCES matches(id)
ON DELETE CASCADE;