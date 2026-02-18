import React, { useState, useEffect } from 'react';
import './App.css';
import ValueBetsTable from './components/ValueBetsTable';
import Statistics from './components/Statistics';
import Header from './components/Header';

const API_URL = 'https://dmyz9vhosh.execute-api.eu-central-1.amazonaws.com/dev/value-bets';

function App() {
  const [valueBets, setValueBets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [lastUpdate, setLastUpdate] = useState(null);
  const [days, setDays] = useState(1);

  const fetchValueBets = async (daysParam = 1) => {
    setLoading(true);
    setError(null);
    
    try {
      const url = `${API_URL}?days=${daysParam}&limit=100`;
      const response = await fetch(url);
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      const data = await response.json();
      
      if (data.success) {
        setValueBets(data.data || []);
        setLastUpdate(new Date(data.timestamp));
      } else {
        throw new Error(data.error || 'Failed to fetch data');
      }
    } catch (err) {
      setError(err.message);
      console.error('Error fetching value bets:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchValueBets(days);
    
    // Auto-refresh every 5 minutes
    const interval = setInterval(() => {
      fetchValueBets(days);
    }, 5 * 60 * 1000);
    
    return () => clearInterval(interval);
  }, [days]);

  const handleRefresh = () => {
    fetchValueBets(days);
  };

  const handleDaysChange = (newDays) => {
    setDays(newDays);
  };

  return (
    <div className="App">
      <Header 
        lastUpdate={lastUpdate}
        onRefresh={handleRefresh}
        loading={loading}
        days={days}
        onDaysChange={handleDaysChange}
      />
      
      <main className="main-content">
        <div className="container">
          {error && (
            <div className="error-banner">
              <span className="error-icon">⚠️</span>
              <span>{error}</span>
              <button onClick={handleRefresh} className="retry-btn">
                Retry
              </button>
            </div>
          )}
          
          <Statistics valueBets={valueBets} loading={loading} />
          <ValueBetsTable valueBets={valueBets} loading={loading} />
        </div>
      </main>
      
      <footer className="footer">
        <p>Bundesliga Analytics • Data-driven value betting insights</p>
        <p className="footer-disclaimer">
          This is a demo project for educational purposes. Always gamble responsibly.
        </p>
      </footer>
    </div>
  );
}

export default App;
