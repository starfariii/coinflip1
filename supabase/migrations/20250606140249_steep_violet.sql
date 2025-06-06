/*
  # Add pending status to matches

  1. Changes
    - Add 'pending' as a valid status for matches
    - This status will be used when match starts but before result is revealed
*/

-- Update matches status check constraint to include 'pending'
ALTER TABLE matches DROP CONSTRAINT IF EXISTS matches_status_check;
ALTER TABLE matches ADD CONSTRAINT matches_status_check 
  CHECK (status = ANY (ARRAY['active'::text, 'pending'::text, 'completed'::text, 'cancelled'::text]));