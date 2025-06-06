import React, { useState } from 'react';
import { ChevronDownIcon, ChevronUpIcon } from 'lucide-react';

interface FaqItem {
  id: number;
  question: string;
  answer: string;
}

export const FaqPage: React.FC = () => {
  const [openItem, setOpenItem] = useState<number | null>(1);
  
  const faqItems: FaqItem[] = [
    {
      id: 1,
      question: 'How does the Coinflip game work?',
      answer: 'The Coinflip game is simple: you choose heads or tails and place your bet. The coin is flipped, and if it lands on your chosen side, you win double your bet amount. If it lands on the opposite side, you lose your bet.'
    },
    {
      id: 2,
      question: 'Is the Coinflip game fair?',
      answer: 'Yes, our Coinflip game uses a cryptographically secure random number generator to ensure that each flip is completely random and fair, with exactly a 50% chance for heads or tails.'
    },
    {
      id: 3,
      question: 'How do I get more coins?',
      answer: 'You can get more coins by winning games, completing daily challenges, or purchasing coin packages from our store. We also offer a daily login bonus and special promotions.'
    },
    {
      id: 4,
      question: 'What are the special items in the inventory?',
      answer: 'Special items can provide various benefits such as increasing your winnings, giving you free flips, or providing insurance against losses. Each item has different rarity and effects, which are described in the item details.'
    },
    {
      id: 5,
      question: 'How does the leaderboard work?',
      answer: 'The leaderboard ranks players based on their total coins earned. We have daily, weekly, and all-time leaderboards. Top players on the leaderboards receive special rewards and recognition.'
    },
    {
      id: 6,
      question: 'Can I withdraw my winnings?',
      answer: 'Currently, coins and items in the game are for entertainment purposes only and cannot be withdrawn as real money. However, we regularly run contests where top players can win real prizes.'
    },
    {
      id: 7,
      question: 'Is there a maximum bet amount?',
      answer: 'Yes, the maximum bet amount is 1000 coins per flip. This limit is in place to ensure fair play and to prevent excessive losses.'
    },
    {
      id: 8,
      question: 'How can I report a bug or contact support?',
      answer: 'If you encounter any issues or have questions, please contact our support team at support@coinflipgame.com. We aim to respond to all inquiries within 24 hours.'
    }
  ];
  
  const toggleItem = (id: number) => {
    if (openItem === id) {
      setOpenItem(null);
    } else {
      setOpenItem(id);
    }
  };

  return (
    <div className="max-w-3xl mx-auto">
      <h2 className="text-2xl font-bold mb-8">Frequently Asked Questions</h2>
      
      <div className="bg-gray-800 rounded-lg overflow-hidden">
        {faqItems.map((item, index) => (
          <div 
            key={item.id}
            className={`border-b border-gray-700 ${index === faqItems.length - 1 ? 'border-b-0' : ''}`}
          >
            <button
              onClick={() => toggleItem(item.id)}
              className="w-full text-left p-6 focus:outline-none flex justify-between items-center"
            >
              <h3 className="text-lg font-medium">{item.question}</h3>
              {openItem === item.id ? (
                <ChevronUpIcon size={20} className="text-indigo-400" />
              ) : (
                <ChevronDownIcon size={20} className="text-gray-400" />
              )}
            </button>
            
            <div 
              className={`overflow-hidden transition-all duration-300 ${
                openItem === item.id ? 'max-h-96' : 'max-h-0'
              }`}
            >
              <p className="px-6 pb-6 text-gray-300">
                {item.answer}
              </p>
            </div>
          </div>
        ))}
      </div>
      
      <div className="mt-8 bg-gray-800 rounded-lg p-6">
        <h3 className="text-xl font-semibold mb-4">Still have questions?</h3>
        <p className="text-gray-300 mb-4">
          If you couldn't find the answer to your question, feel free to contact our support team.
        </p>
        <button className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 rounded-lg transition-colors">
          Contact Support
        </button>
      </div>
    </div>
  );
};