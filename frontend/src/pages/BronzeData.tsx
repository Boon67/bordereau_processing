import React, { useState, useEffect } from 'react'
import { Card, Typography, Table, Button, Select, Input, Space, message, Tag, Statistic, Row, Col } from 'antd'
import { ReloadOutlined, SearchOutlined, DatabaseOutlined, FileTextOutlined, TableOutlined } from '@ant-design/icons'
import { apiService } from '../services/api'
import type { RawDataRecord } from '../services/api'

const { Title } = Typography
const { Search } = Input

interface BronzeDataProps {
  selectedTpa: string
}

interface DataStats {
  totalRecords: number
  uniqueFiles: number
  fileTypes: Record<string, number>
  dateRange: { earliest: string; latest: string } | null
}

const BronzeData: React.FC<BronzeDataProps> = ({ selectedTpa }) => {
  const [loading, setLoading] = useState(false)
  const [data, setData] = useState<RawDataRecord[]>([])
  const [stats, setStats] = useState<DataStats>({
    totalRecords: 0,
    uniqueFiles: 0,
    fileTypes: {},
    dateRange: null,
  })
  const [fileName, setFileName] = useState<string>('')
  const [limit, setLimit] = useState(100)

  useEffect(() => {
    if (selectedTpa) {
      loadData()
    }
  }, [selectedTpa])

  const loadData = async () => {
    if (!selectedTpa) {
      message.warning('Please select a TPA')
      return
    }

    setLoading(true)
    try {
      const result = await apiService.getRawData(selectedTpa, fileName || undefined, limit)
      setData(result)
      
      // Calculate statistics
      const uniqueFiles = new Set(result.map(r => r.FILE_NAME)).size
      const fileTypes = result.reduce((acc, r) => {
        acc[r.FILE_TYPE] = (acc[r.FILE_TYPE] || 0) + 1
        return acc
      }, {} as Record<string, number>)
      
      const timestamps = result.map(r => new Date(r.LOAD_TIMESTAMP).getTime()).filter(t => !isNaN(t))
      const dateRange = timestamps.length > 0 ? {
        earliest: new Date(Math.min(...timestamps)).toLocaleDateString(),
        latest: new Date(Math.max(...timestamps)).toLocaleDateString(),
      } : null
      
      setStats({
        totalRecords: result.length,
        uniqueFiles,
        fileTypes,
        dateRange,
      })
      
      message.success(`Loaded ${result.length} records from ${uniqueFiles} files`)
    } catch (error) {
      message.error('Failed to load raw data')
    } finally {
      setLoading(false)
    }
  }

  const columns = [
    {
      title: 'Record ID',
      dataIndex: 'RECORD_ID',
      key: 'RECORD_ID',
      width: 100,
    },
    {
      title: 'File Name',
      dataIndex: 'FILE_NAME',
      key: 'FILE_NAME',
      width: 250,
      ellipsis: true,
      render: (name: string) => {
        const fileName = name.split('/').pop()
        return <span title={name}>{fileName}</span>
      },
    },
    {
      title: 'Row #',
      dataIndex: 'FILE_ROW_NUMBER',
      key: 'FILE_ROW_NUMBER',
      width: 80,
    },
    {
      title: 'Type',
      dataIndex: 'FILE_TYPE',
      key: 'FILE_TYPE',
      width: 80,
      render: (type: string) => <Tag color="blue">{type}</Tag>,
    },
    {
      title: 'Raw Data',
      dataIndex: 'RAW_DATA',
      key: 'RAW_DATA',
      ellipsis: true,
      render: (data: any) => {
        const dataStr = typeof data === 'string' ? data : JSON.stringify(data)
        return (
          <div style={{ 
            maxWidth: 400, 
            overflow: 'hidden', 
            textOverflow: 'ellipsis',
            fontFamily: 'monospace',
            fontSize: '12px'
          }}>
            {dataStr}
          </div>
        )
      },
    },
    {
      title: 'Load Timestamp',
      dataIndex: 'LOAD_TIMESTAMP',
      key: 'LOAD_TIMESTAMP',
      width: 180,
      render: (date: string) => new Date(date).toLocaleString(),
    },
    {
      title: 'Loaded By',
      dataIndex: 'LOADED_BY',
      key: 'LOADED_BY',
      width: 120,
    },
  ]

  if (!selectedTpa) {
    return (
      <div>
        <Title level={2}>📊 Raw Data</Title>
        <Card style={{ marginTop: 16 }}>
          <p style={{ textAlign: 'center', padding: '40px', color: '#999' }}>
            Please select a TPA from the dropdown in the header to view raw data.
          </p>
        </Card>
      </div>
    )
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <Title level={2}>📊 Raw Data</Title>
        <Button 
          icon={<ReloadOutlined />} 
          onClick={loadData}
          loading={loading}
        >
          Refresh
        </Button>
      </div>

      <p style={{ marginBottom: 24, color: '#666' }}>
        View raw data records loaded from files. TPA: <strong>{selectedTpa}</strong>
      </p>

      {/* Statistics Cards */}
      <Row gutter={16} style={{ marginBottom: 24 }}>
        <Col span={6}>
          <Card>
            <Statistic
              title="Total Records"
              value={stats.totalRecords}
              prefix={<DatabaseOutlined />}
              valueStyle={{ color: '#1890ff' }}
            />
          </Card>
        </Col>
        <Col span={6}>
          <Card>
            <Statistic
              title="Unique Files"
              value={stats.uniqueFiles}
              prefix={<FileTextOutlined />}
              valueStyle={{ color: '#52c41a' }}
            />
          </Card>
        </Col>
        <Col span={6}>
          <Card>
            <Statistic
              title="File Types"
              value={Object.keys(stats.fileTypes).length}
              prefix={<TableOutlined />}
            />
            <div style={{ marginTop: 8, fontSize: '12px' }}>
              {Object.entries(stats.fileTypes).map(([type, count]) => (
                <Tag key={type} color="blue" style={{ marginTop: 4 }}>
                  {type}: {count}
                </Tag>
              ))}
            </div>
          </Card>
        </Col>
        <Col span={6}>
          <Card>
            <div style={{ fontSize: '14px', color: '#666', marginBottom: 8 }}>Date Range</div>
            {stats.dateRange ? (
              <div style={{ fontSize: '12px' }}>
                <div><strong>From:</strong> {stats.dateRange.earliest}</div>
                <div><strong>To:</strong> {stats.dateRange.latest}</div>
              </div>
            ) : (
              <div style={{ fontSize: '12px', color: '#999' }}>No data</div>
            )}
          </Card>
        </Col>
      </Row>

      <Card style={{ marginBottom: 16 }}>
        <Space direction="vertical" style={{ width: '100%' }} size="large">
          <div>
            <label style={{ display: 'block', marginBottom: 8, fontWeight: 'bold' }}>
              Filter by File Name (optional)
            </label>
            <Search
              placeholder="Enter file name to filter..."
              value={fileName}
              onChange={(e) => setFileName(e.target.value)}
              onSearch={loadData}
              enterButton={<SearchOutlined />}
              allowClear
            />
          </div>

          <div>
            <label style={{ display: 'block', marginBottom: 8, fontWeight: 'bold' }}>
              Limit Records
            </label>
            <Select
              value={limit}
              onChange={setLimit}
              style={{ width: 200 }}
              options={[
                { label: '50 records', value: 50 },
                { label: '100 records', value: 100 },
                { label: '500 records', value: 500 },
                { label: '1000 records', value: 1000 },
              ]}
            />
          </div>

          <Space>
            <Button 
              type="primary" 
              icon={<DatabaseOutlined />}
              onClick={loadData}
              loading={loading}
            >
              Load Data
            </Button>
            {data.length === 0 && !loading && (
              <Button 
                type="default"
                onClick={() => {
                  setFileName('')
                  setLimit(100)
                  loadData()
                }}
              >
                Load All Data
              </Button>
            )}
          </Space>
        </Space>
      </Card>

      {data.length > 0 && (
        <Card 
          title={
            <Space>
              <span>Showing {data.length} records</span>
              {fileName && <Tag color="blue">Filtered by: {fileName}</Tag>}
            </Space>
          }
        >
        <Table
          columns={columns}
          dataSource={data}
          rowKey="RECORD_ID"
          loading={loading}
          pagination={{
            pageSize: 20,
            showSizeChanger: true,
            showTotal: (total) => `Total ${total} records`,
          }}
          scroll={{ x: 1400 }}
        />
      </Card>
      )}

      {data.length === 0 && !loading && (
        <Card>
          <div style={{ textAlign: 'center', padding: '40px', color: '#999' }}>
            <DatabaseOutlined style={{ fontSize: '48px', marginBottom: '16px', color: '#d9d9d9' }} />
            <p>No data loaded yet. Click "Load Data" to view raw data records for <strong>{selectedTpa}</strong>.</p>
          </div>
        </Card>
      )}
    </div>
  )
}

export default BronzeData
