import React, { useState, useEffect } from 'react'
import { Routes, Route, Navigate, useNavigate, useLocation } from 'react-router-dom'
import { Layout, Menu, Select, Spin, message } from 'antd'
import {
  DatabaseOutlined,
  CloudUploadOutlined,
  BarChartOutlined,
  FolderOutlined,
  TableOutlined,
  SettingOutlined,
  ThunderboltOutlined,
  ApiOutlined,
} from '@ant-design/icons'
import BronzeUpload from './pages/BronzeUpload'
import BronzeStatus from './pages/BronzeStatus'
import BronzeStages from './pages/BronzeStages'
import BronzeData from './pages/BronzeData'
import BronzeTasks from './pages/BronzeTasks'
import SilverSchemas from './pages/SilverSchemas'
import SilverMappings from './pages/SilverMappings'
import SilverTransform from './pages/SilverTransform'
import SilverData from './pages/SilverData'
import { apiService } from './services/api'
import type { TPA } from './types'
import './App.css'

const { Header, Sider, Content } = Layout

function App() {
  const navigate = useNavigate()
  const location = useLocation()
  const [selectedTpa, setSelectedTpa] = useState<string>('')
  const [tpas, setTpas] = useState<TPA[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadTpas()
  }, [])

  const loadTpas = async () => {
    try {
      const data = await apiService.getTpas()
      setTpas(data)
      if (data.length > 0) {
        setSelectedTpa(data[0].TPA_CODE)
      }
    } catch (error) {
      message.error('Failed to load TPAs')
    } finally {
      setLoading(false)
    }
  }

  const menuItems = [
    {
      key: 'bronze',
      icon: <DatabaseOutlined />,
      label: '🥉 Bronze Layer',
      children: [
        {
          key: '/bronze/upload',
          icon: <CloudUploadOutlined />,
          label: 'Upload Files',
        },
        {
          key: '/bronze/status',
          icon: <BarChartOutlined />,
          label: 'Processing Status',
        },
        {
          key: '/bronze/stages',
          icon: <FolderOutlined />,
          label: 'File Stages',
        },
        {
          key: '/bronze/data',
          icon: <TableOutlined />,
          label: 'Raw Data',
        },
        {
          key: '/bronze/tasks',
          icon: <SettingOutlined />,
          label: 'Task Management',
        },
      ],
    },
    {
      key: 'silver',
      icon: <DatabaseOutlined />,
      label: '🥈 Silver Layer',
      children: [
        {
          key: '/silver/schemas',
          icon: <DatabaseOutlined />,
          label: 'Target Schemas',
        },
        {
          key: '/silver/mappings',
          icon: <ApiOutlined />,
          label: 'Field Mappings',
        },
        {
          key: '/silver/transform',
          icon: <ThunderboltOutlined />,
          label: 'Transform',
        },
        {
          key: '/silver/data',
          icon: <TableOutlined />,
          label: 'View Data',
        },
      ],
    },
  ]

  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh' }}>
        <Spin size="large" />
      </div>
    )
  }

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Header style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
          <DatabaseOutlined style={{ fontSize: '24px', color: '#fff' }} />
          <h1 style={{ color: '#fff', margin: 0 }}>Snowflake Pipeline</h1>
        </div>
        <div style={{ display: 'flex', gap: '16px' }}>
          <Select
            value={selectedTpa}
            onChange={setSelectedTpa}
            style={{ width: 250 }}
            placeholder="Select TPA"
            options={tpas.map(tpa => ({
              value: tpa.TPA_CODE,
              label: tpa.TPA_NAME,
            }))}
          />
        </div>
      </Header>
      <Layout>
        <Sider width={250} theme="light">
          <Menu
            mode="inline"
            items={menuItems}
            selectedKeys={[location.pathname]}
            defaultOpenKeys={['bronze', 'silver']}
            onClick={({ key }) => navigate(key)}
            style={{ height: '100%', borderRight: 0 }}
          />
        </Sider>
        <Layout style={{ padding: '24px' }}>
          <Content
            style={{
              padding: 24,
              margin: 0,
              minHeight: 280,
              background: '#fff',
              borderRadius: '8px',
            }}
          >
            <Routes>
              <Route path="/" element={<Navigate to="/bronze/upload" replace />} />
              <Route path="/bronze/upload" element={<BronzeUpload selectedTpa={selectedTpa} />} />
              <Route path="/bronze/status" element={<BronzeStatus selectedTpa={selectedTpa} />} />
              <Route path="/bronze/stages" element={<BronzeStages selectedTpa={selectedTpa} />} />
              <Route path="/bronze/data" element={<BronzeData selectedTpa={selectedTpa} />} />
              <Route path="/bronze/tasks" element={<BronzeTasks />} />
              <Route path="/silver/schemas" element={<SilverSchemas selectedTpa={selectedTpa} />} />
              <Route path="/silver/mappings" element={<SilverMappings selectedTpa={selectedTpa} />} />
              <Route path="/silver/transform" element={<SilverTransform selectedTpa={selectedTpa} />} />
              <Route path="/silver/data" element={<SilverData selectedTpa={selectedTpa} />} />
            </Routes>
          </Content>
        </Layout>
      </Layout>
    </Layout>
  )
}

export default App
