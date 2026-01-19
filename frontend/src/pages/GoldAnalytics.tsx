import React, { useState, useEffect } from 'react'
import {
  Card,
  Table,
  Select,
  message,
  Spin,
  Typography,
  Space,
  Statistic,
  Row,
  Col,
  Tag,
  Button,
} from 'antd'
import {
  ReloadOutlined,
  BarChartOutlined,
  UserOutlined,
  MedicineBoxOutlined,
  DollarOutlined,
} from '@ant-design/icons'
import { apiService } from '../services/api'

const { Title, Text } = Typography
const { Option } = Select

interface GoldAnalyticsProps {
  selectedTpa: string
  selectedTpaName?: string
}

const GoldAnalytics: React.FC<GoldAnalyticsProps> = ({ selectedTpa, selectedTpaName }) => {
  const [loading, setLoading] = useState(false)
  const [selectedTable, setSelectedTable] = useState<string>('CLAIMS_ANALYTICS')
  const [tableData, setTableData] = useState<any[]>([])
  const [stats, setStats] = useState<any>(null)

  const analyticsTableOptions = [
    { value: 'CLAIMS_ANALYTICS', label: 'Claims Analytics', icon: <MedicineBoxOutlined /> },
    { value: 'MEMBER_360', label: 'Member 360', icon: <UserOutlined /> },
    { value: 'PROVIDER_PERFORMANCE', label: 'Provider Performance', icon: <BarChartOutlined /> },
    { value: 'FINANCIAL_SUMMARY', label: 'Financial Summary', icon: <DollarOutlined /> },
  ]

  useEffect(() => {
    if (selectedTpa && selectedTable) {
      loadTableData()
      loadStats()
    }
  }, [selectedTpa, selectedTable])

  const loadTableData = async () => {
    setLoading(true)
    try {
      const data = await apiService.getGoldTableData(selectedTable, selectedTpa)
      setTableData(data)
    } catch (error: any) {
      message.error('Failed to load table data: ' + (error.response?.data?.detail || error.message))
    } finally {
      setLoading(false)
    }
  }

  const loadStats = async () => {
    try {
      const data = await apiService.getGoldStats(selectedTable, selectedTpa)
      setStats(data)
    } catch (error: any) {
      console.error('Failed to load stats:', error)
    }
  }

  const getColumnsForTable = (tableName: string) => {
    switch (tableName) {
      case 'CLAIMS_ANALYTICS':
        return [
          { title: 'TPA', dataIndex: 'TPA', key: 'TPA', width: 150 },
          { title: 'Year', dataIndex: 'CLAIM_YEAR', key: 'CLAIM_YEAR', width: 100 },
          { title: 'Month', dataIndex: 'CLAIM_MONTH', key: 'CLAIM_MONTH', width: 100 },
          { title: 'Claim Type', dataIndex: 'CLAIM_TYPE', key: 'CLAIM_TYPE', width: 120 },
          {
            title: 'Claim Count',
            dataIndex: 'CLAIM_COUNT',
            key: 'CLAIM_COUNT',
            width: 120,
            render: (val: number) => val?.toLocaleString() || '0',
          },
          {
            title: 'Total Billed',
            dataIndex: 'TOTAL_BILLED_AMOUNT',
            key: 'TOTAL_BILLED_AMOUNT',
            width: 150,
            render: (val: number) => `$${val?.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) || '0.00'}`,
          },
          {
            title: 'Total Paid',
            dataIndex: 'TOTAL_PAID_AMOUNT',
            key: 'TOTAL_PAID_AMOUNT',
            width: 150,
            render: (val: number) => `$${val?.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) || '0.00'}`,
          },
          {
            title: 'Discount Rate',
            dataIndex: 'DISCOUNT_RATE',
            key: 'DISCOUNT_RATE',
            width: 120,
            render: (val: number) => val ? `${(val * 100).toFixed(2)}%` : 'N/A',
          },
        ]
      case 'MEMBER_360':
        return [
          { title: 'TPA', dataIndex: 'TPA', key: 'TPA', width: 150 },
          { title: 'Member ID', dataIndex: 'MEMBER_ID', key: 'MEMBER_ID', width: 150 },
          { title: 'Age', dataIndex: 'AGE', key: 'AGE', width: 80 },
          { title: 'Gender', dataIndex: 'GENDER', key: 'GENDER', width: 100 },
          {
            title: 'Total Claims',
            dataIndex: 'TOTAL_CLAIMS',
            key: 'TOTAL_CLAIMS',
            width: 120,
            render: (val: number) => val?.toLocaleString() || '0',
          },
          {
            title: 'Total Paid',
            dataIndex: 'TOTAL_PAID',
            key: 'TOTAL_PAID',
            width: 150,
            render: (val: number) => `$${val?.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) || '0.00'}`,
          },
          {
            title: 'Risk Score',
            dataIndex: 'RISK_SCORE',
            key: 'RISK_SCORE',
            width: 120,
            render: (val: number) => (
              <Tag color={val >= 4 ? 'red' : val >= 3 ? 'orange' : 'green'}>
                {val || 'N/A'}
              </Tag>
            ),
          },
        ]
      case 'PROVIDER_PERFORMANCE':
        return [
          { title: 'TPA', dataIndex: 'TPA', key: 'TPA', width: 150 },
          { title: 'Provider ID', dataIndex: 'PROVIDER_ID', key: 'PROVIDER_ID', width: 150 },
          { title: 'Period', dataIndex: 'MEASUREMENT_PERIOD', key: 'MEASUREMENT_PERIOD', width: 120 },
          {
            title: 'Total Claims',
            dataIndex: 'TOTAL_CLAIMS',
            key: 'TOTAL_CLAIMS',
            width: 120,
            render: (val: number) => val?.toLocaleString() || '0',
          },
          {
            title: 'Unique Members',
            dataIndex: 'UNIQUE_MEMBERS',
            key: 'UNIQUE_MEMBERS',
            width: 140,
            render: (val: number) => val?.toLocaleString() || '0',
          },
          {
            title: 'Total Paid',
            dataIndex: 'TOTAL_PAID',
            key: 'TOTAL_PAID',
            width: 150,
            render: (val: number) => `$${val?.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) || '0.00'}`,
          },
          {
            title: 'Discount Rate',
            dataIndex: 'DISCOUNT_RATE',
            key: 'DISCOUNT_RATE',
            width: 120,
            render: (val: number) => val ? `${(val * 100).toFixed(2)}%` : 'N/A',
          },
        ]
      case 'FINANCIAL_SUMMARY':
        return [
          { title: 'TPA', dataIndex: 'TPA', key: 'TPA', width: 150 },
          { title: 'Fiscal Year', dataIndex: 'FISCAL_YEAR', key: 'FISCAL_YEAR', width: 120 },
          { title: 'Fiscal Month', dataIndex: 'FISCAL_MONTH', key: 'FISCAL_MONTH', width: 120 },
          { title: 'Claim Type', dataIndex: 'CLAIM_TYPE', key: 'CLAIM_TYPE', width: 120 },
          {
            title: 'Total Billed',
            dataIndex: 'TOTAL_BILLED',
            key: 'TOTAL_BILLED',
            width: 150,
            render: (val: number) => `$${val?.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) || '0.00'}`,
          },
          {
            title: 'Total Paid',
            dataIndex: 'TOTAL_PAID',
            key: 'TOTAL_PAID',
            width: 150,
            render: (val: number) => `$${val?.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) || '0.00'}`,
          },
          {
            title: 'Member Count',
            dataIndex: 'MEMBER_COUNT',
            key: 'MEMBER_COUNT',
            width: 130,
            render: (val: number) => val?.toLocaleString() || '0',
          },
          {
            title: 'PMPM',
            dataIndex: 'PMPM',
            key: 'PMPM',
            width: 120,
            render: (val: number) => val ? `$${val.toFixed(2)}` : 'N/A',
          },
        ]
      default:
        return []
    }
  }

  return (
    <div>
      <Card>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
          <div>
            <Title level={2} style={{ margin: 0 }}>
              🏆 Gold Layer Analytics
            </Title>
            <Text type="secondary">
              View aggregated analytics and business intelligence data for {selectedTpaName || selectedTpa}
            </Text>
          </div>
          <Space>
            <Select
              value={selectedTable}
              onChange={setSelectedTable}
              style={{ width: 250 }}
            >
              {analyticsTableOptions.map(option => (
                <Option key={option.value} value={option.value}>
                  <Space>
                    {option.icon}
                    {option.label}
                  </Space>
                </Option>
              ))}
            </Select>
            <Button
              icon={<ReloadOutlined />}
              onClick={() => {
                loadTableData()
                loadStats()
              }}
              loading={loading}
            >
              Refresh
            </Button>
          </Space>
        </div>

        {stats && (
          <Row gutter={16} style={{ marginBottom: 24 }}>
            <Col span={6}>
              <Card>
                <Statistic
                  title="Total Records"
                  value={stats.total_records || 0}
                  prefix={<BarChartOutlined />}
                />
              </Card>
            </Col>
            <Col span={6}>
              <Card>
                <Statistic
                  title="Last Updated"
                  value={stats.last_updated ? new Date(stats.last_updated).toLocaleDateString() : 'N/A'}
                />
              </Card>
            </Col>
            <Col span={6}>
              <Card>
                <Statistic
                  title="Data Quality"
                  value={stats.quality_score || 0}
                  suffix="%"
                  valueStyle={{ color: (stats.quality_score || 0) >= 95 ? '#3f8600' : '#cf1322' }}
                />
              </Card>
            </Col>
            <Col span={6}>
              <Card>
                <Statistic
                  title="Status"
                  value={stats.status || 'Unknown'}
                  valueStyle={{ color: stats.status === 'Active' ? '#3f8600' : '#999' }}
                />
              </Card>
            </Col>
          </Row>
        )}

        <Table
          columns={getColumnsForTable(selectedTable)}
          dataSource={tableData}
          loading={loading}
          rowKey={(record) => `${record.TPA}_${record.CLAIM_YEAR || record.MEMBER_ID || record.PROVIDER_ID || record.FISCAL_YEAR}_${Math.random()}`}
          pagination={{
            pageSize: 20,
            showSizeChanger: true,
            showTotal: (total) => `Total ${total} records`,
          }}
          scroll={{ x: 1200 }}
        />
      </Card>
    </div>
  )
}

export default GoldAnalytics
