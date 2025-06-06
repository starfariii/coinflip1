import { create } from 'zustand';
import { supabase } from '../lib/supabase';

interface Match {
  id: string;
  creator_id: string;
  member_id?: string;
  items_ids: string[];
  selected_side: 'heads' | 'tails';
  status: 'active' | 'completed';
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
  subscribeToMatches: () => () => void;
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

  subscribeToMatches: () => {
    const channel = supabase
      .channel('matches')
      .on('postgres_changes', { 
        event: '*', 
        schema: 'public', 
        table: 'matches' 
      }, async (payload) => {
        console.log('Match change detected:', payload);
        
        // Обновляем список матчей
        await get().fetchMatches();
        
        // Проверяем, если матч был обновлен с member_id (кто-то присоединился)
        if (payload.eventType === 'UPDATE' && payload.new) {
          const updatedMatch = payload.new as Match;
          const { data: { user } } = await supabase.auth.getUser();
          
          if (user && updatedMatch.member_id && updatedMatch.status === 'active') {
            // Проверяем, участвует ли текущий пользователь в этом матче
            const isParticipant = updatedMatch.creator_id === user.id || updatedMatch.member_id === user.id;
            
            if (isParticipant) {
              // Определяем сторону пользователя
              const userSide = updatedMatch.creator_id === user.id 
                ? updatedMatch.selected_side 
                : (updatedMatch.selected_side === 'heads' ? 'tails' : 'heads');
              
              // Начинаем анимацию кручения монетки
              set({ 
                flipResult: {
                  result: null,
                  winnerSide: null,
                  userSide: userSide,
                  isFlipping: true,
                  showModal: true,
                }
              });
              
              // Через 2 секунды обновляем матч с результатом
              setTimeout(async () => {
                // Генерируем результат (50/50)
                const result = Math.random() < 0.5 ? 'heads' : 'tails';
                
                // Обновляем матч с результатом (только создатель матча делает это)
                if (updatedMatch.creator_id === user.id) {
                  await supabase
                    .from('matches')
                    .update({ status: 'completed', result })
                    .eq('id', updatedMatch.id);
                }
              }, 2000);
            }
          }
        }
        
        // Проверяем, если матч завершен (получен результат)
        if (payload.eventType === 'UPDATE' && payload.new) {
          const completedMatch = payload.new as Match;
          const { data: { user } } = await supabase.auth.getUser();
          
          if (user && completedMatch.status === 'completed' && completedMatch.result) {
            // Проверяем, участвует ли текущий пользователь в этом матче
            const isParticipant = completedMatch.creator_id === user.id || completedMatch.member_id === user.id;
            
            if (isParticipant) {
              // Определяем сторону пользователя
              const userSide = completedMatch.creator_id === user.id 
                ? completedMatch.selected_side 
                : (completedMatch.selected_side === 'heads' ? 'tails' : 'heads');
              
              // Показываем результат
              set({ 
                flipResult: {
                  result: completedMatch.result,
                  winnerSide: completedMatch.result,
                  userSide: userSide,
                  isFlipping: false,
                  showModal: true,
                }
              });
            }
          }
        }
      })
      .subscribe();

    return () => {
      channel.unsubscribe();
    };
  },

  createMatch: async (side: 'heads' | 'tails', selectedItems: { itemId: string; inventoryIndex: number }[]) => {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;

    // Remove items from user's inventory first - remove only selected instances by inventory index
    const { data: inventoryData } = await supabase
      .from('user_inventory')
      .select('items_ids')
      .eq('user_id', user.id)
      .maybeSingle();

    if (inventoryData && inventoryData.items_ids) {
      // Create a copy of the inventory
      const updatedItemsIds = [...inventoryData.items_ids];
      
      // Sort selected items by inventory index in descending order to avoid index shifting issues
      const sortedItems = selectedItems.sort((a, b) => b.inventoryIndex - a.inventoryIndex);
      
      // Remove each selected item by its inventory index
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

    // Extract just the item IDs for the match
    const itemIds = selectedItems.map(item => item.itemId);

    // Create the match with items
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
    
    // Обновляем список матчей
    await get().fetchMatches();
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