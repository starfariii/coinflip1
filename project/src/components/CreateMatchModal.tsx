import React, { useState, useEffect } from 'react';
import { X } from 'lucide-react';
import { supabase } from '../lib/supabase';

interface CreateMatchModalProps {
  isOpen: boolean;
  onClose: () => void;
  onCreateMatch: (side: 'heads' | 'tails', selectedItems: { itemId: string; inventoryIndex: number }[]) => void;
}

export const CreateMatchModal: React.FC<CreateMatchModalProps> = ({
  isOpen,
  onClose,
  onCreateMatch
}) => {
  const [selectedSide, setSelectedSide] = useState<'heads' | 'tails'>('heads');
  const [selectedItems, setSelectedItems] = useState<string[]>([]);
  const [availableItems, setAvailableItems] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchUserItems = async () => {
      try {
        setLoading(true);
        setError(null);
        
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) return;

        // Get user's inventory items
        const { data: inventoryData } = await supabase
          .from('user_inventory')
          .select('items_ids')
          .eq('user_id', user.id)
          .maybeSingle();

        if (inventoryData && inventoryData.items_ids && inventoryData.items_ids.length > 0) {
          // Get unique item IDs to fetch item data
          const uniqueItemIds = [...new Set(inventoryData.items_ids)];
          
          // Fetch actual items data
          const { data: items } = await supabase
            .from('items')
            .select('*')
            .in('id', uniqueItemIds);

          // Create a map of item data for quick lookup
          const itemMap = new Map(items?.map(item => [item.id, item]) || []);
          
          // Process inventory to show each item instance separately
          const processedItems: any[] = [];
          
          inventoryData.items_ids.forEach((itemId: string, index: number) => {
            const itemData = itemMap.get(itemId);
            if (itemData) {
              processedItems.push({
                ...itemData,
                inventoryIndex: index, // Track position in inventory
                uniqueKey: `${itemId}-${index}` // Unique key for React
              });
            }
          });

          setAvailableItems(processedItems);
        } else {
          setAvailableItems([]);
        }
      } catch (error) {
        console.error('Error fetching inventory:', error);
        setError('Failed to load inventory');
      } finally {
        setLoading(false);
      }
    };

    if (isOpen) {
      fetchUserItems();
    }
  }, [isOpen]);

  const totalValue = availableItems
    .filter(item => selectedItems.includes(item.uniqueKey))
    .reduce((sum, item) => sum + item.value, 0);

  const handleCreateMatch = () => {
    if (selectedItems.length === 0) {
      setError('Please select at least one item');
      return;
    }
    
    // Convert selected unique keys to item data with inventory indices
    const selectedItemData = selectedItems.map(uniqueKey => {
      const item = availableItems.find(item => item.uniqueKey === uniqueKey);
      return {
        itemId: item?.id,
        inventoryIndex: item?.inventoryIndex
      };
    }).filter(item => item.itemId);
    
    onCreateMatch(selectedSide, selectedItemData);
    onClose();
    setSelectedItems([]);
    setSelectedSide('heads');
    setError(null);
  };

  useEffect(() => {
    if (!isOpen) {
      setSelectedItems([]);
      setError(null);
    }
  }, [isOpen]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-gray-800 rounded-lg w-full max-w-2xl p-6">
        <div className="flex justify-between items-center mb-6">
          <h3 className="text-xl font-bold">Create Match</h3>
          <button onClick={onClose} className="text-gray-400 hover:text-white">
            <X size={24} />
          </button>
        </div>

        <div className="mb-6">
          <label className="block text-sm text-gray-400 mb-2">Select Side</label>
          <div className="grid grid-cols-2 gap-3">
            <button
              onClick={() => setSelectedSide('heads')}
              className={`py-3 rounded-lg ${
                selectedSide === 'heads'
                  ? 'bg-indigo-600 text-white'
                  : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
              }`}
            >
              Heads
            </button>
            <button
              onClick={() => setSelectedSide('tails')}
              className={`py-3 rounded-lg ${
                selectedSide === 'tails'
                  ? 'bg-indigo-600 text-white'
                  : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
              }`}
            >
              Tails
            </button>
          </div>
        </div>

        <div className="mb-6">
          <div className="flex justify-between items-center mb-2">
            <label className="text-sm text-gray-400">Select Items</label>
            <span className="text-sm text-gray-400">Total: {totalValue} coins</span>
          </div>
          
          {error && (
            <div className="mb-4 p-3 bg-red-900/50 border border-red-700 rounded-lg text-red-400 text-sm">
              {error}
            </div>
          )}

          {loading ? (
            <div className="text-center py-8 text-gray-400">Loading items...</div>
          ) : availableItems.length === 0 ? (
            <div className="text-center py-8 text-gray-400">No items available in your inventory</div>
          ) : (
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3 max-h-64 overflow-y-auto">
              {availableItems.map((item, index) => {
                const isSelected = selectedItems.includes(item.uniqueKey);
                
                return (
                  <div
                    key={item.uniqueKey}
                    onClick={() => {
                      setSelectedItems(prev =>
                        prev.includes(item.uniqueKey)
                          ? prev.filter(key => key !== item.uniqueKey)
                          : [...prev, item.uniqueKey]
                      );
                      setError(null);
                    }}
                    className={`
                      bg-gray-700 rounded-lg p-3 cursor-pointer transition-colors relative
                      ${isSelected ? 'ring-2 ring-indigo-500' : ''}
                    `}
                  >
                    {isSelected && (
                      <div className="absolute -top-2 -right-2 bg-indigo-500 text-white rounded-full w-6 h-6 flex items-center justify-center text-xs font-bold">
                        ✓
                      </div>
                    )}
                    <div className="h-24 rounded overflow-hidden mb-2">
                      <img src={item.image_url} alt={item.name} className="w-full h-full object-cover" />
                    </div>
                    <div className="flex justify-between items-start">
                      <span className="text-sm font-medium">{item.name}</span>
                      <span className={`text-xs px-2 py-1 rounded ${
                        item.rarity === 'rare' ? 'bg-blue-900/30 text-blue-400' :
                        item.rarity === 'epic' ? 'bg-purple-900/30 text-purple-400' :
                        'bg-green-900/30 text-green-400'
                      }`}>
                        {item.rarity}
                      </span>
                    </div>
                    <div className="flex items-center justify-between mt-1">
                      <div className="text-yellow-400 text-sm">{item.value} coins</div>
                      <span className="text-xs text-gray-400">#{index + 1}</span>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        <button
          onClick={handleCreateMatch}
          disabled={selectedItems.length === 0}
          className={`
            w-full py-4 rounded-lg font-medium
            ${selectedItems.length === 0
              ? 'bg-gray-600 text-gray-400 cursor-not-allowed'
              : 'bg-indigo-600 hover:bg-indigo-700 text-white'
            }
          `}
        >
          Create Match
        </button>
      </div>
    </div>
  );
};