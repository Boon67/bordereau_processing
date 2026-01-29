import React, { useState, useEffect } from 'react'
import { Card, Typography, Button, Select, Space, message, Steps, Alert, Descriptions, Statistic, Row, Col, Progress, Timeline, Tag } from 'antd'
import { ThunderboltOutlined, DatabaseOutlined, ApiOutlined, PlayCircleOutlined, CheckCircleOutlined, ClockCircleOutlined, CloseCircleOutlined } from '@ant-design/icons'
import { apiService } from '../services/api'

const { Title } = Typography
const { Step } = Steps

interface SilverTransformProps {
  selectedTpa: string
  selectedTpaName?: string
}

const SilverTransform: React.FC<SilverTransformProps> = ({ selectedTpa, selectedTpaName }) => {
  const [loading, setLoading] = useState(false)
  const [sourceTable, setSourceTable] = useState<string>('RAW_DATA_TABLE')
  const [targetTable, setTargetTable] = useState<string>('')
  const [sourceTables, setSourceTables] = useState<string[]>(['RAW_DATA_TABLE'])
  const [targetTables, setTargetTables] = useState<string[]>([])
  const [currentStep, setCurrentStep] = useState(0)
  const [transformResult, setTransformResult] = useState<any>(null)
  const [transformHistory, setTransformHistory] = useState<any[]>([])

  useEffect(() => {
    if (selectedTpa) {
      loadTables()
    }
  }, [selectedTpa])

  const loadTables = async () => {
    if (!selectedTpa) return

    try {
      // Load created tables for this TPA
      const createdTables = await apiService.getSilverTables()
      
      // Filter to only tables for the selected TPA
      const tpaCreatedTables = createdTables.filter(
        (table: any) => table.TPA.toLowerCase() === selectedTpa.toLowerCase()
      )
      
      // Extract unique schema table names
      const uniqueTargets = Array.from(
        new Set(tpaCreatedTables.map((table: any) => table.SCHEMA_TABLE))
      )
      
      setTargetTables(uniqueTargets as string[])
    } catch (error) {
      message.error('Failed to load tables')
    }
  }

  const handleTransform = async () => {
    if (!sourceTable || !targetTable) {
      message.warning('Please select both source and target tables')
      return
    }

    if (!selectedTpa) {
      message.warning('Please select a TPA')
      return
    }

    setLoading(true)
    const startTime = new Date()
    try {
      const result = await apiService.transformBronzeToSilver(
        sourceTable,
        targetTable,
        selectedTpa
      )
      const endTime = new Date()
      const duration = (endTime.getTime() - startTime.getTime()) / 1000

      const transformData = {
        source: sourceTable,
        target: targetTable,
        tpa: selectedTpa,
        timestamp: startTime.toISOString(),
        duration: `${duration.toFixed(2)}s`,
        result: result,
        status: 'success'
      }

      setTransformResult(transformData)
      setTransformHistory(prev => [transformData, ...prev])
      message.success('Transformation completed successfully!')
      setCurrentStep(3)
    } catch (error: any) {
      const endTime = new Date()
      const duration = (endTime.getTime() - startTime.getTime()) / 1000

      const transformData = {
        source: sourceTable,
        target: targetTable,
        tpa: selectedTpa,
        timestamp: startTime.toISOString(),
        duration: `${duration.toFixed(2)}s`,
        error: error.response?.data?.detail || error.message,
        status: 'failed'
      }

      setTransformResult(transformData)
      setTransformHistory(prev => [transformData, ...prev])
      message.error(`Transformation failed: ${error.response?.data?.detail || error.message}`)
    } finally {
      setLoading(false)
    }
  }

  if (!selectedTpa) {
    return (
      <div>
        <Title level={2}>⚡ Transform</Title>
        <Card style={{ marginTop: 16 }}>
          <p style={{ textAlign: 'center', padding: '40px', color: '#999' }}>
            Please select a TPA from the dropdown in the header to perform transformations.
          </p>
        </Card>
      </div>
    )
  }

  return (
    <div>
      <Title level={2}>⚡ Transform Bronze to Silver</Title>
      
      <p style={{ marginBottom: 24, color: '#666' }}>
        Transform raw data from Bronze layer to structured tables in Silver layer. TPA: <strong>{selectedTpaName || selectedTpa}</strong>
      </p>

      <Card style={{ marginBottom: 24 }}>
        <Steps current={currentStep}>
          <Step title="Select Tables" icon={<DatabaseOutlined />} />
          <Step title="Verify Mappings" icon={<ApiOutlined />} />
          <Step title="Execute Transform" icon={<ThunderboltOutlined />} />
          <Step title="Complete" icon={<PlayCircleOutlined />} />
        </Steps>
      </Card>

      {currentStep === 0 && (
        <Card title="Step 1: Select Source and Target Tables">
          <Space direction="vertical" style={{ width: '100%' }} size="large">
            <div>
              <label style={{ display: 'block', marginBottom: 8, fontWeight: 'bold' }}>
                Source Table (Bronze Layer)
              </label>
              <Select
                value={sourceTable}
                onChange={setSourceTable}
                style={{ width: '100%' }}
                placeholder="Select source table"
                options={sourceTables.map(table => ({
                  label: table,
                  value: table,
                }))}
              />
              <div style={{ marginTop: 8, color: '#666', fontSize: '12px' }}>
                Raw data table containing unstructured data from uploaded files
              </div>
            </div>

            <div>
              <label style={{ display: 'block', marginBottom: 8, fontWeight: 'bold' }}>
                Target Table (Silver Layer)
              </label>
              <Select
                value={targetTable}
                onChange={setTargetTable}
                style={{ width: '100%' }}
                placeholder="Select target table"
                options={targetTables.map(table => ({
                  label: table,
                  value: table,
                }))}
                disabled={!sourceTable}
              />
              <div style={{ marginTop: 8, color: '#666', fontSize: '12px' }}>
                Structured table where transformed data will be stored
              </div>
            </div>

            <div style={{ marginTop: 16 }}>
              <Button
                type="primary"
                onClick={() => setCurrentStep(1)}
                disabled={!sourceTable || !targetTable}
              >
                Next: Verify Configuration
              </Button>
            </div>
          </Space>
        </Card>
      )}

      {currentStep >= 1 && (
        <Card title="Step 2: Verify Configuration" style={{ marginBottom: 16 }}>
          <Descriptions column={1} bordered>
            <Descriptions.Item label="TPA">{selectedTpa}</Descriptions.Item>
            <Descriptions.Item label="Source Table">{sourceTable}</Descriptions.Item>
            <Descriptions.Item label="Target Table">{targetTable}</Descriptions.Item>
          </Descriptions>

          <Alert
            style={{ marginTop: 16 }}
            message="Transformation Process"
            description={
              <ul style={{ marginBottom: 0 }}>
                <li>Extract data from Bronze layer raw data table</li>
                <li>Apply field mappings to transform data structure</li>
                <li>Execute data quality rules and validations</li>
                <li>Load transformed data into Silver layer target table</li>
              </ul>
            }
            type="info"
            showIcon
          />

          <div style={{ marginTop: 24 }}>
            <Space>
              <Button onClick={() => setCurrentStep(0)}>
                Back
              </Button>
              <Button 
                type="primary"
                onClick={() => setCurrentStep(2)}
              >
                Next
              </Button>
            </Space>
          </div>
        </Card>
      )}

      {currentStep >= 2 && (
        <Card title="Step 3: Execute Transformation">
          <Alert
            style={{ marginBottom: 16 }}
            message="Ready to Transform"
            description={`Click the button below to start transforming data from ${sourceTable} to ${targetTable} for TPA ${selectedTpa}.`}
            type="success"
            showIcon
          />

          <Space>
            <Button onClick={() => setCurrentStep(1)}>
              Back
            </Button>
            <Button
              type="primary"
              size="large"
              icon={<ThunderboltOutlined />}
              onClick={handleTransform}
              loading={loading}
            >
              Execute Transformation
            </Button>
          </Space>
        </Card>
      )}

      {currentStep === 3 && transformResult && (
        <Card>
          <Alert
            message={transformResult.status === 'success' ? 'Transformation Complete!' : 'Transformation Failed'}
            description={
              transformResult.status === 'success'
                ? 'Data has been successfully transformed from Bronze to Silver layer.'
                : transformResult.error
            }
            type={transformResult.status === 'success' ? 'success' : 'error'}
            showIcon
          />

          {transformResult.status === 'success' && (
            <div style={{ marginTop: 24 }}>
              <Row gutter={16}>
                <Col span={8}>
                  <Statistic
                    title="Source Table"
                    value={transformResult.source}
                    prefix={<DatabaseOutlined />}
                  />
                </Col>
                <Col span={8}>
                  <Statistic
                    title="Target Table"
                    value={transformResult.target}
                    prefix={<DatabaseOutlined />}
                  />
                </Col>
                <Col span={8}>
                  <Statistic
                    title="Duration"
                    value={transformResult.duration}
                    prefix={<ClockCircleOutlined />}
                  />
                </Col>
              </Row>

              {transformResult.result && (
                <Card title="Transformation Details" style={{ marginTop: 16 }} size="small">
                  <Descriptions column={1} size="small">
                    <Descriptions.Item label="TPA">{transformResult.tpa}</Descriptions.Item>
                    <Descriptions.Item label="Timestamp">{new Date(transformResult.timestamp).toLocaleString()}</Descriptions.Item>
                    <Descriptions.Item label="Status">
                      <Tag color="success" icon={<CheckCircleOutlined />}>Success</Tag>
                    </Descriptions.Item>
                  </Descriptions>
                </Card>
              )}
            </div>
          )}

          <div style={{ marginTop: 24 }}>
            <Button 
              type="primary"
              onClick={() => {
                setCurrentStep(0)
                setSourceTable('')
                setTargetTable('')
                setTransformResult(null)
              }}
            >
              Start New Transformation
            </Button>
          </div>
        </Card>
      )}

      {transformHistory.length > 0 && (
        <Card title="📋 Transformation History" style={{ marginTop: 16 }}>
          <Timeline>
            {transformHistory.map((item, index) => (
              <Timeline.Item
                key={index}
                color={item.status === 'success' ? 'green' : 'red'}
                dot={item.status === 'success' ? <CheckCircleOutlined /> : <CloseCircleOutlined />}
              >
                <div>
                  <strong>{item.source}</strong> → <strong>{item.target}</strong>
                </div>
                <div style={{ fontSize: '12px', color: '#999' }}>
                  {new Date(item.timestamp).toLocaleString()} • {item.duration} • TPA: {item.tpa}
                </div>
                {item.status === 'failed' && (
                  <div style={{ fontSize: '12px', color: '#ff4d4f', marginTop: 4 }}>
                    Error: {item.error}
                  </div>
                )}
              </Timeline.Item>
            ))}
          </Timeline>
        </Card>
      )}

      <Card title="ℹ️ Transformation Information" style={{ marginTop: 16 }}>
        <Space direction="vertical" size="small">
          <div><strong>Bronze Layer:</strong> Contains raw, unstructured data from uploaded files</div>
          <div><strong>Silver Layer:</strong> Contains cleaned, structured, and validated data</div>
          <div><strong>Field Mappings:</strong> Define how raw data fields map to target table columns</div>
          <div><strong>Data Quality Rules:</strong> Applied during transformation to ensure data integrity</div>
        </Space>
      </Card>
    </div>
  )
}

export default SilverTransform
