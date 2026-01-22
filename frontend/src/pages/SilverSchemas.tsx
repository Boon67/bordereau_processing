import React, { useState, useEffect } from 'react'
import { Card, Typography, Table, Button, Select, Space, message, Tag, Descriptions, Modal, Form, Input, Switch, Drawer, Alert, Popconfirm, Collapse, Spin } from 'antd'
import { ReloadOutlined, TableOutlined, PlusOutlined, EditOutlined, DatabaseOutlined, DeleteOutlined, DownOutlined } from '@ant-design/icons'
import { apiService } from '../services/api'
import type { TargetSchema } from '../services/api'

const { Title } = Typography
const { TextArea } = Input
const { Panel } = Collapse

interface SilverSchemasProps {
  selectedTpa: string
  selectedTpaName?: string
}

const SilverSchemas: React.FC<SilverSchemasProps> = ({ selectedTpa, selectedTpaName }) => {
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

  useEffect(() => {
    if (selectedTpa) {
      setSelectedTable('') // Reset table filter when TPA changes
      setSchemas([]) // Clear current schemas
      setAllSchemas([]) // Clear all schemas
      loadSchemas()
    }
  }, [selectedTpa])

  const loadSchemas = async () => {
    if (!selectedTpa) {
      message.warning('Please select a TPA')
      return
    }

    setLoading(true)
    try {
      const data = await apiService.getTargetSchemas(selectedTpa)
      setAllSchemas(data)
      setSchemas(data)
      
      // Extract unique table names
      const uniqueTables = Array.from(new Set(data.map(s => s.TABLE_NAME)))
      setTables(uniqueTables)
      
      // Check which tables physically exist
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
      
      const schemaCount = uniqueTables.length
      const columnCount = data.length
      message.success(`Loaded ${schemaCount} schema${schemaCount !== 1 ? 's' : ''} (${columnCount} column${columnCount !== 1 ? 's' : ''}) for ${selectedTpaName || selectedTpa}`)
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

  const handleSubmitColumn = async (values: any) => {
    try {
      if (editingSchema) {
        // Update existing schema
        await apiService.updateTargetSchema(editingSchema.SCHEMA_ID, {
          DATA_TYPE: values.data_type,
          NULLABLE: values.nullable,
          DEFAULT_VALUE: values.default_value,
          DESCRIPTION: values.description,
        })
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

  const handleCreateTable = async (tableName: string) => {
    try {
      const result = await apiService.createSilverTable(tableName, selectedTpa)
      const physicalTableName = result.physical_table_name || `${selectedTpa.toUpperCase()}_${tableName.toUpperCase()}`
      message.success(`Physical table ${physicalTableName} created successfully in Silver layer`)
      
      // Update table existence state
      setTableExistence(prev => ({ ...prev, [tableName]: true }))
    } catch (error: any) {
      message.error(`Failed to create table: ${error.response?.data?.detail || error.message}`)
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
          >
            Edit
          </Button>
          <Popconfirm
            title="Delete column"
            description={`Are you sure you want to delete ${record.COLUMN_NAME}?`}
            onConfirm={() => handleDeleteColumn(record)}
            okText="Yes"
            cancelText="No"
          >
            <Button type="link" size="small" danger icon={<DeleteOutlined />}>
              Delete
            </Button>
          </Popconfirm>
        </Space>
      ),
    },
  ]

  return (
    <div>
      <Card>
        <Space direction="vertical" size="large" style={{ width: '100%' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <Title level={4} style={{ margin: 0 }}>
                Silver Target Schemas
                {selectedTpaName && <Tag color="blue" style={{ marginLeft: 8 }}>{selectedTpaName}</Tag>}
              </Title>
              <p style={{ margin: '8px 0 0 0', color: '#666' }}>
                Define target table structures for the Silver layer
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
            <p style={{ marginTop: 16, color: '#666' }}>Loading schemas for {selectedTpaName}...</p>
          </div>
        </Card>
      ) : Object.keys(schemasByTable).length === 0 ? (
        <Card style={{ marginTop: 16 }}>
          <p style={{ textAlign: 'center', padding: '40px', color: '#999' }}>
            No target schemas found for {selectedTpaName || 'this TPA'}. Schemas need to be defined before transformation.
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
                      {selectedTpaName && <Tag color="blue">{selectedTpaName}</Tag>}
                      <Tag color="purple">{tableSchemas.length} columns</Tag>
                      {tableExistence[tableName] && (
                        <Tag color="cyan">{selectedTpa.toUpperCase()}_{tableName}</Tag>
                      )}
                    </Space>
                    <Space>
                      <Popconfirm
                        title="Create physical table"
                        description={
                          <div>
                            <p>Create physical table in Silver layer:</p>
                            <p><strong>{selectedTpa.toUpperCase()}_{tableName}</strong></p>
                            <p style={{ marginTop: 8, fontSize: '12px', color: '#666' }}>
                              This will create the actual Snowflake table based on the {tableSchemas.length} columns defined in this schema.
                            </p>
                          </div>
                        }
                        onConfirm={(e) => {
                          e?.stopPropagation()
                          handleCreateTable(tableName)
                        }}
                        okText="Create Table"
                        cancelText="Cancel"
                      >
                        <Button
                          type="primary"
                          size="small"
                          icon={<DatabaseOutlined />}
                          onClick={(e) => e.stopPropagation()}
                        >
                          Create Table
                        </Button>
                      </Popconfirm>
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
                        >
                          Delete Schema
                        </Button>
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

      <Card title="ℹ️ Schema Information" style={{ marginTop: 16 }}>
        <Descriptions column={1} size="small">
          <Descriptions.Item label="Provider">
            <strong style={{ fontSize: '16px', color: '#1890ff' }}>{selectedTpaName || selectedTpa}</strong>
          </Descriptions.Item>
          <Descriptions.Item label="Total Tables">{tables.length}</Descriptions.Item>
          <Descriptions.Item label="Total Columns">{schemas.length}</Descriptions.Item>
          <Descriptions.Item label="TPA Code">{selectedTpa}</Descriptions.Item>
        </Descriptions>
        <div style={{ marginTop: 16, color: '#666' }}>
          <p><strong>Note:</strong> Target schemas define the structure of tables in the Silver layer where transformed data will be stored for <strong>{selectedTpaName || selectedTpa}</strong>.</p>
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

          <Form.Item
            name="default_value"
            label="Default Value (Optional)"
          >
            <Input placeholder="e.g., NULL, 0, 'N/A'" />
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
                <p>This creates a schema definition (metadata) for a new table.</p>
                <p style={{ marginTop: 8 }}>After adding the schema:</p>
                <ol style={{ marginTop: 4, marginBottom: 0, paddingLeft: 20 }}>
                  <li>Define columns for the table</li>
                  <li>Click "Create Table" to create the physical table: <strong>{selectedTpa.toUpperCase()}_[TABLE_NAME]</strong></li>
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
            <Descriptions.Item label="TPA">{selectedTpa}</Descriptions.Item>
            <Descriptions.Item label="TPA Name">{selectedTpaName}</Descriptions.Item>
            <Descriptions.Item label="Schema">SILVER</Descriptions.Item>
            <Descriptions.Item label="Table Name Format">
              <Tag color="cyan">{selectedTpa.toUpperCase()}_[TABLE_NAME]</Tag>
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
    </div>
  )
}

export default SilverSchemas
