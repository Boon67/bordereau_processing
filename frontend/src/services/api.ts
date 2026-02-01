import axios from 'axios'

const API_BASE_URL = import.meta.env.VITE_API_URL || '/api'

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
  withCredentials: true, // Enable sending cookies with cross-origin requests
})

export interface TPA {
  TPA_CODE: string
  TPA_NAME: string
  TPA_DESCRIPTION?: string
  ACTIVE: boolean
}

export interface FileQueueItem {
  QUEUE_ID: number
  FILE_NAME: string
  TPA: string
  FILE_TYPE: string
  STATUS: string
  DISCOVERED_TIMESTAMP: string
  PROCESSED_TIMESTAMP?: string
  ERROR_MESSAGE?: string
}

export interface RawDataRecord {
  RECORD_ID: number
  FILE_NAME: string
  FILE_ROW_NUMBER: number
  TPA: string
  RAW_DATA: any
  FILE_TYPE: string
  LOAD_TIMESTAMP: string
}

export interface TargetSchema {
  SCHEMA_ID: number
  TABLE_NAME: string
  COLUMN_NAME: string
  DATA_TYPE: string
  NULLABLE: boolean
  DEFAULT_VALUE?: string
  DESCRIPTION?: string
}

export interface FieldMapping {
  MAPPING_ID: number
  SOURCE_TABLE: string
  SOURCE_FIELD: string
  TARGET_TABLE: string
  TARGET_COLUMN: string
  TPA: string
  MAPPING_METHOD: string
  CONFIDENCE_SCORE?: number
  APPROVED: boolean
  TRANSFORMATION_LOGIC?: string
}

export interface UserInfo {
  username: string
  role: string
  warehouse: string
  database: string
  schema: string
  account: string
  region: string
}

