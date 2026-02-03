import React, { useState, useEffect } from 'react'
import { Card, Table, Tabs, Tag, Button, Space, DatePicker, Select, Input, message, Modal, Descriptions } from 'antd'
import { ReloadOutlined, SearchOutlined, FileTextOutlined, BugOutlined, ApiOutlined, ThunderboltOutlined } from '@ant-design/icons'
import type { ColumnsType } from 'antd/es/table'
import { apiService } from '../services/api'
import dayjs from 'dayjs'

const { RangePicker } = DatePicker
const { TextArea } = Input

interface ApplicationLog {
  LOG_ID: number
  LOG_TIMESTAMP: string
  LOG_LEVEL: string
  LOG_SOURCE: string
  LOG_MESSAGE: string
  LOG_DETAILS: any
  USER_NAME: string
  TPA_CODE: string
}

interface TaskExecutionLog {
  EXECUTION_ID: number
  TASK_NAME: string
  EXECUTION_START: string
  EXECUTION_END: string
  EXECUTION_STATUS: string
  EXECUTION_DURATION_MS: number
  RECORDS_PROCESSED: number
  RECORDS_FAILED: number
  ERROR_MESSAGE: string
  EXECUTION_DETAILS: any
}

interface FileProcessingLog {
  PROCESSING_LOG_ID: number
  QUEUE_ID: number
  FILE_NAME: string
  TPA_CODE: string
  PROCESSING_STAGE: string
  STAGE_STATUS: string
  STAGE_START: string
  STAGE_END: string
  STAGE_DURATION_MS: number
  ROWS_PROCESSED: number
  ROWS_FAILED: number
  ERROR_MESSAGE: string
  STAGE_DETAILS: any
}

interface ErrorLog {
  ERROR_ID: number
  ERROR_TIMESTAMP: string
  ERROR_LEVEL: string
  ERROR_SOURCE: string
  ERROR_TYPE: string
  ERROR_MESSAGE: string
  ERROR_STACK_TRACE: string
  ERROR_CONTEXT: any
  USER_NAME: string
  TPA_CODE: string
  RESOLUTION_STATUS: string
}

interface APIRequestLog {
  REQUEST_ID: number
  REQUEST_TIMESTAMP: string
  REQUEST_METHOD: string
  REQUEST_PATH: string
  REQUEST_PARAMS: any
  RESPONSE_STATUS: number
  RESPONSE_TIME_MS: number
  ERROR_MESSAGE: string
  USER_NAME: string
  CLIENT_IP: string
}

interface AdminLogsProps {
  tpas: Array<{ TPA_CODE: string; TPA_NAME: string }>
}

