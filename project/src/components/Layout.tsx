import React from 'react';
import { Sidebar } from './Sidebar';

interface LayoutProps {
  children: React.ReactNode;
  activePage: string;
  setActivePage: (page: string) => void;
  user: any;
  onAuthClick: () => void;
}

export const Layout: React.FC<LayoutProps> = ({ 
  children, 
  activePage, 
  setActivePage,
  user,
  onAuthClick
}) => {
  return (
    <div className="flex h-screen bg-gray-900 text-gray-100">
      <Sidebar 
        activePage={activePage} 
        setActivePage={setActivePage}
        user={user}
        onAuthClick={onAuthClick}
      />
      <main className="flex-1 p-6 overflow-auto">
        {children}
      </main>
    </div>
  );
};