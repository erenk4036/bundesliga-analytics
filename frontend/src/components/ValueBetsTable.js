import React from 'react';

function ValueBetsTable({ valueBets, loading }) {
  const formatDate = (dateString) => {
    if (!dateString) return 'N/A';
    try {
      const date = new Date(dateString);
      return date.toLocaleString('en-US', {
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      });
    } catch {
      return 'N/A';
    }
  };

  const getRecommendationClass = (recommendation) => {
    if (!recommendation) return 'hold';
    const rec = recommendation.toLowerCase().replace(' ', '-');
    return rec;
  };

  if (loading) {
    return (
      <div className="table-container">
        <div className="loading-state">
          <div className="loading-icon">⏳</div>
          <h3>Loading value bets...</h3>
          <p>Analyzing odds data from DynamoDB</p>
        </div>
      </div>
    );
  }

  if (valueBets.length === 0) {
    return (
      <div className="table-container">
        <div className="empty-state">
          <div className="empty-state-icon">📊</div>
          <h3>No value bets found</h3>
          <p>Run the ETL pipeline to generate betting opportunities</p>
        </div>
      </div>
    );
  }

  // Sort by value percentage descending
  const sortedBets = [...valueBets].sort((a, b) => 
    parseFloat(b.value_percentage || 0) - parseFloat(a.value_percentage || 0)
  );

  return (
    <div className="table-container">
      <div className="table-header">
        <h2>📊 Value Betting Opportunities</h2>
      </div>
      
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
          {sortedBets.map((bet, index) => (
            <tr key={index}>
              <td>
                <div className="game-info">
                  <span className="game-teams">{bet.game || 'Unknown Match'}</span>
                  <span className="game-time">
                    {bet.bookmaker_count} bookmakers analyzed
                  </span>
                </div>
              </td>
              
              <td>
                <span className={`team-badge ${bet.side?.toLowerCase() || 'home'}`}>
                  {bet.side || 'HOME'}
                </span>
              </td>
              
              <td>
                <span className="value-percentage">
                  +{parseFloat(bet.value_percentage || 0).toFixed(2)}%
                </span>
              </td>
              
              <td>
                <div>
                  <div className="odds-value">
                    {parseFloat(bet.best_odds || 0).toFixed(2)}
                  </div>
                </div>
              </td>
              
              <td>
                <span className="bookmaker">{bet.bookmaker || 'N/A'}</span>
              </td>
              
              <td>
                <span style={{
                  color: parseFloat(bet.market_efficiency || 0) < 0.03 
                    ? 'var(--success)' 
                    : 'var(--warning)'
                }}>
                  {parseFloat(bet.market_efficiency || 0).toFixed(4)}
                </span>
              </td>
              
              <td>
                <span className={`recommendation-badge ${getRecommendationClass(bet.recommendation)}`}>
                  {bet.recommendation || 'HOLD'}
                </span>
              </td>
              
              <td>
                <span className="game-time">
                  {formatDate(bet.commence_time)}
                </span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default ValueBetsTable;
