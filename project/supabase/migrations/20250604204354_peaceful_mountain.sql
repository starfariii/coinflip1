/*
  # Fix match items handling

  1. Changes
    - Add trigger to update items.in_match when match_items change
    - Add trigger to handle match cancellation
*/

-- Function to handle match item changes
CREATE OR REPLACE FUNCTION handle_match_item_changes()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Mark item as in match when added to match_items
    UPDATE items SET in_match = true WHERE id = NEW.item_id;
  ELSIF TG_OP = 'DELETE' THEN
    -- Mark item as not in match when removed from match_items
    UPDATE items SET in_match = false WHERE id = OLD.item_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for match items
DROP TRIGGER IF EXISTS match_items_changes ON match_items;
CREATE TRIGGER match_items_changes
AFTER INSERT OR DELETE ON match_items
FOR EACH ROW
EXECUTE FUNCTION handle_match_item_changes();