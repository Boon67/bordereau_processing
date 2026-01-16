import React, { useState, useEffect } from 'react'
import { Card, Typography, Table, Button, Space, message, Tabs, Popconfirm } from 'antd'
import { ReloadOutlined, FolderOutlined, FileOutlined, DeleteOutlined } from '@ant-design/icons'
import { apiService } from '../services/api'

const { Title } = Typography
const { TabPane } = Tabs

interface StageFile {
  name: string
  size: number
  md5: string
  last_modified: string
}

interface BronzeStagesProps {
  selectedTpa?: string
}

const BronzeStages: React.FC<BronzeStagesProps> = () => {
  const [loading, setLoading] = useState(false)
  const [srcFiles, setSrcFiles] = useState<StageFile[]>([])
  const [completedFiles, setCompletedFiles] = useState<StageFile[]>([])
  const [errorFiles, setErrorFiles] = useState<StageFile[]>([])
  const [archiveFiles, setArchiveFiles] = useState<StageFile[]>([])

  useEffect(() => {
    loadAllStages()
  }, [])

  const loadAllStages = async () => {
    setLoading(true)
    try {
      await Promise.all([
        loadStage('SRC', setSrcFiles),
        loadStage('COMPLETED', setCompletedFiles),
        loadStage('ERROR', setErrorFiles),
        loadStage('ARCHIVE', setArchiveFiles),
      ])
    } finally {
      setLoading(false)
    }
  }

  const loadStage = async (stageName: string, setter: React.Dispatch<React.SetStateAction<StageFile[]>>) => {
    try {
      const data = await apiService.listStageFiles(stageName)
      setter(data)
    } catch (error) {
      message.error(`Failed to load ${stageName} stage`)
      setter([])
    }
  }

  const formatBytes = (bytes: number) => {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i]
  }

  const handleDeleteFile = async (stageName: string, filePath: string) => {
    try {
      await apiService.deleteStageFile(stageName, filePath)
      message.success('File deleted successfully')
      // Reload the specific stage
      if (stageName === 'SRC') loadStage('SRC', setSrcFiles)
      else if (stageName === 'COMPLETED') loadStage('COMPLETED', setCompletedFiles)
      else if (stageName === 'ERROR') loadStage('ERROR', setErrorFiles)
      else if (stageName === 'ARCHIVE') loadStage('ARCHIVE', setArchiveFiles)
    } catch (error) {
      message.error('Failed to delete file')
      console.error('Delete error:', error)
    }
  }

  const getColumns = (stageName: string) => [
    {
      title: 'File Name',
      dataIndex: 'name',
      key: 'name',
      ellipsis: true,
      render: (name: string) => {
        const fileName = name.split('/').pop()
        return (
          <Space>
            <FileOutlined />
            <span>{fileName}</span>
          </Space>
        )
      },
    },
    {
      title: 'TPA',
      dataIndex: 'name',
      key: 'tpa',
      width: 120,
      render: (name: string) => {
        const parts = name.split('/')
        return parts.length > 1 ? parts[1] : '-'
      },
    },
    {
      title: 'Size',
      dataIndex: 'size',
      key: 'size',
      width: 100,
      render: (size: number) => formatBytes(size),
    },
    {
      title: 'Last Modified',
      dataIndex: 'last_modified',
      key: 'last_modified',
      width: 200,
      render: (date: string) => new Date(date).toLocaleString(),
    },
    {
      title: 'MD5',
      dataIndex: 'md5',
      key: 'md5',
      width: 120,
      ellipsis: true,
      render: (md5: string) => (
        <span style={{ fontFamily: 'monospace', fontSize: '11px' }}>{md5.substring(0, 12)}...</span>
      ),
    },
    {
      title: 'Actions',
      key: 'actions',
      width: 100,
      render: (_: any, record: StageFile) => (
        <Popconfirm
          title="Delete this file?"
          description="This will remove the file from the stage and update the processing queue."
          onConfirm={() => handleDeleteFile(stageName, record.name)}
          okText="Yes"
          cancelText="No"
        >
          <Button 
            type="link" 
            danger 
            icon={<DeleteOutlined />}
            size="small"
          >
            Delete
          </Button>
        </Popconfirm>
      ),
    },
  ]

  const getStageInfo = (stageName: string, files: StageFile[]) => {
    const totalSize = files.reduce((sum, f) => sum + f.size, 0)
    const descriptions: Record<string, string> = {
      SRC: 'Source files waiting to be processed',
      COMPLETED: 'Successfully processed files',
      ERROR: 'Files that failed processing',
      ARCHIVE: 'Archived files (older than 30 days)',
    }

    return {
      description: descriptions[stageName],
      count: files.length,
      totalSize: formatBytes(totalSize),
    }
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <Title level={2}>📁 File Stages</Title>
        <Button 
          icon={<ReloadOutlined />} 
          onClick={loadAllStages}
          loading={loading}
        >
          Refresh All
        </Button>
      </div>

      <p style={{ marginBottom: 24, color: '#666' }}>
        View files in different processing stages. Files move through these stages as they are processed.
      </p>

      <Tabs defaultActiveKey="SRC">
        <TabPane 
          tab={
            <span>
              <FolderOutlined />
              SRC ({srcFiles.length})
            </span>
          } 
          key="SRC"
        >
          <Card>
            <div style={{ marginBottom: 16 }}>
              <Space direction="vertical">
                <div><strong>Description:</strong> {getStageInfo('SRC', srcFiles).description}</div>
                <div><strong>Files:</strong> {getStageInfo('SRC', srcFiles).count}</div>
                <div><strong>Total Size:</strong> {getStageInfo('SRC', srcFiles).totalSize}</div>
              </Space>
            </div>
            <Table
              columns={getColumns('SRC')}
              dataSource={srcFiles}
              rowKey="name"
              loading={loading}
              pagination={{ pageSize: 20, showSizeChanger: true }}
            />
          </Card>
        </TabPane>

        <TabPane 
          tab={
            <span>
              <FolderOutlined />
              COMPLETED ({completedFiles.length})
            </span>
          } 
          key="COMPLETED"
        >
          <Card>
            <div style={{ marginBottom: 16 }}>
              <Space direction="vertical">
                <div><strong>Description:</strong> {getStageInfo('COMPLETED', completedFiles).description}</div>
                <div><strong>Files:</strong> {getStageInfo('COMPLETED', completedFiles).count}</div>
                <div><strong>Total Size:</strong> {getStageInfo('COMPLETED', completedFiles).totalSize}</div>
              </Space>
            </div>
            <Table
              columns={getColumns('COMPLETED')}
              dataSource={completedFiles}
              rowKey="name"
              loading={loading}
              pagination={{ pageSize: 20, showSizeChanger: true }}
            />
          </Card>
        </TabPane>

        <TabPane 
          tab={
            <span>
              <FolderOutlined />
              ERROR ({errorFiles.length})
            </span>
          } 
          key="ERROR"
        >
          <Card>
            <div style={{ marginBottom: 16 }}>
              <Space direction="vertical">
                <div><strong>Description:</strong> {getStageInfo('ERROR', errorFiles).description}</div>
                <div><strong>Files:</strong> {getStageInfo('ERROR', errorFiles).count}</div>
                <div><strong>Total Size:</strong> {getStageInfo('ERROR', errorFiles).totalSize}</div>
              </Space>
            </div>
            <Table
              columns={getColumns('ERROR')}
              dataSource={errorFiles}
              rowKey="name"
              loading={loading}
              pagination={{ pageSize: 20, showSizeChanger: true }}
            />
          </Card>
        </TabPane>

        <TabPane 
          tab={
            <span>
              <FolderOutlined />
              ARCHIVE ({archiveFiles.length})
            </span>
          } 
          key="ARCHIVE"
        >
          <Card>
            <div style={{ marginBottom: 16 }}>
              <Space direction="vertical">
                <div><strong>Description:</strong> {getStageInfo('ARCHIVE', archiveFiles).description}</div>
                <div><strong>Files:</strong> {getStageInfo('ARCHIVE', archiveFiles).count}</div>
                <div><strong>Total Size:</strong> {getStageInfo('ARCHIVE', archiveFiles).totalSize}</div>
              </Space>
            </div>
            <Table
              columns={getColumns('ARCHIVE')}
              dataSource={archiveFiles}
              rowKey="name"
              loading={loading}
              pagination={{ pageSize: 20, showSizeChanger: true }}
            />
          </Card>
        </TabPane>
      </Tabs>
    </div>
  )
}

export default BronzeStages
