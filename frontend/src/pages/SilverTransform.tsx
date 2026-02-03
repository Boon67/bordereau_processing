import React, { useState, useEffect } from 'react'
import { Card, Typography, Button, Select, Space, message, Steps, Alert, Descriptions, Statistic, Row, Col, Progress, Timeline, Tag, Table, Spin } from 'antd'
import { ThunderboltOutlined, DatabaseOutlined, ApiOutlined, PlayCircleOutlined, CheckCircleOutlined, ClockCircleOutlined, CloseCircleOutlined, ArrowRightOutlined } from '@ant-design/icons'
import { apiService } from '../services/api'
import type { FieldMapping } from '../services/api'
import TPASelector from '../components/TPASelector'

const { Title } = Typography
const { Step } = Steps

interface SilverTransformProps {
  selectedTpa: string
  setSelectedTpa: (tpa: string) => void
  tpas: Array<{ TPA_CODE: string; TPA_NAME: string }>
  selectedTpaName?: string
}

const SilverTransform: React.FC<SilverTransformProps> = ({ selectedTpa, setSelectedTpa, tpas, selectedTpaName }) => {
  // Add CSS for pending mapping rows
  React.useEffect(() => {
    const style = document.createElement('style')
    style.innerHTML = `
      .pending-mapping-row {
        background-color: #fffbe6 !important;
      }
      .pending-mapping-row:hover {
        background-color: #fff7cc !important;
      }
    `
    document.head.appendChild(style)
    return () => {
      document.head.removeChild(style)
    }
  }, [])

  const [loading, setLoading] = useState(false)
  const [loadingTables, setLoadingTables] = useState(true)
  const [sourceTable, setSourceTable] = useState<string>('RAW_DATA_TABLE')
  const [targetTable, setTargetTable] = useState<string>('')
  const [sourceTables, setSourceTables] = useState<string[]>(['RAW_DATA_TABLE'])
  const [targetTables, setTargetTables] = useState<string[]>([])
  const [tableMapping, setTableMapping] = useState<Record<string, string>>({}) // Maps physical table name to schema table name
  const [currentStep, setCurrentStep] = useState(0)
  const [transformResult, setTransformResult] = useState<any>(null)
  const [transformHistory, setTransformHistory] = useState<any[]>([])
  const [fieldMappings, setFieldMappings] = useState<FieldMapping[]>([])
  const [loadingMappings, setLoadingMappings] = useState(false)

  useEffect(() => {
    if (selectedTpa) {
      loadTables()
    }
  }, [selectedTpa])

  const loadTables = async () => {
    if (!selectedTpa) return

    setLoadingTables(true)
    try {
      // Load created tables for this TPA
      const createdTables = await apiService.getSilverTables()
      
      // Filter to only tables for the selected TPA
      const tpaCreatedTables = createdTables.filter(
        (table: any) => table.TPA.toLowerCase() === selectedTpa.toLowerCase()
      )
      
      // Extract unique physical table names (e.g., PROVIDER_A_DENTAL_CLAIMS)
      const uniqueTargets = Array.from(
        new Set(tpaCreatedTables.map((table: any) => table.TABLE_NAME))
      )
      
      // Create mapping from physical table name to schema table name
      const mapping: Record<string, string> = {}
      tpaCreatedTables.forEach((table: any) => {
        mapping[table.TABLE_NAME] = table.SCHEMA_TABLE
      })
      
      setTargetTables(uniqueTargets as string[])
      setTableMapping(mapping)
      
      // Auto-select source table (always RAW_DATA_TABLE)
      setSourceTable('RAW_DATA_TABLE')
      
      // Auto-select first target table if only one exists
      if (uniqueTargets.length === 1) {
        setTargetTable(uniqueTargets[0] as string)
        // Stay on step 0 to show the diagram, but table is pre-selected
        setCurrentStep(0)
      } else if (uniqueTargets.length > 1) {
        // Clear selection if multiple tables exist
        setTargetTable('')
        // Stay on step 0 so user can select which table
        setCurrentStep(0)
      } else {
        // No tables - stay on step 0 to show error
        setCurrentStep(0)
      }
    } catch (error) {
      message.error('Failed to load tables')
    } finally {
      setLoadingTables(false)
    }
  }

  const loadFieldMappingsForTable = async (physicalTableName: string, mapping: Record<string, string>) => {
    if (!selectedTpa) return

    setLoadingMappings(true)
    try {
      // Use schema table name for fetching mappings
      const schemaTableName = mapping[physicalTableName] || physicalTableName
      const mappings = await apiService.getFieldMappings(selectedTpa, schemaTableName)
      setFieldMappings(mappings)
      
      const approvedCount = mappings.filter(m => m.APPROVED).length
      const totalCount = mappings.length
      
      if (totalCount === 0) {
        message.warning('No field mappings found for this table. Please create mappings first.')
      } else if (approvedCount === 0) {
        message.warning(`Found ${totalCount} mappings but none are approved. Please approve mappings before transforming.`)
      } else if (approvedCount < totalCount) {
        message.info(`${approvedCount} of ${totalCount} mappings are approved and ready for transformation.`)
      } else {
        message.success(`All ${totalCount} mappings are approved and ready for transformation.`)
      }
    } catch (error) {
      message.error('Failed to load field mappings')
      setFieldMappings([])
    } finally {
      setLoadingMappings(false)
    }
  }

  const loadFieldMappings = async () => {
    if (!selectedTpa || !targetTable) return
    await loadFieldMappingsForTable(targetTable, tableMapping)
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
      // Use schema table name for transformation (procedure builds physical name internally)
      const schemaTableName = tableMapping[targetTable] || targetTable
      const result = await apiService.transformBronzeToSilver(
        sourceTable,
        schemaTableName,
        selectedTpa
      )
      const endTime = new Date()
      const duration = (endTime.getTime() - startTime.getTime()) / 1000

      // Parse the result message to extract record count
      // Backend returns: { message: "...", result: "SUCCESS: Transformed X records..." }
      const resultMessage = result.result || result.message || ''
      console.log('Transform result:', result)
      console.log('Result message:', resultMessage)
      console.log('Result message type:', typeof resultMessage)
      
      // Try multiple patterns to extract record count
      let recordCountMatch = resultMessage.match(/Transformed\s+(\d+)\s+records?/i)
      if (!recordCountMatch) {
        // Try pattern with "from" and "to"
        recordCountMatch = resultMessage.match(/(\d+)\s+records?.*from/i)
      }
      if (!recordCountMatch) {
        // Try to find any number followed by "record"
        recordCountMatch = resultMessage.match(/(\d+)\s+record/i)
      }
      
      const recordCount = recordCountMatch ? parseInt(recordCountMatch[1]) : null
      
      console.log('Record count match:', recordCountMatch)
      console.log('Parsed record count:', recordCount)

      // Check if the result indicates an error (even though HTTP status was 200)
      const isError = resultMessage.toUpperCase().startsWith('ERROR')
      
      const transformData = {
        source: sourceTable,
        target: targetTable,
        tpa: selectedTpa,
        timestamp: startTime.toISOString(),
        duration: `${duration.toFixed(2)}s`,
        result: result,
        resultMessage: resultMessage,
        recordCount: recordCount,
        status: isError ? 'failed' : 'success',
        error: isError ? resultMessage : undefined
      }

      setTransformResult(transformData)
      setTransformHistory(prev => [transformData, ...prev])
      
      if (isError) {
        message.error(`Transformation failed: ${resultMessage}`)
      } else if (recordCount !== null && recordCount > 0) {
        message.success(`Transformation completed! ${recordCount} record(s) processed.`)
      } else {
        message.success(`Transformation job has been started successfully. Data is being processed.`)
      }
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
      
      <div style={{ marginBottom: 24 }}>
        <label style={{ display: 'block', marginBottom: 8, fontWeight: 500 }}>Filter by TPA:</label>
        <TPASelector
          value={selectedTpa}
          onChange={setSelectedTpa}
          tpas={tpas}
          placeholder="Select TPA"
        />
      </div>

      <p style={{ marginBottom: 24, color: '#666' }}>
        Transform raw data from Bronze layer to structured tables in Silver layer. TPA: <strong>{selectedTpaName || selectedTpa}</strong>
      </p>

      <Card style={{ marginBottom: 24 }}>
        <Steps current={currentStep}>
          <Step 
            title={targetTables.length === 1 ? "Tables" : "Select Tables"}
            icon={<DatabaseOutlined />}
            description={targetTables.length === 1 ? "Pre-selected" : undefined}
          />
          <Step title="Verify Mappings" icon={<ApiOutlined />} />
          <Step title="Execute Transform" icon={<ThunderboltOutlined />} />
          <Step title="Complete" icon={<PlayCircleOutlined />} />
        </Steps>
      </Card>

      {currentStep === 0 && (
        <Card title={targetTables.length === 1 ? "Tables Pre-Selected" : "Select Source and Target Tables"}>
          <Space direction="vertical" style={{ width: '100%' }} size="large">
            {loadingTables ? (
              <div style={{ textAlign: 'center', padding: '40px 0' }}>
                <Spin size="large" />
                <p style={{ marginTop: 16, color: '#666' }}>Loading tables...</p>
              </div>
            ) : targetTables.length === 0 ? (
              <Alert
                message="No Target Tables Found"
                description={
                  <div>
                    <p>No tables have been created for TPA <strong>{selectedTpaName || selectedTpa}</strong>.</p>
                    <p style={{ marginTop: 8 }}>
                      Please go to <strong>Schemas and Tables</strong> page to create a table first.
                    </p>
                  </div>
                }
                type="warning"
                showIcon
              />
            ) : targetTables.length === 1 ? (
              <>
                <Alert
                  message="Tables Auto-Selected"
                  description={`Source and target tables are pre-defined for this TPA. Proceeding to verify mappings...`}
                  type="success"
                  showIcon
                />
                {/* Show the visual flow even when auto-selected */}
                <div style={{ 
                  display: 'flex', 
                  alignItems: 'center', 
                  justifyContent: 'center',
                  padding: '24px',
                  background: '#f5f5f5',
                  borderRadius: '8px',
                  gap: '24px'
                }}>
                  {/* Source Table */}
                  <div style={{
                    flex: 1,
                    maxWidth: '400px',
                    background: '#fff',
                    border: '2px solid #ffccc7',
                    borderRadius: '8px',
                    padding: '20px',
                    textAlign: 'center'
                  }}>
                    <div style={{ color: '#cf1322', fontWeight: 'bold', marginBottom: '8px' }}>
                      <DatabaseOutlined style={{ fontSize: '20px', marginRight: '8px' }} />
                      Bronze Layer
                    </div>
                    <div style={{ 
                      fontSize: '18px', 
                      fontWeight: 'bold',
                      color: '#262626',
                      marginBottom: '8px'
                    }}>
                      {sourceTable}
                    </div>
                    <div style={{ fontSize: '12px', color: '#8c8c8c' }}>
                      Raw unstructured data
                    </div>
                  </div>

                  {/* Arrow */}
                  <div style={{ fontSize: '32px', color: '#1890ff' }}>
                    <ArrowRightOutlined />
                  </div>

                  {/* Target Table */}
                  <div style={{
                    flex: 1,
                    maxWidth: '400px',
                    background: '#fff',
                    border: '2px solid #b7eb8f',
                    borderRadius: '8px',
                    padding: '20px',
                    textAlign: 'center'
                  }}>
                    <div style={{ color: '#389e0d', fontWeight: 'bold', marginBottom: '8px' }}>
                      <DatabaseOutlined style={{ fontSize: '20px', marginRight: '8px' }} />
                      Silver Layer
                    </div>
                    <div style={{ 
                      fontSize: '18px', 
                      fontWeight: 'bold',
                      color: '#262626',
                      marginBottom: '8px'
                    }}>
                      {targetTable}
                    </div>
                    <div style={{ fontSize: '12px', color: '#8c8c8c' }}>
                      Structured validated data
                    </div>
                  </div>
                </div>
              </>
            ) : (
              <>
                {/* Visual Flow Display */}
                <div style={{ 
                  display: 'flex', 
                  alignItems: 'center', 
                  justifyContent: 'center',
                  padding: '24px',
                  background: '#f5f5f5',
                  borderRadius: '8px',
                  gap: '24px'
                }}>
                  {/* Source Table */}
                  <div style={{
                    flex: 1,
                    maxWidth: '400px',
                    background: '#fff',
                    border: '2px solid #ffccc7',
                    borderRadius: '8px',
                    padding: '20px',
                    textAlign: 'center'
                  }}>
                    <div style={{ color: '#cf1322', fontWeight: 'bold', marginBottom: '8px' }}>
                      <DatabaseOutlined style={{ fontSize: '20px', marginRight: '8px' }} />
                      Bronze Layer
                    </div>
                    <div style={{ 
                      fontSize: '18px', 
                      fontWeight: 'bold',
                      color: '#262626',
                      marginBottom: '8px'
                    }}>
                      {sourceTable}
                    </div>
                    <div style={{ fontSize: '12px', color: '#8c8c8c' }}>
                      Raw unstructured data
                    </div>
                  </div>

                  {/* Arrow */}
                  <div style={{ fontSize: '32px', color: '#1890ff' }}>
                    <ArrowRightOutlined />
                  </div>

                  {/* Target Table */}
                  <div style={{
                    flex: 1,
                    maxWidth: '400px',
                    background: '#fff',
                    border: targetTable ? '2px solid #b7eb8f' : '2px dashed #d9d9d9',
                    borderRadius: '8px',
                    padding: '20px',
                    textAlign: 'center'
                  }}>
                    <div style={{ color: '#389e0d', fontWeight: 'bold', marginBottom: '8px' }}>
                      <DatabaseOutlined style={{ fontSize: '20px', marginRight: '8px' }} />
                      Silver Layer
                    </div>
                    {targetTable ? (
                      <>
                        <div style={{ 
                          fontSize: '18px', 
                          fontWeight: 'bold',
                          color: '#262626',
                          marginBottom: '8px'
                        }}>
                          {targetTable}
                        </div>
                        <div style={{ fontSize: '12px', color: '#8c8c8c' }}>
                          Structured validated data
                        </div>
                      </>
                    ) : (
                      <div style={{ color: '#8c8c8c', fontStyle: 'italic' }}>
                        No table selected
                      </div>
                    )}
                  </div>
                </div>

                {/* Target Table Selection (only if multiple tables) */}
                {targetTables.length > 1 && (
                  <div>
                    <label style={{ display: 'block', marginBottom: 8, fontWeight: 'bold' }}>
                      Select Target Table:
                    </label>
                    <Select
                      value={targetTable}
                      onChange={setTargetTable}
                      style={{ width: '100%' }}
                      placeholder="Select target table to transform"
                      options={targetTables.map(table => ({
                        label: table,
                        value: table,
                      }))}
                    />
                    <div style={{ marginTop: 8, color: '#666', fontSize: '12px' }}>
                      Multiple tables exist for this TPA - select one to transform
                    </div>
                  </div>
                )}
              </>
            )}

            <div style={{ marginTop: 16 }}>
              <Button
                type="primary"
                onClick={() => {
                  setCurrentStep(1)
                  loadFieldMappings()
                }}
                disabled={!sourceTable || !targetTable}
              >
                Next: Verify Mappings
              </Button>
            </div>
          </Space>
        </Card>
      )}

      {currentStep === 1 && (
        <Card title="Verify Mappings" style={{ marginBottom: 16 }}>
          <Descriptions column={1} bordered style={{ marginBottom: 16 }}>
            <Descriptions.Item label="TPA">{selectedTpa}</Descriptions.Item>
            <Descriptions.Item label="Source Table">{sourceTable}</Descriptions.Item>
            <Descriptions.Item label="Target Table">{targetTable}</Descriptions.Item>
          </Descriptions>

          {loadingMappings ? (
            <div style={{ textAlign: 'center', padding: '40px' }}>
              <Progress type="circle" percent={50} status="active" />
              <p style={{ marginTop: 16 }}>Loading field mappings...</p>
            </div>
          ) : fieldMappings.length === 0 ? (
            <Alert
              message="No Field Mappings Found"
              description={
                <div>
                  <p>No field mappings have been created for this table yet.</p>
                  <p style={{ marginTop: 8 }}>
                    Please go to <strong>Field Mappings</strong> page to create mappings before running the transformation.
                  </p>
                </div>
              }
              type="warning"
              showIcon
              style={{ marginBottom: 16 }}
            />
          ) : (
            <>
              <Alert
                message="Field Mappings"
                description={
                  <div>
                    <p>The following field mappings will be applied during transformation:</p>
                    <p style={{ marginTop: 8 }}>
                      <strong>Total Mappings:</strong> {fieldMappings.length} | 
                      <strong style={{ marginLeft: 8, color: '#52c41a' }}>Approved:</strong> {fieldMappings.filter(m => m.APPROVED).length} | 
                      <strong style={{ marginLeft: 8, color: '#faad14' }}>Pending:</strong> {fieldMappings.filter(m => !m.APPROVED).length}
                    </p>
                  </div>
                }
                type="info"
                showIcon
                style={{ marginBottom: 16 }}
              />

              <Table
                columns={[
                  {
                    title: 'Source Field',
                    dataIndex: 'SOURCE_FIELD',
                    key: 'SOURCE_FIELD',
                    width: 200,
                    render: (text: string, record: FieldMapping) => (
                      <div>
                        <strong>{text}</strong>
                        <div style={{ fontSize: '11px', color: '#999' }}>from {record.SOURCE_TABLE}</div>
                      </div>
                    ),
                  },
                  {
                    title: '',
                    key: 'arrow',
                    width: 60,
                    align: 'center' as const,
                    render: () => <ArrowRightOutlined style={{ fontSize: '18px', color: '#1890ff' }} />,
                  },
                  {
                    title: 'Target Column',
                    dataIndex: 'TARGET_COLUMN',
                    key: 'TARGET_COLUMN',
                    width: 200,
                    render: (text: string, record: FieldMapping) => (
                      <div>
                        <strong>{text}</strong>
                        <div style={{ fontSize: '11px', color: '#999' }}>in {record.TARGET_TABLE}</div>
                      </div>
                    ),
                  },
                  {
                    title: 'Method',
                    dataIndex: 'MAPPING_METHOD',
                    key: 'MAPPING_METHOD',
                    width: 120,
                    render: (method: string) => {
                      const methodConfig: Record<string, { color: string; label: string }> = {
                        MANUAL: { color: 'blue', label: 'Manual' },
                        ML_AUTO: { color: 'green', label: 'ML Auto' },
                        LLM_CORTEX: { color: 'purple', label: 'LLM' },
                        SYSTEM: { color: 'default', label: 'System' },
                      }
                      const config = methodConfig[method] || { color: 'default', label: method }
                      return <Tag color={config.color}>{config.label}</Tag>
                    },
                  },
                  {
                    title: 'Confidence',
                    dataIndex: 'CONFIDENCE_SCORE',
                    key: 'CONFIDENCE_SCORE',
                    width: 120,
                    render: (score: number | null) => {
                      if (score === null || score === undefined) return '-'
                      const percentage = Math.round(score * 100)
                      return (
                        <div style={{ width: 80 }}>
                          <Progress 
                            percent={percentage} 
                            size="small"
                            status={percentage >= 80 ? 'success' : percentage >= 60 ? 'normal' : 'exception'}
                            showInfo={false}
                          />
                          <div style={{ fontSize: '11px', textAlign: 'center' }}>{percentage}%</div>
                        </div>
                      )
                    },
                  },
                  {
                    title: 'Status',
                    dataIndex: 'APPROVED',
                    key: 'APPROVED',
                    width: 100,
                    render: (approved: boolean) => (
                      approved ? (
                        <Tag color="success" icon={<CheckCircleOutlined />}>Approved</Tag>
                      ) : (
                        <Tag color="warning">Pending</Tag>
                      )
                    ),
                  },
                  {
                    title: 'Transformation',
                    dataIndex: 'TRANSFORMATION_LOGIC',
                    key: 'TRANSFORMATION_LOGIC',
                    ellipsis: true,
                    render: (logic: string) => {
                      if (!logic) return <span style={{ color: '#999' }}>Direct mapping</span>
                      return (
                        <code style={{ fontSize: '11px', background: '#f5f5f5', padding: '2px 6px', borderRadius: 3 }}>
                          {logic}
                        </code>
                      )
                    },
                  },
                ]}
                dataSource={fieldMappings}
                rowKey="MAPPING_ID"
                pagination={false}
                size="small"
                rowClassName={(record: FieldMapping) => !record.APPROVED ? 'pending-mapping-row' : ''}
              />

              {fieldMappings.filter(m => !m.APPROVED).length > 0 && (
                <Alert
                  message="Pending Mappings"
                  description={
                    <div>
                      <p>
                        {fieldMappings.filter(m => !m.APPROVED).length} mapping(s) are not yet approved. 
                        Only approved mappings will be used in the transformation.
                      </p>
                      <p style={{ marginTop: 8 }}>
                        Go to <strong>Field Mappings</strong> page to approve pending mappings.
                      </p>
                    </div>
                  }
                  type="warning"
                  showIcon
                  style={{ marginTop: 16 }}
                />
              )}
            </>
          )}

          <div style={{ marginTop: 24 }}>
            <Space>
              <Button onClick={() => setCurrentStep(0)}>
                Back
              </Button>
              <Button 
                type="primary"
                onClick={() => setCurrentStep(2)}
                disabled={fieldMappings.filter(m => m.APPROVED).length === 0}
              >
                Next: Execute Transform
              </Button>
            </Space>
          </div>
        </Card>
      )}

      {currentStep === 2 && (
        <Card title="Execute Transformation">
          <Alert
            style={{ marginBottom: 16 }}
            message="Ready to Transform"
            description={`Click the button below to start transforming data from ${sourceTable} to ${targetTable} for TPA ${selectedTpaName || selectedTpa}.`}
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
        <Card title="Transformation Complete">
          <Alert
            message={transformResult.status === 'success' ? 'Transformation Complete!' : 'Transformation Failed'}
            description={
              transformResult.status === 'success'
                ? (transformResult.recordCount !== null && transformResult.recordCount > 0
                    ? `Successfully transformed ${transformResult.recordCount} record(s) from Bronze to Silver layer.`
                    : 'Transformation job has been started successfully. Data is being processed from Bronze to Silver layer.')
                : transformResult.error || transformResult.resultMessage
            }
            type={transformResult.status === 'success' ? 'success' : 'error'}
            showIcon
          />

          {transformResult.status === 'success' && (
            <div style={{ marginTop: 24 }}>
              <Row gutter={16}>
                <Col span={6}>
                  <Statistic
                    title="Records Processed"
                    value={transformResult.recordCount !== null ? transformResult.recordCount : 'N/A'}
                    prefix={<DatabaseOutlined />}
                    valueStyle={{ color: '#3f8600' }}
                  />
                </Col>
                <Col span={6}>
                  <Statistic
                    title="Source Table"
                    value={transformResult.source}
                    prefix={<DatabaseOutlined />}
                  />
                </Col>
                <Col span={6}>
                  <Statistic
                    title="Target Table"
                    value={transformResult.target}
                    prefix={<DatabaseOutlined />}
                  />
                </Col>
                <Col span={6}>
                  <Statistic
                    title="Duration"
                    value={transformResult.duration}
                    prefix={<ClockCircleOutlined />}
                  />
                </Col>
              </Row>

              <Card title="Transformation Details" style={{ marginTop: 16 }} size="small">
                <Descriptions column={1} size="small">
                  <Descriptions.Item label="TPA">{transformResult.tpa}</Descriptions.Item>
                  <Descriptions.Item label="Timestamp">{new Date(transformResult.timestamp).toLocaleString()}</Descriptions.Item>
                  <Descriptions.Item label="Status">
                    <Tag color={transformResult.status === 'success' ? 'success' : 'error'} 
                         icon={transformResult.status === 'success' ? <CheckCircleOutlined /> : <CloseCircleOutlined />}>
                      {transformResult.status === 'success' ? 'Success' : 'Failed'}
                    </Tag>
                  </Descriptions.Item>
                  {transformResult.resultMessage && (
                    <Descriptions.Item label="Result">
                      <div style={{ 
                        fontFamily: 'monospace', 
                        fontSize: '12px', 
                        padding: '8px', 
                        background: '#f5f5f5', 
                        borderRadius: '4px',
                        whiteSpace: 'pre-wrap'
                      }}>
                        {transformResult.resultMessage}
                      </div>
                    </Descriptions.Item>
                  )}
                </Descriptions>
              </Card>
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
                  {item.status === 'success' && item.recordCount !== null && (
                    <Tag color="success" style={{ marginLeft: 8 }}>
                      {item.recordCount} record{item.recordCount !== 1 ? 's' : ''}
                    </Tag>
                  )}
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
