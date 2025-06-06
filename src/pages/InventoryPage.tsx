import React, { useState, useEffect } from 'react';
import { CoinsIcon, PackageIcon } from 'lucide-react';
import { supabase } from '../lib/supabase';

interface InventoryItem {
  id: string;
  name: string;
  value: number;
  rarity: string;
  image_url: string;
}

interface InventoryItemWithCount extends InventoryItem {
  count: number;
  inventoryIndex: number; // To track position in inventory array
}

export const InventoryPage: React.FC = () => {
  const [inventoryItems, setInventoryItems] = useState<InventoryItemWithCount[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchInventory = async () => {
      try {
        setLoading(true);
        setError(null);
        
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) {
          setInventoryItems([]);
          return;
        }

        // Get user's inventory
        const { data: inventoryData, error: inventoryError } = await supabase
          .from('user_inventory')
          .select('items_ids')
          .eq('user_id', user.id)
          .maybeSingle();

        if (inventoryError) {
          console.error('Error fetching inventory:', inventoryError);
          setError('Failed to load inventory');
          return;
        }

        if (inventoryData && inventoryData.items_ids && inventoryData.items_ids.length > 0) {
          // Get unique item IDs to fetch item data
          const uniqueItemIds = [...new Set(inventoryData.items_ids)];
          
          // Fetch actual items data
          const { data: items, error: itemsError } = await supabase
            .from('items')
            .select('*')
            .in('id', uniqueItemIds);

          if (itemsError) {
            console.error('Error fetching items:', itemsError);
            setError('Failed to load items');
            return;
          }

          // Create a map of item data for quick lookup
          const itemMap = new Map(items?.map(item => [item.id, item]) || []);
          
          // Process inventory to show each item instance separately
          const processedItems: InventoryItemWithCount[] = [];
          
          inventoryData.items_ids.forEach((itemId: string, index: number) => {
            const itemData = itemMap.get(itemId);
            if (itemData) {
              processedItems.push({
                ...itemData,
                count: 1, // Each instance is counted as 1
                inventoryIndex: index // Track position in inventory
              });
            }
          });

          setInventoryItems(processedItems);
        } else {
          setInventoryItems([]);
        }
      } catch (error) {
        console.error('Error in fetchInventory:', error);
        setError('An unexpected error occurred');
      } finally {
        setLoading(false);
      }
    };

    fetchInventory();
  }, []);

  const totalValue = inventoryItems.reduce((sum, item) => sum + item.value, 0);

  if (loading) {
    return (
      <div className="max-w-4xl mx-auto">
        <div className="text-center py-8 text-gray-400">Loading inventory...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="max-w-4xl mx-auto">
        <div className="text-center py-8 text-red-400">{error}</div>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-gray-800 rounded-lg p-6 mb-8">
        <div className="flex justify-between items-center mb-6">
          <div>
            <h2 className="text-2xl font-bold">Your Inventory</h2>
            <p className="text-gray-400 mt-1">Manage your items ({inventoryItems.length} items)</p>
          </div>
          <div className="flex items-center bg-gray-700 px-6 py-3 rounded-lg">
            <CoinsIcon size={20} className="text-yellow-400 mr-2" />
            <div>
              <p className="text-sm text-gray-400">Estimated Value</p>
              <p className="font-medium">{totalValue} coins</p>
            </div>
          </div>
        </div>

        {inventoryItems.length === 0 ? (
          <div className="text-center py-8 text-gray-400">
            <PackageIcon size={48} className="mx-auto mb-4 text-gray-600" />
            <p>Your inventory is empty</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {inventoryItems.map((item, index) => (
              <div key={`${item.id}-${item.inventoryIndex}`} className="bg-gray-700 rounded-lg overflow-hidden">
                <div className="h-40 overflow-hidden">
                  <img 
                    src={item.image_url} 
                    alt={item.name}
                    className="w-full h-full object-cover"
                  />
                </div>
                <div className="p-4">
                  <div className="flex justify-between items-start mb-2">
                    <h3 className="font-medium">{item.name}</h3>
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
                      <CoinsIcon size={16} className="mr-1" />
                      <span>{item.value}</span>
                    </div>
                    <span className="text-xs text-gray-400">#{index + 1}</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};