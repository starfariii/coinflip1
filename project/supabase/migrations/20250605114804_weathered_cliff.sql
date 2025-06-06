/*
  # Fix match deletion cascade

  This migration ensures that:
  1. Deleting a match properly cascades to match_items
  2. The trigger correctly handles item status updates
  3. Only match creators can delete their matches
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

-- Drop and recreate the trigger to ensure it's properly set up
DROP TRIGGER IF EXISTS match_items_changes ON match_items;

CREATE TRIGGER match_items_changes
AFTER INSERT OR DELETE ON match_items
FOR EACH ROW
EXECUTE FUNCTION handle_match_item_changes();

-- Add policy to ensure only creators can delete their matches
DROP POLICY IF EXISTS "Users can delete their own matches" ON matches;

CREATE POLICY "Users can delete their own matches"
ON matches
FOR DELETE
TO authenticated
USING (auth.uid() = creator_id);