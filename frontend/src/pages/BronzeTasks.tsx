import React, { useState, useEffect } from 'react'
import { Card, Typography, Table, Button, Space, message, Tag, Modal } from 'antd'
import { 
  ReloadOutlined, 
  PlayCircleOutlined, 
  PauseCircleOutlined,
  CheckCircleOutlined,
  ClockCircleOutlined
} from '@ant-design/icons'
import { apiService } from '../services/api'

const { Title } = Typography
const { confirm } = Modal

interface Task {
  name: string
  state: string
  schedule: string
  definition: string
  comment: string
  warehouse: string
  created_on: string
  last_committed_on: string | null
}

const BronzeTasks: React.FC = () => {
  const [loading, setLoading] = useState(false)
  const [tasks, setTasks] = useState<Task[]>([])
  const [actionLoading, setActionLoading] = useState<string | null>(null)

  useEffect(() => {
    loadTasks()
  }, [])

  const loadTasks = async () => {
    setLoading(true)
    try {
      const data = await apiService.getTasks()
      setTasks(data)
    } catch (error) {
      message.error('Failed to load tasks')
    } finally {
      setLoading(false)
    }
  }

  const handleResumeTask = (taskName: string) => {
    confirm({
      title: 'Resume Task',
      content: `Are you sure you want to resume task "${taskName}"?`,
      okText: 'Resume',
      okType: 'primary',
      onOk: async () => {
        setActionLoading(taskName)
        try {
          await apiService.resumeTask(taskName)
          message.success(`Task "${taskName}" resumed successfully`)
          await loadTasks()
        } catch (error: any) {
          message.error(`Failed to resume task: ${error.response?.data?.detail || error.message}`)
        } finally {
          setActionLoading(null)
        }
      },
    })
  }

  const handleSuspendTask = (taskName: string) => {
    confirm({
      title: 'Suspend Task',
      content: `Are you sure you want to suspend task "${taskName}"?`,
      okText: 'Suspend',
      okType: 'danger',
      onOk: async () => {
        setActionLoading(taskName)
        try {
          await apiService.suspendTask(taskName)
          message.success(`Task "${taskName}" suspended successfully`)
          await loadTasks()
        } catch (error: any) {
          message.error(`Failed to suspend task: ${error.response?.data?.detail || error.message}`)
        } finally {
          setActionLoading(null)
        }
      },
    })
  }

  const getStateTag = (state: string) => {
    const stateConfig: Record<string, { color: string; icon: React.ReactNode }> = {
      started: { color: 'success', icon: <CheckCircleOutlined /> },
      suspended: { color: 'default', icon: <PauseCircleOutlined /> },
      scheduled: { color: 'processing', icon: <ClockCircleOutlined /> },
    }
    const config = stateConfig[state.toLowerCase()] || { color: 'default', icon: null }
    return <Tag color={config.color} icon={config.icon}>{state.toUpperCase()}</Tag>
  }

  const columns = [
    {
      title: 'Task Name',
      dataIndex: 'name',
      key: 'name',
      width: 250,
      render: (name: string) => <strong>{name}</strong>,
    },
    {
      title: 'State',
      dataIndex: 'state',
      key: 'state',
      width: 120,
      render: (state: string) => getStateTag(state),
    },
    {
      title: 'Schedule',
      dataIndex: 'schedule',
      key: 'schedule',
      width: 200,
      ellipsis: true,
    },
    {
      title: 'Warehouse',
      dataIndex: 'warehouse',
      key: 'warehouse',
      width: 150,
    },
    {
      title: 'Definition',
      dataIndex: 'definition',
      key: 'definition',
      ellipsis: true,
      render: (def: string) => (
        <code style={{ fontSize: '11px', background: '#f5f5f5', padding: '2px 6px', borderRadius: 3 }}>
          {def}
        </code>
      ),
    },
    {
      title: 'Comment',
      dataIndex: 'comment',
      key: 'comment',
      ellipsis: true,
      width: 300,
    },
    {
      title: 'Actions',
      key: 'actions',
      width: 200,
      render: (_: any, record: Task) => (
        <Space>
          {record.state.toLowerCase() === 'suspended' ? (
            <Button
              type="primary"
              size="small"
              icon={<PlayCircleOutlined />}
              onClick={() => handleResumeTask(record.name)}
              loading={actionLoading === record.name}
            >
              Resume
            </Button>
          ) : (
            <Button
              danger
              size="small"
              icon={<PauseCircleOutlined />}
              onClick={() => handleSuspendTask(record.name)}
              loading={actionLoading === record.name}
            >
              Suspend
            </Button>
          )}
        </Space>
      ),
    },
  ]

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <Title level={2}>⚙️ Task Management</Title>
        <Button 
          icon={<ReloadOutlined />} 
          onClick={loadTasks}
          loading={loading}
        >
          Refresh
        </Button>
      </div>

      <p style={{ marginBottom: 24, color: '#666' }}>
        Manage Snowflake tasks that automate file discovery, processing, and archival.
      </p>

      <Card>
        <Table
          columns={columns}
          dataSource={tasks}
          rowKey="name"
          loading={loading}
          pagination={{
            pageSize: 10,
            showSizeChanger: true,
            showTotal: (total) => `Total ${total} tasks`,
          }}
          scroll={{ x: 1400 }}
        />
      </Card>

      <Card style={{ marginTop: 16 }} title="ℹ️ Task Information">
        <Space direction="vertical" size="small">
          <div><strong>File Discovery Task:</strong> Scans the SRC stage for new files and adds them to the processing queue.</div>
          <div><strong>File Processing Task:</strong> Processes files in the queue and loads data into raw data tables.</div>
          <div><strong>File Movement Task:</strong> Moves processed files from SRC to COMPLETED or ERROR stages.</div>
          <div><strong>Archive Task:</strong> Archives old files from COMPLETED and ERROR stages to ARCHIVE.</div>
        </Space>
      </Card>
    </div>
  )
}

export default BronzeTasks
