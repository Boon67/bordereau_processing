import React, { useState, useEffect } from 'react'
import {
  Table,
  Button,
  Modal,
  Form,
  Input,
  Switch,
  message,
  Space,
  Card,
  Tag,
  Popconfirm,
  Typography,
  Descriptions,
  Divider,
} from 'antd'
import {
  PlusOutlined,
  EditOutlined,
  DeleteOutlined,
  CheckCircleOutlined,
  CloseCircleOutlined,
  ReloadOutlined,
} from '@ant-design/icons'
import { apiService } from '../services/api'
import type { TPA } from '../types'

const { Title, Text } = Typography
const { TextArea } = Input

interface TPAManagementProps {
  onTpaChange?: () => void
}

const TPAManagement: React.FC<TPAManagementProps> = ({ onTpaChange }) => {
  const [tpas, setTpas] = useState<TPA[]>([])
  const [loading, setLoading] = useState(false)
  const [modalVisible, setModalVisible] = useState(false)
  const [editingTpa, setEditingTpa] = useState<TPA | null>(null)
  const [form] = Form.useForm()

  useEffect(() => {
    loadTpas()
  }, [])

  const loadTpas = async () => {
    setLoading(true)
    try {
      const data = await apiService.getTpas()
      setTpas(data)
      // Notify parent component of TPA changes
      if (onTpaChange) {
        onTpaChange()
      }
    } catch (error: any) {
      message.error('Failed to load TPAs: ' + (error.response?.data?.detail || error.message))
    } finally {
      setLoading(false)
    }
  }

  const handleCreate = () => {
    setEditingTpa(null)
    form.resetFields()
    form.setFieldsValue({ active: true })
    setModalVisible(true)
  }

  const handleEdit = (tpa: TPA) => {
    setEditingTpa(tpa)
    form.setFieldsValue({
      tpa_code: tpa.TPA_CODE,
      tpa_name: tpa.TPA_NAME,
      tpa_description: tpa.TPA_DESCRIPTION || '',
      active: tpa.ACTIVE,
    })
    setModalVisible(true)
  }

  const handleDelete = async (tpaCode: string) => {
    try {
      await apiService.deleteTpa(tpaCode)
      message.success('TPA deleted successfully')
      loadTpas()
    } catch (error: any) {
      message.error('Failed to delete TPA: ' + (error.response?.data?.detail || error.message))
    }
  }

  const handleToggleActive = async (tpaCode: string, active: boolean) => {
    try {
      await apiService.updateTpaStatus(tpaCode, active)
      message.success(`TPA ${active ? 'activated' : 'deactivated'} successfully`)
      loadTpas()
    } catch (error: any) {
      message.error('Failed to update TPA status: ' + (error.response?.data?.detail || error.message))
    }
  }

  const handleSubmit = async () => {
    try {
      const values = await form.validateFields()
      
      if (editingTpa) {
        // Update existing TPA
        await apiService.updateTpa(editingTpa.TPA_CODE, values)
        message.success('TPA updated successfully')
      } else {
        // Create new TPA
        await apiService.createTpa(values)
        message.success('TPA created successfully')
      }
      
      setModalVisible(false)
      form.resetFields()
      loadTpas()
    } catch (error: any) {
      if (error.errorFields) {
        // Form validation error
        return
      }
      message.error(
        `Failed to ${editingTpa ? 'update' : 'create'} TPA: ` +
        (error.response?.data?.detail || error.message)
      )
    }
  }

  const columns = [
    {
      title: 'TPA Code',
      dataIndex: 'TPA_CODE',
      key: 'TPA_CODE',
      width: 150,
      render: (code: string) => <Text strong>{code}</Text>,
    },
    {
      title: 'TPA Name',
      dataIndex: 'TPA_NAME',
      key: 'TPA_NAME',
      width: 250,
    },
    {
      title: 'Description',
      dataIndex: 'TPA_DESCRIPTION',
      key: 'TPA_DESCRIPTION',
      ellipsis: true,
      render: (desc: string) => desc || <Text type="secondary">No description</Text>,
    },
    {
      title: 'Status',
      dataIndex: 'ACTIVE',
      key: 'ACTIVE',
      width: 120,
      render: (active: boolean, record: TPA) => (
        <Switch
          checked={active}
          checkedChildren={<CheckCircleOutlined />}
          unCheckedChildren={<CloseCircleOutlined />}
          onChange={(checked) => handleToggleActive(record.TPA_CODE, checked)}
        />
      ),
    },
    {
      title: 'Created',
      dataIndex: 'CREATED_TIMESTAMP',
      key: 'CREATED_TIMESTAMP',
      width: 180,
      render: (date: string) => date ? new Date(date).toLocaleString() : '-',
    },
    {
      title: 'Actions',
      key: 'actions',
      width: 150,
      render: (_: any, record: TPA) => (
        <Space>
          <Button
            type="link"
            icon={<EditOutlined />}
            onClick={() => handleEdit(record)}
          >
            Edit
          </Button>
          <Popconfirm
            title="Delete TPA"
            description={
              <div>
                <p>Are you sure you want to delete this TPA?</p>
                <p style={{ color: '#ff4d4f', fontWeight: 'bold' }}>
                  This will also delete all associated data!
                </p>
              </div>
            }
            onConfirm={() => handleDelete(record.TPA_CODE)}
            okText="Yes, Delete"
            cancelText="Cancel"
            okButtonProps={{ danger: true }}
          >
            <Button type="link" danger icon={<DeleteOutlined />}>
              Delete
            </Button>
          </Popconfirm>
        </Space>
      ),
    },
  ]

  const activeTpas = tpas.filter(t => t.ACTIVE)
  const inactiveTpas = tpas.filter(t => !t.ACTIVE)

  return (
    <div>
      <Card>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
          <div>
            <Title level={2} style={{ margin: 0 }}>
              🏢 TPA Management
            </Title>
            <Text type="secondary">
              Manage Third-Party Administrators and their configurations
            </Text>
          </div>
          <Space>
            <Button
              icon={<ReloadOutlined />}
              onClick={loadTpas}
              loading={loading}
            >
              Refresh
            </Button>
            <Button
              type="primary"
              icon={<PlusOutlined />}
              onClick={handleCreate}
            >
              Add New TPA
            </Button>
          </Space>
        </div>

        <Divider />

        <Descriptions column={3} style={{ marginBottom: 24 }}>
          <Descriptions.Item label="Total TPAs">
            <Tag color="blue">{tpas.length}</Tag>
          </Descriptions.Item>
          <Descriptions.Item label="Active TPAs">
            <Tag color="green">{activeTpas.length}</Tag>
          </Descriptions.Item>
          <Descriptions.Item label="Inactive TPAs">
            <Tag color="red">{inactiveTpas.length}</Tag>
          </Descriptions.Item>
        </Descriptions>

        <Table
          columns={columns}
          dataSource={tpas}
          rowKey="TPA_CODE"
          loading={loading}
          pagination={{
            pageSize: 10,
            showSizeChanger: true,
            showTotal: (total) => `Total ${total} TPAs`,
          }}
        />
      </Card>

      <Modal
        title={editingTpa ? '✏️ Edit TPA' : '➕ Add New TPA'}
        open={modalVisible}
        onOk={handleSubmit}
        onCancel={() => {
          setModalVisible(false)
          form.resetFields()
        }}
        width={600}
        okText={editingTpa ? 'Update' : 'Create'}
      >
        <Form
          form={form}
          layout="vertical"
          style={{ marginTop: 24 }}
        >
          <Form.Item
            name="tpa_code"
            label="TPA Code"
            rules={[
              { required: true, message: 'Please enter TPA code' },
              { pattern: /^[A-Z0-9_]+$/, message: 'Only uppercase letters, numbers, and underscores allowed' },
              { max: 50, message: 'Maximum 50 characters' },
            ]}
            extra="Unique identifier (e.g., PROVIDER_A, HEALTH_CORP)"
          >
            <Input
              placeholder="PROVIDER_A"
              disabled={!!editingTpa}
              style={{ textTransform: 'uppercase' }}
            />
          </Form.Item>

          <Form.Item
            name="tpa_name"
            label="TPA Name"
            rules={[
              { required: true, message: 'Please enter TPA name' },
              { max: 200, message: 'Maximum 200 characters' },
            ]}
            extra="Full name of the organization"
          >
            <Input placeholder="Provider A Healthcare" />
          </Form.Item>

          <Form.Item
            name="tpa_description"
            label="Description"
            rules={[
              { max: 500, message: 'Maximum 500 characters' },
            ]}
            extra="Optional description of the TPA"
          >
            <TextArea
              rows={4}
              placeholder="Enter description about this TPA, their services, contact info, etc."
            />
          </Form.Item>

          <Form.Item
            name="active"
            label="Status"
            valuePropName="checked"
            extra="Inactive TPAs will not be available for data processing"
          >
            <Switch
              checkedChildren="Active"
              unCheckedChildren="Inactive"
            />
          </Form.Item>
        </Form>
      </Modal>
    </div>
  )
}

export default TPAManagement
