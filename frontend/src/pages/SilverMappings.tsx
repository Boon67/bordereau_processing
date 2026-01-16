import React, { useState, useEffect } from 'react'
import { Card, Typography, Table, Button, Select, Space, message, Tag, Progress, Modal, Form, Input, Popconfirm, Drawer, Alert, Slider, InputNumber } from 'antd'
import { ReloadOutlined, ApiOutlined, CheckCircleOutlined, CloseCircleOutlined, RobotOutlined, ThunderboltOutlined, PlusOutlined } from '@ant-design/icons'
import { apiService } from '../services/api'
import type { FieldMapping } from '../services/api'

const { Title } = Typography
const { TextArea } = Input

interface SilverMappingsProps {
  selectedTpa: string
}

const SilverMappings: React.FC<SilverMappingsProps> = ({ selectedTpa }) => {
  const [loading, setLoading] = useState(false)
  const [mappings, setMappings] = useState<FieldMapping[]>([])
  const [selectedTable, setSelectedTable] = useState<string>('')
  const [tables, setTables] = useState<string[]>([])
  const [isAutoMLDrawerVisible, setIsAutoMLDrawerVisible] = useState(false)
  const [isAutoLLMDrawerVisible, setIsAutoLLMDrawerVisible] = useState(false)
  const [isManualModalVisible, setIsManualModalVisible] = useState(false)
  const [autoMLForm] = Form.useForm()
  const [autoLLMForm] = Form.useForm()
  const [manualForm] = Form.useForm()

  useEffect(() => {
    if (selectedTpa) {
      loadMappings()
    }
  }, [selectedTpa])

  const loadMappings = async () => {
    if (!selectedTpa) {
      message.warning('Please select a TPA')
      return
    }

    setLoading(true)
    try {
      const data = await apiService.getFieldMappings(selectedTpa, selectedTable || undefined)
      setMappings(data)
      
      // Extract unique target tables
      const uniqueTables = Array.from(new Set(data.map(m => m.TARGET_TABLE)))
      setTables(uniqueTables)
      
      message.success(`Loaded ${data.length} field mappings`)
    } catch (error) {
      message.error('Failed to load field mappings')
    } finally {
      setLoading(false)
    }
  }

  const handleApproveMapping = async (mappingId: number) => {
    try {
      await apiService.approveMapping(mappingId)
      message.success('Mapping approved')
      loadMappings()
    } catch (error: any) {
      message.error(`Failed to approve mapping: ${error.response?.data?.detail || error.message}`)
    }
  }

  const handleAutoMapML = async (values: any) => {
    setLoading(true)
    try {
      const result = await apiService.autoMapFieldsML(
        values.source_table,
        values.target_table,
        selectedTpa,
        values.top_n,
        values.min_confidence / 100
      )
      message.success(`Created ${result.mappings_created || 0} ML-based mappings`)
      setIsAutoMLDrawerVisible(false)
      loadMappings()
    } catch (error: any) {
      message.error(`Auto-mapping failed: ${error.response?.data?.detail || error.message}`)
    } finally {
      setLoading(false)
    }
  }

  const handleAutoMapLLM = async (values: any) => {
    setLoading(true)
    try {
      const result = await apiService.autoMapFieldsLLM(
        values.source_table,
        values.target_table,
        selectedTpa,
        values.model_name
      )
      message.success(`Created ${result.mappings_created || 0} LLM-based mappings`)
      setIsAutoLLMDrawerVisible(false)
      loadMappings()
    } catch (error: any) {
      message.error(`Auto-mapping failed: ${error.response?.data?.detail || error.message}`)
    } finally {
      setLoading(false)
    }
  }

  const handleManualMapping = async (values: any) => {
    try {
      await apiService.createFieldMapping({
        SOURCE_TABLE: values.source_table,
        SOURCE_FIELD: values.source_field,
        TARGET_TABLE: values.target_table,
        TARGET_COLUMN: values.target_column,
        TPA: selectedTpa,
        MAPPING_METHOD: 'MANUAL',
        TRANSFORMATION_LOGIC: values.transformation_logic,
        APPROVED: values.approved ?? false,
      })
      message.success('Manual mapping created')
      setIsManualModalVisible(false)
      loadMappings()
    } catch (error: any) {
      message.error(`Failed to create mapping: ${error.response?.data?.detail || error.message}`)
    }
  }

  const getMappingMethodTag = (method: string) => {
    const methodConfig: Record<string, { color: string; label: string }> = {
      MANUAL: { color: 'blue', label: 'Manual' },
      ML_AUTO: { color: 'green', label: 'ML Auto' },
      LLM_CORTEX: { color: 'purple', label: 'LLM' },
      SYSTEM: { color: 'default', label: 'System' },
    }
    const config = methodConfig[method] || { color: 'default', label: method }
    return <Tag color={config.color}>{config.label}</Tag>
  }

  const columns = [
    {
      title: 'Source Field',
      dataIndex: 'SOURCE_FIELD',
      key: 'SOURCE_FIELD',
      width: 200,
      render: (field: string, record: FieldMapping) => (
        <div>
          <div><strong>{field}</strong></div>
          <div style={{ fontSize: '11px', color: '#999' }}>from {record.SOURCE_TABLE}</div>
        </div>
      ),
    },
    {
      title: '→',
      key: 'arrow',
      width: 40,
      align: 'center' as const,
      render: () => <span style={{ fontSize: '18px', color: '#1890ff' }}>→</span>,
    },
    {
      title: 'Target Column',
      dataIndex: 'TARGET_COLUMN',
      key: 'TARGET_COLUMN',
      width: 200,
      render: (column: string, record: FieldMapping) => (
        <div>
          <div><strong>{column}</strong></div>
          <div style={{ fontSize: '11px', color: '#999' }}>in {record.TARGET_TABLE}</div>
        </div>
      ),
    },
    {
      title: 'Method',
      dataIndex: 'MAPPING_METHOD',
      key: 'MAPPING_METHOD',
      width: 120,
      render: (method: string) => getMappingMethodTag(method),
    },
    {
      title: 'Confidence',
      dataIndex: 'CONFIDENCE_SCORE',
      key: 'CONFIDENCE_SCORE',
      width: 150,
      render: (score: number | null) => {
        if (score === null || score === undefined) return '-'
        const percentage = Math.round(score * 100)
        return (
          <div style={{ width: 100 }}>
            <Progress 
              percent={percentage} 
              size="small"
              status={percentage >= 80 ? 'success' : percentage >= 60 ? 'normal' : 'exception'}
            />
          </div>
        )
      },
    },
    {
      title: 'Status',
      dataIndex: 'APPROVED',
      key: 'APPROVED',
      width: 120,
      render: (approved: boolean, record: FieldMapping) => (
        approved ? (
          <Tag color="success" icon={<CheckCircleOutlined />}>Approved</Tag>
        ) : (
          <Popconfirm
            title="Approve this mapping?"
            onConfirm={() => handleApproveMapping(record.MAPPING_ID)}
            okText="Yes"
            cancelText="No"
          >
            <Tag color="warning" icon={<CloseCircleOutlined />} style={{ cursor: 'pointer' }}>
              Pending
            </Tag>
          </Popconfirm>
        )
      ),
    },
    {
      title: 'Transformation',
      dataIndex: 'TRANSFORMATION_LOGIC',
      key: 'TRANSFORMATION_LOGIC',
      ellipsis: true,
      render: (logic: string) => {
        if (!logic) return '-'
        return (
          <code style={{ fontSize: '11px', background: '#f5f5f5', padding: '2px 6px', borderRadius: 3 }}>
            {logic}
          </code>
        )
      },
    },
  ]

  // Group mappings by target table
  const mappingsByTable = mappings.reduce((acc, mapping) => {
    if (!acc[mapping.TARGET_TABLE]) {
      acc[mapping.TARGET_TABLE] = []
    }
    acc[mapping.TARGET_TABLE].push(mapping)
    return acc
  }, {} as Record<string, FieldMapping[]>)

  if (!selectedTpa) {
    return (
      <div>
        <Title level={2}>🔗 Field Mappings</Title>
        <Card style={{ marginTop: 16 }}>
          <p style={{ textAlign: 'center', padding: '40px', color: '#999' }}>
            Please select a TPA from the dropdown in the header to view field mappings.
          </p>
        </Card>
      </div>
    )
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <Title level={2}>🔗 Field Mappings</Title>
        <Space>
          <Button 
            icon={<RobotOutlined />} 
            onClick={() => setIsAutoMLDrawerVisible(true)}
            type="primary"
          >
            Auto-Map (ML)
          </Button>
          <Button 
            icon={<ThunderboltOutlined />} 
            onClick={() => setIsAutoLLMDrawerVisible(true)}
          >
            Auto-Map (LLM)
          </Button>
          <Button 
            icon={<PlusOutlined />} 
            onClick={() => {
              manualForm.resetFields()
              setIsManualModalVisible(true)
            }}
          >
            Manual Mapping
          </Button>
          <Button 
            icon={<ReloadOutlined />} 
            onClick={loadMappings}
            loading={loading}
          >
            Refresh
          </Button>
        </Space>
      </div>

      <p style={{ marginBottom: 24, color: '#666' }}>
        View field mappings from Bronze (raw data) to Silver (target tables). TPA: <strong>{selectedTpa}</strong>
      </p>

      <Card style={{ marginBottom: 16 }}>
        <Space direction="vertical" style={{ width: '100%' }}>
          <div>
            <label style={{ display: 'block', marginBottom: 8, fontWeight: 'bold' }}>
              Filter by Target Table (optional)
            </label>
            <Select
              value={selectedTable}
              onChange={(value) => {
                setSelectedTable(value)
                if (value) {
                  const filtered = mappings.filter(m => m.TARGET_TABLE === value)
                  setMappings(filtered)
                } else {
                  loadMappings()
                }
              }}
              style={{ width: '100%' }}
              placeholder="All tables"
              allowClear
              options={tables.map(table => ({
                label: table,
                value: table,
              }))}
            />
          </div>
        </Space>
      </Card>

      {Object.keys(mappingsByTable).length === 0 ? (
        <Card>
          <p style={{ textAlign: 'center', padding: '40px', color: '#999' }}>
            No field mappings found for this TPA. Mappings need to be created before transformation.
          </p>
        </Card>
      ) : (
        Object.entries(mappingsByTable).map(([tableName, tableMappings]) => {
          const approvedCount = tableMappings.filter(m => m.APPROVED).length
          const totalCount = tableMappings.length
          const approvalRate = Math.round((approvedCount / totalCount) * 100)

          return (
            <Card 
              key={tableName}
              style={{ marginBottom: 16 }}
              title={
                <Space>
                  <ApiOutlined />
                  <span>{tableName}</span>
                  <Tag color="blue">{totalCount} mappings</Tag>
                  <Tag color={approvalRate === 100 ? 'success' : 'warning'}>
                    {approvedCount}/{totalCount} approved
                  </Tag>
                </Space>
              }
            >
              <Table
                columns={columns}
                dataSource={tableMappings}
                rowKey="MAPPING_ID"
                loading={loading}
                pagination={false}
                size="small"
              />
            </Card>
          )
        })
      )}

      <Card title="ℹ️ Mapping Information" style={{ marginTop: 16 }}>
        <Space direction="vertical" size="small">
          <div><strong>Total Mappings:</strong> {mappings.length}</div>
          <div><strong>Approved:</strong> {mappings.filter(m => m.APPROVED).length}</div>
          <div><strong>Pending:</strong> {mappings.filter(m => !m.APPROVED).length}</div>
          <div><strong>Target Tables:</strong> {tables.length}</div>
        </Space>
        <div style={{ marginTop: 16, color: '#666' }}>
          <p><strong>Mapping Methods:</strong></p>
          <ul>
            <li><strong>Manual:</strong> Manually created mappings</li>
            <li><strong>ML Auto:</strong> Machine learning-based automatic mappings</li>
            <li><strong>LLM:</strong> Large language model (Cortex) generated mappings</li>
            <li><strong>System:</strong> System-generated default mappings</li>
          </ul>
        </div>
      </Card>

      {/* Auto-Map ML Drawer */}
      <Drawer
        title="Auto-Map Fields (ML)"
        placement="right"
        onClose={() => setIsAutoMLDrawerVisible(false)}
        open={isAutoMLDrawerVisible}
        width={500}
      >
        <Alert
          message="Machine Learning Auto-Mapping"
          description="Uses ML algorithms to automatically suggest field mappings based on column names and data patterns."
          type="info"
          showIcon
          style={{ marginBottom: 16 }}
        />

        <Form
          form={autoMLForm}
          layout="vertical"
          onFinish={handleAutoMapML}
          initialValues={{ top_n: 3, min_confidence: 60 }}
        >
          <Form.Item
            name="source_table"
            label="Source Table"
            rules={[{ required: true, message: 'Please enter source table' }]}
          >
            <Input placeholder="RAW_DATA_TABLE" />
          </Form.Item>

          <Form.Item
            name="target_table"
            label="Target Table"
            rules={[{ required: true, message: 'Please select target table' }]}
          >
            <Select
              placeholder="Select target table"
              options={tables.map(t => ({ label: t, value: t }))}
              showSearch
            />
          </Form.Item>

          <Form.Item
            name="top_n"
            label="Top N Suggestions"
            tooltip="Number of top mapping suggestions to consider per field"
          >
            <InputNumber min={1} max={10} style={{ width: '100%' }} />
          </Form.Item>

          <Form.Item
            name="min_confidence"
            label="Minimum Confidence (%)"
            tooltip="Only create mappings with confidence above this threshold"
          >
            <Slider min={0} max={100} marks={{ 0: '0%', 50: '50%', 100: '100%' }} />
          </Form.Item>

          <Form.Item>
            <Space>
              <Button type="primary" htmlType="submit" icon={<RobotOutlined />} loading={loading}>
                Generate Mappings
              </Button>
              <Button onClick={() => setIsAutoMLDrawerVisible(false)}>
                Cancel
              </Button>
            </Space>
          </Form.Item>
        </Form>
      </Drawer>

      {/* Auto-Map LLM Drawer */}
      <Drawer
        title="Auto-Map Fields (LLM)"
        placement="right"
        onClose={() => setIsAutoLLMDrawerVisible(false)}
        open={isAutoLLMDrawerVisible}
        width={500}
      >
        <Alert
          message="LLM-Powered Auto-Mapping"
          description="Uses Snowflake Cortex LLM to intelligently map fields based on semantic understanding of column names and descriptions."
          type="info"
          showIcon
          style={{ marginBottom: 16 }}
        />

        <Form
          form={autoLLMForm}
          layout="vertical"
          onFinish={handleAutoMapLLM}
          initialValues={{ model_name: 'llama3.1-70b' }}
        >
          <Form.Item
            name="source_table"
            label="Source Table"
            rules={[{ required: true, message: 'Please enter source table' }]}
          >
            <Input placeholder="RAW_DATA_TABLE" />
          </Form.Item>

          <Form.Item
            name="target_table"
            label="Target Table"
            rules={[{ required: true, message: 'Please select target table' }]}
          >
            <Select
              placeholder="Select target table"
              options={tables.map(t => ({ label: t, value: t }))}
              showSearch
            />
          </Form.Item>

          <Form.Item
            name="model_name"
            label="LLM Model"
          >
            <Select
              options={[
                { label: 'Llama 3.1 70B (Recommended)', value: 'llama3.1-70b' },
                { label: 'Llama 3.1 8B', value: 'llama3.1-8b' },
                { label: 'Mistral Large', value: 'mistral-large' },
                { label: 'Mixtral 8x7B', value: 'mixtral-8x7b' },
              ]}
            />
          </Form.Item>

          <Form.Item>
            <Space>
              <Button type="primary" htmlType="submit" icon={<ThunderboltOutlined />} loading={loading}>
                Generate Mappings
              </Button>
              <Button onClick={() => setIsAutoLLMDrawerVisible(false)}>
                Cancel
              </Button>
            </Space>
          </Form.Item>
        </Form>
      </Drawer>

      {/* Manual Mapping Modal */}
      <Modal
        title="Create Manual Mapping"
        open={isManualModalVisible}
        onCancel={() => setIsManualModalVisible(false)}
        footer={null}
        width={600}
      >
        <Form
          form={manualForm}
          layout="vertical"
          onFinish={handleManualMapping}
          initialValues={{ source_table: 'RAW_DATA_TABLE' }}
        >
          <Form.Item
            name="source_table"
            label="Source Table"
            rules={[{ required: true, message: 'Please enter source table' }]}
          >
            <Input placeholder="RAW_DATA_TABLE" />
          </Form.Item>

          <Form.Item
            name="source_field"
            label="Source Field"
            rules={[{ required: true, message: 'Please enter source field name' }]}
          >
            <Input placeholder="e.g., customer_id" />
          </Form.Item>

          <Form.Item
            name="target_table"
            label="Target Table"
            rules={[{ required: true, message: 'Please select target table' }]}
          >
            <Select
              placeholder="Select target table"
              options={tables.map(t => ({ label: t, value: t }))}
              showSearch
            />
          </Form.Item>

          <Form.Item
            name="target_column"
            label="Target Column"
            rules={[{ required: true, message: 'Please enter target column name' }]}
          >
            <Input placeholder="e.g., CUSTOMER_ID" />
          </Form.Item>

          <Form.Item
            name="transformation_logic"
            label="Transformation Logic (Optional)"
            tooltip="SQL expression to transform the source field"
          >
            <TextArea rows={3} placeholder="e.g., UPPER(source_field)" />
          </Form.Item>

          <Form.Item>
            <Space>
              <Button type="primary" htmlType="submit">
                Create Mapping
              </Button>
              <Button onClick={() => setIsManualModalVisible(false)}>
                Cancel
              </Button>
            </Space>
          </Form.Item>
        </Form>
      </Modal>
    </div>
  )
}

export default SilverMappings
