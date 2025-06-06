import React, { useEffect, useState } from 'react';
import { CoinsIcon, UserIcon, X } from 'lucide-react';
import { CreateMatchModal } from '../components/CreateMatchModal';
import { JoinMatchModal } from '../components/JoinMatchModal';
import { CoinFlipModal } from '../components/CoinFlipModal';
import { useMatchStore } from '../store/matchStore';
import { supabase } from '../lib/supabase';

export const CoinflipPage: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'all' | 'my'>('all');
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [isJoinModalOpen, setIsJoinModalOpen] = useState(false);
  const [selectedMatchId, setSelectedMatchId] = useState<string | null>(null);
  const [selectedMatchValue, setSelectedMatchValue] = useState<number>(0);
  const [matchItems, setMatchItems] = useState<any[]>([]);
  const { 
    matches, 
    loading, 
    flipResult,
    fetchMatches, 
    createMatch, 
    joinMatch, 
    cancelMatch,
    resetFlipResult
  } = useMatchStore();
  const [userId, setUserId] = useState<string | null>(null);

  useEffect(() => {
    const fetchUser = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (user) setUserId(user.id);
    };

    fetchUser();
    fetchMatches();

    // Subscribe to changes for real-time sync
    const channel = supabase
      .channel('matches')
      .on('postgres_changes', { 
        event: 'UPDATE', 
        schema: 'public', 
        table: 'matches' 
      }, async (payload) => {
        console.log('Match updated:', payload);
        
        const updatedMatch = payload.new as any;
        const { data: { user } } = await supabase.auth.getUser();
        
        if (user && updatedMatch) {
          // Если кто-то присоединился к матчу (member_id добавился)
          if (updatedMatch.member_id && updatedMatch.status === 'active' && !updatedMatch.result) {
            const isParticipant = updatedMatch.creator_id === user.id || updatedMatch.member_id === user.id;
            
            if (isParticipant) {
              // Определяем сторону пользователя
              const userSide = updatedMatch.creator_id === user.id 
                ? updatedMatch.selected_side 
                : (updatedMatch.selected_side === 'heads' ? 'tails' : 'heads');
              
              // Начинаем анимацию у всех участников
              useMatchStore.getState().setFlipResult({
                result: null,
                winnerSide: null,
                userSide: userSide,
                isFlipping: true,
                showModal: true,
              });
              
              // Только создатель генерирует результат
              if (updatedMatch.creator_id === user.id) {
                setTimeout(async () => {
                  const result = Math.random() < 0.5 ? 'heads' : 'tails';
                  
                  await supabase
                    .from('matches')
                    .update({ status: 'completed', result })
                    .eq('id', updatedMatch.id);
                }, 2000);
              }
            }
          }
          
          // Если матч завершен (получен результат)
          if (updatedMatch.status === 'completed' && updatedMatch.result) {
            const isParticipant = updatedMatch.creator_id === user.id || updatedMatch.member_id === user.id;
            
            if (isParticipant) {
              const userSide = updatedMatch.creator_id === user.id 
                ? updatedMatch.selected_side 
                : (updatedMatch.selected_side === 'heads' ? 'tails' : 'heads');
              
              // Показываем результат
              useMatchStore.getState().setFlipResult({
                result: updatedMatch.result,
                winnerSide: updatedMatch.result,
                userSide: userSide,
                isFlipping: false,
                showModal: true,
              });
            }
          }
        }
        
        // Обновляем список матчей
        fetchMatches();
      })
      .subscribe();

    return () => {
      channel.unsubscribe();
    };
  }, [fetchMatches]);

  // Fetch items for display
  const [allItems, setAllItems] = useState<any[]>([]);
  
  useEffect(() => {
    const fetchItems = async () => {
      const { data: items } = await supabase.from('items').select('*');
      if (items) setAllItems(items);
    };
    fetchItems();
  }, []);

  const getItemsForMatch = (itemIds: string[]) => {
    // Create a map of item data for quick lookup
    const itemMap = new Map(allItems.map(item => [item.id, item]));
    
    // Return all items including duplicates, preserving order
    return itemIds.map(itemId => itemMap.get(itemId)).filter(Boolean);
  };

  const handleCreateMatch = async (side: 'heads' | 'tails', selectedItems: { itemId: string; inventoryIndex: number }[]) => {
    try {
      await createMatch(side, selectedItems);
      setIsCreateModalOpen(false);
    } catch (error) {
      console.error('Error creating match:', error);
    }
  };

  const handleJoinMatchClick = (matchId: string) => {
    const match = matches.find(m => m.id === matchId);
    if (!match) return;

    const items = getItemsForMatch(match.items_ids);
    const matchValue = items.reduce((sum, item) => sum + item.value, 0);
    setSelectedMatchId(matchId);
    setSelectedMatchValue(matchValue);
    setMatchItems(items);
    setIsJoinModalOpen(true);
  };

  const handleJoinMatch = async (itemIds: string[]) => {
    if (!selectedMatchId) return;
    
    await joinMatch(selectedMatchId, itemIds);
    setIsJoinModalOpen(false);
    setSelectedMatchId(null);
    setSelectedMatchValue(0);
    setMatchItems([]);
  };

  const handleCancelMatch = async (matchId: string) => {
    try {
      await cancelMatch(matchId);
    } catch (error) {
      console.error('Error cancelling match:', error);
      alert(error instanceof Error ? error.message : 'Error cancelling match');
    }
  };

  const handleCloseCoinFlip = () => {
    resetFlipResult();
  };

  const displayedMatches = activeTab === 'my' 
    ? matches.filter(match => match.creator_id === userId || match.member_id === userId)
    : matches;

  if (loading) {
    return <div className="text-center py-8">Loading...</div>;
  }

  return (
    <div className="max-w-5xl mx-auto">
      <div className="flex justify-between items-center mb-8">
        <div className="flex space-x-4">
          <button
            onClick={() => setActiveTab('all')}
            className={`px-6 py-3 rounded-lg font-medium transition-colors ${
              activeTab === 'all'
                ? 'bg-indigo-600 text-white'
                : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
            }`}
          >
            All Matches
          </button>
          <button
            onClick={() => setActiveTab('my')}
            className={`px-6 py-3 rounded-lg font-medium transition-colors ${
              activeTab === 'my'
                ? 'bg-indigo-600 text-white'
                : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
            }`}
          >
            My Matches
          </button>
        </div>
        <button 
          onClick={() => setIsCreateModalOpen(true)}
          className="px-6 py-3 bg-green-600 hover:bg-green-700 text-white rounded-lg font-medium transition-colors"
        >
          Create Match
        </button>
      </div>

      <div className="grid gap-6">
        {displayedMatches.map(match => {
          const isCreator = match.creator_id === userId;
          const isMember = match.member_id === userId;
          const hasJoined = match.member_id !== null;
          const canJoin = !isCreator && !hasJoined && userId;
          const canCancel = isCreator && match.status === 'active' && !hasJoined;
          const items = getItemsForMatch(match.items_ids);
          const totalValue = items.reduce((sum, item) => sum + item.value, 0);
          
          return (
            <div key={match.id} className="bg-gray-800 rounded-lg p-6">
              <div className="flex justify-between items-start mb-6">
                <div className="flex items-center">
                  <div className="w-10 h-10 bg-gray-700 rounded-full flex items-center justify-center mr-3">
                    <UserIcon size={20} className="text-gray-400" />
                  </div>
                  <div>
                    <h3 className="font-medium">
                      {isCreator ? 'You' : 'Player'}
                      {hasJoined && (
                        <span className="text-sm text-gray-400 ml-2">
                          vs {isMember ? 'You' : 'Player'}
                        </span>
                      )}
                    </h3>
                    <p className="text-sm text-gray-400">{new Date(match.created_at).toLocaleString()}</p>
                  </div>
                </div>
                <div className="flex items-center space-x-4">
                  <div className={`px-4 py-2 rounded-lg ${
                    match.selected_side === 'heads' ? 'bg-yellow-900/20 text-yellow-400' : 'bg-gray-900/40 text-gray-300'
                  }`}>
                    {match.selected_side.charAt(0).toUpperCase() + match.selected_side.slice(1)}
                  </div>
                  <div className="flex items-center bg-gray-700 px-4 py-2 rounded-lg">
                    <CoinsIcon size={16} className="text-yellow-400 mr-2" />
                    <span>{totalValue}</span>
                  </div>
                  {canCancel && (
                    <button
                      onClick={() => handleCancelMatch(match.id)}
                      className="p-2 bg-red-600 hover:bg-red-700 text-white rounded-lg transition-colors"
                      title="Cancel Match"
                    >
                      <X size={16} />
                    </button>
                  )}
                </div>
              </div>

              <div className="border-t border-gray-700 pt-4">
                <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3 mb-4">
                  {items.map((item, index) => (
                    <div key={`${item.id}-${index}`} className="bg-gray-700 rounded-lg p-3">
                      <div className="flex justify-between items-start mb-2">
                        <span className="text-sm font-medium">{item.name}</span>
                        <span className={`text-xs px-2 py-1 rounded ${
                          item.rarity === 'rare' ? 'bg-blue-900/30 text-blue-400' :
                          item.rarity === 'epic' ? 'bg-purple-900/30 text-purple-400' :
                          'bg-green-900/30 text-green-400'
                        }`}>
                          {item.rarity}
                        </span>
                      </div>
                      <div className="flex items-center justify-between">
                        <div className="flex items-center text-yellow-400">
                          <CoinsIcon size={14} className="mr-1" />
                          <span className="text-sm">{item.value}</span>
                        </div>
                        <span className="text-xs text-gray-400">#{index + 1}</span>
                      </div>
                    </div>
                  ))}
                </div>
                {canJoin && (
                  <button 
                    onClick={() => handleJoinMatchClick(match.id)}
                    className="w-full py-3 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg font-medium transition-colors"
                  >
                    Join Match
                  </button>
                )}
              </div>
            </div>
          );
        })}
      </div>

      <CreateMatchModal
        isOpen={isCreateModalOpen}
        onClose={() => setIsCreateModalOpen(false)}
        onCreateMatch={handleCreateMatch}
      />

      <JoinMatchModal
        isOpen={isJoinModalOpen}
        onClose={() => {
          setIsJoinModalOpen(false);
          setSelectedMatchId(null);
          setSelectedMatchValue(0);
          setMatchItems([]);
        }}
        onJoinMatch={handleJoinMatch}
        matchValue={selectedMatchValue}
      />

      <CoinFlipModal
        isOpen={flipResult.showModal}
        onClose={handleCloseCoinFlip}
        result={flipResult.result}
        winnerSide={flipResult.winnerSide}
        userSide={flipResult.userSide}
        isFlipping={flipResult.isFlipping}
      />
    </div>
  );
};