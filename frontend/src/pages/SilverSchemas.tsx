import React, { useState, useEffect } from 'react'
import { Card, Typography, Table, Button, Select, Space, message, Tag, Descriptions, Modal, Form, Input, Switch, Drawer, Alert, Popconfirm, Collapse, Spin } from 'antd'
import { ReloadOutlined, TableOutlined, PlusOutlined, EditOutlined, DatabaseOutlined, DeleteOutlined, DownOutlined, EyeOutlined, LinkOutlined, DisconnectOutlined } from '@ant-design/icons'
import { apiService } from '../services/api'
import type { TargetSchema } from '../services/api'

const { Title } = Typography
const { TextArea } = Input
const { Panel } = Collapse

interface SilverSchemasProps {
  selectedTpa: string
  setSelectedTpa: (tpa: string) => void
  tpas: Array<{ TPA_CODE: string; TPA_NAME: string }>
  selectedTpaName?: string
}

const SilverSchemas: React.FC<SilverSchemasProps> = ({ selectedTpa, setSelectedTpa, tpas, selectedTpaName }) => {
  const [loading, setLoading] = useState(false)
  const [schemas, setSchemas] = useState<TargetSchema[]>([])
  const [allSchemas, setAllSchemas] = useState<TargetSchema[]>([])
  const [selectedTable, setSelectedTable] = useState<string>('')
  const [tables, setTables] = useState<string[]>([])
  const [isModalVisible, setIsModalVisible] = useState(false)
  const [isDrawerVisible, setIsDrawerVisible] = useState(false)
  const [selectedSchema, setSelectedSchema] = useState<TargetSchema | null>(null)
  const [editingSchema, setEditingSchema] = useState<TargetSchema | null>(null)
  const [form] = Form.useForm()
  const [createTableForm] = Form.useForm()
  const [activeKeys, setActiveKeys] = useState<string[]>([])
  const [tableExistence, setTableExistence] = useState<Record<string, boolean>>({})
  const [createTableModalVisible, setCreateTableModalVisible] = useState(false)
  const [selectedTableForCreation, setSelectedTableForCreation] = useState<string>('')
  const [createPhysicalTableForm] = Form.useForm()
  const [createdTables, setCreatedTables] = useState<any[]>([])
  const [loadingCreatedTables, setLoadingCreatedTables] = useState(false)
  const [viewSchemaModalVisible, setViewSchemaModalVisible] = useState(false)
  const [selectedTableSchema, setSelectedTableSchema] = useState<TargetSchema[]>([])
  const [selectedTableName, setSelectedTableName] = useState<string>('')
  const [qualityData, setQualityData] = useState<Record<string, any>>({})
  const [loadingQuality, setLoadingQuality] = useState(false)
  const [tableMappings, setTableMappings] = useState<Record<string, number>>({})
  const [schemaTableCounts, setSchemaTableCounts] = useState<Record<string, number>>({})

  useEffect(() => {
    // Load schemas once on mount (TPA-agnostic)
    loadSchemas()
    loadCreatedTables()
    loadQualityData()
    loadTableMappings()
  }, [])

  useEffect(() => {
    // Reload table existence checks when TPA changes
    if (selectedTpa && tables.length > 0) {
      checkTableExistence()
    }
  }, [selectedTpa])

  const checkTableExistence = async () => {
    if (!selectedTpa || tables.length === 0) return
    
    const existenceChecks = await Promise.all(
      tables.map(async (tableName) => {
        try {
          const result = await apiService.checkTableExists(tableName, selectedTpa)
          return { tableName, exists: result.exists }
        } catch {
          return { tableName, exists: false }
        }
      })
    )
    
    const existenceMap = existenceChecks.reduce((acc, { tableName, exists }) => {
      acc[tableName] = exists
      return acc
    }, {} as Record<string, boolean>)
    
    setTableExistence(existenceMap)
  }


  const loadCreatedTables = async () => {
    setLoadingCreatedTables(true)
    try {
      const data = await apiService.getSilverTables()
      setCreatedTables(data)
      
      // Calculate how many physical tables exist for each schema
      const schemaCounts: Record<string, number> = {}
      data.forEach((table: any) => {
        const schemaName = table.SCHEMA_TABLE
        if (schemaName) {
          schemaCounts[schemaName] = (schemaCounts[schemaName] || 0) + 1
        }
      })
      setSchemaTableCounts(schemaCounts)
      
      // Load mappings after tables are loaded
      if (data.length > 0) {
        await loadTableMappingsForTables(data)
      }
    } catch (error) {
      message.error('Failed to load created tables')
    } finally {
      setLoadingCreatedTables(false)
    }
  }

  const loadQualityData = async () => {
    setLoadingQuality(true)
    try {
      const response = await fetch('/api/silver/quality/summary')
      if (response.ok) {
        const data = await response.json()
        // Create a map of table_name -> quality data
        const qualityMap = data.reduce((acc: any, item: any) => {
          const key = `${item.TPA}_${item.TARGET_TABLE}`
          acc[key] = item
          return acc
        }, {})
        setQualityData(qualityMap)
      }
    } catch (error) {
      console.error('Failed to load quality data:', error)
    } finally {
      setLoadingQuality(false)
    }
  }

  const runQualityCheck = async (tableName: string, tpa: string) => {
    try {
      message.loading({ content: 'Running quality checks...', key: 'quality-check' })
      const response = await fetch('/api/silver/quality/check', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ table_name: tableName, tpa })
      })
      
      if (response.ok) {
        const result = await response.json()
        message.success({ content: result.message || 'Quality check completed', key: 'quality-check' })
        // Reload quality data
        await loadQualityData()
      } else {
        throw new Error('Quality check failed')
      }
    } catch (error: any) {
      message.error({ content: `Failed to run quality check: ${error.message}`, key: 'quality-check' })
    }
  }

  const loadTableMappings = async () => {
    // This is called on mount, but createdTables might be empty
    // The actual loading happens in loadTableMappingsForTables
  }

  const loadTableMappingsForTables = async (tables: any[]) => {
    try {
      // Load all mappings for all TPAs
      const allMappings: Record<string, number> = {}
      
      // Get all unique TPAs from created tables
      const uniqueTpas = Array.from(new Set(tables.map((t: any) => t.TPA)))
      
      // Load mappings for each TPA
      await Promise.all(
        uniqueTpas.map(async (tpa) => {
          try {
            const mappings = await apiService.getFieldMappings(tpa)
            // Count mappings per table
            mappings.forEach((mapping: any) => {
              const key = `${tpa}_${mapping.TARGET_TABLE}`
              allMappings[key] = (allMappings[key] || 0) + 1
            })
          } catch (error) {
            console.error(`Failed to load mappings for TPA ${tpa}:`, error)
          }
        })
      )
      
      setTableMappings(allMappings)
    } catch (error) {
      console.error('Failed to load table mappings:', error)
    }
  }

  const loadSchemas = async () => {
    setLoading(true)
    try {
      // Load TPA-agnostic schemas
      const data = await apiService.getTargetSchemas()
      setAllSchemas(data)
      setSchemas(data)
      
      // Extract unique table names
      const uniqueTables = Array.from(new Set(data.map(s => s.TABLE_NAME)))
      setTables(uniqueTables)
      
      // Check which tables physically exist for the selected TPA
      if (selectedTpa) {
        const existenceChecks = await Promise.all(
          uniqueTables.map(async (tableName) => {
            try {
              const result = await apiService.checkTableExists(tableName, selectedTpa)
              return { tableName, exists: result.exists }
            } catch {
              return { tableName, exists: false }
            }
          })
        )
        
        const existenceMap = existenceChecks.reduce((acc, { tableName, exists }) => {
          acc[tableName] = exists
          return acc
        }, {} as Record<string, boolean>)
        
        setTableExistence(existenceMap)
      }
      
      // Check for schema validation issues
      const invalidColumns = data.filter(s => !s.NULLABLE && !s.DEFAULT_VALUE)
      if (invalidColumns.length > 0) {
        message.warning({
          content: `Found ${invalidColumns.length} non-nullable column${invalidColumns.length !== 1 ? 's' : ''} without default values. These should be fixed to ensure data integrity.`,
          duration: 5
        })
      }
      
      const schemaCount = uniqueTables.length
      const columnCount = data.length
      message.success(`Loaded ${schemaCount} schema${schemaCount !== 1 ? 's' : ''} (${columnCount} column${columnCount !== 1 ? 's' : ''})`)
    } catch (error) {
      message.error('Failed to load target schemas')
    } finally {
      setLoading(false)
    }
  }

  const handleAddColumn = (tableName?: string) => {
    form.resetFields()
    setEditingSchema(null)
    if (tableName) {
      form.setFieldsValue({ table_name: tableName })
    }
    setIsModalVisible(true)
  }

  const handleEditColumn = (schema: TargetSchema) => {
    setEditingSchema(schema)
    form.setFieldsValue({
      table_name: schema.TABLE_NAME,
      column_name: schema.COLUMN_NAME,
      data_type: schema.DATA_TYPE,
      nullable: schema.NULLABLE,
      default_value: schema.DEFAULT_VALUE,
      description: schema.DESCRIPTION,
    })
    setIsModalVisible(true)
  }

  const handleDeleteColumn = async (schema: TargetSchema) => {
    try {
      await apiService.deleteTargetSchema(schema.SCHEMA_ID)
      message.success(`Column ${schema.COLUMN_NAME} deleted successfully`)
      loadSchemas()
    } catch (error: any) {
      message.error(`Failed to delete column: ${error.response?.data?.detail || error.message}`)
    }
  }

  const handleDeleteTable = async (tableName: string) => {
    try {
      const result = await apiService.deleteTableSchema(tableName, selectedTpa)
      message.success(`Table schema ${tableName} deleted successfully (${result.columns_deleted} columns removed)`)
      loadSchemas()
    } catch (error: any) {
      message.error(`Failed to delete table schema: ${error.response?.data?.detail || error.message}`)
    }
  }

  const handleAddSchema = () => {
    createTableForm.resetFields()
    setIsDrawerVisible(true)
  }

  const validateDefaultValue = (dataType: string, defaultValue: string): { valid: boolean; message: string } => {
    if (!defaultValue || !defaultValue.trim()) {
      return { valid: true, message: '' }
    }

    const value = defaultValue.trim()
    const baseType = dataType.toUpperCase().split('(')[0].trim()
    const isFunction = value.includes('(') && value.includes(')')

    // Type-specific validation
    if (baseType === 'DATE') {
      if (value.toUpperCase().includes('CURRENT_TIMESTAMP') || value.toUpperCase().includes('GETDATE')) {
        return { valid: false, message: 'DATE columns cannot use CURRENT_TIMESTAMP(). Use CURRENT_DATE() instead.' }
      }
    } else if (baseType.startsWith('TIMESTAMP')) {
      if (value.toUpperCase().includes('CURRENT_DATE()')) {
        return { valid: false, message: 'TIMESTAMP columns cannot use CURRENT_DATE(). Use CURRENT_TIMESTAMP() instead.' }
      }
    } else if (['NUMBER', 'INT', 'INTEGER', 'FLOAT', 'DOUBLE', 'DECIMAL'].includes(baseType)) {
      if (!isFunction && isNaN(Number(value.replace(',', '')))) {
        return { valid: false, message: `'${value}' is not a valid number for ${dataType}.` }
      }
    } else if (baseType === 'BOOLEAN') {
      if (!['TRUE', 'FALSE', '0', '1'].includes(value.toUpperCase())) {
        return { valid: false, message: 'BOOLEAN default must be TRUE or FALSE.' }
      }
    }

    return { valid: true, message: '' }
  }

  const handleSubmitColumn = async (values: any) => {
    try {
      // Validate default value compatibility
      if (values.default_value && values.data_type) {
        const validation = validateDefaultValue(values.data_type, values.default_value)
        if (!validation.valid) {
          message.error(validation.message)
          return
        }
      }

      if (editingSchema) {
        // Update existing schema - only send fields that have values
        const updatePayload: any = {}
        if (values.data_type !== undefined) updatePayload.DATA_TYPE = values.data_type
        if (values.nullable !== undefined) updatePayload.NULLABLE = values.nullable
        if (values.default_value !== undefined && values.default_value !== null) {
          updatePayload.DEFAULT_VALUE = values.default_value
        }
        if (values.description !== undefined) updatePayload.DESCRIPTION = values.description
        
        await apiService.updateTargetSchema(editingSchema.SCHEMA_ID, updatePayload)
        message.success('Schema column updated successfully')
      } else {
        // Create new schema
        await apiService.createTargetSchema({
          TABLE_NAME: values.table_name,
          COLUMN_NAME: values.column_name,
          TPA: selectedTpa,
          DATA_TYPE: values.data_type,
          NULLABLE: values.nullable ?? true,
          DEFAULT_VALUE: values.default_value,
          DESCRIPTION: values.description,
        })
        message.success('Schema column added successfully')
      }
      setIsModalVisible(false)
      loadSchemas()
    } catch (error: any) {
      message.error(`Failed to ${editingSchema ? 'update' : 'add'} column: ${error.response?.data?.detail || error.message}`)
    }
  }

  const handleAddSchemaSubmit = async (values: any) => {
    try {
      await apiService.createSilverTable(values.table_name, selectedTpa)
      message.success(`Schema ${values.table_name} added successfully`)
      setIsDrawerVisible(false)
      loadSchemas()
    } catch (error: any) {
      message.error(`Failed to add schema: ${error.response?.data?.detail || error.message}`)
    }
  }

  const showCreateTableModal = (tableName: string) => {
    setSelectedTableForCreation(tableName)
    createPhysicalTableForm.setFieldsValue({ tpa: selectedTpa })
    setCreateTableModalVisible(true)
  }

  const handleCreateTable = async (values: any) => {
    try {
      const result = await apiService.createSilverTable(selectedTableForCreation, values.tpa)
      const physicalTableName = result.physical_table_name || `${values.tpa.toUpperCase()}_${selectedTableForCreation.toUpperCase()}`
      message.success(`Physical table ${physicalTableName} created successfully in Silver layer`)
      
      // Update table existence state
      setTableExistence(prev => ({ ...prev, [selectedTableForCreation]: true }))
      
      // Reload created tables to show the new table
      await loadCreatedTables()
      
      setCreateTableModalVisible(false)
    } catch (error: any) {
      message.error(`Failed to create table: ${error.response?.data?.detail || error.message}`)
    }
  }

  const handleViewTableSchema = (schemaTableName: string, physicalTableName: string) => {
    // Find the schema definition for this table
    const tableSchema = allSchemas.filter(s => s.TABLE_NAME === schemaTableName)
    setSelectedTableSchema(tableSchema)
    setSelectedTableName(physicalTableName)
    setViewSchemaModalVisible(true)
  }

  const handleDeletePhysicalTable = async (tableName: string, tpa: string) => {
    try {
      await apiService.deletePhysicalTable(tableName, tpa)
      message.success(`Table ${tableName} deleted successfully`)
      // Reload the created tables list to reflect the deletion
      await loadCreatedTables()
      // Also reload schemas in case the schema definition was affected
      await loadSchemas()
    } catch (error: any) {
      message.error(`Failed to delete table: ${error.response?.data?.detail || error.message}`)
    }
  }

  // Group schemas by table
  const schemasByTable = schemas.reduce((acc, schema) => {
    if (!acc[schema.TABLE_NAME]) {
      acc[schema.TABLE_NAME] = []
    }
    acc[schema.TABLE_NAME].push(schema)
    return acc
  }, {} as Record<string, TargetSchema[]>)

  const columns = [
    {
      title: 'Column Name',
      dataIndex: 'COLUMN_NAME',
      key: 'COLUMN_NAME',
      width: 200,
      render: (text: string, record: TargetSchema) => {
        // Highlight columns that are non-nullable without default value
        const hasIssue = !record.NULLABLE && !record.DEFAULT_VALUE
        return (
          <Space>
            <strong>{text}</strong>
            {hasIssue && (
              <Tag color="red" style={{ fontSize: '10px' }}>⚠️ Missing Default</Tag>
            )}
          </Space>
        )
      },
    },
    {
      title: 'Data Type',
      dataIndex: 'DATA_TYPE',
      key: 'DATA_TYPE',
      width: 150,
      render: (text: string) => <Tag color="blue">{text}</Tag>,
    },
    {
      title: 'Nullable',
      dataIndex: 'NULLABLE',
      key: 'NULLABLE',
      width: 100,
      render: (nullable: boolean) => (
        <Tag color={nullable ? 'green' : 'red'}>{nullable ? 'YES' : 'NO'}</Tag>
      ),
    },
    {
      title: 'Default Value',
      dataIndex: 'DEFAULT_VALUE',
      key: 'DEFAULT_VALUE',
      width: 150,
      render: (text: string) => text || <span style={{ color: '#999' }}>-</span>,
    },
    {
      title: 'Description',
      dataIndex: 'DESCRIPTION',
      key: 'DESCRIPTION',
      ellipsis: true,
      render: (text: string) => text || <span style={{ color: '#999' }}>No description</span>,
    },
    {
      title: 'Actions',
      key: 'actions',
      width: 120,
      render: (_: any, record: TargetSchema) => (
        <Space size="small">
          <Button
            type="link"
            size="small"
            icon={<EditOutlined />}
            onClick={() => handleEditColumn(record)}
          />
          <Popconfirm
            title="Delete column"
            description={`Are you sure you want to delete ${record.COLUMN_NAME}?`}
            onConfirm={() => handleDeleteColumn(record)}
            okText="Yes"
            cancelText="No"
          >
            <Button type="link" size="small" danger icon={<DeleteOutlined />} />
          </Popconfirm>
        </Space>
      ),
    },
  ]

  return (
    <div>
      <Title level={2}>Target Schemas</Title>

      <Card>
        <Space direction="vertical" size="large" style={{ width: '100%' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <Title level={4} style={{ margin: 0 }}>
                Schemas and Tables
              </Title>
              <p style={{ margin: '8px 0 0 0', color: '#666' }}>
                Define target table structures for the Silver layer (shared across all providers)
              </p>
            </div>
            <Space>
              <Button icon={<ReloadOutlined />} onClick={loadSchemas} loading={loading}>
                Reload
              </Button>
              <Button type="primary" icon={<DatabaseOutlined />} onClick={handleAddSchema}>
                Add Schema
              </Button>
            </Space>
          </div>
        </Space>
      </Card>

      {loading && schemas.length === 0 ? (
        <Card style={{ marginTop: 16 }}>
          <div style={{ textAlign: 'center', padding: '40px' }}>
            <Spin size="large" />
            <p style={{ marginTop: 16, color: '#666' }}>Loading schemas...</p>
          </div>
        </Card>
      ) : Object.keys(schemasByTable).length === 0 ? (
        <Card style={{ marginTop: 16 }}>
          <p style={{ textAlign: 'center', padding: '40px', color: '#999' }}>
            No target schemas found. Schemas need to be defined before transformation.
          </p>
        </Card>
      ) : (
        <Card style={{ marginTop: 16 }}>
          <Collapse
            activeKey={activeKeys}
            onChange={(keys) => setActiveKeys(keys as string[])}
            expandIcon={({ isActive }) => <DownOutlined rotate={isActive ? 180 : 0} />}
          >
            {Object.entries(schemasByTable).map(([tableName, tableSchemas]) => (
                <Panel
                key={tableName}
                header={
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', width: '100%' }}>
                    <Space>
                      <TableOutlined />
                      <strong>{tableName}</strong>
                      <Tag color="cyan">{tableSchemas.length} columns</Tag>
                      <Tag color="green">{schemaTableCounts[tableName] || 0} tables</Tag>
                    </Space>
                    <Space>
                      <Button
                        type="primary"
                        size="small"
                        icon={<DatabaseOutlined />}
                        onClick={(e) => {
                          e.stopPropagation()
                          showCreateTableModal(tableName)
                        }}
                      >
                        Create Table
                      </Button>
                      <Popconfirm
                        title="Delete table schema"
                        description={`Are you sure you want to delete ${tableName} and all its ${tableSchemas.length} columns?`}
                        onConfirm={(e) => {
                          e?.stopPropagation()
                          handleDeleteTable(tableName)
                        }}
                        okText="Yes"
                        cancelText="No"
                        okButtonProps={{ danger: true }}
                      >
                        <Button
                          danger
                          size="small"
                          icon={<DeleteOutlined />}
                          onClick={(e) => e.stopPropagation()}
                        />
                      </Popconfirm>
                    </Space>
                  </div>
                }
              >
                <Table
                  columns={columns}
                  dataSource={tableSchemas}
                  rowKey="SCHEMA_ID"
                  loading={loading}
                  pagination={false}
                  size="small"
                />
                <div style={{ marginTop: 16, textAlign: 'right' }}>
                  <Button
                    type="primary"
                    icon={<PlusOutlined />}
                    onClick={() => handleAddColumn(tableName)}
                  >
                    Add Column
                  </Button>
                </div>
              </Panel>
            ))}
          </Collapse>
        </Card>
      )}

      <Card title="📋 Created Tables" style={{ marginTop: 16 }}>
        {loadingCreatedTables ? (
          <div style={{ textAlign: 'center', padding: '40px 0' }}>
            <Spin size="large" />
            <p style={{ marginTop: 16, color: '#666' }}>Loading created tables...</p>
          </div>
        ) : createdTables.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '40px', color: '#999' }}>
            <p>No tables have been created yet.</p>
            <p style={{ fontSize: '12px' }}>
              Use the <strong>Create Table</strong> button above to create physical tables from schema definitions.
            </p>
          </div>
        ) : (
          <Table
            columns={[
              {
                title: 'Table Name',
                dataIndex: 'TABLE_NAME',
                key: 'TABLE_NAME',
                render: (text: string) => (
                  <Space>
                    <DatabaseOutlined />
                    <strong>{text}</strong>
                  </Space>
                ),
              },
              {
                title: 'Schema',
                dataIndex: 'SCHEMA_TABLE',
                key: 'SCHEMA_TABLE',
                width: 180,
                render: (text: string) => <Tag color="blue">{text}</Tag>,
              },
              {
                title: 'Provider',
                dataIndex: 'TPA',
                key: 'TPA',
                width: 150,
                render: (tpaCode: string) => {
                  const tpa = tpas.find(t => t.TPA_CODE === tpaCode)
                  return <Tag color="green">{tpa ? tpa.TPA_NAME : tpaCode}</Tag>
                },
              },
              {
                title: 'Mappings',
                key: 'mappings',
                width: 120,
                render: (_: any, record: any) => {
                  const mappingKey = `${record.TPA}_${record.SCHEMA_TABLE}`
                  const mappingCount = tableMappings[mappingKey] || 0
                  
                  if (mappingCount > 0) {
                    return (
                      <Space>
                        <LinkOutlined style={{ color: '#52c41a' }} />
                        <Tag color="success">{mappingCount} mappings</Tag>
                      </Space>
                    )
                  } else {
                    return (
                      <Space>
                        <DisconnectOutlined style={{ color: '#d9d9d9' }} />
                        <Tag color="default">No mappings</Tag>
                      </Space>
                    )
                  }
                },
              },
              {
                title: 'Rows',
                dataIndex: 'ROW_COUNT',
                key: 'ROW_COUNT',
                width: 100,
                render: (count: number) => count?.toLocaleString() || '0',
              },
              {
                title: 'Size',
                dataIndex: 'BYTES',
                key: 'BYTES',
                width: 100,
                render: (bytes: number) => {
                  if (!bytes) return '0 B'
                  const kb = bytes / 1024
                  const mb = kb / 1024
                  const gb = mb / 1024
                  if (gb >= 1) return `${gb.toFixed(2)} GB`
                  if (mb >= 1) return `${mb.toFixed(2)} MB`
                  if (kb >= 1) return `${kb.toFixed(2)} KB`
                  return `${bytes} B`
                },
              },
              {
                title: 'Created By',
                dataIndex: 'CREATED_BY',
                key: 'CREATED_BY',
                width: 150,
              },
              {
                title: 'Created At',
                dataIndex: 'CREATED_AT',
                key: 'CREATED_AT',
                width: 180,
                render: (date: string) => {
                  if (!date) return <span style={{ color: '#999' }}>-</span>
                  const d = new Date(date)
                  return d.toLocaleString()
                },
              },
              {
                title: 'Quality Score',
                key: 'quality_score',
                width: 150,
                render: (_: any, record: any) => {
                  const qualityKey = `${record.TPA}_${record.TABLE_NAME}`
                  const quality = qualityData[qualityKey]
                  
                  if (!quality) {
                    return (
                      <Button
                        size="small"
                        onClick={() => runQualityCheck(record.SCHEMA_TABLE, record.TPA)}
                        loading={loadingQuality}
                      >
                        Run Check
                      </Button>
                    )
                  }
                  
                  const score = quality.QUALITY_SCORE || 0
                  const color = score >= 80 ? 'green' : score >= 60 ? 'orange' : 'red'
                  
                  return (
                    <Space direction="vertical" size="small" style={{ width: '100%' }}>
                      <Tag color={color} style={{ width: '100%', textAlign: 'center' }}>
                        {score.toFixed(1)}%
                      </Tag>
                      <div style={{ fontSize: '11px', color: '#666' }}>
                        {quality.CHECKS_PASSED}/{quality.TOTAL_CHECKS} checks
                      </div>
                    </Space>
                  )
                },
              },
              {
                title: 'Actions',
                key: 'actions',
                width: 200,
                render: (_: any, record: any) => (
                  <Space size="small">
                    <Button
                      type="link"
                      size="small"
                      icon={<EyeOutlined />}
                      onClick={() => handleViewTableSchema(record.SCHEMA_TABLE, record.TABLE_NAME)}
                    >
                      View Schema
                    </Button>
                    <Popconfirm
                      title="Delete Physical Table"
                      description={
                        <div>
                          <p>Are you sure you want to delete <strong>{record.TABLE_NAME}</strong>?</p>
                          <p style={{ color: '#ff4d4f', marginTop: 8 }}>
                            ⚠️ This will permanently delete the table and all its data ({record.ROW_COUNT?.toLocaleString() || 0} rows).
                          </p>
                        </div>
                      }
                      onConfirm={() => handleDeletePhysicalTable(record.SCHEMA_TABLE, record.TPA)}
                      okText="Yes, Delete"
                      cancelText="Cancel"
                      okButtonProps={{ danger: true }}
                    >
                      <Button
                        type="link"
                        size="small"
                        danger
                        icon={<DeleteOutlined />}
                      />
                    </Popconfirm>
                  </Space>
                ),
              },
            ]}
            dataSource={createdTables}
            rowKey="TABLE_NAME"
            loading={loadingCreatedTables}
            pagination={false}
            size="small"
          />
        )}
        <div style={{ marginTop: 16, padding: '12px', backgroundColor: '#f0f7ff', borderRadius: '4px' }}>
          <p style={{ margin: 0, color: '#666' }}>
            <strong>Note:</strong> These are physical tables created from TPA-agnostic schemas. Each table is specific to a provider (e.g., PROVIDER_A_DENTAL_CLAIMS).
          </p>
        </div>
      </Card>

      {/* Add/Edit Column Modal */}
      <Modal
        title={editingSchema ? "Edit Schema Column" : "Add Schema Column"}
        open={isModalVisible}
        onCancel={() => {
          setIsModalVisible(false)
          setEditingSchema(null)
        }}
        footer={null}
        width={600}
      >
        <Form
          form={form}
          layout="vertical"
          onFinish={handleSubmitColumn}
        >
          <Form.Item
            name="table_name"
            label="Table Name"
            rules={[{ required: true, message: 'Please enter table name' }]}
          >
            <Select
              placeholder="Select or enter table name"
              options={tables.map(t => ({ label: t, value: t }))}
              showSearch
              allowClear
              disabled={!!editingSchema}
            />
          </Form.Item>

          <Form.Item
            name="column_name"
            label="Column Name"
            rules={[{ required: true, message: 'Please enter column name' }]}
          >
            <Input placeholder="e.g., CUSTOMER_ID" disabled={!!editingSchema} />
          </Form.Item>

          <Form.Item
            name="data_type"
            label="Data Type"
            rules={[{ required: true, message: 'Please select data type' }]}
          >
            <Select
              placeholder="Select data type"
              options={[
                { label: 'VARCHAR', value: 'VARCHAR' },
                { label: 'VARCHAR(100)', value: 'VARCHAR(100)' },
                { label: 'VARCHAR(500)', value: 'VARCHAR(500)' },
                { label: 'NUMBER', value: 'NUMBER' },
                { label: 'NUMBER(18,2)', value: 'NUMBER(18,2)' },
                { label: 'NUMBER(18,4)', value: 'NUMBER(18,4)' },
                { label: 'FLOAT', value: 'FLOAT' },
                { label: 'BOOLEAN', value: 'BOOLEAN' },
                { label: 'DATE', value: 'DATE' },
                { label: 'TIMESTAMP', value: 'TIMESTAMP' },
                { label: 'TIMESTAMP_NTZ', value: 'TIMESTAMP_NTZ' },
                { label: 'VARIANT', value: 'VARIANT' },
              ]}
            />
          </Form.Item>

          <Form.Item
            name="nullable"
            label="Nullable"
            valuePropName="checked"
            initialValue={true}
          >
            <Switch />
          </Form.Item>

          <Form.Item noStyle shouldUpdate={(prevValues, currentValues) => prevValues.nullable !== currentValues.nullable || prevValues.data_type !== currentValues.data_type}>
            {({ getFieldValue }) => {
              const isNullable = getFieldValue('nullable')
              const dataType = getFieldValue('data_type')
              
              return (
                <>
                  <Form.Item
                    name="default_value"
                    label="Default Value"
                    rules={[
                      {
                        required: !isNullable,
                        message: 'Default value is required for non-nullable columns'
                      },
                      {
                        validator: async (_, value) => {
                          if (value && dataType) {
                            const validation = validateDefaultValue(dataType, value)
                            if (!validation.valid) {
                              return Promise.reject(new Error(validation.message))
                            }
                          }
                          return Promise.resolve()
                        }
                      }
                    ]}
                  >
                    <Input 
                      placeholder={
                        dataType === 'DATE' ? "e.g., CURRENT_DATE(), '2024-01-01'" :
                        dataType?.startsWith('TIMESTAMP') ? "e.g., CURRENT_TIMESTAMP()" :
                        dataType?.startsWith('NUMBER') ? "e.g., 0, 100.50" :
                        dataType === 'BOOLEAN' ? "e.g., TRUE, FALSE" :
                        dataType?.startsWith('VARCHAR') ? "e.g., 'N/A', 'Unknown'" :
                        isNullable ? "e.g., NULL, 0, 'N/A' (Optional)" : "e.g., 0, 'N/A', CURRENT_TIMESTAMP() (Required)"
                      } 
                    />
                  </Form.Item>
                  {!isNullable && (
                    <Alert
                      message="Required Field"
                      description="Non-nullable columns must have a default value to ensure data integrity. Common defaults: 0 for numbers, empty string ('') for text, CURRENT_TIMESTAMP() for timestamps."
                      type="warning"
                      showIcon
                      style={{ marginBottom: 16 }}
                    />
                  )}
                  {dataType === 'DATE' && (
                    <Alert
                      message="DATE Column"
                      description="For DATE columns, use CURRENT_DATE() for current date, not CURRENT_TIMESTAMP()."
                      type="info"
                      showIcon
                      style={{ marginBottom: 16 }}
                    />
                  )}
                  {dataType?.startsWith('TIMESTAMP') && (
                    <Alert
                      message="TIMESTAMP Column"
                      description="For TIMESTAMP columns, use CURRENT_TIMESTAMP() for current timestamp, not CURRENT_DATE()."
                      type="info"
                      showIcon
                      style={{ marginBottom: 16 }}
                    />
                  )}
                </>
              )
            }}
          </Form.Item>

          <Form.Item
            name="description"
            label="Description (Optional)"
          >
            <TextArea rows={3} placeholder="Describe this column..." />
          </Form.Item>

          <Form.Item>
            <Space>
              <Button type="primary" htmlType="submit">
                {editingSchema ? 'Update Column' : 'Add Column'}
              </Button>
              <Button onClick={() => {
                setIsModalVisible(false)
                setEditingSchema(null)
              }}>
                Cancel
              </Button>
            </Space>
          </Form.Item>
        </Form>
      </Modal>

      {/* Add Schema Drawer */}
      <Drawer
        title="Add Silver Schema"
        placement="right"
        onClose={() => setIsDrawerVisible(false)}
        open={isDrawerVisible}
        width={500}
      >
        <Form
          form={createTableForm}
          layout="vertical"
          onFinish={handleAddSchemaSubmit}
        >
          <Alert
            message="Add New Schema Definition"
            description={
              <div>
                <p>This creates a TPA-agnostic schema definition (metadata) for a new table.</p>
                <p style={{ marginTop: 8 }}>After adding the schema:</p>
                <ol style={{ marginTop: 4, marginBottom: 0, paddingLeft: 20 }}>
                  <li>Define columns for the table</li>
                  <li>Click "Create Table" and select a provider to create the physical table</li>
                </ol>
              </div>
            }
            type="info"
            showIcon
            style={{ marginBottom: 16 }}
          />

          <Form.Item
            name="table_name"
            label="Table Name"
            rules={[{ required: true, message: 'Please enter table name' }]}
          >
            <Input placeholder="e.g., MEDICAL_CLAIMS" />
          </Form.Item>

          <Descriptions column={1} size="small" bordered style={{ marginBottom: 16 }}>
            <Descriptions.Item label="Schema Type">
              <Tag color="green">TPA-Agnostic (Shared)</Tag>
            </Descriptions.Item>
            <Descriptions.Item label="Schema">SILVER</Descriptions.Item>
            <Descriptions.Item label="Physical Table Format">
              <Tag color="cyan">[TPA_CODE]_[TABLE_NAME]</Tag>
            </Descriptions.Item>
          </Descriptions>

          <Form.Item>
            <Space>
              <Button type="primary" htmlType="submit" icon={<PlusOutlined />}>
                Add Schema Definition
              </Button>
              <Button onClick={() => setIsDrawerVisible(false)}>
                Cancel
              </Button>
            </Space>
          </Form.Item>
        </Form>
      </Drawer>

      {/* Create Physical Table Modal */}
      <Modal
        title="Create Physical Table"
        open={createTableModalVisible}
        onCancel={() => setCreateTableModalVisible(false)}
        footer={null}
        width={500}
      >
        <Form
          form={createPhysicalTableForm}
          layout="vertical"
          onFinish={handleCreateTable}
        >
          <Alert
            message="Create Physical Table"
            description={
              <div>
                <p>This will create the actual Snowflake table in the Silver layer based on the schema definition.</p>
                <p style={{ marginTop: 8 }}>Select the provider (TPA) for which to create the table.</p>
              </div>
            }
            type="info"
            showIcon
            style={{ marginBottom: 16 }}
          />

          <Descriptions column={1} size="small" bordered style={{ marginBottom: 16 }}>
            <Descriptions.Item label="Schema Table">{selectedTableForCreation}</Descriptions.Item>
            <Descriptions.Item label="Columns">
              {schemasByTable[selectedTableForCreation]?.length || 0} columns defined
            </Descriptions.Item>
          </Descriptions>

          <Form.Item
            name="tpa"
            label="Provider (TPA)"
            rules={[{ required: true, message: 'Please select a provider' }]}
          >
            <Select
              placeholder="Select provider"
              options={tpas.map(tpa => ({
                label: tpa.TPA_NAME,
                value: tpa.TPA_CODE
              }))}
              showSearch
              filterOption={(input, option) =>
                (option?.label ?? '').toLowerCase().includes(input.toLowerCase())
              }
              onChange={() => {
                // Force re-render to update the physical table name preview
                createPhysicalTableForm.validateFields(['tpa'])
              }}
            />
          </Form.Item>

          <Form.Item noStyle shouldUpdate={(prevValues, currentValues) => prevValues.tpa !== currentValues.tpa}>
            {({ getFieldValue }) => {
              const selectedTpaCode = getFieldValue('tpa')
              return (
                <Alert
                  message="Physical Table Name"
                  description={
                    <div>
                      <p>The table will be created as:</p>
                      <p style={{ marginTop: 8 }}>
                        <Tag color="cyan" style={{ fontSize: '14px', padding: '4px 8px' }}>
                          {selectedTpaCode ? `${selectedTpaCode.toUpperCase()}_${selectedTableForCreation}` : `[TPA]_${selectedTableForCreation}`}
                        </Tag>
                      </p>
                    </div>
                  }
                  type="warning"
                  showIcon
                  style={{ marginBottom: 16 }}
                />
              )
            }}
          </Form.Item>

          <Form.Item>
            <Space>
              <Button type="primary" htmlType="submit" icon={<DatabaseOutlined />}>
                Create Table
              </Button>
              <Button onClick={() => setCreateTableModalVisible(false)}>
                Cancel
              </Button>
            </Space>
          </Form.Item>
        </Form>
      </Modal>

      {/* View Table Schema Modal */}
      <Modal
        title={
          <Space>
            <TableOutlined />
            <span>Table Schema: {selectedTableName}</span>
          </Space>
        }
        open={viewSchemaModalVisible}
        onCancel={() => setViewSchemaModalVisible(false)}
        footer={[
          <Button key="close" onClick={() => setViewSchemaModalVisible(false)}>
            Close
          </Button>
        ]}
        width={900}
      >
        {selectedTableSchema.length > 0 ? (
          <>
            <Alert
              message="Schema Definition"
              description={`This table has ${selectedTableSchema.length} column${selectedTableSchema.length !== 1 ? 's' : ''} defined.`}
              type="info"
              showIcon
              style={{ marginBottom: 16 }}
            />
            <Table
              columns={[
                {
                  title: 'Column Name',
                  dataIndex: 'COLUMN_NAME',
                  key: 'COLUMN_NAME',
                  width: 200,
                  render: (text: string) => <strong>{text}</strong>,
                },
                {
                  title: 'Data Type',
                  dataIndex: 'DATA_TYPE',
                  key: 'DATA_TYPE',
                  width: 150,
                  render: (text: string) => <Tag color="blue">{text}</Tag>,
                },
                {
                  title: 'Nullable',
                  dataIndex: 'NULLABLE',
                  key: 'NULLABLE',
                  width: 100,
                  render: (nullable: boolean) => (
                    <Tag color={nullable ? 'green' : 'red'}>{nullable ? 'YES' : 'NO'}</Tag>
                  ),
                },
                {
                  title: 'Default Value',
                  dataIndex: 'DEFAULT_VALUE',
                  key: 'DEFAULT_VALUE',
                  width: 150,
                  render: (text: string) => text || <span style={{ color: '#999' }}>-</span>,
                },
                {
                  title: 'Description',
                  dataIndex: 'DESCRIPTION',
                  key: 'DESCRIPTION',
                  ellipsis: true,
                  render: (text: string) => text || <span style={{ color: '#999' }}>No description</span>,
                },
              ]}
              dataSource={selectedTableSchema}
              rowKey="SCHEMA_ID"
              pagination={false}
              size="small"
            />
          </>
        ) : (
          <div style={{ textAlign: 'center', padding: '40px', color: '#999' }}>
            <p>No schema information available for this table.</p>
          </div>
        )}
      </Modal>
    </div>
  )
}

export default SilverSchemas
