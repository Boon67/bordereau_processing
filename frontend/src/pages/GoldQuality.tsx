import React, { useState, useEffect } from 'react'
import {
  Card,
  Table,
  message,
  Typography,
  Button,
  Tag,
  Space,
  Descriptions,
  Row,
  Col,
  Statistic,
  Progress,
} from 'antd'
import {
  ReloadOutlined,
  CheckCircleOutlined,
  CloseCircleOutlined,
  WarningOutlined,
  InfoCircleOutlined,
} from '@ant-design/icons'
import { apiService } from '../services/api'

const { Title, Text } = Typography

interface GoldQualityProps {
  selectedTpa: string
  setSelectedTpa: (tpa: string) => void
  tpas: Array<{ TPA_CODE: string; TPA_NAME: string }>
  selectedTpaName?: string
}

const GoldQuality: React.FC<GoldQualityProps> = ({ selectedTpa, setSelectedTpa, tpas, selectedTpaName }) => {
  const [loading, setLoading] = useState(false)
  const [qualityResults, setQualityResults] = useState<any[]>([])
  const [qualityStats, setQualityStats] = useState<any>(null)

  useEffect(() => {
    if (selectedTpa) {
      loadQualityResults()
      loadQualityStats()
    }
  }, [selectedTpa])

  const loadQualityResults = async () => {
    setLoading(true)
    try {
      const data = await apiService.getQualityCheckResults(selectedTpa)
      setQualityResults(data)
    } catch (error: any) {
      message.error('Failed to load quality results: ' + (error.response?.data?.detail || error.message))
    } finally {
      setLoading(false)
    }
  }

  const loadQualityStats = async () => {
    try {
      const data = await apiService.getQualityStats(selectedTpa)
      setQualityStats(data)
    } catch (error: any) {
      console.error('Failed to load quality stats:', error)
    }
  }

  const getSeverityColor = (severity: string) => {
    switch (severity?.toUpperCase()) {
      case 'CRITICAL':
        return 'red'
      case 'ERROR':
        return 'red'
      case 'WARNING':
        return 'orange'
      case 'INFO':
        return 'blue'
      default:
        return 'default'
    }
  }

  const getSeverityIcon = (severity: string) => {
    switch (severity?.toUpperCase()) {
      case 'CRITICAL':
      case 'ERROR':
        return <CloseCircleOutlined />
      case 'WARNING':
        return <WarningOutlined />
      case 'INFO':
        return <InfoCircleOutlined />
      default:
        return <CheckCircleOutlined />
    }
  }

  const getStatusColor = (status: string) => {
    switch (status?.toUpperCase()) {
      case 'PASSED':
        return 'green'
      case 'FAILED':
        return 'red'
      case 'WARNING':
        return 'orange'
      default:
        return 'default'
    }
  }

  const columns = [
    {
      title: 'Check Date',
      dataIndex: 'CHECK_TIMESTAMP',
      key: 'CHECK_TIMESTAMP',
      width: 180,
      render: (date: string) => date ? new Date(date).toLocaleString() : 'N/A',
      sorter: (a: any, b: any) => new Date(a.CHECK_TIMESTAMP).getTime() - new Date(b.CHECK_TIMESTAMP).getTime(),
    },
    {
      title: 'Table',
      dataIndex: 'TABLE_NAME',
      key: 'TABLE_NAME',
      width: 200,
    },
    {
      title: 'Rule Name',
      dataIndex: 'RULE_NAME',
      key: 'RULE_NAME',
      width: 250,
      render: (name: string) => <Text strong>{name}</Text>,
    },
    {
      title: 'Status',
      dataIndex: 'CHECK_STATUS',
      key: 'CHECK_STATUS',
      width: 120,
      render: (status: string) => (
        <Tag color={getStatusColor(status)}>
          {status}
        </Tag>
      ),
      filters: [
        { text: 'Passed', value: 'PASSED' },
        { text: 'Failed', value: 'FAILED' },
        { text: 'Warning', value: 'WARNING' },
      ],
      onFilter: (value: any, record: any) => record.CHECK_STATUS === value,
    },
    {
      title: 'Severity',
      dataIndex: 'SEVERITY',
      key: 'SEVERITY',
      width: 120,
      render: (severity: string) => (
        <Tag icon={getSeverityIcon(severity)} color={getSeverityColor(severity)}>
          {severity}
        </Tag>
      ),
    },
    {
      title: 'Records Checked',
      dataIndex: 'RECORDS_CHECKED',
      key: 'RECORDS_CHECKED',
      width: 150,
      render: (val: number) => val?.toLocaleString() || '0',
    },
    {
      title: 'Records Failed',
      dataIndex: 'RECORDS_FAILED',
      key: 'RECORDS_FAILED',
      width: 150,
      render: (val: number) => val?.toLocaleString() || '0',
    },
    {
      title: 'Pass Rate',
      dataIndex: 'PASS_RATE',
      key: 'PASS_RATE',
      width: 120,
      render: (val: number, record: any) => {
        const passRate = record.RECORDS_CHECKED > 0
          ? ((record.RECORDS_CHECKED - record.RECORDS_FAILED) / record.RECORDS_CHECKED * 100)
          : 100
        return (
          <Tag color={passRate >= 95 ? 'green' : passRate >= 75 ? 'orange' : 'red'}>
            {passRate.toFixed(1)}%
          </Tag>
        )
      },
    },
  ]

  const expandedRowRender = (record: any) => {
    return (
      <Descriptions column={2} bordered size="small">
        <Descriptions.Item label="Check Logic" span={2}>
          <Text code>{record.CHECK_LOGIC || 'N/A'}</Text>
        </Descriptions.Item>
        <Descriptions.Item label="Error Message" span={2}>
          {record.ERROR_MESSAGE ? (
            <Text type="danger">{record.ERROR_MESSAGE}</Text>
          ) : (
            <Text type="secondary">No errors</Text>
          )}
        </Descriptions.Item>
        <Descriptions.Item label="Execution Time">
          {record.EXECUTION_TIME_MS ? `${record.EXECUTION_TIME_MS}ms` : 'N/A'}
        </Descriptions.Item>
        <Descriptions.Item label="Action Taken">
          {record.ACTION_TAKEN || 'N/A'}
        </Descriptions.Item>
      </Descriptions>
    )
  }

  const passedChecks = qualityResults.filter(r => r.CHECK_STATUS === 'PASSED').length
  const failedChecks = qualityResults.filter(r => r.CHECK_STATUS === 'FAILED').length
  const warningChecks = qualityResults.filter(r => r.CHECK_STATUS === 'WARNING').length
  const overallPassRate = qualityResults.length > 0
    ? (passedChecks / qualityResults.length * 100)
    : 100

  return (
    <div>
      <Title level={2}>✅ Quality Checks</Title>
      
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

      <Card>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
          <div>
            <Title level={4} style={{ margin: 0 }}>
              ✅ Data Quality Checks
            </Title>
            <Text type="secondary">
              View quality check results for {selectedTpaName || selectedTpa}
            </Text>
          </div>
          <Button
            icon={<ReloadOutlined />}
            onClick={() => {
              loadQualityResults()
              loadQualityStats()
            }}
            loading={loading}
          >
            Refresh
          </Button>
        </div>

        <Row gutter={16} style={{ marginBottom: 24 }}>
          <Col span={6}>
            <Card>
              <Statistic
                title="Total Checks"
                value={qualityResults.length}
                prefix={<CheckCircleOutlined />}
              />
            </Card>
          </Col>
          <Col span={6}>
            <Card>
              <Statistic
                title="Passed"
                value={passedChecks}
                valueStyle={{ color: '#3f8600' }}
                prefix={<CheckCircleOutlined />}
              />
            </Card>
          </Col>
          <Col span={6}>
            <Card>
              <Statistic
                title="Failed"
                value={failedChecks}
                valueStyle={{ color: '#cf1322' }}
                prefix={<CloseCircleOutlined />}
              />
            </Card>
          </Col>
          <Col span={6}>
            <Card>
              <Statistic
                title="Warnings"
                value={warningChecks}
                valueStyle={{ color: '#faad14' }}
                prefix={<WarningOutlined />}
              />
            </Card>
          </Col>
        </Row>

        <Card style={{ marginBottom: 24, background: '#f0f2f5' }}>
          <Space direction="vertical" style={{ width: '100%' }}>
            <Text strong>Overall Quality Score</Text>
            <Progress
              percent={Number(overallPassRate.toFixed(1))}
              status={overallPassRate >= 95 ? 'success' : overallPassRate >= 75 ? 'normal' : 'exception'}
              strokeColor={overallPassRate >= 95 ? '#52c41a' : overallPassRate >= 75 ? '#faad14' : '#ff4d4f'}
            />
          </Space>
        </Card>

        <Table
          columns={columns}
          dataSource={qualityResults}
          loading={loading}
          rowKey="CHECK_ID"
          expandable={{
            expandedRowRender,
            expandRowByClick: true,
          }}
          pagination={{
            pageSize: 20,
            showSizeChanger: true,
            showTotal: (total) => `Total ${total} quality checks`,
          }}
        />
      </Card>
    </div>
  )
}

export default GoldQuality