export const apiService = {
  // User endpoints
  getCurrentUser: async (): Promise<UserInfo> => {
    const response = await api.get('/user/current')
    return response.data
  },

  // TPA endpoints
  getTpas: async (): Promise<TPA[]> => {
    const response = await api.get('/tpas')
    return response.data
  },

  createTpa: async (tpa: { tpa_code: string; tpa_name: string; tpa_description?: string; active?: boolean }): Promise<any> => {
    const response = await api.post('/tpas', tpa)
    return response.data
  },

  updateTpa: async (tpaCode: string, tpa: { tpa_name?: string; tpa_description?: string; active?: boolean }): Promise<any> => {
    const response = await api.put(`/tpas/${tpaCode}`, tpa)
    return response.data
  },

  deleteTpa: async (tpaCode: string): Promise<any> => {
    const response = await api.delete(`/tpas/${tpaCode}`)
    return response.data
  },

  updateTpaStatus: async (tpaCode: string, active: boolean): Promise<any> => {
    const response = await api.patch(`/tpas/${tpaCode}/status`, { active })
    return response.data
  },

  // Bronze endpoints
  uploadFile: async (tpa: string, file: File): Promise<any> => {
    const formData = new FormData()
    formData.append('file', file)
    formData.append('tpa', tpa)
    const response = await api.post('/bronze/upload', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    })
    return response.data
  },

  getProcessingQueue: async (tpa?: string): Promise<FileQueueItem[]> => {
    const response = await api.get('/bronze/queue', { params: { tpa } })
    return response.data
  },

  getProcessingStatus: async (): Promise<any> => {
    const response = await api.get('/bronze/status')
    return response.data
  },

  getBronzeStats: async (tpa?: string): Promise<any> => {
    const response = await api.get('/bronze/stats', {
      params: tpa ? { tpa } : {},
    })
    return response.data
  },

  getRawData: async (tpa: string, fileName?: string, limit = 100): Promise<RawDataRecord[]> => {
    const response = await api.get('/bronze/raw-data', {
      params: { tpa, file_name: fileName, limit },
    })
    return response.data
  },

  listStageFiles: async (stage: string): Promise<any[]> => {
    const response = await api.get(`/bronze/stages/${stage}`)
    return response.data
  },

  deleteStageFile: async (stage: string, filePath: string): Promise<any> => {
    const response = await api.delete(`/bronze/stages/${stage}/files`, {
      params: { file_path: filePath },
    })
    return response.data
  },

  bulkDeleteStageFiles: async (stage: string, filePaths: string[]): Promise<any> => {
    const response = await api.post(`/bronze/stages/${stage}/files/bulk-delete`, filePaths)
    return response.data
  },

  discoverFiles: async (): Promise<any> => {
    const response = await api.post('/bronze/discover')
    return response.data
  },

  processQueue: async (): Promise<any> => {
    const response = await api.post('/bronze/process')
    return response.data
  },

  reprocessFile: async (queueId: number): Promise<any> => {
    const response = await api.post(`/bronze/reprocess/${queueId}`)
    return response.data
  },

  clearAllData: async (): Promise<any> => {
    const response = await api.post('/bronze/clear-all-data')
    return response.data
  },

  deleteFileData: async (fileName: string, tpa: string): Promise<any> => {
    const response = await api.delete(`/bronze/data/file/${encodeURIComponent(fileName)}`, {
      params: { tpa }
    })
    return response.data
  },

  getTasks: async (): Promise<any[]> => {
    const response = await api.get('/bronze/tasks')
    return response.data
  },

  resumeTask: async (taskName: string): Promise<any> => {
    const response = await api.post(`/bronze/tasks/${taskName}/resume`)
    return response.data
  },

  suspendTask: async (taskName: string): Promise<any> => {
    const response = await api.post(`/bronze/tasks/${taskName}/suspend`)
    return response.data
  },

  updateTaskSchedule: async (taskName: string, schedule: string): Promise<any> => {
    const response = await api.put(`/bronze/tasks/${taskName}/schedule`, { schedule })
    return response.data
  },

  // Silver endpoints
  getSilverTasks: async (): Promise<any[]> => {
    const response = await api.get('/silver/tasks')
    return response.data
  },

  resumeSilverTask: async (taskName: string): Promise<any> => {
    const response = await api.post(`/silver/tasks/${taskName}/resume`)
    return response.data
  },

  suspendSilverTask: async (taskName: string): Promise<any> => {
    const response = await api.post(`/silver/tasks/${taskName}/suspend`)
    return response.data
  },

  updateSilverTaskSchedule: async (taskName: string, schedule: string): Promise<any> => {
    const response = await api.put(`/silver/tasks/${taskName}/schedule`, { schedule })
    return response.data
  },
  getTargetSchemas: async (tableName?: string): Promise<TargetSchema[]> => {
    const response = await api.get('/silver/schemas', {
      params: { table_name: tableName },
    })
    return response.data
  },

  createTargetSchema: async (schema: Partial<TargetSchema>): Promise<any> => {
    const response = await api.post('/silver/schemas', {
      table_name: schema.TABLE_NAME,
      column_name: schema.COLUMN_NAME,
      data_type: schema.DATA_TYPE,
      nullable: schema.NULLABLE,
      default_value: schema.DEFAULT_VALUE,
      description: schema.DESCRIPTION,
    })
    return response.data
  },

  updateTargetSchema: async (schemaId: number, schema: Partial<TargetSchema>): Promise<any> => {
    // Only send fields that are actually defined
    const payload: any = {}
    if (schema.DATA_TYPE !== undefined) payload.data_type = schema.DATA_TYPE
    if (schema.NULLABLE !== undefined) payload.nullable = schema.NULLABLE
    if (schema.DEFAULT_VALUE !== undefined) payload.default_value = schema.DEFAULT_VALUE
    if (schema.DESCRIPTION !== undefined) payload.description = schema.DESCRIPTION
    
    const response = await api.put(`/silver/schemas/${schemaId}`, payload)
    return response.data
  },

  deleteTargetSchema: async (schemaId: number): Promise<any> => {
    const response = await api.delete(`/silver/schemas/${schemaId}`)
    return response.data
  },

  deleteTableSchema: async (tableName: string, tpa: string): Promise<any> => {
    const response = await api.delete(`/silver/schemas/table/${tableName}`, {
      params: { tpa }
    })
    return response.data
  },

  getSilverTables: async (): Promise<any[]> => {
    const response = await api.get('/silver/tables')
    return response.data
  },

  getSourceFields: async (tpa: string): Promise<string[]> => {
    const response = await api.get('/bronze/source-fields', {
      params: { tpa },
    })
    return response.data
  },

  getTargetColumns: async (tableName: string): Promise<string[]> => {
    const response = await api.get(`/silver/schemas/${tableName}/columns`)
    return response.data
  },

  getCortexModels: async (): Promise<string[]> => {
    const response = await api.get('/silver/cortex-models')
    return response.data
  },

  checkTableExists: async (tableName: string, tpa: string): Promise<{ exists: boolean; physical_table_name: string }> => {
    const response = await api.get('/silver/tables/exists', {
      params: { table_name: tableName, tpa }
    })
    return response.data
  },

  getSilverData: async (tpa: string, tableName: string, limit: number = 100): Promise<any> => {
    const response = await api.get('/silver/data', {
      params: { tpa, table_name: tableName, limit }
    })
    return response.data
  },

  getSilverDataStats: async (tpa: string, tableName: string): Promise<any> => {
    const response = await api.get('/silver/data/stats', {
      params: { tpa, table_name: tableName }
    })
    return response.data
  },

  createSilverTable: async (tableName: string, tpa: string): Promise<any> => {
    const response = await api.post('/silver/tables/create', null, {
      params: { table_name: tableName, tpa }
    })
    return response.data
  },

  deletePhysicalTable: async (tableName: string, tpa: string): Promise<any> => {
    const response = await api.delete('/silver/tables/delete', {
      params: { table_name: tableName, tpa }
    })
    return response.data
  },

  getFieldMappings: async (tpa: string, targetTable?: string): Promise<FieldMapping[]> => {
    const response = await api.get('/silver/mappings', {
      params: { tpa, target_table: targetTable },
    })
    return response.data
  },

  createFieldMapping: async (mapping: Partial<FieldMapping>): Promise<any> => {
    const response = await api.post('/silver/mappings', {
      source_table: mapping.SOURCE_TABLE,
      source_field: mapping.SOURCE_FIELD,
      target_table: mapping.TARGET_TABLE,
      target_column: mapping.TARGET_COLUMN,
      tpa: mapping.TPA,
      mapping_method: mapping.MAPPING_METHOD,
      transformation_logic: mapping.TRANSFORMATION_LOGIC,
      approved: mapping.APPROVED,
    })
    return response.data
  },

  autoMapFieldsML: async (
    sourceTable: string,
    targetTable: string,
    tpa: string,
    topN = 3,
    minConfidence = 0.6
  ): Promise<any> => {
    const response = await api.post('/silver/mappings/auto-ml', {
      source_table: sourceTable,
      target_table: targetTable,
      tpa,
      top_n: topN,
      min_confidence: minConfidence,
    })
    return response.data
  },

  autoMapFieldsLLM: async (
    sourceTable: string,
    targetTable: string,
    tpa: string,
    modelName = 'llama3.1-70b'
  ): Promise<any> => {
    const response = await api.post('/silver/mappings/auto-llm', {
      source_table: sourceTable,
      target_table: targetTable,
      tpa,
      model_name: modelName,
    })
    return response.data
  },

  approveMapping: async (mappingId: number): Promise<any> => {
    const response = await api.post(`/silver/mappings/${mappingId}/approve`)
    return response.data
  },

  declineMapping: async (mappingId: number): Promise<any> => {
    const response = await api.delete(`/silver/mappings/${mappingId}`)
    return response.data
  },

  transformBronzeToSilver: async (
    sourceTable: string,
    targetTable: string,
    tpa: string,
    options: any = {}
  ): Promise<any> => {
    const response = await api.post('/silver/transform', {
      source_table: sourceTable,
      target_table: targetTable,
      tpa,
      ...options,
    })
    return response.data
  },

  // Gold endpoints
  getGoldTasks: async (): Promise<any[]> => {
    const response = await api.get('/gold/tasks')
    return response.data
  },

  resumeGoldTask: async (taskName: string): Promise<any> => {
    const response = await api.post(`/gold/tasks/${taskName}/resume`)
    return response.data
  },

  suspendGoldTask: async (taskName: string): Promise<any> => {
    const response = await api.post(`/gold/tasks/${taskName}/suspend`)
    return response.data
  },

  updateGoldTaskSchedule: async (taskName: string, schedule: string): Promise<any> => {
    const response = await api.put(`/gold/tasks/${taskName}/schedule`, { schedule })
    return response.data
  },

  getGoldTableData: async (tableName: string, tpa: string, limit = 100): Promise<any[]> => {
    const response = await api.get(`/gold/analytics/${tableName}`, {
      params: { tpa, limit },
    })
    return response.data
  },

  getGoldStats: async (tableName: string, tpa: string): Promise<any> => {
    const response = await api.get(`/gold/analytics/${tableName}/stats`, {
      params: { tpa },
    })
    return response.data
  },

  getBusinessMetrics: async (tpa: string): Promise<any[]> => {
    const response = await api.get('/gold/metrics', {
      params: { tpa },
    })
    return response.data
  },

  getQualityCheckResults: async (tpa: string, limit = 100): Promise<any[]> => {
    const response = await api.get('/gold/quality/results', {
      params: { tpa, limit },
    })
    return response.data
  },

  getQualityStats: async (tpa: string): Promise<any> => {
    const response = await api.get('/gold/quality/stats', {
      params: { tpa },
    })
    return response.data
  },

  getTransformationRules: async (tpa: string): Promise<any[]> => {
    const response = await api.get('/gold/rules/transformation', {
      params: { tpa },
    })
    return response.data
  },

  getQualityRules: async (tpa: string): Promise<any[]> => {
    const response = await api.get('/gold/rules/quality', {
      params: { tpa },
    })
    return response.data
  },

  updateRuleStatus: async (ruleId: number, isActive: boolean, ruleType: 'transformation' | 'quality'): Promise<any> => {
    const endpoint = ruleType === 'transformation'
      ? `/gold/rules/transformation/${ruleId}/status`
      : `/gold/rules/quality/${ruleId}/status`
    const response = await api.patch(endpoint, { is_active: isActive })
    return response.data
  },

  // Logging endpoints
  getApplicationLogs: async (params?: { limit?: number; level?: string; source?: string; days?: number }): Promise<any[]> => {
    const response = await api.get('/logs/application', { params })
    return response.data
  },

  getTaskExecutionLogs: async (params?: { limit?: number; task_name?: string; status?: string; days?: number }): Promise<any[]> => {
    const response = await api.get('/logs/tasks', { params })
    return response.data
  },

  getFileProcessingLogs: async (params?: { limit?: number; file_name?: string; stage?: string; tpa?: string; days?: number }): Promise<any[]> => {
    const response = await api.get('/logs/file-processing', { params })
    return response.data
  },

  getErrorLogs: async (params?: { limit?: number; source?: string; resolution_status?: string; days?: number }): Promise<any[]> => {
    const response = await api.get('/logs/errors', { params })
    return response.data
  },

  getAPIRequestLogs: async (params?: { limit?: number; method?: string; path?: string; min_response_time?: number; days?: number }): Promise<any[]> => {
    const response = await api.get('/logs/api-requests', { params })
    return response.data
  },

  getLogStatistics: async (days?: number): Promise<any[]> => {
    const response = await api.get('/logs/stats', { params: { days } })
    return response.data
  },
}

export default api
