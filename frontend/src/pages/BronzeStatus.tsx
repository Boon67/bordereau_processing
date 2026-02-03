import React, { useState, useEffect } from 'react'
import { Card, Typography, Button, Table, Tag, Statistic, Row, Col, Select, Space, message, Popconfirm } from 'antd'
import { 
  ReloadOutlined, 
  CheckCircleOutlined, 
  CloseCircleOutlined, 
  SyncOutlined,
  ClockCircleOutlined,
  FileTextOutlined,
  RiseOutlined,
  RedoOutlined,
  DeleteOutlined
} from '@ant-design/icons'
import { apiService } from '../services/api'
import type { FileQueueItem } from '../services/api'
import type { TPA } from '../types'

const { Title } = Typography

interface BronzeStatusProps {
  selectedTpa: string
  setSelectedTpa: (tpa: string) => void
  tpas: TPA[]
  selectedTpaName?: string
}

const BronzeStatus: React.FC<BronzeStatusProps> = ({ selectedTpa, setSelectedTpa, tpas, selectedTpaName }) => {
  const [loading, setLoading] = useState(false)
  const [queue, setQueue] = useState<FileQueueItem[]>([])
  const [statusFilter, setStatusFilter] = useState<string[]>([])
  const [typeFilter, setTypeFilter] = useState<string[]>([])
  const [tpaFilter, setTpaFilter] = useState<string[]>([])
  const [totalRows, setTotalRows] = useState(0)

  useEffect(() => {
    loadQueue()
    loadStats()
  }, [])

  const loadQueue = async () => {
    setLoading(true)
    try {
      const data = await apiService.getProcessingQueue()
      setQueue(data)
    } catch (error) {
      message.error('Failed to load processing queue')
    } finally {
      setLoading(false)
    }
  }

  const loadStats = async () => {
    try {
      const stats = await apiService.getBronzeStats()
      setTotalRows(stats.total_rows || 0)
    } catch (error) {
      console.error('Failed to load Bronze stats:', error)
    }
  }

  const handleReprocess = async (queueId: number, fileName: string) => {
    try {
      const result = await apiService.reprocessFile(queueId)
      message.success(`File ${fileName} reset to PENDING status for reprocessing`)
      loadQueue() // Refresh the queue
    } catch (error: any) {
      message.error(`Failed to reprocess file: ${error.response?.data?.detail || error.message}`)
    }
  }

  const handleDeleteFileData = async (fileName: string, tpa: string) => {
    try {
      const result = await apiService.deleteFileData(fileName, tpa)
      message.success(result.message || `Data deleted for file: ${fileName} (TPA: ${tpa})`)
      loadQueue() // Refresh the queue
      loadStats() // Refresh stats
    } catch (error: any) {
      message.error(`Failed to delete file data: ${error.response?.data?.detail || error.message}`)
    }
  }

  // Calculate statistics
  const filteredQueue = queue.filter(item => {
    const statusMatch = statusFilter.length === 0 || statusFilter.includes(item.STATUS)
    const typeMatch = typeFilter.length === 0 || typeFilter.includes(item.FILE_TYPE)
    const tpaMatch = tpaFilter.length === 0 || tpaFilter.includes(item.TPA)
    return statusMatch && typeMatch && tpaMatch
  })

  const totalFiles = filteredQueue.length
  const successFiles = filteredQueue.filter(f => f.STATUS === 'SUCCESS').length
  const failedFiles = filteredQueue.filter(f => f.STATUS === 'FAILED').length
  const processingFiles = filteredQueue.filter(f => f.STATUS === 'PROCESSING').length
  const pendingFiles = filteredQueue.filter(f => f.STATUS === 'PENDING').length
  const successRate = totalFiles > 0 ? ((successFiles / totalFiles) * 100).toFixed(1) : '0.0'

  const statusOptions = [
    { label: 'SUCCESS', value: 'SUCCESS' },
    { label: 'FAILED', value: 'FAILED' },
    { label: 'PROCESSING', value: 'PROCESSING' },
    { label: 'PENDING', value: 'PENDING' },
  ]

  const typeOptions = Array.from(new Set(queue.map(f => f.FILE_TYPE))).map(type => ({
    label: type,
    value: type
  }))

  const tpaOptions = Array.from(new Set(queue.map(f => f.TPA))).map(tpaCode => {
    const tpa = tpas.find(t => t.TPA_CODE === tpaCode)
    return {
      label: tpa ? tpa.TPA_NAME : tpaCode,
      value: tpaCode
    }
  })

  const getStatusTag = (status: string) => {
    const statusConfig: Record<string, { color: string; icon: React.ReactNode }> = {
      SUCCESS: { color: 'success', icon: <CheckCircleOutlined /> },
      FAILED: { color: 'error', icon: <CloseCircleOutlined /> },
      PROCESSING: { color: 'processing', icon: <SyncOutlined spin /> },
      PENDING: { color: 'default', icon: <ClockCircleOutlined /> },
    }
    const config = statusConfig[status] || { color: 'default', icon: null }
    return <Tag color={config.color} icon={config.icon}>{status}</Tag>
  }

  const columns = [
    {
      title: 'File Name',
      dataIndex: 'FILE_NAME',
      key: 'FILE_NAME',
      width: 300,
      ellipsis: true,
    },
    {
      title: 'Type',
      dataIndex: 'FILE_TYPE',
      key: 'FILE_TYPE',
      width: 80,
    },
    {
      title: 'TPA',
      dataIndex: 'TPA',
      key: 'TPA',
      width: 120,
      render: (tpaCode: string) => {
        const tpa = tpas.find(t => t.TPA_CODE === tpaCode)
        return tpa ? tpa.TPA_NAME : tpaCode
      },
    },
    {
      title: 'Status',
      dataIndex: 'STATUS',
      key: 'STATUS',
      width: 130,
      render: (status: string) => getStatusTag(status),
    },
    {
      title: 'Discovered',
      dataIndex: 'DISCOVERED_TIMESTAMP',
      key: 'DISCOVERED_TIMESTAMP',
      width: 180,
      render: (date: string) => new Date(date).toLocaleString(),
    },
    {
      title: 'Processed',
      dataIndex: 'PROCESSED_TIMESTAMP',
      key: 'PROCESSED_TIMESTAMP',
      width: 180,
      render: (date: string) => date ? new Date(date).toLocaleString() : '-',
    },
    {
      title: 'Result',
      dataIndex: 'PROCESS_RESULT',
      key: 'PROCESS_RESULT',
      ellipsis: true,
      render: (result: string, record: FileQueueItem) => {
        if (record.STATUS === 'FAILED' && record.ERROR_MESSAGE) {
          return <span style={{ color: '#ff4d4f' }}>{record.ERROR_MESSAGE}</span>
        }
        return result || '-'
      },
    },
    {
      title: 'Actions',
      key: 'actions',
      width: 180,
      render: (_: any, record: FileQueueItem) => (
        <Space>
          {record.STATUS === 'FAILED' && (
            <Button
              type="link"
              size="small"
              icon={<RedoOutlined />}
              onClick={() => handleReprocess(record.QUEUE_ID, record.FILE_NAME)}
            >
              Reprocess
            </Button>
          )}
          {record.STATUS === 'SUCCESS' && (
            <Popconfirm
              title="Delete File Data"
              description={`This will delete all ${record.PROCESS_RESULT?.match(/\d+/)?.[0] || 'data'} rows for this file (TPA: ${record.TPA}). Continue?`}
              onConfirm={() => handleDeleteFileData(record.FILE_NAME, record.TPA)}
              okText="Yes, Delete"
              cancelText="Cancel"
              okButtonProps={{ danger: true }}
            >
              <Button
                type="link"
                size="small"
                danger
                icon={<DeleteOutlined />}
              >
                Delete Data
              </Button>
            </Popconfirm>
          )}
        </Space>
      ),
    },
  ]

  return (
    <div>
      <Title level={2}>Processing Status</Title>
      
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <div />
        <Button 
          icon={<ReloadOutlined />} 
          onClick={loadQueue}
          loading={loading}
        >
          Refresh Now
        </Button>
      </div>

      <p style={{ marginBottom: 24, color: '#666' }}>
        View all files that have been processed through the pipeline with their status and statistics.
      </p>

      {/* Statistics Cards */}
      <Row gutter={16} style={{ marginBottom: 24 }}>
        <Col span={4}>
          <Card>
            <Statistic
              title="Total Files"
              value={totalFiles}
              prefix={<FileTextOutlined />}
            />
          </Card>
        </Col>
        <Col span={5}>
          <Card>
            <Statistic
              title="✅ Success"
              value={successFiles}
              suffix={<span style={{ fontSize: 14 }}>/ {totalFiles}</span>}
              valueStyle={{ color: '#52c41a' }}
            />
            <div style={{ marginTop: 8, fontSize: 12, color: '#52c41a' }}>
              <RiseOutlined /> {successRate}%
            </div>
          </Card>
        </Col>
        <Col span={5}>
          <Card>
            <Statistic
              title="❌ Failed"
              value={failedFiles}
              suffix={<span style={{ fontSize: 14 }}>/ {totalFiles}</span>}
              valueStyle={{ color: '#ff4d4f' }}
            />
            <div style={{ marginTop: 8, fontSize: 12, color: '#ff4d4f' }}>
              ↑ {totalFiles > 0 ? ((failedFiles / totalFiles) * 100).toFixed(1) : '0.0'}%
            </div>
          </Card>
        </Col>
        <Col span={5}>
          <Card>
            <Statistic
              title="⏳ Processing"
              value={processingFiles + pendingFiles}
              valueStyle={{ color: '#1890ff' }}
            />
          </Card>
        </Col>
        <Col span={5}>
          <Card>
            <Statistic
              title="📊 Total Rows"
              value={totalRows.toLocaleString()}
            />
          </Card>
        </Col>
      </Row>

      {/* Filters */}
      <Card style={{ marginBottom: 16 }}>
        <Row gutter={16}>
          <Col span={8}>
            <div style={{ marginBottom: 8 }}><strong>Filter by TPA</strong></div>
            <Select
              mode="multiple"
              style={{ width: '100%' }}
              placeholder="All TPAs"
              value={tpaFilter}
              onChange={setTpaFilter}
              options={tpaOptions}
              allowClear
            />
          </Col>
          <Col span={8}>
            <div style={{ marginBottom: 8 }}><strong>Filter by Status</strong></div>
            <Select
              mode="multiple"
              style={{ width: '100%' }}
              placeholder="All statuses"
              value={statusFilter}
              onChange={setStatusFilter}
              options={statusOptions}
              allowClear
            />
          </Col>
          <Col span={8}>
            <div style={{ marginBottom: 8 }}><strong>Filter by File Type</strong></div>
            <Select
              mode="multiple"
              style={{ width: '100%' }}
              placeholder="All types"
              value={typeFilter}
              onChange={setTypeFilter}
              options={typeOptions}
              allowClear
            />
          </Col>
        </Row>
      </Card>

      {/* File List */}
      <Card title={`Showing ${filteredQueue.length} files`}>
        <Table
          columns={columns}
          dataSource={filteredQueue}
          rowKey="QUEUE_ID"
          loading={loading}
          pagination={{
            pageSize: 20,
            showSizeChanger: true,
            showTotal: (total) => `Total ${total} files`,
          }}
          scroll={{ x: 1200 }}
        />
      </Card>
    </div>
  )
}

export default BronzeStatus
