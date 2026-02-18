import React from 'react';

function Header({ lastUpdate, onRefresh, loading, days, onDaysChange }) {
  const formatLastUpdate = () => {
    if (!lastUpdate) return 'Never';
    
    const now = new Date();
    const diff = Math.floor((now - lastUpdate) / 1000); // seconds
    
    if (diff < 60) return 'Just now';
    if (diff < 3600) return `${Math.floor(diff / 60)} minutes ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)} hours ago`;
    return lastUpdate.toLocaleDateString();
  };

  return (
    <header className="header">
      <div className="header-content">
        <div className="header-top">
          <div className="header-title">
            <h1>⚽ Bundesliga Analytics</h1>
            <span className="league-badge">VALUE BETTING</span>
          </div>
          
          <div className="header-actions">
            <div className="days-selector">
              <button 
                className={`days-btn ${days === 1 ? 'active' : ''}`}
                onClick={() => onDaysChange(1)}
              >
                Today
              </button>
              <button 
                className={`days-btn ${days === 3 ? 'active' : ''}`}
                onClick={() => onDaysChange(3)}
              >
                3 Days
              </button>
              <button 
                className={`days-btn ${days === 7 ? 'active' : ''}`}
                onClick={() => onDaysChange(7)}
              >
                7 Days
              </button>
            </div>
            
            <button 
              className={`refresh-btn ${loading ? 'loading' : ''}`}
              onClick={onRefresh}
              disabled={loading}
            >
              <span className={loading ? 'spinner' : ''}>🔄</span>
              {loading ? 'Refreshing...' : 'Refresh'}
            </button>
          </div>
        </div>
        
        <div className="last-update">
          Last updated: {formatLastUpdate()}
        </div>
      </div>
    </header>
  );
}

export default Header;
