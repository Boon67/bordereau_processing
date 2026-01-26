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
  selectedTpaName?: string
}

const BronzeStages: React.FC<BronzeStagesProps> = ({ selectedTpaName }) => {
  const [loading, setLoading] = useState(false)
  const [srcFiles, setSrcFiles] = useState<StageFile[]>([])
  const [processingFiles, setProcessingFiles] = useState<StageFile[]>([])
  const [completedFiles, setCompletedFiles] = useState<StageFile[]>([])
  const [errorFiles, setErrorFiles] = useState<StageFile[]>([])
  const [archiveFiles, setArchiveFiles] = useState<StageFile[]>([])
  const [selectedRowKeys, setSelectedRowKeys] = useState<Record<string, React.Key[]>>({
    SRC: [],
    PROCESSING: [],
    COMPLETED: [],
    ERROR: [],
    ARCHIVE: []
  })
  const [bulkDeleting, setBulkDeleting] = useState(false)

  useEffect(() => {
    loadAllStages()
  }, [])

  const loadAllStages = async () => {
    setLoading(true)
    try {
      await Promise.all([
        loadStage('SRC', setSrcFiles),
        loadStage('PROCESSING', setProcessingFiles),
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
      reloadStage(stageName)
    } catch (error) {
      message.error('Failed to delete file')
      console.error('Delete error:', error)
    }
  }

  const handleBulkDelete = async (stageName: string) => {
    const selectedFiles = selectedRowKeys[stageName]
    if (selectedFiles.length === 0) {
      message.warning('Please select files to delete')
      return
    }

    setBulkDeleting(true)
    try {
      const result = await apiService.bulkDeleteStageFiles(stageName, selectedFiles as string[])
      
      if (result.results.failed.length === 0) {
        message.success(`Successfully deleted ${result.results.success.length} file(s)`)
      } else {
        message.warning(
          `Deleted ${result.results.success.length} file(s), ${result.results.failed.length} failed`
        )
      }
      
      // Clear selection and reload
      setSelectedRowKeys(prev => ({ ...prev, [stageName]: [] }))
      reloadStage(stageName)
    } catch (error) {
      message.error('Bulk delete failed')
      console.error('Bulk delete error:', error)
    } finally {
      setBulkDeleting(false)
    }
  }

  const reloadStage = (stageName: string) => {
    if (stageName === 'SRC') loadStage('SRC', setSrcFiles)
    else if (stageName === 'PROCESSING') loadStage('PROCESSING', setProcessingFiles)
    else if (stageName === 'COMPLETED') loadStage('COMPLETED', setCompletedFiles)
    else if (stageName === 'ERROR') loadStage('ERROR', setErrorFiles)
    else if (stageName === 'ARCHIVE') loadStage('ARCHIVE', setArchiveFiles)
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
      SRC: 'Source files (uploaded, queued, or being processed)',
      PROCESSING: 'Reserved for future use',
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
              <Space direction="vertical" style={{ width: '100%' }}>
                <Space>
                  <div><strong>Description:</strong> {getStageInfo('SRC', srcFiles).description}</div>
                </Space>
                <Space>
                  <div><strong>Files:</strong> {getStageInfo('SRC', srcFiles).count}</div>
                  <div><strong>Total Size:</strong> {getStageInfo('SRC', srcFiles).totalSize}</div>
                </Space>
                {selectedRowKeys.SRC.length > 0 && (
                  <Space>
                    <Popconfirm
                      title={`Delete ${selectedRowKeys.SRC.length} selected file(s)?`}
                      description="This will remove the files from the stage and update the processing queue."
                      onConfirm={() => handleBulkDelete('SRC')}
                      okText="Yes, delete all"
                      cancelText="Cancel"
                    >
                      <Button 
                        type="primary" 
                        danger 
                        icon={<DeleteOutlined />}
                        loading={bulkDeleting}
                      >
                        Delete Selected ({selectedRowKeys.SRC.length})
                      </Button>
                    </Popconfirm>
                    <Button 
                      onClick={() => setSelectedRowKeys(prev => ({ ...prev, SRC: [] }))}
                    >
                      Clear Selection
                    </Button>
                  </Space>
                )}
              </Space>
            </div>
            <Table
              columns={getColumns('SRC')}
              dataSource={srcFiles}
              rowKey="name"
              loading={loading}
              pagination={{ pageSize: 20, showSizeChanger: true }}
              rowSelection={{
                selectedRowKeys: selectedRowKeys.SRC,
                onChange: (keys) => setSelectedRowKeys(prev => ({ ...prev, SRC: keys })),
              }}
            />
          </Card>
        </TabPane>

        <TabPane 
          tab={
            <span>
              <FolderOutlined />
              PROCESSING ({processingFiles.length})
            </span>
          } 
          key="PROCESSING"
        >
          <Card>
            <div style={{ marginBottom: 16 }}>
              <Space direction="vertical" style={{ width: '100%' }}>
                <Space>
                  <div><strong>Description:</strong> {getStageInfo('PROCESSING', processingFiles).description}</div>
                </Space>
                <Space>
                  <div><strong>Files:</strong> {getStageInfo('PROCESSING', processingFiles).count}</div>
                  <div><strong>Total Size:</strong> {getStageInfo('PROCESSING', processingFiles).totalSize}</div>
                </Space>
                {selectedRowKeys.PROCESSING.length > 0 && (
                  <Space>
                    <Popconfirm
                      title={`Delete ${selectedRowKeys.PROCESSING.length} selected file(s)?`}
                      description="This will remove the files from the stage and update the processing queue."
                      onConfirm={() => handleBulkDelete('PROCESSING')}
                      okText="Yes, delete all"
                      cancelText="Cancel"
                    >
                      <Button 
                        type="primary" 
                        danger 
                        icon={<DeleteOutlined />}
                        loading={bulkDeleting}
                      >
                        Delete Selected ({selectedRowKeys.PROCESSING.length})
                      </Button>
                    </Popconfirm>
                    <Button 
                      onClick={() => setSelectedRowKeys(prev => ({ ...prev, PROCESSING: [] }))}
                    >
                      Clear Selection
                    </Button>
                  </Space>
                )}
              </Space>
            </div>
            <Table
              columns={getColumns('PROCESSING')}
              dataSource={processingFiles}
              rowKey="name"
              loading={loading}
              pagination={{ pageSize: 20, showSizeChanger: true }}
              rowSelection={{
                selectedRowKeys: selectedRowKeys.PROCESSING,
                onChange: (keys) => setSelectedRowKeys(prev => ({ ...prev, PROCESSING: keys })),
              }}
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
              <Space direction="vertical" style={{ width: '100%' }}>
                <Space>
                  <div><strong>Description:</strong> {getStageInfo('COMPLETED', completedFiles).description}</div>
                </Space>
                <Space>
                  <div><strong>Files:</strong> {getStageInfo('COMPLETED', completedFiles).count}</div>
                  <div><strong>Total Size:</strong> {getStageInfo('COMPLETED', completedFiles).totalSize}</div>
                </Space>
                {selectedRowKeys.COMPLETED.length > 0 && (
                  <Space>
                    <Popconfirm
                      title={`Delete ${selectedRowKeys.COMPLETED.length} selected file(s)?`}
                      description="This will remove the files from the stage and update the processing queue."
                      onConfirm={() => handleBulkDelete('COMPLETED')}
                      okText="Yes, delete all"
                      cancelText="Cancel"
                    >
                      <Button 
                        type="primary" 
                        danger 
                        icon={<DeleteOutlined />}
                        loading={bulkDeleting}
                      >
                        Delete Selected ({selectedRowKeys.COMPLETED.length})
                      </Button>
                    </Popconfirm>
                    <Button 
                      onClick={() => setSelectedRowKeys(prev => ({ ...prev, COMPLETED: [] }))}
                    >
                      Clear Selection
                    </Button>
                  </Space>
                )}
              </Space>
            </div>
            <Table
              columns={getColumns('COMPLETED')}
              dataSource={completedFiles}
              rowKey="name"
              loading={loading}
              pagination={{ pageSize: 20, showSizeChanger: true }}
              rowSelection={{
                selectedRowKeys: selectedRowKeys.COMPLETED,
                onChange: (keys) => setSelectedRowKeys(prev => ({ ...prev, COMPLETED: keys })),
              }}
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
              <Space direction="vertical" style={{ width: '100%' }}>
                <Space>
                  <div><strong>Description:</strong> {getStageInfo('ERROR', errorFiles).description}</div>
                </Space>
                <Space>
                  <div><strong>Files:</strong> {getStageInfo('ERROR', errorFiles).count}</div>
                  <div><strong>Total Size:</strong> {getStageInfo('ERROR', errorFiles).totalSize}</div>
                </Space>
                {selectedRowKeys.ERROR.length > 0 && (
                  <Space>
                    <Popconfirm
                      title={`Delete ${selectedRowKeys.ERROR.length} selected file(s)?`}
                      description="This will remove the files from the stage and update the processing queue."
                      onConfirm={() => handleBulkDelete('ERROR')}
                      okText="Yes, delete all"
                      cancelText="Cancel"
                    >
                      <Button 
                        type="primary" 
                        danger 
                        icon={<DeleteOutlined />}
                        loading={bulkDeleting}
                      >
                        Delete Selected ({selectedRowKeys.ERROR.length})
                      </Button>
                    </Popconfirm>
                    <Button 
                      onClick={() => setSelectedRowKeys(prev => ({ ...prev, ERROR: [] }))}
                    >
                      Clear Selection
                    </Button>
                  </Space>
                )}
              </Space>
            </div>
            <Table
              columns={getColumns('ERROR')}
              dataSource={errorFiles}
              rowKey="name"
              loading={loading}
              pagination={{ pageSize: 20, showSizeChanger: true }}
              rowSelection={{
                selectedRowKeys: selectedRowKeys.ERROR,
                onChange: (keys) => setSelectedRowKeys(prev => ({ ...prev, ERROR: keys })),
              }}
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
              <Space direction="vertical" style={{ width: '100%' }}>
                <Space>
                  <div><strong>Description:</strong> {getStageInfo('ARCHIVE', archiveFiles).description}</div>
                </Space>
                <Space>
                  <div><strong>Files:</strong> {getStageInfo('ARCHIVE', archiveFiles).count}</div>
                  <div><strong>Total Size:</strong> {getStageInfo('ARCHIVE', archiveFiles).totalSize}</div>
                </Space>
                {selectedRowKeys.ARCHIVE.length > 0 && (
                  <Space>
                    <Popconfirm
                      title={`Delete ${selectedRowKeys.ARCHIVE.length} selected file(s)?`}
                      description="This will remove the files from the stage and update the processing queue."
                      onConfirm={() => handleBulkDelete('ARCHIVE')}
                      okText="Yes, delete all"
                      cancelText="Cancel"
                    >
                      <Button 
                        type="primary" 
                        danger 
                        icon={<DeleteOutlined />}
                        loading={bulkDeleting}
                      >
                        Delete Selected ({selectedRowKeys.ARCHIVE.length})
                      </Button>
                    </Popconfirm>
                    <Button 
                      onClick={() => setSelectedRowKeys(prev => ({ ...prev, ARCHIVE: [] }))}
                    >
                      Clear Selection
                    </Button>
                  </Space>
                )}
              </Space>
            </div>
            <Table
              columns={getColumns('ARCHIVE')}
              dataSource={archiveFiles}
              rowKey="name"
              loading={loading}
              pagination={{ pageSize: 20, showSizeChanger: true }}
              rowSelection={{
                selectedRowKeys: selectedRowKeys.ARCHIVE,
                onChange: (keys) => setSelectedRowKeys(prev => ({ ...prev, ARCHIVE: keys })),
              }}
            />
          </Card>
        </TabPane>
      </Tabs>
    </div>
  )
}

export default BronzeStages
