import React, { useState, useEffect } from 'react'
import { Card, Typography, Table, Button, Select, Space, message, Tag, Progress, Modal, Form, Input, Popconfirm, Drawer, Alert, Slider, InputNumber, Collapse, Radio, Spin } from 'antd'
import { ApiOutlined, CheckCircleOutlined, CloseCircleOutlined, RobotOutlined, ThunderboltOutlined, PlusOutlined, ExclamationCircleOutlined, SearchOutlined, FilterOutlined, WarningOutlined } from '@ant-design/icons'
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

const SilverMappings: React.FC<SilverMappingsProps> = ({ tpas }) => {
  const [loading, setLoading] = useState(false)
  const [loadingTables, setLoadingTables] = useState(true)
  const [mappings, setMappings] = useState<FieldMapping[]>([])
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
  const [searchText, setSearchText] = useState('')
  const [mappingFilter, setMappingFilter] = useState<'all' | 'with-mappings' | 'no-mappings'>('all')
  const [checkingSourceData, setCheckingSourceData] = useState(false)
  const [sourceDataAvailability, setSourceDataAvailability] = useState<Record<string, boolean>>({})

  useEffect(() => {
    // Load all created tables and mappings (not filtered by TPA)
    loadTargetTables()
    loadAllMappings()
  }, [])

  useEffect(() => {
    // Clear selection when table changes
    if (selectedTable) {
      setSelectedRowKeys([])
    }
  }, [selectedTable])

  useEffect(() => {
    // Set default values when selectedTable changes
    // Extract schema table name from physical table name
    const tableInfo = availableTargetTables.find(t => t.physicalName === selectedTable)
    const schemaTableName = tableInfo?.name || ''
    
    autoMLForm.setFieldsValue({
      source_table: 'RAW_DATA_TABLE',
      target_table: schemaTableName
    })
    
    autoLLMForm.setFieldsValue({
      source_table: 'RAW_DATA_TABLE',
      target_table: schemaTableName
    })
    
    manualForm.setFieldsValue({
      source_table: 'RAW_DATA_TABLE',
      target_table: schemaTableName
    })
  }, [selectedTable, availableTargetTables])

  useEffect(() => {
    // Set default model when cortex models are loaded
    if (cortexModels.length > 0) {
      autoLLMForm.setFieldsValue({
        model_name: cortexModels[0] // Use first model as default
      })
    }
  }, [cortexModels])

  const loadTargetTables = async () => {
    setLoadingTables(true)
    try {
      // Load all created tables (no TPA filter)
      const allCreatedTables = await apiService.getSilverTables()
      
      // Load all schema definitions
      const schemas = await apiService.getTargetSchemas()
      
      // Map each created table with its column count from schemas
      const tablesWithColumns = allCreatedTables.map((table: any) => {
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
    } catch (error) {
      console.error('Failed to load target tables:', error)
      message.error('Failed to load tables')
    } finally {
      setLoadingTables(false)
    }
  }

  const loadAllMappings = async () => {
    setLoading(true)
    try {
      // Load all mappings (no TPA filter)
      const data = await apiService.getFieldMappings()
      setMappings(data)
    } catch (error) {
      console.error('Failed to load mappings:', error)
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

  const checkSourceDataAvailable = async (tpa: string): Promise<boolean> => {
    // Check cache first
    if (sourceDataAvailability[tpa] !== undefined) {
      return sourceDataAvailability[tpa]
    }
    
    setCheckingSourceData(true)
    try {
      const fields = await apiService.getSourceFields(tpa)
      const hasData = fields.length > 0
      setSourceDataAvailability(prev => ({ ...prev, [tpa]: hasData }))
      return hasData
    } catch (error) {
      console.error('Failed to check source data availability:', error)
      // On error, don't block - let the backend handle validation
      return true
    } finally {
      setCheckingSourceData(false)
    }
  }

  const handleMLButtonClick = async (e: React.MouseEvent, tableInfo: any) => {
    e.stopPropagation()
    setSelectedTable(tableInfo.physicalName)
    
    const hasData = await checkSourceDataAvailable(tableInfo.tpa)
    if (!hasData) {
      message.warning({
        content: `No source data found for TPA "${tableInfo.tpaName}" in the RAW table. Please upload data files first using the Bronze Upload feature before running auto-mapping.`,
        duration: 8,
        icon: <WarningOutlined style={{ color: '#faad14' }} />,
      })
      return
    }
    
    autoMLForm.setFieldsValue({ 
      source_table: 'RAW_DATA_TABLE',
      target_table: tableInfo.name 
    })
    setIsAutoMLDrawerVisible(true)
  }

  const handleLLMButtonClick = async (e: React.MouseEvent, tableInfo: any) => {
    e.stopPropagation()
    setSelectedTable(tableInfo.physicalName)
    
    const hasData = await checkSourceDataAvailable(tableInfo.tpa)
    if (!hasData) {
      message.warning({
        content: `No source data found for TPA "${tableInfo.tpaName}" in the RAW table. Please upload data files first using the Bronze Upload feature before running auto-mapping.`,
        duration: 8,
        icon: <WarningOutlined style={{ color: '#faad14' }} />,
      })
      return
    }
    
    autoLLMForm.setFieldsValue({ 
      source_table: 'RAW_DATA_TABLE',
      target_table: tableInfo.name 
    })
    setIsAutoLLMDrawerVisible(true)
    loadCortexModels()
  }

  const handleApproveMapping = async (mappingId: number) => {
    try {
      await apiService.approveMapping(mappingId)
      message.success('Mapping approved')
      await loadAllMappings()
    } catch (error: any) {
      message.error(`Failed to approve mapping: ${error.response?.data?.detail || error.message}`)
    }
  }

  const handleDeclineMapping = async (mappingId: number) => {
    try {
      await apiService.declineMapping(mappingId)
      message.success('Mapping declined and deleted')
      await loadAllMappings()
    } catch (error: any) {
      message.error(`Failed to decline mapping: ${error.response?.data?.detail || error.message}`)
    }
  }

  const handleAutoMapML = async (values: any) => {
    setLoading(true)
    try {
      console.log('Auto-Map ML - Form values:', values)
      
      // Get TPA from the currently selected physical table (not from form values)
      // selectedTable is the physical table name like "PROVIDER_A_DENTAL_CLAIMS"
      const targetTableInfo = availableTargetTables.find(t => t.physicalName === selectedTable)
      const tpa = targetTableInfo?.tpa || ''
      const schemaTableName = targetTableInfo?.name || values.target_table
      
      console.log('Auto-Map ML - Target table info:', { 
        selectedTable, 
        targetTableInfo, 
        tpa, 
        schemaTableName 
      })
      
      if (!tpa) {
        message.error('Could not determine TPA from selected table')
        setLoading(false)
        return
      }
      
      // Use the schema table name (e.g., DENTAL_CLAIMS) for the procedure
      const result = await apiService.autoMapFieldsML(
        values.source_table,
        schemaTableName,  // Schema table name (e.g., DENTAL_CLAIMS)
        tpa,              // TPA from selected physical table
        values.top_n,
        values.min_confidence / 100
      )
      
      console.log('Auto-Map ML - Result:', result)
      
      // Always close the drawer first
      setIsAutoMLDrawerVisible(false)
      
      // Reload all mappings to show any new ones
      await loadAllMappings()
      
      // Table is already selected (we used selectedTable to get the TPA)
      // No need to switch tables
      
      // Check if mapping was successful and show appropriate message
      if (result.mappings_created > 0) {
        message.success(`Created ${result.mappings_created} ML-based mappings for ${schemaTableName}`)
      } else if (result.success) {
        // If success flag is true but mappings_created is 0, show the message
        message.success(result.message || `Auto-mapping completed for ${schemaTableName}`)
      } else {
        // Show the actual error/info message from the procedure
        const errorMsg = result.message || result.result || 'No mappings created'
        message.warning(errorMsg, 10) // Show for 10 seconds
      }
    } catch (error: any) {
      setIsAutoMLDrawerVisible(false)
      const errorDetail = error.response?.data?.detail || error.message
      message.error(`Auto-mapping failed: ${errorDetail}`, 10)
    } finally {
      setLoading(false)
    }
  }

  const handleAutoMapLLM = async (values: any) => {
    setLoading(true)
    try {
      console.log('Auto-Map LLM - Form values:', values)
      
      // Get TPA from the currently selected physical table (not from form values)
      // selectedTable is the physical table name like "PROVIDER_A_DENTAL_CLAIMS"
      const targetTableInfo = availableTargetTables.find(t => t.physicalName === selectedTable)
      const tpa = targetTableInfo?.tpa || ''
      const schemaTableName = targetTableInfo?.name || values.target_table
      
      console.log('Auto-Map LLM - Target table info:', { 
        selectedTable, 
        targetTableInfo, 
        tpa, 
        schemaTableName 
      })
      
      if (!tpa) {
        message.error('Could not determine TPA from selected table')
        setLoading(false)
        return
      }
      
      // Use the schema table name (e.g., DENTAL_CLAIMS) for the procedure
      const result = await apiService.autoMapFieldsLLM(
        values.source_table,
        schemaTableName,  // Schema table name (e.g., DENTAL_CLAIMS)
        tpa,              // TPA from selected physical table
        values.model_name
      )
      
      console.log('Auto-Map LLM - Result:', result)
      
      // Always close the drawer first
      setIsAutoLLMDrawerVisible(false)
      
      // Reload all mappings to show any new ones
      await loadAllMappings()
      
      // Table is already selected (we used selectedTable to get the TPA)
      // No need to switch tables
      
      // Check if mapping was successful and show appropriate message
      if (result.mappings_created > 0) {
        message.success(`Created ${result.mappings_created} LLM-based mappings for ${schemaTableName}`)
      } else if (result.success) {
        // If success flag is true but mappings_created is 0, show the message
        message.success(result.message || `Auto-mapping completed for ${schemaTableName}`)
      } else {
        // Show the actual error/info message from the procedure
        const errorMsg = result.message || result.result || 'No mappings created'
        message.warning(errorMsg, 10) // Show for 10 seconds
      }
    } catch (error: any) {
      setIsAutoLLMDrawerVisible(false)
      const errorDetail = error.response?.data?.detail || error.message
      message.error(`Auto-mapping failed: ${errorDetail}`, 10)
    } finally {
      setLoading(false)
    }
  }

  const handleManualMapping = async (values: any) => {
    try {
      console.log('Manual Mapping - Form values:', values)
      
      // Get the TPA from the target table (values.target_table is the schema name)
      const targetTableInfo = availableTargetTables.find(t => t.name === values.target_table)
      const tpa = targetTableInfo?.tpa || ''
      
      console.log('Manual Mapping - Target table info:', { targetTableInfo, tpa })
      
      await apiService.createFieldMapping({
        SOURCE_TABLE: values.source_table,
        SOURCE_FIELD: values.source_field,
        TARGET_TABLE: values.target_table,  // Already the schema table name from form
        TARGET_COLUMN: values.target_column,
        TPA: tpa,
        MAPPING_METHOD: 'MANUAL',
        TRANSFORMATION_LOGIC: values.transformation_logic,
        APPROVED: values.approved ?? false,
      })
      message.success('Manual mapping created')
      setIsManualModalVisible(false)
      await loadAllMappings()
      
      // Switch to the table that was just mapped
      if (targetTableInfo) {
        setSelectedTable(targetTableInfo.physicalName)
      }
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
          apiService.approveMapping(Number(mappingId))
        )
      )
      message.success(`Approved ${selectedRowKeys.length} mapping(s)`)
      setSelectedRowKeys([])
      await loadAllMappings()
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
          apiService.deleteMapping(Number(mappingId))
        )
      )
      message.success(`Deleted ${selectedRowKeys.length} mapping(s)`)
      setSelectedRowKeys([])
      await loadAllMappings()
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

  // Detect duplicate mappings (same source field mapped to multiple targets, or multiple sources to same target)
  const getDuplicateMappings = (mappingsToCheck: FieldMapping[]) => {
    const duplicates = new Set<number>()
    
    // Check for duplicate source fields (same source → multiple targets)
    const sourceFieldMap = new Map<string, FieldMapping[]>()
    mappingsToCheck.forEach(mapping => {
      const key = `${mapping.SOURCE_TABLE}:${mapping.SOURCE_FIELD}:${mapping.TARGET_TABLE}`
      if (!sourceFieldMap.has(key)) {
        sourceFieldMap.set(key, [])
      }
      sourceFieldMap.get(key)!.push(mapping)
    })
    
    // Mark all mappings in groups with duplicates
    sourceFieldMap.forEach(group => {
      if (group.length > 1) {
        group.forEach(m => duplicates.add(m.MAPPING_ID))
      }
    })
    
    // Check for duplicate target columns (multiple sources → same target)
    const targetColumnMap = new Map<string, FieldMapping[]>()
    mappingsToCheck.forEach(mapping => {
      const key = `${mapping.TARGET_TABLE}:${mapping.TARGET_COLUMN}`
      if (!targetColumnMap.has(key)) {
        targetColumnMap.set(key, [])
      }
      targetColumnMap.get(key)!.push(mapping)
    })
    
    targetColumnMap.forEach(group => {
      if (group.length > 1) {
        group.forEach(m => duplicates.add(m.MAPPING_ID))
      }
    })
    
    return duplicates
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
      title: 'Duplicate',
      key: 'DUPLICATE',
      width: 100,
      align: 'center' as const,
      render: (_: any, record: FieldMapping) => {
        // Check if this mapping is a duplicate within the current table
        const tableMappings = mappings.filter(m => m.TARGET_TABLE === record.TARGET_TABLE)
        const duplicates = getDuplicateMappings(tableMappings)
        const isDuplicate = duplicates.has(record.MAPPING_ID)
        
        if (!isDuplicate) return null
        
        // Determine duplicate type
        const sameSourceCount = tableMappings.filter(m => 
          m.SOURCE_TABLE === record.SOURCE_TABLE && 
          m.SOURCE_FIELD === record.SOURCE_FIELD &&
          m.TARGET_TABLE === record.TARGET_TABLE
        ).length
        
        const sameTargetCount = tableMappings.filter(m => 
          m.TARGET_TABLE === record.TARGET_TABLE && 
          m.TARGET_COLUMN === record.TARGET_COLUMN
        ).length
        
        const tooltipText = []
        if (sameSourceCount > 1) {
          tooltipText.push(`Source field "${record.SOURCE_FIELD}" mapped ${sameSourceCount} times`)
        }
        if (sameTargetCount > 1) {
          tooltipText.push(`Target column "${record.TARGET_COLUMN}" has ${sameTargetCount} mappings`)
        }
        
        return (
          <Tag 
            color="warning" 
            icon={<ExclamationCircleOutlined />}
            title={tooltipText.join('\n')}
          >
            Duplicate
          </Tag>
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
        {availableTargetTables.length > 0 && (
          <Space>
            <Tag color="blue" style={{ fontSize: '14px', padding: '4px 12px' }}>
              {availableTargetTables.length} {availableTargetTables.length === 1 ? 'Table' : 'Tables'} Total
            </Tag>
            <Tag color="green" style={{ fontSize: '14px', padding: '4px 12px' }}>
              {mappings.length} {mappings.length === 1 ? 'Mapping' : 'Mappings'}
            </Tag>
          </Space>
        )}
      </div>

      <p style={{ marginBottom: 24, color: '#666' }}>
        View field mappings from Bronze (raw data) to Silver (target tables). All tables across all TPAs are shown below.
      </p>

      {/* Search and Filter Controls */}
      <Card style={{ marginBottom: 16 }}>
        <Space direction="vertical" style={{ width: '100%' }} size="middle">
          <Space style={{ width: '100%', justifyContent: 'space-between' }}>
            <Input
              placeholder="Search tables by name, TPA, or schema..."
              prefix={<SearchOutlined />}
              value={searchText}
              onChange={(e) => setSearchText(e.target.value)}
              style={{ width: 400 }}
              allowClear
            />
            <Space>
              <FilterOutlined />
              <Radio.Group value={mappingFilter} onChange={(e) => setMappingFilter(e.target.value)}>
                <Radio.Button value="all">All Tables</Radio.Button>
                <Radio.Button value="with-mappings">With Mappings</Radio.Button>
                <Radio.Button value="no-mappings">No Mappings</Radio.Button>
              </Radio.Group>
            </Space>
          </Space>
        </Space>
      </Card>

      {loadingTables ? (
        <Card>
          <div style={{ textAlign: 'center', padding: '40px 0' }}>
            <Spin size="large" />
            <p style={{ marginTop: 16, color: '#666' }}>Loading tables...</p>
          </div>
        </Card>
      ) : availableTargetTables.length === 0 ? (
        <Card>
          <Alert
            message="No Tables Created"
            description={
              <div>
                <p>No physical tables have been created yet. To create field mappings, you must first:</p>
                <ol>
                  <li>Go to <strong>Schemas and Tables</strong> page</li>
                  <li>Select a schema definition (e.g., DENTAL_CLAIMS, MEDICAL_CLAIMS)</li>
                  <li>Click <strong>Create Table</strong> and select a TPA</li>
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
          onChange={(key) => setSelectedTable(Array.isArray(key) ? key[0] : key as string)}
          style={{ marginBottom: 16 }}
        >
          {availableTargetTables
            .filter(tableInfo => {
              // Apply search filter
              const searchLower = searchText.toLowerCase()
              const matchesSearch = !searchText || 
                tableInfo.physicalName.toLowerCase().includes(searchLower) ||
                tableInfo.name.toLowerCase().includes(searchLower) ||
                tableInfo.tpa.toLowerCase().includes(searchLower) ||
                tableInfo.tpaName.toLowerCase().includes(searchLower)
              
              if (!matchesSearch) return false
              
              // Apply mapping filter
              const tableMappings = mappings.filter(m => m.TARGET_TABLE === tableInfo.name)
              const hasMappings = tableMappings.length > 0
              
              if (mappingFilter === 'with-mappings') return hasMappings
              if (mappingFilter === 'no-mappings') return !hasMappings
              return true // 'all'
            })
            .map(tableInfo => {
              const tableMappings = mappings.filter(m => m.TARGET_TABLE === tableInfo.name)
              const approvedCount = tableMappings.filter(m => m.APPROVED).length
              const totalCount = tableMappings.length
              const approvalRate = totalCount > 0 ? Math.round((approvedCount / totalCount) * 100) : 0

              return (
                <Panel
                  key={tableInfo.physicalName}
                  header={
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', width: '100%' }}>
                      <Space>
                        <ApiOutlined />
                        <span><strong>{tableInfo.physicalName}</strong></span>
                        <Tag color="purple">{tableInfo.tpaName}</Tag>
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
                      <Space onClick={(e) => e.stopPropagation()}>
                        <Button 
                          icon={<RobotOutlined />} 
                          size="small"
                          loading={checkingSourceData}
                          onClick={(e) => handleMLButtonClick(e, tableInfo)}
                        >
                          ML
                        </Button>
                        <Button 
                          icon={<ThunderboltOutlined />} 
                          size="small"
                          loading={checkingSourceData}
                          onClick={(e) => handleLLMButtonClick(e, tableInfo)}
                        >
                          LLM
                        </Button>
                        <Button 
                          icon={<PlusOutlined />} 
                          size="small"
                          onClick={async (e) => {
                            e.stopPropagation()
                            setSelectedTable(tableInfo.physicalName)
                            
                            const hasData = await checkSourceDataAvailable(tableInfo.tpa)
                            if (!hasData) {
                              message.warning({
                                content: `No source data found for TPA "${tableInfo.tpaName}" in the RAW table. Please upload data files first using the Bronze Upload feature before creating mappings.`,
                                duration: 8,
                                icon: <WarningOutlined style={{ color: '#faad14' }} />,
                              })
                              return
                            }
                            
                            manualForm.resetFields()
                            manualForm.setFieldsValue({ 
                              source_table: 'RAW_DATA_TABLE',
                              target_table: tableInfo.name 
                            })
                            setIsManualModalVisible(true)
                            loadSourceFields()
                          }}
                        >
                          Manual
                        </Button>
                      </Space>
                    </div>
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
                            name: String(record.MAPPING_ID),
                          }),
                        }}
                        rowClassName={(record: FieldMapping) => {
                          const duplicates = getDuplicateMappings(tableMappings)
                          return duplicates.has(record.MAPPING_ID) ? 'duplicate-mapping-row' : ''
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
      }

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
            target_table: '',
            top_n: 3, 
            min_confidence: 60 
          }}
        >
          <Form.Item
            name="source_table"
            hidden
          >
            <Input />
          </Form.Item>

          <Form.Item
            name="target_table"
            hidden
          >
            <Input />
          </Form.Item>

          <Form.Item noStyle shouldUpdate>
            {() => (
              <Alert
                message={
                  <Space direction="vertical" size="small" style={{ width: '100%' }}>
                    <div><strong>Source Table:</strong> {autoMLForm.getFieldValue('source_table') || 'RAW_DATA_TABLE'}</div>
                    <div><strong>Target Table:</strong> {autoMLForm.getFieldValue('target_table') || 'Not selected'}</div>
                  </Space>
                }
                type="info"
                style={{ marginBottom: 16 }}
              />
            )}
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
            target_table: '',
          }}
        >
          <Form.Item
            name="source_table"
            hidden
          >
            <Input />
          </Form.Item>

          <Form.Item
            name="target_table"
            hidden
          >
            <Input />
          </Form.Item>

          <Form.Item noStyle shouldUpdate>
            {() => (
              <Alert
                message={
                  <Space direction="vertical" size="small" style={{ width: '100%' }}>
                    <div><strong>Source Table:</strong> {autoLLMForm.getFieldValue('source_table') || 'RAW_DATA_TABLE'}</div>
                    <div><strong>Target Table:</strong> {autoLLMForm.getFieldValue('target_table') || 'Not selected'}</div>
                  </Space>
                }
                type="info"
                style={{ marginBottom: 16 }}
              />
            )}
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
            target_table: '',
          }}
        >
          <Form.Item
            name="source_table"
            hidden
          >
            <Input />
          </Form.Item>

          <Form.Item
            name="target_table"
            hidden
          >
            <Input />
          </Form.Item>

          <Form.Item noStyle shouldUpdate>
            {() => (
              <Alert
                message={
                  <Space direction="vertical" size="small" style={{ width: '100%' }}>
                    <div><strong>Source Table:</strong> {manualForm.getFieldValue('source_table') || 'RAW_DATA_TABLE'}</div>
                    <div><strong>Target Table:</strong> {manualForm.getFieldValue('target_table') || 'Not selected'}</div>
                  </Space>
                }
                type="info"
                style={{ marginBottom: 16 }}
              />
            )}
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