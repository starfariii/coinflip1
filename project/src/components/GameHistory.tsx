import React from 'react';

interface GameHistoryProps {
  history: Array<{
    id: number;
    result: 'heads' | 'tails';
    won: boolean;
    amount: number;
  }>;
}

export const GameHistory: React.FC<GameHistoryProps> = ({ history }) => {
  if (history.length === 0) {
    return (
      <div className="text-center py-8 text-gray-500">
        No games played yet. Start flipping!
      </div>
    );
  }

  return (
    <div className="overflow-hidden">
      <div className="overflow-y-auto max-h-[500px] pr-2">
        {history.map((game) => (
          <div 
            key={game.id} 
            className={`
              mb-2 p-3 rounded-lg border
              ${game.won 
                ? 'bg-green-900 bg-opacity-20 border-green-700' 
                : 'bg-red-900 bg-opacity-20 border-red-700'
              }
            `}
          >
            <div className="flex justify-between items-center">
              <div className="flex items-center">
                <div className={`
                  w-8 h-8 rounded-full flex items-center justify-center
                  ${game.result === 'heads' 
                    ? 'bg-gradient-to-br from-yellow-300 to-yellow-600' 
                    : 'bg-gradient-to-br from-gray-300 to-gray-600'
                  }
                `}>
                  <span className="text-xs font-bold">
                    {game.result === 'heads' ? 'H' : 'T'}
                  </span>
                </div>
                <div className="ml-3">
                  <p className="font-medium">{game.result.charAt(0).toUpperCase() + game.result.slice(1)}</p>
                  <p className="text-xs text-gray-400">
                    {new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                  </p>
                </div>
              </div>
              <div className="text-right">
                <p className={`font-medium ${game.won ? 'text-green-400' : 'text-red-400'}`}>
                  {game.won ? '+' : '-'}{game.amount}
                </p>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};