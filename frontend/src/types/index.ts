export interface TPA {
  TPA_CODE: string
  TPA_NAME: string
  TPA_DESCRIPTION?: string
  ACTIVE: boolean
  CREATED_TIMESTAMP?: string
  UPDATED_TIMESTAMP?: string
}

export interface FileQueueItem {
  QUEUE_ID: number
  FILE_NAME: string
  TPA: string
  FILE_TYPE: string
  FILE_SIZE_BYTES?: number
  STATUS: 'PENDING' | 'PROCESSING' | 'SUCCESS' | 'FAILED'
  DISCOVERED_TIMESTAMP: string
  PROCESSED_TIMESTAMP?: string
  ERROR_MESSAGE?: string
  PROCESS_RESULT?: string
  RETRY_COUNT: number
}

export interface RawDataRecord {
  RECORD_ID: number
  FILE_NAME: string
  FILE_ROW_NUMBER: number
  TPA: string
  RAW_DATA: any
  FILE_TYPE: string
  LOAD_TIMESTAMP: string
  LOADED_BY: string
}

export interface TargetSchema {
  SCHEMA_ID: number
  TABLE_NAME: string
  COLUMN_NAME: string
  TPA: string
  DATA_TYPE: string
  NULLABLE: boolean
  DEFAULT_VALUE?: string
  DESCRIPTION?: string
  CREATED_TIMESTAMP?: string
  UPDATED_TIMESTAMP?: string
  ACTIVE: boolean
}

export interface FieldMapping {
  MAPPING_ID: number
  SOURCE_FIELD: string
  SOURCE_TABLE: string
  TARGET_TABLE: string
  TARGET_COLUMN: string
  TPA: string
  MAPPING_METHOD: 'MANUAL' | 'ML_AUTO' | 'LLM_CORTEX' | 'SYSTEM'
  TRANSFORMATION_LOGIC?: string
  CONFIDENCE_SCORE?: number
  APPROVED: boolean
  APPROVED_BY?: string
  APPROVED_TIMESTAMP?: string
  DESCRIPTION?: string
  CREATED_TIMESTAMP?: string
  UPDATED_TIMESTAMP?: string
  ACTIVE: boolean
}

export interface TransformationRule {
  rule_id: string
  tpa: string
  rule_name: string
  rule_type: 'DATA_QUALITY' | 'BUSINESS_LOGIC' | 'STANDARDIZATION' | 'DEDUPLICATION' | 'REFERENTIAL_INTEGRITY'
  target_table?: string
  target_column?: string
  rule_logic: string
  error_action: 'REJECT' | 'QUARANTINE' | 'FLAG' | 'CORRECT'
  priority: number
  active: boolean
  description?: string
}

export interface ProcessingLog {
  log_id: number
  batch_id: string
  tpa: string
  source_table?: string
  target_table?: string
  processing_type: string
  status: string
  records_processed?: number
  records_success?: number
  records_failed?: number
  start_timestamp: string
  end_timestamp?: string
  duration_seconds?: number
  error_message?: string
}
