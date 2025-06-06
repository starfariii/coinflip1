/*
  # Add in_match column to items table

  1. Changes
    - Add `in_match` boolean column to `items` table with default value of false
    - Add `cancelled` as a valid status for matches table
*/

-- Add in_match column to items table
ALTER TABLE items ADD COLUMN IF NOT EXISTS in_match boolean DEFAULT false;

-- Update matches status check constraint
ALTER TABLE matches DROP CONSTRAINT IF EXISTS matches_status_check;
ALTER TABLE matches ADD CONSTRAINT matches_status_check 
  CHECK (status = ANY (ARRAY['active'::text, 'completed'::text, 'cancelled'::text]));