import React, { useState, useEffect } from 'react'
import { Routes, Route, Navigate, useNavigate, useLocation } from 'react-router-dom'
import { Layout, Menu, Select, Spin, message, Button, Popconfirm, Modal } from 'antd'
import {
  DatabaseOutlined,
  CloudUploadOutlined,
  BarChartOutlined,
  FolderOutlined,
  TableOutlined,
  SettingOutlined,
  ThunderboltOutlined,
  ApiOutlined,
  DeleteOutlined,
  ExclamationCircleOutlined,
  TeamOutlined,
  ToolOutlined,
  UserOutlined,
  SafetyOutlined,
  CloudServerOutlined,
  FileTextOutlined,
} from '@ant-design/icons'
import BronzeUpload from './pages/BronzeUpload'
import BronzeStatus from './pages/BronzeStatus'
import BronzeStages from './pages/BronzeStages'
import BronzeData from './pages/BronzeData'
import SilverSchemas from './pages/SilverSchemas'
import SilverMappings from './pages/SilverMappings'
import SilverTransform from './pages/SilverTransform'
import SilverData from './pages/SilverData'
import GoldAnalytics from './pages/GoldAnalytics'
import GoldMetrics from './pages/GoldMetrics'
import GoldQuality from './pages/GoldQuality'
import GoldRules from './pages/GoldRules'
import TPAManagement from './pages/TPAManagement'
import TaskManagement from './pages/TaskManagement'
import AdminLogs from './pages/AdminLogs'
import { apiService, UserInfo } from './services/api'
import type { TPA } from './types'
import './App.css'

const { Header, Sider, Content, Footer } = Layout

