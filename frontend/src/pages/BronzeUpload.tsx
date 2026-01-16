import React, { useState } from 'react'
import { Upload, Button, Card, message, Progress, List, Checkbox } from 'antd'
import { InboxOutlined, CloudUploadOutlined } from '@ant-design/icons'
import type { UploadFile } from 'antd'
import { apiService } from '../services/api'

const { Dragger } = Upload

interface Props {
  selectedTpa: string
}

const BronzeUpload: React.FC<Props> = ({ selectedTpa }) => {
  const [fileList, setFileList] = useState<UploadFile[]>([])
  const [uploading, setUploading] = useState(false)
  const [uploadProgress, setUploadProgress] = useState(0)
  const [processNow, setProcessNow] = useState(true)

  const handleUpload = async () => {
    if (fileList.length === 0) {
      message.warning('Please select files to upload')
      return
    }

    if (!selectedTpa) {
      message.error('Please select a TPA')
      return
    }

    setUploading(true)
    setUploadProgress(0)

    const totalFiles = fileList.length
    let uploadedFiles = 0

    for (const file of fileList) {
      try {
        const fileObj = file.originFileObj || (file as any)
        if (!fileObj) {
          message.error(`Invalid file object for ${file.name}`)
          continue
        }
        await apiService.uploadFile(selectedTpa, fileObj as File)
        uploadedFiles++
        setUploadProgress((uploadedFiles / totalFiles) * 100)
        message.success(`Uploaded: ${file.name}`)
      } catch (error: any) {
        console.error('Upload error:', error)
        const errorMsg = error.response?.data?.detail || error.message || 'Unknown error'
        message.error(`Failed to upload ${file.name}: ${errorMsg}`)
      }
    }

    setUploading(false)
    setFileList([])
    
    if (uploadedFiles > 0) {
      message.success(`Successfully uploaded ${uploadedFiles} of ${totalFiles} files`)
      
      // Trigger processing if checkbox is checked
      if (processNow) {
        try {
          message.info('Triggering file discovery and processing...')
          await apiService.discoverFiles()
          await apiService.processQueue()
          message.success('Processing started! Check Processing Status for updates.')
        } catch (error) {
          message.warning('Files uploaded but auto-processing failed. Use Task Management to process manually.')
        }
      }
    }
  }

  const uploadProps = {
    multiple: true,
    fileList,
    beforeUpload: (file: File) => {
      const uploadFile: UploadFile = {
        uid: `${Date.now()}-${file.name}`,
        name: file.name,
        size: file.size,
        type: file.type,
        originFileObj: file as any,
      }
      setFileList(prev => [...prev, uploadFile])
      return false
    },
    onRemove: (file: UploadFile) => {
      setFileList(prev => prev.filter(f => f.uid !== file.uid))
    },
  }

  if (!selectedTpa) {
    return (
      <div>
        <h2>📤 Upload Files</h2>
        <Card style={{ marginTop: 16 }}>
          <p style={{ textAlign: 'center', padding: '40px', color: '#999' }}>
            Please select a TPA from the dropdown in the header to upload files.
          </p>
        </Card>
      </div>
    )
  }

  return (
    <div>
      <h2>📤 Upload Files</h2>
      <p>Upload CSV or Excel files for TPA: <strong>{selectedTpa}</strong></p>

      <Card style={{ marginTop: 16 }}>
        <Dragger {...uploadProps} accept=".csv,.xlsx,.xls">
          <p className="ant-upload-drag-icon">
            <InboxOutlined />
          </p>
          <p className="ant-upload-text">Click or drag files to this area to upload</p>
          <p className="ant-upload-hint">
            Support for CSV and Excel files. Files will be uploaded to @SRC/{selectedTpa}/
          </p>
        </Dragger>

        {fileList.length > 0 && (
          <div style={{ marginTop: 16 }}>
            <List
              size="small"
              dataSource={fileList}
              renderItem={file => (
                <List.Item>{file.name} ({(file.size! / 1024).toFixed(2)} KB)</List.Item>
              )}
            />
          </div>
        )}

        {uploading && (
          <div style={{ marginTop: 16 }}>
            <Progress percent={Math.round(uploadProgress)} status="active" />
          </div>
        )}

        <div style={{ marginTop: 16 }}>
          <Checkbox 
            checked={processNow} 
            onChange={(e) => setProcessNow(e.target.checked)}
            style={{ marginBottom: 16 }}
          >
            <strong>Process files immediately after upload</strong>
            <div style={{ fontSize: '12px', color: '#666', marginTop: 4 }}>
              Automatically discover and process uploaded files through the pipeline
            </div>
          </Checkbox>
        </div>

        <Button
          type="primary"
          icon={<CloudUploadOutlined />}
          onClick={handleUpload}
          disabled={fileList.length === 0 || uploading}
          loading={uploading}
          style={{ marginTop: 8 }}
          size="large"
        >
          Upload {fileList.length} File{fileList.length !== 1 ? 's' : ''}
        </Button>
      </Card>

      <Card style={{ marginTop: 16 }} title="ℹ️ Information">
        <p><strong>File Organization:</strong></p>
        <ul>
          <li>Files are uploaded to <code>@SRC/{selectedTpa}/</code></li>
          <li>Supported formats: CSV, Excel (.xlsx, .xls)</li>
          <li>Files are automatically discovered and processed by the task pipeline</li>
          <li>Processing status can be monitored in the "Processing Status" page</li>
        </ul>
      </Card>
    </div>
  )
}

export default BronzeUpload
