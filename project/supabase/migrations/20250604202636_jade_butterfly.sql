-- Reset all matches and items
UPDATE items SET in_match = false;
UPDATE matches SET status = 'cancelled' WHERE status = 'active';