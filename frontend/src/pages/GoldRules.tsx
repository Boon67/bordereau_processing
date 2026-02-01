import React, { useState, useEffect } from 'react'
import {
  Card,
  Table,
  Tabs,
  message,
  Typography,
  Button,
  Tag,
  Space,
  Descriptions,
  Switch,
} from 'antd'
import {
  ReloadOutlined,
  ThunderboltOutlined,
  SafetyOutlined,
  CheckCircleOutlined,
  CloseCircleOutlined,
} from '@ant-design/icons'
import { apiService } from '../services/api'

const { Title, Text } = Typography
const { TabPane } = Tabs

interface GoldRulesProps {
  selectedTpa: string
  setSelectedTpa: (tpa: string) => void
  tpas: Array<{ TPA_CODE: string; TPA_NAME: string }>
  selectedTpaName?: string
}

const GoldRules: React.FC<GoldRulesProps> = ({ selectedTpa, setSelectedTpa, tpas, selectedTpaName }) => {
  const [loading, setLoading] = useState(false)
  const [transformationRules, setTransformationRules] = useState<any[]>([])
  const [qualityRules, setQualityRules] = useState<any[]>([])

  useEffect(() => {
    if (selectedTpa) {
      loadRules()
    }
  }, [selectedTpa])

  const loadRules = async () => {
    setLoading(true)
    try {
      const [transformRules, qualRules] = await Promise.all([
        apiService.getTransformationRules(selectedTpa),
        apiService.getQualityRules(selectedTpa),
      ])
      setTransformationRules(transformRules)
      setQualityRules(qualRules)
    } catch (error: any) {
      message.error('Failed to load rules: ' + (error.response?.data?.detail || error.message))
    } finally {
      setLoading(false)
    }
  }

  const handleToggleRuleStatus = async (ruleId: number, isActive: boolean, ruleType: 'transformation' | 'quality') => {
    try {
      await apiService.updateRuleStatus(ruleId, isActive, ruleType)
      message.success(`Rule ${isActive ? 'activated' : 'deactivated'} successfully`)
      loadRules()
    } catch (error: any) {
      message.error('Failed to update rule status: ' + (error.response?.data?.detail || error.message))
    }
  }

  const getRuleTypeColor = (type: string) => {
    const typeMap: { [key: string]: string } = {
      'AGGREGATION': 'blue',
      'CALCULATION': 'green',
      'TRANSFORMATION': 'purple',
      'VALIDATION': 'orange',
      'ENRICHMENT': 'cyan',
      'VALIDITY': 'red',
      'COMPLETENESS': 'orange',
      'CONSISTENCY': 'blue',
      'TIMELINESS': 'green',
    }
    return typeMap[type] || 'default'
  }

  const transformationColumns = [
    {
      title: 'Rule Name',
      dataIndex: 'RULE_NAME',
      key: 'RULE_NAME',
      width: 250,
      render: (name: string) => <Text strong>{name}</Text>,
    },
    {
      title: 'Type',
      dataIndex: 'RULE_TYPE',
      key: 'RULE_TYPE',
      width: 150,
      render: (type: string) => (
        <Tag color={getRuleTypeColor(type)}>{type}</Tag>
      ),
    },
    {
      title: 'Source Table',
      dataIndex: 'SOURCE_TABLE',
      key: 'SOURCE_TABLE',
      width: 200,
      ellipsis: true,
    },
    {
      title: 'Target Table',
      dataIndex: 'TARGET_TABLE',
      key: 'TARGET_TABLE',
      width: 200,
      ellipsis: true,
    },
    {
      title: 'Priority',
      dataIndex: 'PRIORITY',
      key: 'PRIORITY',
      width: 100,
      sorter: (a: any, b: any) => a.PRIORITY - b.PRIORITY,
    },
    {
      title: 'Execution Order',
      dataIndex: 'EXECUTION_ORDER',
      key: 'EXECUTION_ORDER',
      width: 140,
      sorter: (a: any, b: any) => a.EXECUTION_ORDER - b.EXECUTION_ORDER,
    },
    {
      title: 'Status',
      dataIndex: 'IS_ACTIVE',
      key: 'IS_ACTIVE',
      width: 100,
      render: (active: boolean, record: any) => (
        <Switch
          checked={active}
          checkedChildren={<CheckCircleOutlined />}
          unCheckedChildren={<CloseCircleOutlined />}
          onChange={(checked) => handleToggleRuleStatus(record.RULE_ID, checked, 'transformation')}
        />
      ),
    },
  ]

  const qualityColumns = [
    {
      title: 'Rule Name',
      dataIndex: 'RULE_NAME',
      key: 'RULE_NAME',
      width: 250,
      render: (name: string) => <Text strong>{name}</Text>,
    },
    {
      title: 'Type',
      dataIndex: 'RULE_TYPE',
      key: 'RULE_TYPE',
      width: 150,
      render: (type: string) => (
        <Tag color={getRuleTypeColor(type)}>{type}</Tag>
      ),
    },
    {
      title: 'Table',
      dataIndex: 'TABLE_NAME',
      key: 'TABLE_NAME',
      width: 200,
    },
    {
      title: 'Field',
      dataIndex: 'FIELD_NAME',
      key: 'FIELD_NAME',
      width: 150,
      render: (field: string) => field || <Text type="secondary">All fields</Text>,
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
      title: 'Action on Failure',
      dataIndex: 'ACTION_ON_FAILURE',
      key: 'ACTION_ON_FAILURE',
      width: 150,
      render: (action: string) => <Tag>{action}</Tag>,
    },
    {
      title: 'Status',
      dataIndex: 'IS_ACTIVE',
      key: 'IS_ACTIVE',
      width: 100,
      render: (active: boolean, record: any) => (
        <Switch
          checked={active}
          checkedChildren={<CheckCircleOutlined />}
          unCheckedChildren={<CloseCircleOutlined />}
          onChange={(checked) => handleToggleRuleStatus(record.QUALITY_RULE_ID, checked, 'quality')}
        />
      ),
    },
  ]

  const transformationExpandedRow = (record: any) => {
    return (
      <Descriptions column={1} bordered size="small">
        <Descriptions.Item label="Rule Logic">
          <Text code style={{ whiteSpace: 'pre-wrap' }}>{record.RULE_LOGIC}</Text>
        </Descriptions.Item>
        <Descriptions.Item label="Description">
          {record.RULE_DESCRIPTION || 'N/A'}
        </Descriptions.Item>
        <Descriptions.Item label="Business Justification">
          {record.BUSINESS_JUSTIFICATION || 'N/A'}
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

  const qualityExpandedRow = (record: any) => {
    return (
      <Descriptions column={1} bordered size="small">
        <Descriptions.Item label="Check Logic">
          <Text code style={{ whiteSpace: 'pre-wrap' }}>{record.CHECK_LOGIC}</Text>
        </Descriptions.Item>
        <Descriptions.Item label="Threshold">
          {record.THRESHOLD_VALUE} {record.THRESHOLD_OPERATOR}
        </Descriptions.Item>
        <Descriptions.Item label="Description">
          {record.RULE_DESCRIPTION || 'N/A'}
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

  const activeTransformRules = transformationRules.filter(r => r.IS_ACTIVE).length
  const activeQualityRules = qualityRules.filter(r => r.IS_ACTIVE).length

  return (
    <div>
      <Title level={2}>⚡ Transformation Rules</Title>
      
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
              📋 Transformation & Quality Rules
            </Title>
            <Text type="secondary">
              Manage rules and quality checks for {selectedTpaName || selectedTpa}
            </Text>
          </div>
          <Button
            icon={<ReloadOutlined />}
            onClick={loadRules}
            loading={loading}
          >
            Refresh
          </Button>
        </div>

        <Tabs defaultActiveKey="transformation">
          <TabPane
            tab={
              <span>
                <ThunderboltOutlined />
                Transformation Rules ({transformationRules.length})
              </span>
            }
            key="transformation"
          >
            <Space direction="vertical" size="middle" style={{ width: '100%', marginBottom: 16 }}>
              <Descriptions column={3} bordered size="small">
                <Descriptions.Item label="Total Rules">
                  <Tag color="blue">{transformationRules.length}</Tag>
                </Descriptions.Item>
                <Descriptions.Item label="Active Rules">
                  <Tag color="green">{activeTransformRules}</Tag>
                </Descriptions.Item>
                <Descriptions.Item label="Inactive Rules">
                  <Tag color="red">{transformationRules.length - activeTransformRules}</Tag>
                </Descriptions.Item>
              </Descriptions>
            </Space>

            <Table
              columns={transformationColumns}
              dataSource={transformationRules}
              loading={loading}
              rowKey="RULE_ID"
              expandable={{
                expandedRowRender: transformationExpandedRow,
                expandRowByClick: true,
              }}
              pagination={{
                pageSize: 10,
                showSizeChanger: true,
                showTotal: (total) => `Total ${total} rules`,
              }}
            />
          </TabPane>

          <TabPane
            tab={
              <span>
                <SafetyOutlined />
                Quality Rules ({qualityRules.length})
              </span>
            }
            key="quality"
          >
            <Space direction="vertical" size="middle" style={{ width: '100%', marginBottom: 16 }}>
              <Descriptions column={3} bordered size="small">
                <Descriptions.Item label="Total Rules">
                  <Tag color="blue">{qualityRules.length}</Tag>
                </Descriptions.Item>
                <Descriptions.Item label="Active Rules">
                  <Tag color="green">{activeQualityRules}</Tag>
                </Descriptions.Item>
                <Descriptions.Item label="Inactive Rules">
                  <Tag color="red">{qualityRules.length - activeQualityRules}</Tag>
                </Descriptions.Item>
              </Descriptions>
            </Space>

            <Table
              columns={qualityColumns}
              dataSource={qualityRules}
              loading={loading}
              rowKey="QUALITY_RULE_ID"
              expandable={{
                expandedRowRender: qualityExpandedRow,
                expandRowByClick: true,
              }}
              pagination={{
                pageSize: 10,
                showSizeChanger: true,
                showTotal: (total) => `Total ${total} rules`,
              }}
            />
          </TabPane>
        </Tabs>
      </Card>
    </div>
  )
}

export default GoldRules
