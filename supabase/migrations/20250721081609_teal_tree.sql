/*
  # Add more items and update user initialization

  1. New Items
    - Add 8 more items with different rarities and values
    - Total of 10+ items available for variety

  2. Update User Initialization
    - Give each new user 5 different random items
    - Update existing users to have 5 items if they have less

  3. Security
    - Maintain existing RLS policies
    - Update trigger function for new user registration
*/

-- Add more items to the items table
INSERT INTO public.items (id, name, value, rarity, image_url) VALUES
  ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'Diamond Ring', 300, 'epic', 'https://images.pexels.com/photos/1232931/pexels-photo-1232931.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1'),
  ('b2c3d4e5-f6g7-8901-bcde-f23456789012', 'Silver Watch', 150, 'rare', 'https://images.pexels.com/photos/190819/pexels-photo-190819.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1'),
  ('c3d4e5f6-g7h8-9012-cdef-345678901234', 'Ruby Gem', 250, 'epic', 'https://images.pexels.com/photos/1191531/pexels-photo-1191531.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1'),
  ('d4e5f6g7-h8i9-0123-defg-456789012345', 'Bronze Medal', 75, 'uncommon', 'https://images.pexels.com/photos/1263986/pexels-photo-1263986.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1'),
  ('e5f6g7h8-i9j0-1234-efgh-567890123456', 'Crystal Orb', 400, 'legendary', 'https://images.pexels.com/photos/1191710/pexels-photo-1191710.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1'),
  ('f6g7h8i9-j0k1-2345-fghi-678901234567', 'Ancient Scroll', 180, 'rare', 'https://images.pexels.com/photos/1029141/pexels-photo-1029141.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1'),
  ('g7h8i9j0-k1l2-3456-ghij-789012345678', 'Magic Potion', 120, 'uncommon', 'https://images.pexels.com/photos/4021775/pexels-photo-4021775.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1'),
  ('h8i9j0k1-l2m3-4567-hijk-890123456789', 'Golden Amulet', 220, 'rare', 'https://images.pexels.com/photos/1191531/pexels-photo-1191531.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1')
ON CONFLICT (id) DO NOTHING;

-- Update the handle_new_user function to give 5 random items
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  random_items uuid[];
BEGIN
  -- Get 5 random items from the items table
  SELECT array_agg(id) INTO random_items
  FROM (
    SELECT id 
    FROM public.items 
    ORDER BY RANDOM() 
    LIMIT 5
  ) AS selected_items;

  -- Insert inventory for new user with 5 random items
  INSERT INTO public.user_inventory (user_id, items_ids)
  VALUES (NEW.id, random_items)
  ON CONFLICT (user_id) DO NOTHING;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE LOG 'Error in handle_new_user: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Update existing users who have less than 5 items
DO $$
DECLARE
  user_record RECORD;
  current_items uuid[];
  items_needed integer;
  additional_items uuid[];
  all_available_items uuid[];
BEGIN
  -- Get all available item IDs
  SELECT array_agg(id) INTO all_available_items FROM public.items;
  
  -- Loop through all users
  FOR user_record IN 
    SELECT user_id, COALESCE(items_ids, '{}') as items_ids 
    FROM public.user_inventory
  LOOP
    current_items := user_record.items_ids;
    items_needed := 5 - array_length(current_items, 1);
    
    -- If user needs more items
    IF items_needed > 0 THEN
      -- Get random items that the user doesn't already have
      SELECT array_agg(id) INTO additional_items
      FROM (
        SELECT id 
        FROM public.items 
        WHERE id != ALL(current_items)
        ORDER BY RANDOM() 
        LIMIT items_needed
      ) AS new_items;
      
      -- Update user's inventory
      IF additional_items IS NOT NULL THEN
        UPDATE public.user_inventory 
        SET items_ids = current_items || additional_items
        WHERE user_id = user_record.user_id;
      END IF;
    END IF;
  END LOOP;
END $$;

-- Also update users who don't have inventory records yet
INSERT INTO public.user_inventory (user_id, items_ids)
SELECT 
  u.id,
  (
    SELECT array_agg(i.id)
    FROM (
      SELECT id 
      FROM public.items 
      ORDER BY RANDOM() 
      LIMIT 5
    ) AS i
  )
FROM auth.users u
WHERE u.id NOT IN (SELECT user_id FROM public.user_inventory)
ON CONFLICT (user_id) DO NOTHING;