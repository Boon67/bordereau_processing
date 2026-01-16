import React, { useState, useEffect } from 'react'
import { Card, Typography, Table, Button, Select, Space, message, Tag, Descriptions, Modal, Form, Input, Switch, Drawer, Alert } from 'antd'
import { ReloadOutlined, TableOutlined, PlusOutlined, EditOutlined, DatabaseOutlined } from '@ant-design/icons'
import { apiService } from '../services/api'
import type { TargetSchema } from '../services/api'

const { Title } = Typography
const { TextArea } = Input

interface SilverSchemasProps {
  selectedTpa: string
}

const SilverSchemas: React.FC<SilverSchemasProps> = ({ selectedTpa }) => {
  const [loading, setLoading] = useState(false)
  const [schemas, setSchemas] = useState<TargetSchema[]>([])
  const [selectedTable, setSelectedTable] = useState<string>('')
  const [tables, setTables] = useState<string[]>([])
  const [isModalVisible, setIsModalVisible] = useState(false)
  const [isDrawerVisible, setIsDrawerVisible] = useState(false)
  const [selectedSchema, setSelectedSchema] = useState<TargetSchema | null>(null)
  const [form] = Form.useForm()
  const [createTableForm] = Form.useForm()

  useEffect(() => {
    if (selectedTpa) {
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
      const data = await apiService.getTargetSchemas(selectedTpa, selectedTable || undefined)
      setSchemas(data)
      
      // Extract unique table names
      const uniqueTables = Array.from(new Set(data.map(s => s.TABLE_NAME)))
      setTables(uniqueTables)
      
      message.success(`Loaded ${data.length} schema definitions`)
    } catch (error) {
      message.error('Failed to load target schemas')
    } finally {
      setLoading(false)
    }
  }

  const handleAddColumn = () => {
    form.resetFields()
    setSelectedSchema(null)
    setIsModalVisible(true)
  }

  const handleCreateTable = () => {
    createTableForm.resetFields()
    setIsDrawerVisible(true)
  }

  const handleSubmitColumn = async (values: any) => {
    try {
      await apiService.createTargetSchema({
        table_name: values.table_name,
        column_name: values.column_name,
        tpa: selectedTpa,
        data_type: values.data_type,
        nullable: values.nullable ?? true,
        default_value: values.default_value,
        description: values.description,
      })
      message.success('Schema column added successfully')
      setIsModalVisible(false)
      loadSchemas()
    } catch (error: any) {
      message.error(`Failed to add column: ${error.response?.data?.detail || error.message}`)
    }
  }

  const handleCreateTableSubmit = async (values: any) => {
    try {
      await apiService.createSilverTable(values.table_name, selectedTpa)
      message.success(`Table ${values.table_name} created successfully`)
      setIsDrawerVisible(false)
      loadSchemas()
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
      render: (name: string) => <strong>{name}</strong>,
    },
    {
      title: 'Data Type',
      dataIndex: 'DATA_TYPE',
      key: 'DATA_TYPE',
      width: 150,
      render: (type: string) => <Tag color="blue">{type}</Tag>,
    },
    {
      title: 'Nullable',
      dataIndex: 'NULLABLE',
      key: 'NULLABLE',
      width: 100,
      render: (nullable: boolean) => (
        nullable ? <Tag color="orange">NULL</Tag> : <Tag color="green">NOT NULL</Tag>
      ),
    },
    {
      title: 'Default Value',
      dataIndex: 'DEFAULT_VALUE',
      key: 'DEFAULT_VALUE',
      width: 150,
      render: (value: string) => value || '-',
    },
    {
      title: 'Description',
      dataIndex: 'DESCRIPTION',
      key: 'DESCRIPTION',
      ellipsis: true,
      render: (desc: string) => desc || '-',
    },
  ]

  if (!selectedTpa) {
    return (
      <div>
        <Title level={2}>🗄️ Target Schemas</Title>
        <Card style={{ marginTop: 16 }}>
          <p style={{ textAlign: 'center', padding: '40px', color: '#999' }}>
            Please select a TPA from the dropdown in the header to view target schemas.
          </p>
        </Card>
      </div>
    )
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <Title level={2}>🗄️ Target Schemas</Title>
        <Space>
          <Button 
            icon={<DatabaseOutlined />} 
            onClick={handleCreateTable}
            type="primary"
          >
            Create Table
          </Button>
          <Button 
            icon={<PlusOutlined />} 
            onClick={handleAddColumn}
          >
            Add Column
          </Button>
          <Button 
            icon={<ReloadOutlined />} 
            onClick={loadSchemas}
            loading={loading}
          >
            Refresh
          </Button>
        </Space>
      </div>

      <p style={{ marginBottom: 24, color: '#666' }}>
        View target table schemas for data transformation. TPA: <strong>{selectedTpa}</strong>
      </p>

      <Card style={{ marginBottom: 16 }}>
        <Space direction="vertical" style={{ width: '100%' }}>
          <div>
            <label style={{ display: 'block', marginBottom: 8, fontWeight: 'bold' }}>
              Filter by Table (optional)
            </label>
            <Select
              value={selectedTable}
              onChange={(value) => {
                setSelectedTable(value)
                if (value) {
                  const filtered = schemas.filter(s => s.TABLE_NAME === value)
                  setSchemas(filtered)
                } else {
                  loadSchemas()
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

      {Object.keys(schemasByTable).length === 0 ? (
        <Card>
          <p style={{ textAlign: 'center', padding: '40px', color: '#999' }}>
            No target schemas found for this TPA. Schemas need to be defined before transformation.
          </p>
        </Card>
      ) : (
        Object.entries(schemasByTable).map(([tableName, tableSchemas]) => (
          <Card 
            key={tableName}
            style={{ marginBottom: 16 }}
            title={
              <Space>
                <TableOutlined />
                <span>{tableName}</span>
                <Tag color="purple">{tableSchemas.length} columns</Tag>
              </Space>
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
          </Card>
        ))
      )}

      <Card title="ℹ️ Schema Information" style={{ marginTop: 16 }}>
        <Descriptions column={1} size="small">
          <Descriptions.Item label="Total Tables">{tables.length}</Descriptions.Item>
          <Descriptions.Item label="Total Columns">{schemas.length}</Descriptions.Item>
          <Descriptions.Item label="TPA">{selectedTpa}</Descriptions.Item>
        </Descriptions>
        <div style={{ marginTop: 16, color: '#666' }}>
          <p><strong>Note:</strong> Target schemas define the structure of tables in the Silver layer where transformed data will be stored.</p>
        </div>
      </Card>

      {/* Add Column Modal */}
      <Modal
        title="Add Schema Column"
        open={isModalVisible}
        onCancel={() => setIsModalVisible(false)}
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
            />
          </Form.Item>

          <Form.Item
            name="column_name"
            label="Column Name"
            rules={[{ required: true, message: 'Please enter column name' }]}
          >
            <Input placeholder="e.g., CUSTOMER_ID" />
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
                { label: 'NUMBER', value: 'NUMBER' },
                { label: 'FLOAT', value: 'FLOAT' },
                { label: 'BOOLEAN', value: 'BOOLEAN' },
                { label: 'DATE', value: 'DATE' },
                { label: 'TIMESTAMP', value: 'TIMESTAMP' },
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
                Add Column
              </Button>
              <Button onClick={() => setIsModalVisible(false)}>
                Cancel
              </Button>
            </Space>
          </Form.Item>
        </Form>
      </Modal>

      {/* Create Table Drawer */}
      <Drawer
        title="Create Silver Table"
        placement="right"
        onClose={() => setIsDrawerVisible(false)}
        open={isDrawerVisible}
        width={500}
      >
        <Form
          form={createTableForm}
          layout="vertical"
          onFinish={handleCreateTableSubmit}
        >
          <Alert
            message="Create Table from Metadata"
            description="This will create a physical table in the Silver layer based on the schema definitions you've added."
            type="info"
            showIcon
            style={{ marginBottom: 16 }}
          />

          <Form.Item
            name="table_name"
            label="Table Name"
            rules={[{ required: true, message: 'Please select table name' }]}
          >
            <Select
              placeholder="Select table to create"
              options={tables.map(t => ({ label: t, value: t }))}
              showSearch
            />
          </Form.Item>

          <Descriptions column={1} size="small" bordered style={{ marginBottom: 16 }}>
            <Descriptions.Item label="TPA">{selectedTpa}</Descriptions.Item>
            <Descriptions.Item label="Schema">SILVER</Descriptions.Item>
          </Descriptions>

          <Form.Item>
            <Space>
              <Button type="primary" htmlType="submit" icon={<DatabaseOutlined />}>
                Create Table
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
