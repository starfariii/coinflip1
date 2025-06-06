import React from 'react';
import { Coin } from './Coin';

interface GameResultModalProps {
  isOpen: boolean;
  isFlipping: boolean;
  result: 'heads' | 'tails' | null;
  hasWon: boolean | null;
}

export const GameResultModal: React.FC<GameResultModalProps> = ({
  isOpen,
  isFlipping,
  result,
  hasWon
}) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-gray-800 rounded-lg p-8 flex flex-col items-center">
        <Coin isFlipping={isFlipping} result={result} />
        
        {!isFlipping && result && (
          <div className={`mt-8 text-center ${
            hasWon ? 'text-green-400' : 'text-red-400'
          }`}>
            <h2 className="text-3xl font-bold mb-2">
              {hasWon ? 'You Won!' : 'You Lost'}
            </h2>
            <p className="text-gray-400">
              The coin landed on {result.charAt(0).toUpperCase() + result.slice(1)}
            </p>
          </div>
        )}
      </div>
    </div>
  );
};