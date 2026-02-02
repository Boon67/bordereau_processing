import React, { useState, useEffect } from 'react'
import { Card, Typography, Table, Button, Select, Space, message, Tag, Progress, Modal, Form, Input, Popconfirm, Drawer, Alert, Slider, InputNumber, Collapse } from 'antd'
import { ReloadOutlined, ApiOutlined, CheckCircleOutlined, CloseCircleOutlined, RobotOutlined, ThunderboltOutlined, PlusOutlined } from '@ant-design/icons'
import { apiService } from '../services/api'
import type { FieldMapping } from '../services/api'
import type { TPA } from '../types'

const { Title } = Typography
const { TextArea } = Input
const { Panel } = Collapse

interface SilverMappingsProps {
  selectedTpa: string
  setSelectedTpa: (tpa: string) => void
  tpas: TPA[]
  selectedTpaName?: string
}

const SilverMappings: React.FC<SilverMappingsProps> = ({ selectedTpa, setSelectedTpa, tpas, selectedTpaName }) => {
  const [loading, setLoading] = useState(false)
  const [mappings, setMappings] = useState<FieldMapping[]>([])
  const [tables, setTables] = useState<string[]>([])
  const [availableTargetTables, setAvailableTargetTables] = useState<any[]>([])
  const [selectedTable, setSelectedTable] = useState<string>('')
  const [isAutoMLDrawerVisible, setIsAutoMLDrawerVisible] = useState(false)
  const [isAutoLLMDrawerVisible, setIsAutoLLMDrawerVisible] = useState(false)
  const [isManualModalVisible, setIsManualModalVisible] = useState(false)
  const [autoMLForm] = Form.useForm()
  const [autoLLMForm] = Form.useForm()
  const [manualForm] = Form.useForm()
  const [sourceFields, setSourceFields] = useState<string[]>([])
  const [targetColumns, setTargetColumns] = useState<string[]>([])
  const [loadingSourceFields, setLoadingSourceFields] = useState(false)
  const [loadingTargetColumns, setLoadingTargetColumns] = useState(false)
  const [cortexModels, setCortexModels] = useState<string[]>([])
  const [loadingCortexModels, setLoadingCortexModels] = useState(false)
  const [selectedRowKeys, setSelectedRowKeys] = useState<React.Key[]>([])
  const [bulkActionLoading, setBulkActionLoading] = useState(false)

  useEffect(() => {
    // Load all created tables on mount or when selectedTpa changes
    loadTargetTables()
  }, [selectedTpa])

  useEffect(() => {
    // Load mappings when table changes
    if (selectedTable) {
      setSelectedRowKeys([]) // Clear selection when table changes
      loadMappings()
    }
  }, [selectedTable])

  useEffect(() => {
    // Set default values when selectedTable changes
    autoMLForm.setFieldsValue({
      source_table: 'RAW_DATA_TABLE',
      target_table: selectedTable
    })
    
    autoLLMForm.setFieldsValue({
      source_table: 'RAW_DATA_TABLE',
      target_table: selectedTable
    })
    
    manualForm.setFieldsValue({
      source_table: 'RAW_DATA_TABLE',
      target_table: selectedTable
    })
  }, [selectedTable])

  useEffect(() => {
    // Set default model when cortex models are loaded
    if (cortexModels.length > 0) {
      autoLLMForm.setFieldsValue({
        model_name: cortexModels[0] // Use first model as default
      })
    }
  }, [cortexModels])

  const loadTargetTables = async () => {
    if (!selectedTpa) {
      setAvailableTargetTables([])
      setSelectedTable('')
      return
    }

    try {
      // Load all created tables
      const allCreatedTables = await apiService.getSilverTables()
      
      // Filter tables for the selected TPA
      const tpaTables = allCreatedTables.filter(
        (table: any) => table.TPA.toLowerCase() === selectedTpa.toLowerCase()
      )
      
      // Load all schema definitions
      const schemas = await apiService.getTargetSchemas()
      
      // Map each created table with its column count from schemas
      const tablesWithColumns = tpaTables.map((table: any) => {
        const tableSchemas = schemas.filter(
          (s: any) => s.TABLE_NAME === table.SCHEMA_TABLE
        )
        const tpaInfo = tpas.find(t => t.TPA_CODE === table.TPA)
        return {
          name: table.SCHEMA_TABLE,
          physicalName: table.TABLE_NAME,
          tpa: table.TPA,
          tpaName: tpaInfo?.TPA_NAME || table.TPA,
          columns: tableSchemas.length,
        }
      })
      
      setAvailableTargetTables(tablesWithColumns)
      
      // Auto-select the first table if available and only one table exists for the TPA
      // Or if the currently selected table is not valid for the new TPA
      if (tablesWithColumns.length > 0) {
        const currentTableIsValid = tablesWithColumns.some(t => t.physicalName === selectedTable)

        if (tablesWithColumns.length === 1 && tablesWithColumns[0].physicalName !== selectedTable) {
          setSelectedTable(tablesWithColumns[0].physicalName)
        } else if (!currentTableIsValid) {
          setSelectedTable(tablesWithColumns[0].physicalName) // Select first valid table
        }
      } else {
        setSelectedTable('') // Clear selection if no tables for TPA
      }
    } catch (error) {
      console.error('Failed to load target tables:', error)
    }
  }

  const loadMappings = async () => {
    if (!selectedTable || !selectedTpa) {
      return
    }

    setLoading(true)
    try {
      // Get the schema table name (without TPA prefix)
      // Mappings are stored with the schema table name (e.g., "PHARMACY_CLAIMS")
      // not the physical table name (e.g., "PROVIDER_A_PHARMACY_CLAIMS")
      const tableInfo = availableTargetTables.find(t => t.physicalName === selectedTable)
      const schemaTableName = tableInfo?.name || selectedTable
      
      const data = await apiService.getFieldMappings(selectedTpa, schemaTableName)
      setMappings(data)
      
      // Extract unique target tables from mappings
      const uniqueTables = Array.from(new Set(data.map(m => m.TARGET_TABLE)))
      setTables(uniqueTables)
      
      if (data.length > 0) {
        message.success(`Loaded ${data.length} field mappings`)
      }
    } catch (error) {
      message.error('Failed to load field mappings')
    } finally {
      setLoading(false)
    }
  }

  const loadSourceFields = async () => {
    if (!selectedTable) return
    
    // Extract TPA from selected table name (e.g., "PROVIDER_A_DENTAL_CLAIMS" -> "provider_a")
    const tableParts = selectedTable.split('_')
    const tpa = (tableParts[0] + '_' + tableParts[1]).toLowerCase()
    
    setLoadingSourceFields(true)
    try {
      const fields = await apiService.getSourceFields(tpa)
      setSourceFields(fields)
    } catch (error) {
      console.error('Failed to load source fields:', error)
      message.error('Failed to load source fields')
    } finally {
      setLoadingSourceFields(false)
    }
  }

  const loadTargetColumns = async (tableName: string) => {
    if (!tableName) return
    
    setLoadingTargetColumns(true)
    try {
      const columns = await apiService.getTargetColumns(tableName)
      setTargetColumns(columns)
    } catch (error) {
      console.error('Failed to load target columns:', error)
      message.error('Failed to load target columns')
    } finally {
      setLoadingTargetColumns(false)
    }
  }

  const loadCortexModels = async () => {
    setLoadingCortexModels(true)
    try {
      const models = await apiService.getCortexModels()
      setCortexModels(models)
    } catch (error) {
      console.error('Failed to load Cortex models:', error)
      message.error('Failed to load Cortex models')
      // Set default models on error
      setCortexModels(['llama3.1-70b', 'llama3.1-8b', 'mistral-large', 'mixtral-8x7b', 'gemma-7b'])
    } finally {
      setLoadingCortexModels(false)
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

  const handleDeclineMapping = async (mappingId: number) => {
    try {
      await apiService.declineMapping(mappingId)
      message.success('Mapping declined and deleted')
      loadMappings()
    } catch (error: any) {
      message.error(`Failed to decline mapping: ${error.response?.data?.detail || error.message}`)
    }
  }

  const handleAutoMapML = async (values: any) => {
    setLoading(true)
    try {
      // Get the schema table name (without TPA prefix) for the procedure
      const tableInfo = availableTargetTables.find(t => t.physicalName === selectedTable)
      const schemaTableName = tableInfo?.name || selectedTable
      
      const result = await apiService.autoMapFieldsML(
        values.source_table,
        schemaTableName,  // Use schema table name, not physical name
        selectedTpa,
        values.top_n,
        values.min_confidence / 100
      )
      
      // Check if mapping was successful
      if (result.mappings_created > 0) {
        message.success(`Created ${result.mappings_created} ML-based mappings`)
        setIsAutoMLDrawerVisible(false)
        loadMappings()
      } else {
        // Show the actual error/info message from the procedure
        const errorMsg = result.message || result.result || 'No mappings created'
        message.warning(errorMsg, 10) // Show for 10 seconds
      }
    } catch (error: any) {
      const errorDetail = error.response?.data?.detail || error.message
      message.error(`Auto-mapping failed: ${errorDetail}`, 10)
    } finally {
      setLoading(false)
    }
  }

  const handleAutoMapLLM = async (values: any) => {
    setLoading(true)
    try {
      // Get the schema table name (without TPA prefix) for the procedure
      const tableInfo = availableTargetTables.find(t => t.physicalName === selectedTable)
      const schemaTableName = tableInfo?.name || selectedTable
      
      const result = await apiService.autoMapFieldsLLM(
        values.source_table,
        schemaTableName,  // Use schema table name, not physical name
        selectedTpa,
        values.model_name
      )
      
      // Check if mapping was successful
      if (result.mappings_created > 0) {
        message.success(`Created ${result.mappings_created} LLM-based mappings`)
        setIsAutoLLMDrawerVisible(false)
        loadMappings()
      } else {
        // Show the actual error/info message from the procedure
        const errorMsg = result.message || result.result || 'No mappings created'
        message.warning(errorMsg, 10) // Show for 10 seconds
      }
    } catch (error: any) {
      const errorDetail = error.response?.data?.detail || error.message
      message.error(`Auto-mapping failed: ${errorDetail}`, 10)
    } finally {
      setLoading(false)
    }
  }

  const handleManualMapping = async (values: any) => {
    try {
      // Get the schema table name (without TPA prefix)
      const tableInfo = availableTargetTables.find(t => t.physicalName === selectedTable)
      const schemaTableName = tableInfo?.name || selectedTable
      
      await apiService.createFieldMapping({
        SOURCE_TABLE: values.source_table,
        SOURCE_FIELD: values.source_field,
        TARGET_TABLE: schemaTableName,  // Use schema table name, not physical name
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

  const handleBulkApprove = async () => {
    if (selectedRowKeys.length === 0) {
      message.warning('Please select at least one mapping to approve')
      return
    }

    setBulkActionLoading(true)
    try {
      // Approve all selected mappings in parallel
      await Promise.all(
        selectedRowKeys.map(mappingId => 
          apiService.approveMapping(mappingId as string)
        )
      )
      message.success(`Approved ${selectedRowKeys.length} mapping(s)`)
      setSelectedRowKeys([])
      loadMappings()
    } catch (error: any) {
      message.error(`Bulk approve failed: ${error.response?.data?.detail || error.message}`)
    } finally {
      setBulkActionLoading(false)
    }
  }

  const handleBulkDelete = async () => {
    if (selectedRowKeys.length === 0) {
      message.warning('Please select at least one mapping to delete')
      return
    }

    setBulkActionLoading(true)
    try {
      // Delete all selected mappings in parallel
      await Promise.all(
        selectedRowKeys.map(mappingId => 
          apiService.deleteMapping(mappingId as string)
        )
      )
      message.success(`Deleted ${selectedRowKeys.length} mapping(s)`)
      setSelectedRowKeys([])
      loadMappings()
    } catch (error: any) {
      message.error(`Bulk delete failed: ${error.response?.data?.detail || error.message}`)
    } finally {
      setBulkActionLoading(false)
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
      width: 150,
      render: (approved: boolean, record: FieldMapping) => (
        <Space size="small">
          {approved ? (
            <>
              <Tag color="success" icon={<CheckCircleOutlined />}>Approved</Tag>
              <Popconfirm
                title="Delete this approved mapping?"
                description="This action cannot be undone."
                onConfirm={() => handleDeclineMapping(record.MAPPING_ID)}
                okText="Yes"
                cancelText="No"
                okButtonProps={{ danger: true }}
              >
                <Button 
                  danger 
                  size="small" 
                  icon={<CloseCircleOutlined />}
                  title="Delete"
                />
              </Popconfirm>
            </>
          ) : (
            <>
              <Popconfirm
                title="Approve this mapping?"
                onConfirm={() => handleApproveMapping(record.MAPPING_ID)}
                okText="Yes"
                cancelText="No"
              >
                <Button 
                  type="primary" 
                  size="small" 
                  icon={<CheckCircleOutlined />}
                  title="Approve"
                />
              </Popconfirm>
              <Popconfirm
                title="Decline and delete this mapping?"
                description="This action cannot be undone."
                onConfirm={() => handleDeclineMapping(record.MAPPING_ID)}
                okText="Yes"
                cancelText="No"
                okButtonProps={{ danger: true }}
              >
                <Button 
                  danger 
                  size="small" 
                  icon={<CloseCircleOutlined />}
                  title="Decline"
                />
              </Popconfirm>
            </>
          )}
        </Space>
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


  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <Title level={2}>🔗 Field Mappings</Title>
        <Space>
          <Button 
            icon={<RobotOutlined />} 
            onClick={() => setIsAutoMLDrawerVisible(true)}
            type="primary"
            disabled={!selectedTable}
          >
            Auto-Map (ML)
          </Button>
          <Button 
            icon={<ThunderboltOutlined />} 
            onClick={() => {
              setIsAutoLLMDrawerVisible(true)
              loadCortexModels() // Load models when drawer opens
            }}
            type="primary"
            disabled={!selectedTable}
          >
            Auto-Map (LLM)
          </Button>
          <Button 
            icon={<PlusOutlined />} 
            onClick={() => {
              manualForm.resetFields()
              setIsManualModalVisible(true)
              loadSourceFields() // Load source fields when modal opens
            }}
            type="primary"
            disabled={!selectedTable}
          >
            Manual Mapping
          </Button>
          <Button 
            icon={<ReloadOutlined />} 
            onClick={loadMappings}
            loading={loading}
            type="primary"
            disabled={!selectedTable}
          >
            Refresh
          </Button>
        </Space>
      </div>

      <p style={{ marginBottom: 24, color: '#666' }}>
        View field mappings from Bronze (raw data) to Silver (target tables).
      </p>

      {!selectedTpa ? (
        <Card>
          <Alert
            message="No TPA Selected"
            description={
              <div>
                <p>Please select a provider (TPA) from the header dropdown to view and manage field mappings.</p>
              </div>
            }
            type="info"
            showIcon
            style={{ margin: '20px 0' }}
          />
        </Card>
      ) : (
        availableTargetTables.length === 0 ? (
          <Card>
            <Alert
              message="No Tables Created for this TPA"
              description={
                <div>
                  <p>No physical tables have been created yet for TPA <strong>{selectedTpaName || selectedTpa}</strong>. To create field mappings, you must first:</p>
                  <ol>
                    <li>Go to <strong>Schemas and Tables</strong> page</li>
                    <li>Select a schema definition (e.g., DENTAL_CLAIMS, MEDICAL_CLAIMS)</li>
                    <li>Click <strong>Create Table</strong> and select <strong>{selectedTpaName || selectedTpa}</strong></li>
                    <li>Return here to create field mappings for the created table</li>
                  </ol>
                </div>
              }
              type="info"
              showIcon
              style={{ margin: '20px 0' }}
            />
          </Card>
        ) : (
          <Collapse 
            accordion
            activeKey={selectedTable}
            onChange={(key) => setSelectedTable(key as string)}
            style={{ marginBottom: 16 }}
          >
            {availableTargetTables.map(tableInfo => {
              const tableMappings = mappings.filter(m => m.TARGET_TABLE === tableInfo.name)
              const approvedCount = tableMappings.filter(m => m.APPROVED).length
              const totalCount = tableMappings.length
              const approvalRate = totalCount > 0 ? Math.round((approvedCount / totalCount) * 100) : 0

              return (
                <Panel
                  key={tableInfo.physicalName}
                  header={
                    <Space>
                      <ApiOutlined />
                      <span><strong>{tableInfo.physicalName}</strong></span>
                      <Tag color="cyan">{tableInfo.columns} columns</Tag>
                      {totalCount > 0 ? (
                        <>
                          <Tag color="blue">{totalCount} mappings</Tag>
                          <Tag color={approvalRate === 100 ? 'success' : 'warning'}>
                            {approvedCount}/{totalCount} approved
                          </Tag>
                        </>
                      ) : (
                        <Tag color="default">No mappings yet</Tag>
                      )}
                    </Space>
                  }
                >
                  {totalCount > 0 ? (
                    <>
                      {selectedRowKeys.length > 0 && (
                        <Alert
                          message={`${selectedRowKeys.length} mapping(s) selected`}
                          type="info"
                          showIcon
                          style={{ marginBottom: 16 }}
                          action={
                            <Space>
                              <Popconfirm
                                title={`Approve ${selectedRowKeys.length} mapping(s)?`}
                                description="This will approve all selected mappings."
                                onConfirm={handleBulkApprove}
                                okText="Yes"
                                cancelText="No"
                              >
                                <Button 
                                  type="primary" 
                                  size="small" 
                                  icon={<CheckCircleOutlined />}
                                  loading={bulkActionLoading}
                                >
                                  Bulk Approve
                                </Button>
                              </Popconfirm>
                              <Popconfirm
                                title={`Delete ${selectedRowKeys.length} mapping(s)?`}
                                description="This action cannot be undone."
                                onConfirm={handleBulkDelete}
                                okText="Yes"
                                cancelText="No"
                                okButtonProps={{ danger: true }}
                              >
                                <Button 
                                  danger 
                                  size="small" 
                                  icon={<CloseCircleOutlined />}
                                  loading={bulkActionLoading}
                                >
                                  Bulk Delete
                                </Button>
                              </Popconfirm>
                              <Button 
                                size="small" 
                                onClick={() => setSelectedRowKeys([])}
                              >
                                Clear Selection
                              </Button>
                            </Space>
                          }
                        />
                      )}
                      <Table
                        columns={columns}
                        dataSource={tableMappings}
                        rowKey="MAPPING_ID"
                        loading={loading}
                        pagination={false}
                        size="small"
                        rowSelection={{
                          selectedRowKeys: selectedRowKeys,
                          onChange: (newSelectedRowKeys: React.Key[]) => {
                            setSelectedRowKeys(newSelectedRowKeys)
                          },
                          getCheckboxProps: (record: FieldMapping) => ({
                            name: record.MAPPING_ID,
                          }),
                        }}
                      />
                    </>
                  ) : (
                    <div style={{ textAlign: 'center', padding: '40px', color: '#999' }}>
                      <p>No field mappings created for this table yet.</p>
                      <p style={{ fontSize: '12px' }}>
                        Use <strong>Auto-Map (ML)</strong>, <strong>Auto-Map (LLM)</strong>, or <strong>Manual Mapping</strong> to create mappings.
                      </p>
                    </div>
                  )}
                </Panel>
              )
            })}
          </Collapse>
        )
      )}

      <Card title="ℹ️ Mapping Information" style={{ marginTop: 16 }}>
        <Space direction="vertical" size="small">
          <div><strong>Total Mappings:</strong> {mappings.length}</div>
          <div><strong>Approved:</strong> {mappings.filter(m => m.APPROVED).length}</div>
          <div><strong>Pending:</strong> {mappings.filter(m => !m.APPROVED).length}</div>
          <div><strong>Target Tables:</strong> {availableTargetTables.length}</div>
          <div><strong>Tables with Mappings:</strong> {availableTargetTables.filter(t => mappings.some(m => m.TARGET_TABLE === t.name)).length}</div>
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
          initialValues={{ 
            source_table: 'RAW_DATA_TABLE',
            top_n: 3, 
            min_confidence: 60 
          }}
        >
          <Form.Item
            name="source_table"
            label="Source Table"
            rules={[{ required: true, message: 'Please enter source table' }]}
          >
            <Input placeholder="RAW_DATA_TABLE" />
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
          initialValues={{ 
            source_table: 'RAW_DATA_TABLE',
          }}
        >
          <Form.Item
            name="source_table"
            label="Source Table"
            rules={[{ required: true, message: 'Please enter source table' }]}
          >
            <Input placeholder="RAW_DATA_TABLE" />
          </Form.Item>

          <Form.Item
            name="model_name"
            label="LLM Model"
            rules={[{ required: true, message: 'Please select a model' }]}
          >
            <Select
              placeholder="Select Cortex LLM model"
              options={cortexModels.map(model => ({ 
                label: model, 
                value: model 
              }))}
              showSearch
              loading={loadingCortexModels}
              notFoundContent={loadingCortexModels ? 'Loading models...' : 'No models available'}
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
          initialValues={{ 
            source_table: 'RAW_DATA_TABLE',
          }}
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
            rules={[{ required: true, message: 'Please select source field' }]}
          >
            <Select
              placeholder="Select source field"
              options={sourceFields.map(field => ({ 
                label: field, 
                value: field 
              }))}
              showSearch
              loading={loadingSourceFields}
              notFoundContent={loadingSourceFields ? 'Loading...' : 'No source fields found. Upload data first.'}
            />
          </Form.Item>

          <Form.Item
            name="target_column"
            label="Target Column"
            rules={[{ required: true, message: 'Please select target column' }]}
          >
            <Select
              placeholder="Select target column"
              options={targetColumns.map(column => ({ 
                label: column, 
                value: column 
              }))}
              showSearch
              loading={loadingTargetColumns}
              notFoundContent={loadingTargetColumns ? 'Loading...' : 'Select a target table first'}
              disabled={targetColumns.length === 0}
            />
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