/*
  # Add in_match column to items table

  1. Changes
    - Add `in_match` boolean column to items table with default false
    - Update existing items to have in_match = false
*/

ALTER TABLE items 
ADD COLUMN IF NOT EXISTS in_match boolean DEFAULT false;

-- Set all existing items to not be in a match
UPDATE items SET in_match = false WHERE in_match IS NULL;