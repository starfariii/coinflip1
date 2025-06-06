/*
  # Add in_match column to items table

  1. Changes
    - Add `in_match` boolean column to `items` table with default value of false
    - This column tracks whether an item is currently being used in a match

  2. Notes
    - Default value ensures existing items are marked as not in a match
    - Column is nullable to maintain compatibility with existing data
*/

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'items' 
    AND column_name = 'in_match'
  ) THEN
    ALTER TABLE items ADD COLUMN in_match boolean DEFAULT false;
  END IF;
END $$;