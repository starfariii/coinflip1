import React from 'react';

interface CoinProps {
  isFlipping: boolean;
  result: 'heads' | 'tails' | null;
}

export const Coin: React.FC<CoinProps> = ({ isFlipping, result }) => {
  return (
    <div className="relative">
      <div 
        className={`
          w-32 h-32 rounded-full 
          ${isFlipping ? 'animate-flip' : ''} 
          ${!isFlipping && result ? 'transform transition-transform duration-300' : ''}
          ${!isFlipping && result === 'tails' ? 'rotate-y-180' : ''}
        `}
      >
        {/* Heads side */}
        <div className={`absolute inset-0 rounded-full bg-gradient-to-br from-yellow-300 to-yellow-600 flex items-center justify-center ${result === 'tails' && !isFlipping ? 'opacity-0' : ''}`}>
          <span className="text-xl font-bold text-yellow-900">H</span>
        </div>
        
        {/* Tails side */}
        <div className={`absolute inset-0 rounded-full bg-gradient-to-br from-gray-300 to-gray-600 flex items-center justify-center transform rotate-y-180 ${result === 'heads' && !isFlipping ? 'opacity-0' : ''}`}>
          <span className="text-xl font-bold text-gray-900">T</span>
        </div>
      </div>
      
      {/* Coin shadow */}
      <div className="w-32 h-4 rounded-full bg-black bg-opacity-20 blur-sm mx-auto -mt-2"></div>
    </div>
  );
};