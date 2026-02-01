import React, { useState, useEffect } from 'react'
import { Card, Typography, Table, Button, Select, Space, message, Statistic, Row, Col, Input, Tag, Collapse, Tooltip } from 'antd'
import { ReloadOutlined, DatabaseOutlined, SearchOutlined, BarChartOutlined, CheckCircleOutlined, CloseCircleOutlined, InfoCircleOutlined } from '@ant-design/icons'
import { apiService } from '../services/api'

const { Title } = Typography
const { Panel } = Collapse

interface SilverDataProps {
  selectedTpa: string
  setSelectedTpa: (tpa: string) => void
  tpas: Array<{ TPA_CODE: string; TPA_NAME: string }>
  selectedTpaName?: string
}

const SilverData: React.FC<SilverDataProps> = ({ selectedTpa, setSelectedTpa, tpas, selectedTpaName }) => {
  const [loading, setLoading] = useState(false)
  const [data, setData] = useState<any[]>([])
  const [selectedTable, setSelectedTable] = useState<string>('')
  const [tables, setTables] = useState<Array<{ physicalName: string; schemaName: string }>>([])
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
      // Get all created tables
      const allTables = await apiService.getSilverTables()
      
      // Filter tables for the selected TPA
      const tpaCreatedTables = allTables.filter(
        (table: any) => table.TPA.toLowerCase() === selectedTpa.toLowerCase()
      )
      
      // Map to include both physical and schema names
      const tableList = tpaCreatedTables.map((table: any) => ({
        physicalName: table.TABLE_NAME,
        schemaName: table.SCHEMA_TABLE
      }))
      
      setTables(tableList)
      
      // Auto-select the first table if available and no table is currently selected
      if (tableList.length > 0 && !selectedTable) {
        setSelectedTable(tableList[0].physicalName)
      }
    } catch (error) {
      message.error('Failed to load tables')
      console.error('Error loading tables:', error)
    }
  }

  const loadData = async () => {
    if (!selectedTpa || !selectedTable) return

    setLoading(true)
    try {
      // Find the schema name for the selected physical table
      const tableInfo = tables.find(t => t.physicalName === selectedTable)
      const schemaName = tableInfo?.schemaName || selectedTable
      
      const result = await apiService.getSilverData(selectedTpa, schemaName, limit)
      setData(result.data || [])
      
      if (result.total_count === 0) {
        message.info('No data found in this table')
      }
    } catch (error: any) {
      message.error(`Failed to load Silver data: ${error.response?.data?.detail || error.message}`)
      setData([])
    } finally {
      setLoading(false)
    }
  }

  const loadStatistics = async () => {
    if (!selectedTpa || !selectedTable) return

    try {
      // Find the schema name for the selected physical table
      const tableInfo = tables.find(t => t.physicalName === selectedTable)
      const schemaName = tableInfo?.schemaName || selectedTable
      
      const stats = await apiService.getSilverDataStats(selectedTpa, schemaName)
      setStatistics({
        totalRecords: stats.total_records || 0,
        lastUpdated: stats.last_updated,
        dataQualityScore: stats.data_quality_score || 0,
        qualityMetrics: stats.quality_metrics || [],
      })
    } catch (error: any) {
      console.error('Failed to load statistics:', error)
      setStatistics({
        totalRecords: 0,
        lastUpdated: null,
        dataQualityScore: 0,
        qualityMetrics: [],
      })
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
      <Title level={2}>💎 Silver Data</Title>
      
      <div style={{ marginBottom: 24 }}>
        <label style={{ display: 'block', marginBottom: 8, fontWeight: 500 }}>Select Provider (TPA):</label>
        <Select
          value={selectedTpa}
          onChange={setSelectedTpa}
          style={{ width: 300 }}
          placeholder="Select TPA"
          options={tpas.map(tpa => ({
            value: tpa.TPA_CODE,
            label: tpa.TPA_NAME,
          }))}
        />
      </div>

      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 24 }}>
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
              <Tooltip title="Click to view quality metrics details">
                <Statistic
                  title={
                    <Space>
                      Data Quality Score
                      {statistics.qualityMetrics && statistics.qualityMetrics.length > 0 && (
                        <InfoCircleOutlined style={{ color: '#1890ff', cursor: 'pointer' }} />
                      )}
                    </Space>
                  }
                  value={statistics.dataQualityScore}
                  suffix="%"
                  prefix={<BarChartOutlined />}
                  valueStyle={{ color: statistics.dataQualityScore >= 90 ? '#3f8600' : statistics.dataQualityScore >= 70 ? '#faad14' : '#cf1322' }}
                />
              </Tooltip>
            </Col>
            <Col span={12}>
              <Statistic
                title="Last Updated"
                value={statistics.lastUpdated ? new Date(statistics.lastUpdated).toLocaleString() : 'N/A'}
              />
            </Col>
          </Row>
          
          {/* Quality Metrics Details */}
          {statistics.qualityMetrics && statistics.qualityMetrics.length > 0 && (
            <Collapse 
              style={{ marginTop: 16 }}
              items={[
                {
                  key: 'quality-metrics',
                  label: (
                    <Space>
                      <BarChartOutlined />
                      <strong>Data Quality Metrics</strong>
                      <Tag color={statistics.dataQualityScore >= 90 ? 'success' : statistics.dataQualityScore >= 70 ? 'warning' : 'error'}>
                        {statistics.qualityMetrics.filter((m: any) => m.passed).length} / {statistics.qualityMetrics.length} Passed
                      </Tag>
                    </Space>
                  ),
                  children: (
                    <Table
                      dataSource={statistics.qualityMetrics}
                      rowKey="metric_name"
                      pagination={false}
                      size="small"
                      columns={[
                        {
                          title: 'Status',
                          dataIndex: 'passed',
                          key: 'passed',
                          width: 80,
                          render: (passed: boolean) => (
                            passed ? (
                              <CheckCircleOutlined style={{ color: '#52c41a', fontSize: '18px' }} />
                            ) : (
                              <CloseCircleOutlined style={{ color: '#ff4d4f', fontSize: '18px' }} />
                            )
                          ),
                        },
                        {
                          title: 'Metric',
                          dataIndex: 'metric_name',
                          key: 'metric_name',
                          render: (text: string) => <strong>{text.replace(/_/g, ' ')}</strong>,
                        },
                        {
                          title: 'Description',
                          dataIndex: 'description',
                          key: 'description',
                        },
                        {
                          title: 'Value',
                          dataIndex: 'metric_value',
                          key: 'metric_value',
                          width: 120,
                          render: (value: number) => (
                            <Tag color="blue">{value !== null && value !== undefined ? value.toLocaleString() : 'N/A'}</Tag>
                          ),
                        },
                        {
                          title: 'Threshold',
                          dataIndex: 'metric_threshold',
                          key: 'metric_threshold',
                          width: 120,
                          render: (threshold: number) => (
                            <Tag color="default">{threshold !== null && threshold !== undefined ? threshold.toLocaleString() : 'N/A'}</Tag>
                          ),
                        },
                        {
                          title: 'Measured',
                          dataIndex: 'measured_timestamp',
                          key: 'measured_timestamp',
                          width: 180,
                          render: (timestamp: string) => timestamp ? new Date(timestamp).toLocaleString() : 'N/A',
                        },
                      ]}
                    />
                  ),
                },
              ]}
            />
          )}
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
                label: table.physicalName,
                value: table.physicalName,
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
