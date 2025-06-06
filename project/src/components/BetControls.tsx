import React from 'react';

interface BetControlsProps {
  betAmount: number;
  setBetAmount: (amount: number) => void;
  balance: number;
  selectedSide: 'heads' | 'tails';
  setSelectedSide: (side: 'heads' | 'tails') => void;
  onFlip: () => void;
  disabled: boolean;
}

export const BetControls: React.FC<BetControlsProps> = ({
  betAmount,
  setBetAmount,
  balance,
  selectedSide,
  setSelectedSide,
  onFlip,
  disabled
}) => {
  const predefinedBets = [10, 50, 100, 250, 500];

  return (
    <div>
      <div className="mb-6">
        <div className="flex justify-between mb-2">
          <label className="text-sm text-gray-400">Your Balance</label>
          <span className="font-medium">{balance} coins</span>
        </div>
        <div className="w-full bg-gray-700 rounded-full h-1">
          <div 
            className="bg-indigo-500 h-1 rounded-full" 
            style={{ width: `${Math.min(100, (balance / 2000) * 100)}%` }}
          ></div>
        </div>
      </div>

      <div className="mb-6">
        <label className="block text-sm text-gray-400 mb-2">Bet Amount</label>
        <div className="flex flex-wrap gap-2 mb-3">
          {predefinedBets.map(amount => (
            <button
              key={amount}
              onClick={() => setBetAmount(amount)}
              className={`px-3 py-1 rounded ${
                betAmount === amount 
                  ? 'bg-indigo-600 text-white' 
                  : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
              }`}
            >
              {amount}
            </button>
          ))}
        </div>
        <div className="flex items-center">
          <input
            type="range"
            min="10"
            max={Math.min(1000, balance)}
            value={betAmount}
            onChange={(e) => setBetAmount(Number(e.target.value))}
            className="w-full h-2 bg-gray-700 rounded-lg appearance-none cursor-pointer"
          />
          <span className="ml-3 w-16 text-center">{betAmount}</span>
        </div>
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

      <button
        onClick={onFlip}
        disabled={disabled || betAmount > balance}
        className={`w-full py-4 rounded-lg font-medium ${
          disabled || betAmount > balance
            ? 'bg-gray-600 text-gray-400 cursor-not-allowed'
            : 'bg-indigo-600 hover:bg-indigo-700 text-white'
        } transition-colors`}
      >
        {disabled ? 'Flipping...' : 'Flip Coin'}
      </button>
    </div>
  );
};