import React, { useState, useEffect } from 'react'
import { Card, Typography, Table, Button, Select, Space, message, Statistic, Row, Col, Input, Tag } from 'antd'
import { ReloadOutlined, DatabaseOutlined, SearchOutlined, BarChartOutlined } from '@ant-design/icons'
import { apiService } from '../services/api'

const { Title } = Typography

interface SilverDataProps {
  selectedTpa: string
  selectedTpaName?: string
}

const SilverData: React.FC<SilverDataProps> = ({ selectedTpa, selectedTpaName }) => {
  const [loading, setLoading] = useState(false)
  const [data, setData] = useState<any[]>([])
  const [selectedTable, setSelectedTable] = useState<string>('')
  const [tables, setTables] = useState<string[]>([])
  const [limit, setLimit] = useState(100)
  const [searchText, setSearchText] = useState('')
  const [statistics, setStatistics] = useState<any>(null)

  useEffect(() => {
    if (selectedTpa) {
      loadTables()
    }
  }, [selectedTpa])

  useEffect(() => {
    if (selectedTpa && selectedTable) {
      loadData()
      loadStatistics()
    }
  }, [selectedTpa, selectedTable, limit])

  const loadTables = async () => {
    if (!selectedTpa) return

    try {
      const schemas = await apiService.getTargetSchemas(selectedTpa)
      const uniqueTables = Array.from(new Set(schemas.map(s => s.TABLE_NAME)))
      setTables(uniqueTables)
      
      if (uniqueTables.length > 0 && !selectedTable) {
        setSelectedTable(uniqueTables[0])
      }
    } catch (error) {
      message.error('Failed to load tables')
    }
  }

  const loadData = async () => {
    if (!selectedTpa || !selectedTable) return

    setLoading(true)
    try {
      // This would call a backend endpoint to fetch Silver layer data
      // For now, we'll show a placeholder
      message.info('Silver data viewer ready')
      setData([])
    } catch (error) {
      message.error('Failed to load Silver data')
    } finally {
      setLoading(false)
    }
  }

  const loadStatistics = async () => {
    if (!selectedTpa || !selectedTable) return

    try {
      // Placeholder for statistics
      setStatistics({
        totalRecords: 0,
        lastUpdated: new Date().toISOString(),
        dataQualityScore: 95,
      })
    } catch (error) {
      console.error('Failed to load statistics:', error)
    }
  }

  if (!selectedTpa) {
    return (
      <div>
        <Title level={2}>💎 Silver Data</Title>
        <Card style={{ marginTop: 16 }}>
          <p style={{ textAlign: 'center', padding: '40px', color: '#999' }}>
            Please select a TPA from the dropdown in the header to view Silver layer data.
          </p>
        </Card>
      </div>
    )
  }

  // Generate columns dynamically based on data
  const columns = data.length > 0
    ? Object.keys(data[0]).map(key => ({
        title: key,
        dataIndex: key,
        key: key,
        ellipsis: true,
        sorter: (a: any, b: any) => {
          if (typeof a[key] === 'string') {
            return a[key].localeCompare(b[key])
          }
          return a[key] - b[key]
        },
      }))
    : []

  const filteredData = searchText
    ? data.filter(record =>
        Object.values(record).some(value =>
          String(value).toLowerCase().includes(searchText.toLowerCase())
        )
      )
    : data

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <Title level={2}>💎 Silver Data</Title>
        <Button 
          icon={<ReloadOutlined />} 
          onClick={loadData}
          loading={loading}
        >
          Refresh
        </Button>
      </div>

      <p style={{ marginBottom: 24, color: '#666' }}>
        View transformed and validated data in the Silver layer. TPA: <strong>{selectedTpaName || selectedTpa}</strong>
      </p>

      {/* Statistics */}
      {statistics && (
        <Card style={{ marginBottom: 16 }}>
          <Row gutter={16}>
            <Col span={6}>
              <Statistic
                title="Total Records"
                value={statistics.totalRecords}
                prefix={<DatabaseOutlined />}
              />
            </Col>
            <Col span={6}>
              <Statistic
                title="Data Quality Score"
                value={statistics.dataQualityScore}
                suffix="%"
                prefix={<BarChartOutlined />}
                valueStyle={{ color: statistics.dataQualityScore >= 90 ? '#3f8600' : '#cf1322' }}
              />
            </Col>
            <Col span={12}>
              <Statistic
                title="Last Updated"
                value={new Date(statistics.lastUpdated).toLocaleString()}
              />
            </Col>
          </Row>
        </Card>
      )}

      {/* Table Selection and Search */}
      <Card style={{ marginBottom: 16 }}>
        <Space direction="vertical" style={{ width: '100%' }} size="middle">
          <div>
            <label style={{ display: 'block', marginBottom: 8, fontWeight: 'bold' }}>
              Select Table
            </label>
            <Select
              value={selectedTable}
              onChange={setSelectedTable}
              style={{ width: '100%' }}
              placeholder="Select a table"
              options={tables.map(table => ({
                label: table,
                value: table,
              }))}
            />
          </div>

          <Space style={{ width: '100%' }}>
            <Input
              placeholder="Search data..."
              prefix={<SearchOutlined />}
              value={searchText}
              onChange={e => setSearchText(e.target.value)}
              style={{ width: 300 }}
            />
            <Select
              value={limit}
              onChange={setLimit}
              style={{ width: 150 }}
              options={[
                { label: '100 rows', value: 100 },
                { label: '500 rows', value: 500 },
                { label: '1000 rows', value: 1000 },
                { label: '5000 rows', value: 5000 },
              ]}
            />
          </Space>
        </Space>
      </Card>

      {/* Data Table */}
      {selectedTable ? (
        <Card title={
          <Space>
            <DatabaseOutlined />
            <span>{selectedTable}</span>
            <Tag color="blue">{filteredData.length} records</Tag>
          </Space>
        }>
          {data.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '40px', color: '#999' }}>
              <p>No data found in this table.</p>
              <p style={{ fontSize: '12px' }}>
                Data will appear here after successful transformation from Bronze to Silver layer.
              </p>
            </div>
          ) : (
            <Table
              columns={columns}
              dataSource={filteredData}
              loading={loading}
              pagination={{
                pageSize: 50,
                showSizeChanger: true,
                showTotal: (total) => `Total ${total} records`,
              }}
              scroll={{ x: 'max-content' }}
              size="small"
            />
          )}
        </Card>
      ) : (
        <Card>
          <p style={{ textAlign: 'center', padding: '40px', color: '#999' }}>
            Please select a table to view data.
          </p>
        </Card>
      )}

      <Card title="ℹ️ Silver Layer Information" style={{ marginTop: 16 }}>
        <Space direction="vertical" size="small">
          <div><strong>Purpose:</strong> The Silver layer contains cleaned, validated, and structured data</div>
          <div><strong>Data Quality:</strong> All records have passed validation rules and quality checks</div>
          <div><strong>Schema:</strong> Data conforms to predefined target schemas</div>
          <div><strong>Usage:</strong> This data is ready for analytics, reporting, and downstream applications</div>
        </Space>
      </Card>
    </div>
  )
}

export default SilverData
