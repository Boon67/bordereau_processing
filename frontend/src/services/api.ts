import axios from 'axios'

const API_BASE_URL = import.meta.env.VITE_API_URL || '/api'

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
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
  TPA: string
  DATA_TYPE: string
  NULLABLE: boolean
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

export const apiService = {
  // TPA endpoints
  getTpas: async (): Promise<TPA[]> => {
    const response = await api.get('/tpas')
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

  // Silver endpoints
  getTargetSchemas: async (tpa: string, tableName?: string): Promise<TargetSchema[]> => {
    const response = await api.get('/silver/schemas', {
      params: { tpa, table_name: tableName },
    })
    return response.data
  },

  createTargetSchema: async (schema: Partial<TargetSchema>): Promise<any> => {
    const response = await api.post('/silver/schemas', schema)
    return response.data
  },

  createSilverTable: async (tableName: string, tpa: string): Promise<any> => {
    const response = await api.post('/silver/tables/create', { table_name: tableName, tpa })
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
}

export default api
