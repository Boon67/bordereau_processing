import React, { useState, useEffect } from 'react'
import { Card, Typography, Table, Button, Space, message, Tag, Modal, Tooltip, Input, Tabs, Statistic, Row, Col } from 'antd'
import { 
  ReloadOutlined, 
  PlayCircleOutlined, 
  PauseCircleOutlined,
  CheckCircleOutlined,
  ClockCircleOutlined,
  EditOutlined,
  InfoCircleOutlined,
  ThunderboltOutlined,
  DatabaseOutlined
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
  schema: string
}

interface TaskStats {
  total: number
  started: number
  suspended: number
  scheduled: number
}

const TaskManagement: React.FC = () => {
  const [loading, setLoading] = useState(false)
  const [bronzeTasks, setBronzeTasks] = useState<Task[]>([])
  const [silverTasks, setSilverTasks] = useState<Task[]>([])
  const [goldTasks, setGoldTasks] = useState<Task[]>([])
  const [actionLoading, setActionLoading] = useState<string | null>(null)
  const [editScheduleModal, setEditScheduleModal] = useState<{ visible: boolean; task: Task | null }>({
    visible: false,
    task: null,
  })
  const [newSchedule, setNewSchedule] = useState('')
  const [activeTab, setActiveTab] = useState('bronze')

  useEffect(() => {
    loadAllTasks()
  }, [])

  const loadAllTasks = async () => {
    setLoading(true)
    try {
      await Promise.all([
        loadBronzeTasks(),
        loadSilverTasks(),
        loadGoldTasks()
      ])
    } catch (error) {
      message.error('Failed to load tasks')
    } finally {
      setLoading(false)
    }
  }

  const loadBronzeTasks = async () => {
    try {
      const data = await apiService.getTasks()
      setBronzeTasks(data.map((task: any) => ({ ...task, schema: 'BRONZE' })))
    } catch (error) {
      console.error('Failed to load Bronze tasks:', error)
    }
  }

  const loadSilverTasks = async () => {
    try {
      const data = await apiService.getSilverTasks()
      setSilverTasks(data.map((task: any) => ({ ...task, schema: 'SILVER' })))
    } catch (error) {
      console.error('Failed to load Silver tasks:', error)
    }
  }

  const loadGoldTasks = async () => {
    try {
      const data = await apiService.getGoldTasks()
      setGoldTasks(data.map((task: any) => ({ ...task, schema: 'GOLD' })))
    } catch (error) {
      console.error('Failed to load Gold tasks:', error)
    }
  }

  const handleResumeTask = (task: Task) => {
    confirm({
      title: 'Resume Task',
      content: `Are you sure you want to resume task "${task.name}" in ${task.schema} layer?`,
      okText: 'Resume',
      okType: 'primary',
      onOk: async () => {
        setActionLoading(task.name)
        try {
          if (task.schema === 'BRONZE') {
            await apiService.resumeTask(task.name)
          } else if (task.schema === 'SILVER') {
            await apiService.resumeSilverTask(task.name)
          } else if (task.schema === 'GOLD') {
            await apiService.resumeGoldTask(task.name)
          }
          message.success(`Task "${task.name}" resumed successfully`)
          await loadAllTasks()
        } catch (error: any) {
          message.error(`Failed to resume task: ${error.response?.data?.detail || error.message}`)
        } finally {
          setActionLoading(null)
        }
      },
    })
  }

  const handleSuspendTask = (task: Task) => {
    confirm({
      title: 'Suspend Task',
      content: `Are you sure you want to suspend task "${task.name}" in ${task.schema} layer?`,
      okText: 'Suspend',
      okType: 'danger',
      onOk: async () => {
        setActionLoading(task.name)
        try {
          if (task.schema === 'BRONZE') {
            await apiService.suspendTask(task.name)
          } else if (task.schema === 'SILVER') {
            await apiService.suspendSilverTask(task.name)
          } else if (task.schema === 'GOLD') {
            await apiService.suspendGoldTask(task.name)
          }
          message.success(`Task "${task.name}" suspended successfully`)
          await loadAllTasks()
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
      if (editScheduleModal.task.schema === 'BRONZE') {
        await apiService.updateTaskSchedule(editScheduleModal.task.name, newSchedule)
      } else if (editScheduleModal.task.schema === 'SILVER') {
        await apiService.updateSilverTaskSchedule(editScheduleModal.task.name, newSchedule)
      } else if (editScheduleModal.task.schema === 'GOLD') {
        await apiService.updateGoldTaskSchedule(editScheduleModal.task.name, newSchedule)
      }
      message.success(`Schedule updated successfully for "${editScheduleModal.task.name}"`)
      setEditScheduleModal({ visible: false, task: null })
      await loadAllTasks()
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

  const getTaskStats = (tasks: Task[]): TaskStats => {
    return {
      total: tasks.length,
      started: tasks.filter(t => t.state.toLowerCase() === 'started').length,
      suspended: tasks.filter(t => t.state.toLowerCase() === 'suspended').length,
      scheduled: tasks.filter(t => t.state.toLowerCase() === 'scheduled').length,
    }
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
                  onClick={() => handleResumeTask(record)}
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
                  onClick={() => handleSuspendTask(record)}
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

  const bronzeStats = getTaskStats(bronzeTasks)
  const silverStats = getTaskStats(silverTasks)
  const goldStats = getTaskStats(goldTasks)

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <Title level={2}>⚙️ Task Management</Title>
        <Button 
          icon={<ReloadOutlined />} 
          onClick={loadAllTasks}
          loading={loading}
        >
          Refresh All
        </Button>
      </div>

      <p style={{ marginBottom: 24, color: '#666' }}>
        Manage Snowflake tasks across Bronze, Silver, and Gold layers that automate data processing workflows.
      </p>

      {/* Overall Statistics */}
      <Card style={{ marginBottom: 24 }}>
        <Row gutter={16}>
          <Col span={6}>
            <Statistic 
              title="Total Tasks" 
              value={bronzeStats.total + silverStats.total + goldStats.total}
              prefix={<ThunderboltOutlined />}
            />
          </Col>
          <Col span={6}>
            <Statistic 
              title="Running" 
              value={bronzeStats.started + silverStats.started + goldStats.started}
              valueStyle={{ color: '#52c41a' }}
              prefix={<CheckCircleOutlined />}
            />
          </Col>
          <Col span={6}>
            <Statistic 
              title="Suspended" 
              value={bronzeStats.suspended + silverStats.suspended + goldStats.suspended}
              valueStyle={{ color: '#999' }}
              prefix={<PauseCircleOutlined />}
            />
          </Col>
          <Col span={6}>
            <Statistic 
              title="Scheduled" 
              value={bronzeStats.scheduled + silverStats.scheduled + goldStats.scheduled}
              valueStyle={{ color: '#1890ff' }}
              prefix={<ClockCircleOutlined />}
            />
          </Col>
        </Row>
      </Card>

      {/* Tabbed Interface */}
      <Tabs 
        activeKey={activeTab} 
        onChange={setActiveTab}
        items={[
          {
            key: 'bronze',
            label: (
              <span>
                <DatabaseOutlined /> 🥉 Bronze Layer ({bronzeTasks.length})
              </span>
            ),
            children: (
              <div>
                <Card style={{ marginBottom: 16 }}>
                  <Row gutter={16}>
                    <Col span={8}>
                      <Statistic title="Total Tasks" value={bronzeStats.total} />
                    </Col>
                    <Col span={8}>
                      <Statistic 
                        title="Running" 
                        value={bronzeStats.started} 
                        valueStyle={{ color: '#52c41a' }}
                      />
                    </Col>
                    <Col span={8}>
                      <Statistic 
                        title="Suspended" 
                        value={bronzeStats.suspended}
                        valueStyle={{ color: '#999' }}
                      />
                    </Col>
                  </Row>
                </Card>
                <Card>
                  <Table
                    columns={columns}
                    dataSource={bronzeTasks}
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
                <Card style={{ marginTop: 16 }} title="ℹ️ Bronze Layer Tasks">
                  <Space direction="vertical" size="small">
                    <div><strong>File Discovery Task:</strong> Scans the SRC stage for new files and adds them to the processing queue.</div>
                    <div><strong>File Processing Task:</strong> Processes files in the queue and loads data into raw data tables.</div>
                    <div><strong>File Movement Task:</strong> Moves processed files from SRC to COMPLETED or ERROR stages.</div>
                    <div><strong>Archive Task:</strong> Archives old files from COMPLETED and ERROR stages to ARCHIVE.</div>
                  </Space>
                </Card>
              </div>
            ),
          },
          {
            key: 'silver',
            label: (
              <span>
                <DatabaseOutlined /> 🥈 Silver Layer ({silverTasks.length})
              </span>
            ),
            children: (
              <div>
                <Card style={{ marginBottom: 16 }}>
                  <Row gutter={16}>
                    <Col span={8}>
                      <Statistic title="Total Tasks" value={silverStats.total} />
                    </Col>
                    <Col span={8}>
                      <Statistic 
                        title="Running" 
                        value={silverStats.started}
                        valueStyle={{ color: '#52c41a' }}
                      />
                    </Col>
                    <Col span={8}>
                      <Statistic 
                        title="Suspended" 
                        value={silverStats.suspended}
                        valueStyle={{ color: '#999' }}
                      />
                    </Col>
                  </Row>
                </Card>
                <Card>
                  <Table
                    columns={columns}
                    dataSource={silverTasks}
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
                <Card style={{ marginTop: 16 }} title="ℹ️ Silver Layer Tasks">
                  <Space direction="vertical" size="small">
                    <div><strong>Transformation Tasks:</strong> Transform Bronze raw data into structured Silver tables using field mappings.</div>
                    <div><strong>Data Quality Tasks:</strong> Apply validation rules and quality checks to Silver data.</div>
                    <div><strong>Incremental Load Tasks:</strong> Process only new or changed records for efficient updates.</div>
                  </Space>
                </Card>
              </div>
            ),
          },
          {
            key: 'gold',
            label: (
              <span>
                <DatabaseOutlined /> 🏆 Gold Layer ({goldTasks.length})
              </span>
            ),
            children: (
              <div>
                <Card style={{ marginBottom: 16 }}>
                  <Row gutter={16}>
                    <Col span={8}>
                      <Statistic title="Total Tasks" value={goldStats.total} />
                    </Col>
                    <Col span={8}>
                      <Statistic 
                        title="Running" 
                        value={goldStats.started}
                        valueStyle={{ color: '#52c41a' }}
                      />
                    </Col>
                    <Col span={8}>
                      <Statistic 
                        title="Suspended" 
                        value={goldStats.suspended}
                        valueStyle={{ color: '#999' }}
                      />
                    </Col>
                  </Row>
                </Card>
                <Card>
                  <Table
                    columns={columns}
                    dataSource={goldTasks}
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
                <Card style={{ marginTop: 16 }} title="ℹ️ Gold Layer Tasks">
                  <Space direction="vertical" size="small">
                    <div><strong>Analytics Tasks:</strong> Generate claims analytics, member 360 views, and provider performance metrics.</div>
                    <div><strong>Aggregation Tasks:</strong> Create business-level aggregations and summary tables.</div>
                    <div><strong>Quality Check Tasks:</strong> Execute quality rules and validation checks on Gold data.</div>
                  </Space>
                </Card>
              </div>
            ),
          },
        ]}
      />

      <Card style={{ marginTop: 16 }} title="💡 Task Management Tips">
        <Space direction="vertical" size="small">
          <div style={{ color: '#666' }}>
            <InfoCircleOutlined /> <em>Tasks with predecessors (shown with info icon) run automatically after their predecessor completes.</em>
          </div>
          <div style={{ color: '#666' }}>
            <InfoCircleOutlined /> <em>Dependent tasks cannot be started manually or have their schedule edited.</em>
          </div>
          <div style={{ color: '#666' }}>
            <InfoCircleOutlined /> <em>Use the schedule editor to adjust when root tasks run (CRON or interval syntax).</em>
          </div>
        </Space>
      </Card>

      {/* Edit Schedule Modal */}
      <Modal
        title={`Edit Schedule: ${editScheduleModal.task?.name} (${editScheduleModal.task?.schema})`}
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

export default TaskManagement
