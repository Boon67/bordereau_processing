import React, { useState, useEffect } from 'react'
import {
  Card,
  Table,
  message,
  Typography,
  Space,
  Button,
  Tag,
  Descriptions,
  Divider,
} from 'antd'
import {
  ReloadOutlined,
  DashboardOutlined,
  DollarOutlined,
  TeamOutlined,
  MedicineBoxOutlined,
} from '@ant-design/icons'
import { apiService } from '../services/api'

const { Title, Text } = Typography

interface GoldMetricsProps {
  selectedTpa: string
  setSelectedTpa: (tpa: string) => void
  tpas: Array<{ TPA_CODE: string; TPA_NAME: string }>
  selectedTpaName?: string
}

const GoldMetrics: React.FC<GoldMetricsProps> = ({ selectedTpa, setSelectedTpa, tpas, selectedTpaName }) => {
  const [loading, setLoading] = useState(false)
  const [metrics, setMetrics] = useState<any[]>([])

  useEffect(() => {
    if (selectedTpa) {
      loadMetrics()
    }
  }, [selectedTpa])

  const loadMetrics = async () => {
    setLoading(true)
    try {
      const data = await apiService.getBusinessMetrics(selectedTpa)
      setMetrics(data)
    } catch (error: any) {
      message.error('Failed to load metrics: ' + (error.response?.data?.detail || error.message))
    } finally {
      setLoading(false)
    }
  }

  const getCategoryIcon = (category: string) => {
    switch (category) {
      case 'FINANCIAL':
        return <DollarOutlined style={{ color: '#52c41a' }} />
      case 'OPERATIONAL':
        return <DashboardOutlined style={{ color: '#1890ff' }} />
      case 'CLINICAL':
        return <MedicineBoxOutlined style={{ color: '#722ed1' }} />
      default:
        return <TeamOutlined />
    }
  }

  const getCategoryColor = (category: string) => {
    switch (category) {
      case 'FINANCIAL':
        return 'green'
      case 'OPERATIONAL':
        return 'blue'
      case 'CLINICAL':
        return 'purple'
      default:
        return 'default'
    }
  }

  const columns = [
    {
      title: 'Metric Name',
      dataIndex: 'METRIC_NAME',
      key: 'METRIC_NAME',
      width: 250,
      render: (name: string) => <Text strong>{name}</Text>,
    },
    {
      title: 'Category',
      dataIndex: 'METRIC_CATEGORY',
      key: 'METRIC_CATEGORY',
      width: 150,
      render: (category: string) => (
        <Tag icon={getCategoryIcon(category)} color={getCategoryColor(category)}>
          {category}
        </Tag>
      ),
    },
    {
      title: 'Description',
      dataIndex: 'DESCRIPTION',
      key: 'DESCRIPTION',
      ellipsis: true,
    },
    {
      title: 'Refresh Frequency',
      dataIndex: 'REFRESH_FREQUENCY',
      key: 'REFRESH_FREQUENCY',
      width: 150,
      render: (freq: string) => <Tag>{freq}</Tag>,
    },
    {
      title: 'Owner',
      dataIndex: 'METRIC_OWNER',
      key: 'METRIC_OWNER',
      width: 180,
    },
    {
      title: 'Status',
      dataIndex: 'IS_ACTIVE',
      key: 'IS_ACTIVE',
      width: 100,
      render: (active: boolean) => (
        <Tag color={active ? 'green' : 'red'}>
          {active ? 'Active' : 'Inactive'}
        </Tag>
      ),
    },
  ]

  const expandedRowRender = (record: any) => {
    return (
      <Descriptions column={1} bordered size="small">
        <Descriptions.Item label="Calculation Logic">
          <Text code>{record.CALCULATION_LOGIC}</Text>
        </Descriptions.Item>
        <Descriptions.Item label="Source Tables">
          {record.SOURCE_TABLES}
        </Descriptions.Item>
        <Descriptions.Item label="Created">
          {record.CREATED_AT ? new Date(record.CREATED_AT).toLocaleString() : 'N/A'}
        </Descriptions.Item>
        <Descriptions.Item label="Last Updated">
          {record.UPDATED_AT ? new Date(record.UPDATED_AT).toLocaleString() : 'N/A'}
        </Descriptions.Item>
      </Descriptions>
    )
  }

  const financialMetrics = metrics.filter(m => m.METRIC_CATEGORY === 'FINANCIAL')
  const operationalMetrics = metrics.filter(m => m.METRIC_CATEGORY === 'OPERATIONAL')
  const clinicalMetrics = metrics.filter(m => m.METRIC_CATEGORY === 'CLINICAL')

  return (
    <div>
      <Title level={2}>📈 Business Metrics</Title>
      
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
              📊 Business Metrics
            </Title>
            <Text type="secondary">
              View business metrics and KPIs for {selectedTpaName || selectedTpa}
            </Text>
          </div>
          <Button
            icon={<ReloadOutlined />}
            onClick={loadMetrics}
            loading={loading}
          >
            Refresh
          </Button>
        </div>

        <Divider />

        <Space direction="vertical" size="large" style={{ width: '100%' }}>
          <Descriptions column={3} bordered>
            <Descriptions.Item label="Total Metrics">
              <Tag color="blue">{metrics.length}</Tag>
            </Descriptions.Item>
            <Descriptions.Item label="Financial Metrics">
              <Tag color="green">{financialMetrics.length}</Tag>
            </Descriptions.Item>
            <Descriptions.Item label="Operational Metrics">
              <Tag color="blue">{operationalMetrics.length}</Tag>
            </Descriptions.Item>
            <Descriptions.Item label="Clinical Metrics">
              <Tag color="purple">{clinicalMetrics.length}</Tag>
            </Descriptions.Item>
            <Descriptions.Item label="Active Metrics">
              <Tag color="green">{metrics.filter(m => m.IS_ACTIVE).length}</Tag>
            </Descriptions.Item>
            <Descriptions.Item label="Inactive Metrics">
              <Tag color="red">{metrics.filter(m => !m.IS_ACTIVE).length}</Tag>
            </Descriptions.Item>
          </Descriptions>

          <Table
            columns={columns}
            dataSource={metrics}
            loading={loading}
            rowKey="METRIC_ID"
            expandable={{
              expandedRowRender,
              expandRowByClick: true,
            }}
            pagination={{
              pageSize: 10,
              showSizeChanger: true,
              showTotal: (total) => `Total ${total} metrics`,
            }}
          />
        </Space>
      </Card>
    </div>
  )
}

export default GoldMetrics
