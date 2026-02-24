import React, { useState } from 'react';
import './ValueBetsTable.css';

function ValueBetsTable({ valueBets, loading }) {
  const [sortBy, setSortBy] = useState('value'); // 'value' or 'kickoff'
  const [kickoffFilter, setKickoffFilter] = useState('all'); // 'all', 'today', 'tomorrow'

  // Filter by kick-off time
  const filterByKickoff = (bets) => {
    if (kickoffFilter === 'all') return bets;
    
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);
    const dayAfterTomorrow = new Date(tomorrow);
    dayAfterTomorrow.setDate(dayAfterTomorrow.getDate() + 1);

    return bets.filter(bet => {
      const kickoff = new Date(bet.kick_off);
      
      switch(kickoffFilter) {
        case 'today':
          return kickoff >= today && kickoff < tomorrow;
        case 'tomorrow':
          return kickoff >= tomorrow && kickoff < dayAfterTomorrow;
        default:
          return true;
      }
    });
  };

  // Sort bets
  const sortedBets = [...filterByKickoff(valueBets)].sort((a, b) => {
    if (sortBy === 'kickoff') {
      return new Date(a.kick_off) - new Date(b.kick_off);
    } else {
      // Sort by value percentage (default)
      return parseFloat(b.value_percentage) - parseFloat(a.value_percentage);
    }
  });

  const getRecommendationStyle = (recommendation) => {
    const styles = {
      'STRONG BUY': 'badge-strong-buy',
      'BUY': 'badge-buy',
      'CONSIDER': 'badge-consider',
      'HOLD': 'badge-hold'
    };
    return styles[recommendation] || 'badge-default';
  };

  const getRecommendationEmoji = (recommendation) => {
    const emojis = {
      'STRONG BUY': '🔥',
      'BUY': '✅',
      'CONSIDER': '🤔',
      'HOLD': '⚪'
    };
    return emojis[recommendation] || '';
  };

  const formatKickoff = (kickoffTime) => {
    const date = new Date(kickoffTime);
    const now = new Date();
    const tomorrow = new Date(now);
    tomorrow.setDate(tomorrow.getDate() + 1);
    
    const isToday = date.toDateString() === now.toDateString();
    const isTomorrow = date.toDateString() === tomorrow.toDateString();
    
    const timeStr = date.toLocaleTimeString('de-DE', { 
      hour: '2-digit', 
      minute: '2-digit',
      hour12: false 
    });
    
    if (isToday) return `Today, ${timeStr}`;
    if (isTomorrow) return `Tomorrow, ${timeStr}`;
    
    return date.toLocaleDateString('de-DE', { 
      month: 'short', 
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  if (loading) {
    return (
      <div className="table-container">
        <div className="loading-spinner">Loading value bets...</div>
      </div>
    );
  }

  return (
    <div className="table-container">
      {/* Filter Controls */}
      <div className="table-controls">
        <div className="control-group">
          <label>Kick-off Time:</label>
          <div className="button-group">
            <button
              className={kickoffFilter === 'all' ? 'active' : ''}
              onClick={() => setKickoffFilter('all')}
            >
              All Games
            </button>
            <button
              className={kickoffFilter === 'today' ? 'active' : ''}
              onClick={() => setKickoffFilter('today')}
            >
              Today
            </button>
            <button
              className={kickoffFilter === 'tomorrow' ? 'active' : ''}
              onClick={() => setKickoffFilter('tomorrow')}
            >
              Tomorrow
            </button>
          </div>
        </div>

        <div className="control-group">
          <label>Sort By:</label>
          <div className="button-group">
            <button
              className={sortBy === 'value' ? 'active' : ''}
              onClick={() => setSortBy('value')}
            >
              📈 Value %
            </button>
            <button
              className={sortBy === 'kickoff' ? 'active' : ''}
              onClick={() => setSortBy('kickoff')}
            >
              ⏰ Kick-off
            </button>
          </div>
        </div>
      </div>

      {/* Table */}
      <div className="table-wrapper">
        <table className="value-bets-table">
          <thead>
            <tr>
              <th>Match</th>
              <th>Side</th>
              <th>Value Edge</th>
              <th>Best Odds</th>
              <th>Bookmaker</th>
              <th>Market Efficiency</th>
              <th>Recommendation</th>
              <th>Kick-off</th>
            </tr>
          </thead>
          <tbody>
            {sortedBets.length === 0 ? (
              <tr>
                <td colSpan="8" className="no-data">
                  No value betting opportunities found.
                </td>
              </tr>
            ) : (
              sortedBets.map((bet, index) => (
                <tr key={index} className="table-row">
                  <td className="match-cell">
                    <div className="match-name">{bet.game}</div>
                    <div className="match-info">
                      {bet.bookmakers_analyzed} bookmakers analyzed
                    </div>
                  </td>
                  <td>
                    <span className={`side-badge ${bet.outcome.toLowerCase()}`}>
                      {bet.outcome}
                    </span>
                  </td>
                  <td className="value-cell">
                    +{parseFloat(bet.value_percentage).toFixed(2)}%
                  </td>
                  <td className="odds-cell">
                    {parseFloat(bet.best_odds).toFixed(2)}
                  </td>
                  <td>{bet.best_bookmaker}</td>
                  <td className="efficiency-cell">
                    <span className={`efficiency ${
                      parseFloat(bet.market_efficiency) < 0.04 ? 'good' :
                      parseFloat(bet.market_efficiency) < 0.06 ? 'medium' : 'poor'
                    }`}>
                      {parseFloat(bet.market_efficiency).toFixed(4)}
                    </span>
                  </td>
                  <td>
                    <span className={`recommendation-badge ${getRecommendationStyle(bet.recommendation)}`}>
                      {getRecommendationEmoji(bet.recommendation)} {bet.recommendation}
                    </span>
                  </td>
                  <td className="kickoff-cell">
                    {formatKickoff(bet.kick_off)}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export default ValueBetsTable;