import React, { useState, useEffect } from 'react'
import { Card, Typography, Table, Button, Space, message, Tag, Modal, Tooltip, Input } from 'antd'
import { 
  ReloadOutlined, 
  PlayCircleOutlined, 
  PauseCircleOutlined,
  CheckCircleOutlined,
  ClockCircleOutlined,
  EditOutlined,
  InfoCircleOutlined
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
  predecessors?: string
}

const BronzeTasks: React.FC = () => {
  const [loading, setLoading] = useState(false)
  const [tasks, setTasks] = useState<Task[]>([])
  const [actionLoading, setActionLoading] = useState<string | null>(null)
  const [editScheduleModal, setEditScheduleModal] = useState<{ visible: boolean; task: Task | null }>({
    visible: false,
    task: null,
  })
  const [newSchedule, setNewSchedule] = useState('')

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

  const handleEditSchedule = (task: Task) => {
    setEditScheduleModal({ visible: true, task })
    setNewSchedule(task.schedule || '')
  }

  const handleSaveSchedule = async () => {
    if (!editScheduleModal.task) return

    setActionLoading(editScheduleModal.task.name)
    try {
      await apiService.updateTaskSchedule(editScheduleModal.task.name, newSchedule)
      message.success(`Schedule updated successfully for "${editScheduleModal.task.name}"`)
      setEditScheduleModal({ visible: false, task: null })
      await loadTasks()
    } catch (error: any) {
      message.error(error.response?.data?.detail || 'Failed to update schedule')
    } finally {
      setActionLoading(null)
    }
  }

  const hasPredecessors = (task: Task): boolean => {
    return !!(task.predecessors && task.predecessors.trim())
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
      width: 250,
      ellipsis: {
        showTitle: false,
      },
      render: (schedule: string, record: Task) => {
        const hasSchedule = schedule && schedule.trim() && !schedule.includes('AFTER')
        const canEdit = hasSchedule && !hasPredecessors(record)
        
        return (
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <Tooltip placement="topLeft" title={schedule}>
              <span style={{ flex: 1, overflow: 'hidden', textOverflow: 'ellipsis' }}>
                {schedule || <span style={{ color: '#999' }}>After predecessor</span>}
              </span>
            </Tooltip>
            {canEdit && (
              <Button
                type="text"
                size="small"
                icon={<EditOutlined />}
                onClick={() => handleEditSchedule(record)}
                style={{ flexShrink: 0 }}
              />
            )}
            {hasPredecessors(record) && (
              <Tooltip title="This task runs after a predecessor task. Schedule cannot be edited.">
                <InfoCircleOutlined style={{ color: '#1890ff', flexShrink: 0 }} />
              </Tooltip>
            )}
          </div>
        )
      },
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
      ellipsis: {
        showTitle: false,
      },
      render: (def: string) => (
        <Tooltip placement="topLeft" title={def}>
          <code style={{ fontSize: '11px', background: '#f5f5f5', padding: '2px 6px', borderRadius: 3 }}>
            {def}
          </code>
        </Tooltip>
      ),
    },
    {
      title: 'Comment',
      dataIndex: 'comment',
      key: 'comment',
      ellipsis: {
        showTitle: false,
      },
      width: 300,
      render: (comment: string) => (
        <Tooltip placement="topLeft" title={comment}>
          {comment}
        </Tooltip>
      ),
    },
    {
      title: 'Actions',
      key: 'actions',
      width: 120,
      render: (_: any, record: Task) => {
        const taskHasPredecessors = hasPredecessors(record)
        const isSuspended = record.state.toLowerCase() === 'suspended'
        
        // Tasks with predecessors cannot be manually started
        if (taskHasPredecessors && isSuspended) {
          return (
            <Tooltip title="This task runs automatically after its predecessor completes. It cannot be started manually.">
              <Button
                type="primary"
                size="small"
                icon={<PlayCircleOutlined />}
                disabled
              >
                Start
              </Button>
            </Tooltip>
          )
        }
        
        return (
          <Space>
            {isSuspended ? (
              <Tooltip title="Start this task">
                <Button
                  type="primary"
                  size="small"
                  icon={<PlayCircleOutlined />}
                  onClick={() => handleResumeTask(record.name)}
                  loading={actionLoading === record.name}
                >
                  Start
                </Button>
              </Tooltip>
            ) : (
              <Tooltip title="Stop this task">
                <Button
                  danger
                  size="small"
                  icon={<PauseCircleOutlined />}
                  onClick={() => handleSuspendTask(record.name)}
                  loading={actionLoading === record.name}
                >
                  Stop
                </Button>
              </Tooltip>
            )}
          </Space>
        )
      },
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
          <div style={{ marginTop: 8, color: '#666' }}>
            <InfoCircleOutlined /> <em>Tasks with predecessors (shown with info icon) run automatically after their predecessor completes.</em>
          </div>
          <div style={{ color: '#666' }}>
            <InfoCircleOutlined /> <em>Dependent tasks cannot be started manually or have their schedule edited.</em>
          </div>
        </Space>
      </Card>

      {/* Edit Schedule Modal */}
      <Modal
        title={`Edit Schedule: ${editScheduleModal.task?.name}`}
        open={editScheduleModal.visible}
        onOk={handleSaveSchedule}
        onCancel={() => setEditScheduleModal({ visible: false, task: null })}
        confirmLoading={actionLoading === editScheduleModal.task?.name}
        okText="Save Schedule"
        width={600}
      >
        <div style={{ marginBottom: 16 }}>
          <p style={{ marginBottom: 8 }}>
            <strong>Current Schedule:</strong> {editScheduleModal.task?.schedule}
          </p>
          <p style={{ marginBottom: 16, color: '#666', fontSize: '12px' }}>
            Enter a new schedule using Snowflake schedule syntax.
          </p>
        </div>

        <div style={{ marginBottom: 16 }}>
          <label style={{ display: 'block', marginBottom: 8, fontWeight: 500 }}>
            New Schedule:
          </label>
          <Input.TextArea
            value={newSchedule}
            onChange={(e) => setNewSchedule(e.target.value)}
            placeholder="e.g., USING CRON 0 * * * * America/New_York"
            rows={3}
            style={{ fontFamily: 'monospace' }}
          />
        </div>

        <Card size="small" title="Schedule Examples" style={{ marginTop: 16 }}>
          <Space direction="vertical" size="small" style={{ width: '100%' }}>
            <div>
              <code style={{ background: '#f5f5f5', padding: '2px 6px', borderRadius: 3 }}>
                USING CRON 0 * * * * America/New_York
              </code>
              <span style={{ marginLeft: 8, color: '#666' }}>Every hour</span>
            </div>
            <div>
              <code style={{ background: '#f5f5f5', padding: '2px 6px', borderRadius: 3 }}>
                USING CRON 0 */30 * * * America/New_York
              </code>
              <span style={{ marginLeft: 8, color: '#666' }}>Every 30 minutes</span>
            </div>
            <div>
              <code style={{ background: '#f5f5f5', padding: '2px 6px', borderRadius: 3 }}>
                USING CRON 0 2 * * * America/New_York
              </code>
              <span style={{ marginLeft: 8, color: '#666' }}>Daily at 2 AM</span>
            </div>
            <div>
              <code style={{ background: '#f5f5f5', padding: '2px 6px', borderRadius: 3 }}>
                60 MINUTE
              </code>
              <span style={{ marginLeft: 8, color: '#666' }}>Every 60 minutes (simple syntax)</span>
            </div>
          </Space>
        </Card>
      </Modal>
    </div>
  )
}

export default BronzeTasks