function App() {
  const navigate = useNavigate()
  const location = useLocation()
  const [selectedTpa, setSelectedTpa] = useState<string>('')
  const [tpas, setTpas] = useState<TPA[]>([])
  const [loading, setLoading] = useState(true)
  const [userInfo, setUserInfo] = useState<UserInfo | null>(null)
  const [openKeys, setOpenKeys] = useState<string[]>([])

  // Determine which menu should be open based on current path
  useEffect(() => {
    const path = location.pathname
    if (path.startsWith('/bronze')) {
      setOpenKeys(['bronze'])
    } else if (path.startsWith('/silver')) {
      setOpenKeys(['silver'])
    } else if (path.startsWith('/gold')) {
      setOpenKeys(['gold'])
    } else if (path.startsWith('/admin')) {
      setOpenKeys(['admin'])
    }
  }, [location.pathname])

  useEffect(() => {
    loadTpas()
    loadUserInfo()
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

  const loadUserInfo = async () => {
    try {
      const data = await apiService.getCurrentUser()
      setUserInfo(data)
    } catch (error) {
      console.error('Failed to load user info:', error)
      // Don't show error message as this is not critical
    }
  }

  const handleClearAllData = () => {
    Modal.confirm({
      title: '⚠️ Clear All Bronze Data',
      icon: <ExclamationCircleOutlined style={{ color: '#ff4d4f' }} />,
      content: (
        <div>
          <p><strong>This will permanently delete:</strong></p>
          <ul style={{ marginLeft: 20 }}>
            <li>All files from all stages (SRC, COMPLETED, ERROR, ARCHIVE)</li>
            <li>All records from RAW_DATA_TABLE</li>
            <li>All entries from file_processing_queue</li>
          </ul>
          <p style={{ color: '#ff4d4f', fontWeight: 'bold' }}>
            ⚠️ This action CANNOT be undone!
          </p>
          <p>Type "DELETE" below to confirm:</p>
        </div>
      ),
      okText: 'Yes, Delete Everything',
      okType: 'danger',
      cancelText: 'Cancel',
      width: 600,
      onOk: async () => {
        const result = await apiService.clearAllData()
        message.success(result.message || 'All data cleared successfully')
        
        // Show detailed results if available
        if (result.results) {
          const { stages_cleared, tables_truncated, errors } = result.results
          if (errors && errors.length > 0) {
            Modal.warning({
              title: 'Some operations failed',
              content: (
                <div>
                  <p>Cleared: {stages_cleared.join(', ')}</p>
                  <p>Truncated: {tables_truncated.join(', ')}</p>
                  <p style={{ color: '#ff4d4f' }}>Errors:</p>
                  <ul>
                    {errors.map((err: string, idx: number) => (
                      <li key={idx}>{err}</li>
                    ))}
                  </ul>
                </div>
              ),
            })
          }
        }
      },
      onCancel: () => {
        // Modal will close automatically
      },
    })
  }

  // Get the selected TPA object
  const selectedTpaObject = tpas.find(tpa => tpa.TPA_CODE === selectedTpa)

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
    {
      key: 'gold',
      icon: <DatabaseOutlined />,
      label: '🏆 Gold Layer',
      children: [
        {
          key: '/gold/analytics',
          icon: <BarChartOutlined />,
          label: 'Analytics',
        },
        {
          key: '/gold/metrics',
          icon: <BarChartOutlined />,
          label: 'Business Metrics',
        },
        {
          key: '/gold/quality',
          icon: <SettingOutlined />,
          label: 'Quality Checks',
        },
        {
          key: '/gold/rules',
          icon: <ThunderboltOutlined />,
          label: 'Rules',
        },
      ],
    },
    {
      key: 'admin',
      icon: <ToolOutlined />,
      label: '⚙️ Administration',
      children: [
        {
          key: '/admin/tasks',
          icon: <ThunderboltOutlined />,
          label: 'Task Management',
        },
        {
          key: '/admin/tpas',
          icon: <TeamOutlined />,
          label: 'TPA Management',
        },
        {
          key: '/admin/logs',
          icon: <FileTextOutlined />,
          label: 'System Logs',
        },
        {
          key: 'clear-data',
          icon: <DeleteOutlined />,
          label: 'Clear All Data',
          danger: true,
          onClick: () => handleClearAllData(),
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
      </Header>
      <Layout>
        <Sider width={250} theme="light">
          <Menu
            mode="inline"
            items={menuItems}
            selectedKeys={[location.pathname]}
            openKeys={openKeys}
            onOpenChange={(keys) => setOpenKeys(keys)}
            onClick={({ key }) => {
              if (key === 'clear-data') {
                handleClearAllData()
              } else {
                navigate(key)
              }
            }}
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
              <Route path="/bronze/upload" element={<BronzeUpload selectedTpa={selectedTpa} setSelectedTpa={setSelectedTpa} tpas={tpas} selectedTpaName={selectedTpaObject?.TPA_NAME} />} />
              <Route path="/bronze/status" element={<BronzeStatus selectedTpa={selectedTpa} setSelectedTpa={setSelectedTpa} tpas={tpas} selectedTpaName={selectedTpaObject?.TPA_NAME} />} />
              <Route path="/bronze/stages" element={<BronzeStages selectedTpa={selectedTpa} setSelectedTpa={setSelectedTpa} tpas={tpas} selectedTpaName={selectedTpaObject?.TPA_NAME} />} />
              <Route path="/bronze/data" element={<BronzeData selectedTpa={selectedTpa} setSelectedTpa={setSelectedTpa} tpas={tpas} selectedTpaName={selectedTpaObject?.TPA_NAME} />} />
              <Route path="/silver/schemas" element={<SilverSchemas selectedTpa={selectedTpa} setSelectedTpa={setSelectedTpa} tpas={tpas} selectedTpaName={selectedTpaObject?.TPA_NAME} />} />
              <Route path="/silver/mappings" element={<SilverMappings selectedTpa={selectedTpa} setSelectedTpa={setSelectedTpa} tpas={tpas} selectedTpaName={selectedTpaObject?.TPA_NAME} />} />
              <Route path="/silver/transform" element={<SilverTransform selectedTpa={selectedTpa} setSelectedTpa={setSelectedTpa} tpas={tpas} selectedTpaName={selectedTpaObject?.TPA_NAME} />} />
              <Route path="/silver/data" element={<SilverData selectedTpa={selectedTpa} setSelectedTpa={setSelectedTpa} tpas={tpas} selectedTpaName={selectedTpaObject?.TPA_NAME} />} />
              <Route path="/gold/analytics" element={<GoldAnalytics selectedTpa={selectedTpa} setSelectedTpa={setSelectedTpa} tpas={tpas} selectedTpaName={selectedTpaObject?.TPA_NAME} />} />
              <Route path="/gold/metrics" element={<GoldMetrics selectedTpa={selectedTpa} setSelectedTpa={setSelectedTpa} tpas={tpas} selectedTpaName={selectedTpaObject?.TPA_NAME} />} />
              <Route path="/gold/quality" element={<GoldQuality selectedTpa={selectedTpa} setSelectedTpa={setSelectedTpa} tpas={tpas} selectedTpaName={selectedTpaObject?.TPA_NAME} />} />
              <Route path="/gold/rules" element={<GoldRules selectedTpa={selectedTpa} setSelectedTpa={setSelectedTpa} tpas={tpas} selectedTpaName={selectedTpaObject?.TPA_NAME} />} />
              <Route path="/admin/tasks" element={<TaskManagement />} />
              <Route path="/admin/tpas" element={<TPAManagement onTpaChange={loadTpas} />} />
              <Route path="/admin/logs" element={<AdminLogs />} />
            </Routes>
          </Content>
          <Footer
            style={{
              textAlign: 'center',
              background: '#f0f2f5',
              padding: '12px 24px',
              marginTop: '24px',
              borderRadius: '8px',
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '16px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '24px', flexWrap: 'wrap' }}>
                {userInfo && (
                  <>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      <UserOutlined style={{ color: '#1890ff' }} />
                      <span style={{ fontWeight: 500 }}>User:</span>
                      <span>{userInfo.username}</span>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      <SafetyOutlined style={{ color: '#52c41a' }} />
                      <span style={{ fontWeight: 500 }}>Role:</span>
                      <span>{userInfo.role}</span>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      <CloudServerOutlined style={{ color: '#722ed1' }} />
                      <span style={{ fontWeight: 500 }}>Warehouse:</span>
                      <span>{userInfo.warehouse}</span>
                    </div>
                  </>
                )}
                {!userInfo && (
                  <span style={{ color: '#999' }}>Loading user information...</span>
                )}
              </div>
              <div style={{ color: '#999', fontSize: '12px' }}>
                Bordereau Processing Pipeline © 2026
              </div>
            </div>
          </Footer>
        </Layout>
      </Layout>
    </Layout>
  )
}

export default App