const AdminLogs: React.FC<AdminLogsProps> = ({ tpas }) => {
  const [applicationLogs, setApplicationLogs] = useState<ApplicationLog[]>([])
  const [taskLogs, setTaskLogs] = useState<TaskExecutionLog[]>([])
  const [fileProcessingLogs, setFileProcessingLogs] = useState<FileProcessingLog[]>([])
  const [errorLogs, setErrorLogs] = useState<ErrorLog[]>([])
  const [apiLogs, setAPILogs] = useState<APIRequestLog[]>([])

  const renderTpaName = (tpaCode: string) => {
    const tpa = tpas.find(t => t.TPA_CODE === tpaCode)
    return tpa ? tpa.TPA_NAME : tpaCode
  }
  const [loading, setLoading] = useState(false)
  const [selectedLog, setSelectedLog] = useState<any>(null)
  const [detailsVisible, setDetailsVisible] = useState(false)

  useEffect(() => {
    loadLogs()
  }, [])

  const loadLogs = async () => {
    setLoading(true)
    try {
      const [appLogs, tasks, fileProc, errors, api] = await Promise.all([
        apiService.getApplicationLogs(),
        apiService.getTaskExecutionLogs(),
        apiService.getFileProcessingLogs(),
        apiService.getErrorLogs(),
        apiService.getAPIRequestLogs(),
      ])
      
      setApplicationLogs(appLogs)
      setTaskLogs(tasks)
      setFileProcessingLogs(fileProc)
      setErrorLogs(errors)
      setAPILogs(api)
    } catch (error: any) {
      message.error('Failed to load logs')
    } finally {
      setLoading(false)
    }
  }

  const showDetails = (record: any) => {
    setSelectedLog(record)
    setDetailsVisible(true)
  }

  const getLevelColor = (level: string) => {
    const colors: Record<string, string> = {
      DEBUG: 'default',
      INFO: 'blue',
      WARNING: 'orange',
      ERROR: 'red',
      CRITICAL: 'red',
    }
    return colors[level] || 'default'
  }

  const getStatusColor = (status: string) => {
    const colors: Record<string, string> = {
      STARTED: 'processing',
      RUNNING: 'processing',
      SUCCESS: 'success',
      FAILED: 'error',
      SKIPPED: 'default',
    }
    return colors[status] || 'default'
  }

  const applicationColumns: ColumnsType<ApplicationLog> = [
    {
      title: 'Timestamp',
      dataIndex: 'LOG_TIMESTAMP',
      key: 'timestamp',
      width: 180,
      render: (text) => dayjs(text).format('YYYY-MM-DD HH:mm:ss'),
      sorter: (a, b) => new Date(a.LOG_TIMESTAMP).getTime() - new Date(b.LOG_TIMESTAMP).getTime(),
    },
    {
      title: 'Level',
      dataIndex: 'LOG_LEVEL',
      key: 'level',
      width: 100,
      render: (level) => <Tag color={getLevelColor(level)}>{level}</Tag>,
      filters: [
        { text: 'DEBUG', value: 'DEBUG' },
        { text: 'INFO', value: 'INFO' },
        { text: 'WARNING', value: 'WARNING' },
        { text: 'ERROR', value: 'ERROR' },
      ],
      onFilter: (value, record) => record.LOG_LEVEL === value,
    },
    {
      title: 'Source',
      dataIndex: 'LOG_SOURCE',
      key: 'source',
      width: 150,
    },
    {
      title: 'Message',
      dataIndex: 'LOG_MESSAGE',
      key: 'message',
      ellipsis: true,
    },
    {
      title: 'User',
      dataIndex: 'USER_NAME',
      key: 'user',
      width: 120,
    },
    {
      title: 'TPA',
      dataIndex: 'TPA_CODE',
      key: 'tpa',
      width: 100,
      render: renderTpaName,
    },
    {
      title: 'Actions',
      key: 'actions',
      width: 100,
      render: (_, record) => (
        <Button size="small" icon={<SearchOutlined />} onClick={() => showDetails(record)}>
          Details
        </Button>
      ),
    },
  ]

  const taskColumns: ColumnsType<TaskExecutionLog> = [
    {
      title: 'Task Name',
      dataIndex: 'TASK_NAME',
      key: 'task',
      width: 200,
    },
    {
      title: 'Start Time',
      dataIndex: 'EXECUTION_START',
      key: 'start',
      width: 180,
      render: (text) => dayjs(text).format('YYYY-MM-DD HH:mm:ss'),
    },
    {
      title: 'Status',
      dataIndex: 'EXECUTION_STATUS',
      key: 'status',
      width: 120,
      render: (status) => <Tag color={getStatusColor(status)}>{status}</Tag>,
    },
    {
      title: 'Duration',
      dataIndex: 'EXECUTION_DURATION_MS',
      key: 'duration',
      width: 120,
      render: (ms) => ms ? `${(ms / 1000).toFixed(2)}s` : '-',
    },
    {
      title: 'Processed',
      dataIndex: 'RECORDS_PROCESSED',
      key: 'processed',
      width: 100,
    },
    {
      title: 'Failed',
      dataIndex: 'RECORDS_FAILED',
      key: 'failed',
      width: 100,
      render: (count) => count > 0 ? <Tag color="red">{count}</Tag> : count,
    },
    {
      title: 'Actions',
      key: 'actions',
      width: 100,
      render: (_, record) => (
        <Button size="small" icon={<SearchOutlined />} onClick={() => showDetails(record)}>
          Details
        </Button>
      ),
    },
  ]

  const fileProcessingColumns: ColumnsType<FileProcessingLog> = [
    {
      title: 'File Name',
      dataIndex: 'FILE_NAME',
      key: 'file',
      ellipsis: true,
      width: 250,
    },
    {
      title: 'Stage',
      dataIndex: 'PROCESSING_STAGE',
      key: 'stage',
      width: 120,
    },
    {
      title: 'Status',
      dataIndex: 'STAGE_STATUS',
      key: 'status',
      width: 100,
      render: (status) => <Tag color={getStatusColor(status)}>{status}</Tag>,
    },
    {
      title: 'Time',
      dataIndex: 'STAGE_END',
      key: 'time',
      width: 180,
      render: (text) => text ? dayjs(text).format('YYYY-MM-DD HH:mm:ss') : '-',
    },
    {
      title: 'Rows',
      dataIndex: 'ROWS_PROCESSED',
      key: 'rows',
      width: 100,
    },
    {
      title: 'TPA',
      dataIndex: 'TPA_CODE',
      key: 'tpa',
      width: 100,
      render: renderTpaName,
    },
    {
      title: 'Actions',
      key: 'actions',
      width: 100,
      render: (_, record) => (
        <Button size="small" icon={<SearchOutlined />} onClick={() => showDetails(record)}>
          Details
        </Button>
      ),
    },
  ]

  const errorColumns: ColumnsType<ErrorLog> = [
    {
      title: 'Timestamp',
      dataIndex: 'ERROR_TIMESTAMP',
      key: 'timestamp',
      width: 180,
      render: (text) => dayjs(text).format('YYYY-MM-DD HH:mm:ss'),
    },
    {
      title: 'Source',
      dataIndex: 'ERROR_SOURCE',
      key: 'source',
      width: 150,
    },
    {
      title: 'Type',
      dataIndex: 'ERROR_TYPE',
      key: 'type',
      width: 150,
    },
    {
      title: 'Message',
      dataIndex: 'ERROR_MESSAGE',
      key: 'message',
      ellipsis: true,
    },
    {
      title: 'Status',
      dataIndex: 'RESOLUTION_STATUS',
      key: 'resolution',
      width: 120,
      render: (status) => (
        <Tag color={status === 'RESOLVED' ? 'green' : status === 'INVESTIGATING' ? 'orange' : 'red'}>
          {status}
        </Tag>
      ),
    },
    {
      title: 'Actions',
      key: 'actions',
      width: 100,
      render: (_, record) => (
        <Button size="small" icon={<BugOutlined />} onClick={() => showDetails(record)}>
          Details
        </Button>
      ),
    },
  ]

  const apiColumns: ColumnsType<APIRequestLog> = [
    {
      title: 'Timestamp',
      dataIndex: 'REQUEST_TIMESTAMP',
      key: 'timestamp',
      width: 180,
      render: (text) => dayjs(text).format('YYYY-MM-DD HH:mm:ss'),
    },
    {
      title: 'Method',
      dataIndex: 'REQUEST_METHOD',
      key: 'method',
      width: 80,
      render: (method) => {
        const colors: Record<string, string> = {
          GET: 'blue',
          POST: 'green',
          PUT: 'orange',
          DELETE: 'red',
        }
        return <Tag color={colors[method]}>{method}</Tag>
      },
    },
    {
      title: 'Path',
      dataIndex: 'REQUEST_PATH',
      key: 'path',
      ellipsis: true,
    },
    {
      title: 'Status',
      dataIndex: 'RESPONSE_STATUS',
      key: 'status',
      width: 80,
      render: (status) => {
        const color = status < 300 ? 'green' : status < 400 ? 'blue' : status < 500 ? 'orange' : 'red'
        return <Tag color={color}>{status}</Tag>
      },
    },
    {
      title: 'Time',
      dataIndex: 'RESPONSE_TIME_MS',
      key: 'time',
      width: 100,
      render: (ms) => `${ms}ms`,
    },
    {
      title: 'IP',
      dataIndex: 'CLIENT_IP',
      key: 'ip',
      width: 120,
    },
    {
      title: 'Actions',
      key: 'actions',
      width: 100,
      render: (_, record) => (
        <Button size="small" icon={<SearchOutlined />} onClick={() => showDetails(record)}>
          Details
        </Button>
      ),
    },
  ]

  const tabItems = [
    {
      key: 'application',
      label: (
        <span>
          <FileTextOutlined /> Application Logs
        </span>
      ),
      children: (
        <Table
          columns={applicationColumns}
          dataSource={applicationLogs}
          rowKey="LOG_ID"
          loading={loading}
          pagination={{ pageSize: 50 }}
          scroll={{ x: 1200 }}
        />
      ),
    },
    {
      key: 'tasks',
      label: (
        <span>
          <ThunderboltOutlined /> Task Executions
        </span>
      ),
      children: (
        <Table
          columns={taskColumns}
          dataSource={taskLogs}
          rowKey="EXECUTION_ID"
          loading={loading}
          pagination={{ pageSize: 50 }}
          scroll={{ x: 1200 }}
        />
      ),
    },
    {
      key: 'files',
      label: (
        <span>
          <FileTextOutlined /> File Processing
        </span>
      ),
      children: (
        <Table
          columns={fileProcessingColumns}
          dataSource={fileProcessingLogs}
          rowKey="PROCESSING_LOG_ID"
          loading={loading}
          pagination={{ pageSize: 50 }}
          scroll={{ x: 1200 }}
        />
      ),
    },
    {
      key: 'errors',
      label: (
        <span>
          <BugOutlined /> Errors
        </span>
      ),
      children: (
        <Table
          columns={errorColumns}
          dataSource={errorLogs}
          rowKey="ERROR_ID"
          loading={loading}
          pagination={{ pageSize: 50 }}
          scroll={{ x: 1200 }}
        />
      ),
    },
    {
      key: 'api',
      label: (
        <span>
          <ApiOutlined /> API Requests
        </span>
      ),
      children: (
        <Table
          columns={apiColumns}
          dataSource={apiLogs}
          rowKey="REQUEST_ID"
          loading={loading}
          pagination={{ pageSize: 50 }}
          scroll={{ x: 1200 }}
        />
      ),
    },
  ]

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
        <h2>📊 System Logs</h2>
        <Button type="primary" icon={<ReloadOutlined />} onClick={loadLogs} loading={loading}>
          Refresh
        </Button>
      </div>

      <Card>
        <Tabs items={tabItems} />
      </Card>

      <Modal
        title="Log Details"
        open={detailsVisible}
        onCancel={() => setDetailsVisible(false)}
        footer={[
          <Button key="close" onClick={() => setDetailsVisible(false)}>
            Close
          </Button>,
        ]}
        width={800}
      >
        {selectedLog && (
          <div>
            <pre style={{ background: '#f5f5f5', padding: 16, borderRadius: 4, overflow: 'auto', maxHeight: 500 }}>
              {JSON.stringify(selectedLog, null, 2)}
            </pre>
          </div>
        )}
      </Modal>
    </div>
  )
}

export default AdminLogs
