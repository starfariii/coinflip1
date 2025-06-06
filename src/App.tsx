import React, { useState, useEffect } from 'react';
import { Layout } from './components/Layout';
import { CoinflipPage } from './pages/CoinflipPage';
import { InventoryPage } from './pages/InventoryPage';
import { LeaderboardPage } from './pages/LeaderboardPage';
import { FaqPage } from './pages/FaqPage';
import { AuthModal } from './components/AuthModal';
import { supabase } from './lib/supabase';

function App() {
  const [activePage, setActivePage] = useState('coinflip');
  const [isAuthModalOpen, setIsAuthModalOpen] = useState(false);
  const [user, setUser] = useState(null);

  useEffect(() => {
    // Check current session with error handling for invalid refresh tokens
    supabase.auth.getSession().then(({ data: { session }, error }) => {
      if (error) {
        // Check if the error is related to invalid refresh token
        if (error.message?.includes('Invalid Refresh Token') || 
            error.message?.includes('refresh_token_not_found')) {
          // Clear the invalid session from local storage
          supabase.auth.signOut();
          setUser(null);
          return;
        }
        console.error('Session error:', error);
      }
      setUser(session?.user || null);
    });

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user || null);
    });

    return () => subscription.unsubscribe();
  }, []);

  return (
    <>
      <Layout 
        activePage={activePage} 
        setActivePage={setActivePage}
        user={user}
        onAuthClick={() => setIsAuthModalOpen(true)}
      >
        {activePage === 'coinflip' && <CoinflipPage />}
        {activePage === 'inventory' && <InventoryPage />}
        {activePage === 'leaderboard' && <LeaderboardPage />}
        {activePage === 'faq' && <FaqPage />}
      </Layout>
      
      <AuthModal 
        isOpen={isAuthModalOpen} 
        onClose={() => setIsAuthModalOpen(false)} 
      />
    </>
  );
}

export default App;