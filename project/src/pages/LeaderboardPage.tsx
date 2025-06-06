import React, { useState } from 'react';
import { TrophyIcon, TrendingUpIcon, CoinsIcon } from 'lucide-react';

export const LeaderboardPage: React.FC = () => {
  const [activeTab, setActiveTab] = useState('all-time');
  
  const leaderboardData = {
    'all-time': [
      { id: 1, username: 'CoinMaster', rank: 1, wins: 234, coins: 45890, winRate: 68 },
      { id: 2, username: 'FlipKing', rank: 2, wins: 198, coins: 32456, winRate: 62 },
      { id: 3, username: 'LuckyFlip', rank: 3, wins: 187, coins: 28734, winRate: 59 },
      { id: 4, username: 'CoinWizard', rank: 4, wins: 165, coins: 26500, winRate: 57 },
      { id: 5, username: 'HeadsOrTails', rank: 5, wins: 152, coins: 24100, winRate: 55 },
      { id: 6, username: 'FlipChamp', rank: 6, wins: 143, coins: 22780, winRate: 53 },
      { id: 7, username: 'CoinLord', rank: 7, wins: 138, coins: 21345, winRate: 52 },
      { id: 8, username: 'FlipMaster', rank: 8, wins: 129, coins: 19870, winRate: 51 },
      { id: 9, username: 'LuckyToss', rank: 9, wins: 118, coins: 18450, winRate: 50 },
      { id: 10, username: 'CoinPro', rank: 10, wins: 106, coins: 17200, winRate: 49 },
    ],
    'weekly': [
      { id: 3, username: 'LuckyFlip', rank: 1, wins: 42, coins: 7845, winRate: 64 },
      { id: 1, username: 'CoinMaster', rank: 2, wins: 38, coins: 6720, winRate: 61 },
      { id: 5, username: 'HeadsOrTails', rank: 3, wins: 36, coins: 5890, winRate: 59 },
      { id: 2, username: 'FlipKing', rank: 4, wins: 32, coins: 5400, winRate: 58 },
      { id: 8, username: 'FlipMaster', rank: 5, wins: 29, coins: 4900, winRate: 56 },
      { id: 4, username: 'CoinWizard', rank: 6, wins: 27, coins: 4500, winRate: 55 },
      { id: 11, username: 'HeadMaster', rank: 7, wins: 25, coins: 4120, winRate: 54 },
      { id: 9, username: 'LuckyToss', rank: 8, wins: 23, coins: 3800, winRate: 53 },
      { id: 12, username: 'CoinGuru', rank: 9, wins: 21, coins: 3500, winRate: 52 },
      { id: 6, username: 'FlipChamp', rank: 10, wins: 19, coins: 3200, winRate: 51 },
    ],
    'daily': [
      { id: 5, username: 'HeadsOrTails', rank: 1, wins: 12, coins: 2450, winRate: 67 },
      { id: 11, username: 'HeadMaster', rank: 2, wins: 10, coins: 2100, winRate: 65 },
      { id: 3, username: 'LuckyFlip', rank: 3, wins: 9, coins: 1900, winRate: 62 },
      { id: 8, username: 'FlipMaster', rank: 4, wins: 8, coins: 1750, winRate: 60 },
      { id: 1, username: 'CoinMaster', rank: 5, wins: 7, coins: 1600, winRate: 58 },
      { id: 13, username: 'FlipWinner', rank: 6, wins: 6, coins: 1400, winRate: 57 },
      { id: 2, username: 'FlipKing', rank: 7, wins: 6, coins: 1300, winRate: 55 },
      { id: 14, username: 'CoinFlipPro', rank: 8, wins: 5, coins: 1200, winRate: 54 },
      { id: 9, username: 'LuckyToss', rank: 9, wins: 5, coins: 1100, winRate: 53 },
      { id: 4, username: 'CoinWizard', rank: 10, wins: 4, coins: 1000, winRate: 52 },
    ]
  };
  
  const tabs = [
    { id: 'all-time', label: 'All Time' },
    { id: 'weekly', label: 'Weekly' },
    { id: 'daily', label: 'Daily' }
  ];

  return (
    <div className="max-w-4xl mx-auto">
      <div className="flex justify-between items-center mb-8">
        <h2 className="text-2xl font-bold">Leaderboard</h2>
        
        <div className="flex space-x-2">
          {tabs.map(tab => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`px-4 py-2 rounded-lg text-sm font-medium ${
                activeTab === tab.id
                  ? 'bg-indigo-600 text-white'
                  : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>
      
      <div className="bg-gray-800 rounded-lg overflow-hidden">
        {/* Top 3 podium for larger screens */}
        <div className="hidden md:flex justify-center items-end p-8 bg-gradient-to-b from-gray-800 to-gray-900 border-b border-gray-700">
          {leaderboardData[activeTab as keyof typeof leaderboardData].slice(0, 3).map((player, index) => {
            const heights = ['h-28', 'h-36', 'h-24'];
            const positions = ['order-2', 'order-1', 'order-3'];
            
            return (
              <div key={player.id} className={`flex flex-col items-center mx-4 ${positions[index]}`}>
                <div className="mb-2">
                  <div className="w-16 h-16 rounded-full bg-gray-700 flex items-center justify-center mb-2 mx-auto">
                    <span className="text-lg font-bold">{player.username.charAt(0)}</span>
                  </div>
                  <p className="text-center font-medium">{player.username}</p>
                  <p className="text-center text-indigo-400 text-sm">{player.coins} coins</p>
                </div>
                <div className={`${heights[index]} w-24 bg-gradient-to-t from-indigo-700 to-indigo-500 rounded-t-lg flex items-center justify-center`}>
                  <div className="text-center">
                    <TrophyIcon size={24} className={index === 0 ? 'text-yellow-400' : index === 1 ? 'text-yellow-300' : 'text-yellow-500'} />
                    <p className="font-bold text-xl">#{player.rank}</p>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
        
        {/* Leaderboard table */}
        <div className="p-6">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="text-gray-400 text-sm">
                  <th className="text-left pb-4 font-medium">Rank</th>
                  <th className="text-left pb-4 font-medium">Player</th>
                  <th className="text-right pb-4 font-medium">
                    <div className="flex items-center justify-end">
                      <TrophyIcon size={16} className="mr-1" />
                      Wins
                    </div>
                  </th>
                  <th className="text-right pb-4 font-medium">
                    <div className="flex items-center justify-end">
                      <CoinsIcon size={16} className="mr-1" />
                      Coins
                    </div>
                  </th>
                  <th className="text-right pb-4 font-medium">
                    <div className="flex items-center justify-end">
                      <TrendingUpIcon size={16} className="mr-1" />
                      Win Rate
                    </div>
                  </th>
                </tr>
              </thead>
              <tbody>
                {leaderboardData[activeTab as keyof typeof leaderboardData].map((player) => (
                  <tr 
                    key={player.id} 
                    className="border-t border-gray-700 hover:bg-gray-750"
                  >
                    <td className="py-4">
                      <div className={`
                        w-8 h-8 rounded-full flex items-center justify-center font-bold
                        ${player.rank === 1 ? 'bg-yellow-500 text-yellow-900' : 
                          player.rank === 2 ? 'bg-gray-400 text-gray-900' : 
                          player.rank === 3 ? 'bg-amber-700 text-amber-100' : 
                          'bg-gray-700 text-gray-300'}
                      `}>
                        {player.rank}
                      </div>
                    </td>
                    <td className="py-4">
                      <div className="flex items-center">
                        <div className="w-8 h-8 rounded-full bg-indigo-600 flex items-center justify-center mr-3">
                          <span>{player.username.charAt(0)}</span>
                        </div>
                        <span className="font-medium">{player.username}</span>
                      </div>
                    </td>
                    <td className="py-4 text-right font-medium">{player.wins}</td>
                    <td className="py-4 text-right font-medium text-indigo-400">{player.coins.toLocaleString()}</td>
                    <td className="py-4 text-right font-medium">{player.winRate}%</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
};