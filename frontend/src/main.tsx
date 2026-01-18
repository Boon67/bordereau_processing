import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import { ConfigProvider } from 'antd'
import App from './App'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <BrowserRouter>
    <ConfigProvider
      theme={{
        token: {
          colorPrimary: '#29B5E8',
          borderRadius: 6,
        },
      }}
    >
      <App />
    </ConfigProvider>
  </BrowserRouter>,
)
