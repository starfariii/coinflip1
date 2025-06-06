/*
  # Fix cascade deletion for matches

  This migration ensures that when a match is deleted:
  1. All related match_items are automatically deleted (CASCADE)
  2. The items' in_match status is properly updated
*/

-- First remove the existing foreign key if it exists
ALTER TABLE match_items
DROP CONSTRAINT IF EXISTS match_items_match_id_fkey;

-- Add it back with CASCADE
ALTER TABLE match_items
ADD CONSTRAINT match_items_match_id_fkey
FOREIGN KEY (match_id)
REFERENCES matches(id)
ON DELETE CASCADE;

-- Update the trigger function to handle cascaded deletes
CREATE OR REPLACE FUNCTION handle_match_item_changes()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE items SET in_match = true WHERE id = NEW.item_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE items SET in_match = false WHERE id = OLD.item_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;