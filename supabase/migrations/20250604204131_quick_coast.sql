/*
  # Clean up matches and reset items

  1. Changes
    - Delete all existing matches
    - Reset all items to not be in matches
  2. Security
    - No changes to security policies
*/

-- Delete all match items first due to foreign key constraints
DELETE FROM match_items;

-- Delete all matches
DELETE FROM matches;

-- Reset all items to not be in matches
UPDATE items SET in_match = false;