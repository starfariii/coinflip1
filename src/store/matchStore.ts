import { create } from 'zustand';
import { supabase } from '../lib/supabase';

interface Match {
  id: string;
  creator_id: string;
  member_id?: string;
  items_ids: string[];
  selected_side: 'heads' | 'tails';
  status: 'active' | 'pending' | 'completed';
  result?: 'heads' | 'tails';
  created_at: string;
}

interface MatchStore {
  matches: Match[];
  loading: boolean;
  flipResult: {
    result: 'heads' | 'tails' | null;
    winnerSide: 'heads' | 'tails' | null;
    userSide: 'heads' | 'tails' | null;
    isFlipping: boolean;
    showModal: boolean;
  };
  fetchMatches: () => Promise<void>;
  createMatch: (side: 'heads' | 'tails', selectedItems: { itemId: string; inventoryIndex: number }[]) => Promise<void>;
  joinMatch: (matchId: string, itemIds: string[]) => Promise<void>;
  cancelMatch: (matchId: string) => Promise<void>;
  setFlipResult: (result: any) => void;
  resetFlipResult: () => void;
}

export const useMatchStore = create<MatchStore>((set, get) => ({
  matches: [],
  loading: false,
  flipResult: {
    result: null,
    winnerSide: null,
    userSide: null,
    isFlipping: false,
    showModal: false,
  },

  setFlipResult: (result) => set({ flipResult: result }),
  
  resetFlipResult: () => set({ 
    flipResult: {
      result: null,
      winnerSide: null,
      userSide: null,
      isFlipping: false,
      showModal: false,
    }
  }),

  fetchMatches: async () => {
    set({ loading: true });
    
    const { data: matches } = await supabase
      .from('matches')
      .select('*')
      .eq('status', 'active')
      .order('created_at', { ascending: false });

    if (matches) {
      set({ matches });
    }

    set({ loading: false });
  },

  createMatch: async (side: 'heads' | 'tails', selectedItems: { itemId: string; inventoryIndex: number }[]) => {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;

    // Extract just the item IDs for the match
    const itemIds = selectedItems.map(item => item.itemId);

    // Remove items from user's inventory first
    const { data: inventoryData } = await supabase
      .from('user_inventory')
      .select('items_ids')
      .eq('user_id', user.id)
      .maybeSingle();

    if (inventoryData && inventoryData.items_ids) {
      const updatedItemsIds = [...inventoryData.items_ids];
      
      // Sort by inventory index in descending order to avoid index shifting
      const sortedItems = selectedItems.sort((a, b) => b.inventoryIndex - a.inventoryIndex);
      
      sortedItems.forEach(({ inventoryIndex }) => {
        if (inventoryIndex >= 0 && inventoryIndex < updatedItemsIds.length) {
          updatedItemsIds.splice(inventoryIndex, 1);
        }
      });

      await supabase
        .from('user_inventory')
        .update({ items_ids: updatedItemsIds })
        .eq('user_id', user.id);
    }

    // Create the match
    const { data: match } = await supabase
      .from('matches')
      .insert({ 
        creator_id: user.id, 
        selected_side: side,
        items_ids: itemIds
      })
      .select()
      .single();

    if (match) {
      await get().fetchMatches();
    }
  },

  joinMatch: async (matchId: string, itemIds: string[]) => {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      throw new Error('You must be logged in to join a match.');
    }

    console.log('Attempting to join match:', matchId, 'with items:', itemIds);

    // Fetch the latest match data from the database to ensure we have current state
    const { data: matchData, error: fetchError } = await supabase
      .from('matches')
      .select('*')
      .eq('id', matchId)
      .maybeSingle();

    console.log('Fetched match data:', matchData, 'Error:', fetchError);

    if (fetchError) {
      console.error('Database error fetching match:', fetchError);
      throw new Error('Failed to fetch match data. Please try again.');
    }

    if (!matchData) {
      console.error('No match found with ID:', matchId);
      throw new Error('The match you tried to join no longer exists.');
    }

    // Check if match is still active and available to join
    if (matchData.status !== 'active') {
      console.error('Match status is not active:', matchData.status);
      throw new Error('This match is no longer active and cannot be joined.');
    }

    if (matchData.member_id) {
      console.error('Match already has a member:', matchData.member_id);
      throw new Error('This match already has a member and is no longer available.');
    }

    if (matchData.creator_id === user.id) {
      console.error('User trying to join own match');
      throw new Error('You cannot join your own match.');
    }

    // Calculate total values for validation
    const { data: selectedItems } = await supabase
      .from('items')
      .select('value')
      .in('id', itemIds);

    if (!selectedItems) {
      throw new Error('Failed to fetch selected items data.');
    }

    const { data: matchItems } = await supabase
      .from('items')
      .select('value')
      .in('id', matchData.items_ids);

    if (!matchItems) {
      throw new Error('Failed to fetch match items data.');
    }

    const joinValue = selectedItems.reduce((sum, item) => sum + item.value, 0);
    const matchValue = matchItems.reduce((sum, item) => sum + item.value, 0);
    
    console.log('Value validation - Join value:', joinValue, 'Match value:', matchValue);
    
    // Check if join value is within acceptable range
    if (joinValue < matchValue * 0.9 || joinValue > matchValue * 1.1) {
      throw new Error(`Total value must be between ${Math.floor(matchValue * 0.9)} and ${Math.ceil(matchValue * 1.1)} coins`);
    }

    // Generate the coin flip result immediately
    const result = Math.random() < 0.5 ? 'heads' : 'tails';
    console.log('Generated result:', result);

    // Use RPC function for atomic update to prevent race conditions
    const { data: updateResult, error: updateError } = await supabase.rpc('join_match_atomic', {
      match_id: matchId,
      user_id: user.id,
      new_items: itemIds
    });

    console.log('Update result:', updateResult, 'Error:', updateError);

    if (updateError) {
      console.error('Error updating match:', updateError);
      
      if (updateError.message?.includes('already has a member')) {
        throw new Error('Another player joined this match first. Please try a different match.');
      } else if (updateError.message?.includes('not found')) {
        throw new Error('The match is no longer available.');
      } else {
        throw new Error('Failed to join match. Please try again.');
      }
    }

    if (!updateResult || !updateResult.success) {
      console.error('Match update failed:', updateResult);
      throw new Error('The match is no longer available. Another player may have joined it first.');
    }

    console.log('Match joined successfully');

    // Update match to pending status with the pre-generated result
    // This will trigger the realtime sync for both players
    const { error: pendingError } = await supabase
      .from('matches')
      .update({ 
        status: 'pending',
        result: result // Store the result but don't reveal it yet
      })
      .eq('id', matchId);

    if (pendingError) {
      console.error('Error setting match to pending:', pendingError);
    }

    // After 2 seconds, reveal the result by setting status to completed
    setTimeout(async () => {
      const { error } = await supabase
        .from('matches')
        .update({ status: 'completed' })
        .eq('id', matchId);

      if (error) {
        console.error('Error completing match:', error);
      } else {
        console.log('Match completed successfully');
      }

      await get().fetchMatches();
    }, 2000);
  },

  cancelMatch: async (matchId: string) => {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;

    // Get the match data
    const { data: matchData } = await supabase
      .from('matches')
      .select('*')
      .eq('id', matchId)
      .single();

    if (!matchData) {
      throw new Error('Match not found');
    }

    if (matchData.status !== 'active') {
      throw new Error('Cannot cancel a completed match');
    }

    if (matchData.creator_id !== user.id) {
      throw new Error('Only the match creator can cancel the match');
    }

    // Return items to creator's inventory
    if (matchData.items_ids && matchData.items_ids.length > 0) {
      const { data: inventoryData } = await supabase
        .from('user_inventory')
        .select('items_ids')
        .eq('user_id', user.id)
        .maybeSingle();

      if (inventoryData && inventoryData.items_ids) {
        const updatedItemsIds = [...inventoryData.items_ids, ...matchData.items_ids];

        await supabase
          .from('user_inventory')
          .update({ items_ids: updatedItemsIds })
          .eq('user_id', user.id);
      }
    }

    // Delete the match
    const { error } = await supabase
      .from('matches')
      .delete()
      .eq('id', matchId)
      .eq('creator_id', user.id);

    if (error) {
      console.error('Error deleting match:', error);
      throw new Error('Failed to cancel match');
    }

    await get().fetchMatches();
  }
}));