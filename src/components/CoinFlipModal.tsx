import React, { useEffect, useState } from 'react';
import { Coin } from './Coin';

interface CoinFlipModalProps {
  isOpen: boolean;
  onClose: () => void;
  result: 'heads' | 'tails' | null;
  winnerSide: 'heads' | 'tails' | null;
  userSide: 'heads' | 'tails' | null;
  isFlipping: boolean;
}

export const CoinFlipModal: React.FC<CoinFlipModalProps> = ({
  isOpen,
  onClose,
  result,
  winnerSide,
  userSide,
  isFlipping
}) => {
  const [showResult, setShowResult] = useState(false);

  useEffect(() => {
    if (!isFlipping && result) {
      const timer = setTimeout(() => {
        setShowResult(true);
      }, 500);
      return () => clearTimeout(timer);
    } else {
      setShowResult(false);
    }
  }, [isFlipping, result]);

  useEffect(() => {
    if (!isOpen) {
      setShowResult(false);
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const hasWon = userSide === winnerSide;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50">
      <div className="bg-gray-800 rounded-lg p-8 flex flex-col items-center max-w-md w-full mx-4">
        <h2 className="text-2xl font-bold mb-8 text-center">
          {isFlipping ? 'Flipping Coin...' : showResult ? (hasWon ? 'You Won!' : 'You Lost!') : 'Match Result'}
        </h2>
        
        <div className="mb-8">
          <Coin isFlipping={isFlipping} result={result} />
        </div>
        
        {showResult && result && (
          <div className="text-center">
            <div className={`text-xl font-semibold mb-4 ${
              hasWon ? 'text-green-400' : 'text-red-400'
            }`}>
              {hasWon ? '🎉 Congratulations!' : '😔 Better luck next time!'}
            </div>
            <p className="text-gray-400 mb-2">
              The coin landed on <span className="font-medium text-white">
                {result.charAt(0).toUpperCase() + result.slice(1)}
              </span>
            </p>
            <p className="text-gray-400 mb-6">
              You chose <span className="font-medium text-white">
                {userSide?.charAt(0).toUpperCase() + userSide?.slice(1)}
              </span>
            </p>
            <button
              onClick={onClose}
              className="px-6 py-3 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg font-medium transition-colors"
            >
              Close
            </button>
          </div>
        )}
        
        {isFlipping && (
          <div className="text-center">
            <div className="animate-pulse text-gray-400">
              Determining the winner...
            </div>
          </div>
        )}
      </div>
    </div>
  );
};