import React, { useState } from 'react';
import axios from 'axios';
import './App.css';

function App() {
  const [url, setUrl] = useState('');
  const [shortUrl, setShortUrl] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const response = await axios.post(`https://url.omoknooni.link/api/conv`, {
        params: { url },
      });
      setShortUrl(response.data);
    } catch (error) {
      console.error('Error shortening URL:', error);
      setShortUrl('Error creating short URL');
    }
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>URL Shortener</h1>
        <form onSubmit={handleSubmit}>
          <input
            type="url"
            value={url}
            onChange={(e) => setUrl(e.target.value)}
            placeholder="Enter URL"
            required
          />
          <button type="submit">Shorten</button>
        </form>
        {shortUrl && (
          <div>
            <p>Shortened URL:</p>
            <a href={shortUrl} target="_blank" rel="noopener noreferrer">
              {shortUrl}
            </a>
          </div>
        )}
      </header>
    </div>
  );
}

export default App;
