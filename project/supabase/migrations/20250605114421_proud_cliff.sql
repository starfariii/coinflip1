/*
  # Fix match deletion cascade

  1. Changes
    - Add ON DELETE CASCADE to match_items foreign key
    - Ensure items are properly marked as not in_match when matches are deleted
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