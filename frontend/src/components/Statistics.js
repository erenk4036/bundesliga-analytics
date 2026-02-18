import React from 'react';

function Statistics({ valueBets, loading }) {
  if (loading) {
    return (
      <div className="statistics">
        {[1, 2, 3, 4].map(i => (
          <div key={i} className="stat-card">
            <div className="stat-header">
              <span className="stat-label">Loading...</span>
              <span className="stat-icon">⏳</span>
            </div>
            <div className="stat-value">--</div>
          </div>
        ))}
      </div>
    );
  }

  const strongBuyCount = valueBets.filter(bet => 
    bet.recommendation === 'STRONG BUY'
  ).length;

  const buyCount = valueBets.filter(bet => 
    bet.recommendation === 'BUY' || bet.recommendation === 'STRONG BUY'
  ).length;

  const avgValuePercentage = valueBets.length > 0
    ? (valueBets.reduce((sum, bet) => sum + parseFloat(bet.value_percentage || 0), 0) / valueBets.length).toFixed(2)
    : 0;

  const bestValue = valueBets.length > 0
    ? Math.max(...valueBets.map(bet => parseFloat(bet.value_percentage || 0))).toFixed(2)
    : 0;

  return (
    <div className="statistics">
      <div className="stat-card">
        <div className="stat-header">
          <span className="stat-label">Total Opportunities</span>
          <span className="stat-icon">🎯</span>
        </div>
        <div className="stat-value">{valueBets.length}</div>
        <div className="stat-description">
          Value betting opportunities identified
        </div>
      </div>

      <div className="stat-card">
        <div className="stat-header">
          <span className="stat-label">Strong Buy Signals</span>
          <span className="stat-icon">⭐</span>
        </div>
        <div className="stat-value">{strongBuyCount}</div>
        <div className="stat-description">
          High-conviction recommendations
        </div>
      </div>

      <div className="stat-card">
        <div className="stat-header">
          <span className="stat-label">Buy Signals</span>
          <span className="stat-icon">📈</span>
        </div>
        <div className="stat-value">{buyCount}</div>
        <div className="stat-description">
          All actionable signals (Buy + Strong Buy)
        </div>
      </div>

      <div className="stat-card">
        <div className="stat-header">
          <span className="stat-label">Avg Value Edge</span>
          <span className="stat-icon">💎</span>
        </div>
        <div className="stat-value">{avgValuePercentage}%</div>
        <div className="stat-description">
          Average value percentage across all bets
        </div>
      </div>
    </div>
  );
}

export default Statistics;
