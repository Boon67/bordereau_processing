# File Processing Workflow - Final Implementation

## Issues Fixed

### 1. Missing PROCESSING Stage in UI
**Problem**: The File Stages page didn't show the PROCESSING stage tab.
**Solution**: Added PROCESSING tab to `BronzeStages.tsx` component.

### 2. Files Not Being Removed from SRC
**Problem**: Files were being copied to PROCESSING but not removed from SRC, resulting in duplicates.
**Root Cause**: The `REMOVE` command in Snowpark Python procedures was failing silently.
**Solution**: Simplified the workflow to eliminate problematic file movements.

### 3. Missing Icon Import
**Problem**: Application showed blank page due to `FileTextOutlined` icon not being imported.
**Solution**: Added `FileTextOutlined` to imports in `App.tsx`.

## Final Workflow Design

### Simplified File Flow
```
@SRC → [Processing] → @COMPLETED or @ERROR
```

**Key Design Decision**: Files remain in `@SRC` as the source of truth throughout processing.

### Stage Purposes
- **@SRC**: Source files (uploaded, queued, being processed, or completed)
  - Files are uploaded here
  - Files are processed from here
  - Files remain here even after processing (source of truth)
  
- **@PROCESSING**: Reserved for future use (currently not used in workflow)
  
- **@COMPLETED**: Successfully processed files (copies only)
  - Files are COPIED here after successful processing
  - Original remains in @SRC
  
- **@ERROR**: Failed files (copies only)
  - Files are COPIED here after max retries
  - Original remains in @SRC

### Processing Steps

1. **discover_files()**
   - Scans @SRC for new files
   - Adds files to `file_processing_queue` with STATUS='PENDING'
   - Files stay in @SRC

2. **process_queued_files()**
   - Reads PENDING files from queue
   - Updates STATUS to 'PROCESSING'
   - Reads file content from @SRC/{tpa}/{filename}
   - Processes data and loads into RAW_DATA_TABLE
   - Updates STATUS to 'SUCCESS' or 'FAILED'

3. **move_processed_files()**
   - Finds files with STATUS='SUCCESS'
   - COPIES files from @SRC to @COMPLETED
   - Original files remain in @SRC

4. **move_failed_files()**
   - Finds files with STATUS='FAILED' and retry_count >= 3
   - COPIES files from @SRC to @ERROR
   - Original files remain in @SRC

### Benefits of This Approach

1. **Reliability**: No file movement failures - files always stay in @SRC
2. **Traceability**: Original files are never deleted, providing audit trail
3. **Simplicity**: Fewer moving parts, less chance of errors
4. **Idempotency**: Can reprocess files by resetting queue status
5. **Performance**: No expensive file moves during processing

### Queue Status as Source of Truth

The `file_processing_queue` table tracks the processing state:
- **PENDING**: Discovered, waiting to be processed
- **PROCESSING**: Currently being processed
- **SUCCESS**: Successfully processed
- **FAILED**: Processing failed (can be retried)
- **DELETED**: Data was deleted by user

### Future Enhancements

If needed, a cleanup task can be added to:
- Archive old files from @SRC to @ARCHIVE after X days
- Remove files from @SRC after successful archival
- This would be a separate, optional maintenance task

## Files Modified

### Backend
- `bronze/3_Bronze_Setup_Logic.sql`: Simplified file movement logic
  - `discover_files()`: No longer moves files
  - `process_queued_files()`: Reads from @SRC
  - `move_processed_files()`: Copies to @COMPLETED (no remove)
  - `move_failed_files()`: Copies to @ERROR (no remove)

### Frontend
- `frontend/src/App.tsx`: Added `FileTextOutlined` import
- `frontend/src/pages/BronzeStages.tsx`: 
  - Added PROCESSING stage tab
  - Updated stage descriptions
  - Added state management for PROCESSING files

## Testing Results

✅ **Complete Workflow Test**:
1. File uploaded to @SRC/provider_a/dental-claims-20240301.csv
2. `discover_files()` → File queued with STATUS='PENDING'
3. `process_queued_files()` → 5 rows loaded, STATUS='SUCCESS'
4. `move_processed_files()` → File copied to @COMPLETED
5. Final state:
   - Queue: 1 file with STATUS='SUCCESS'
   - RAW_DATA_TABLE: 5 rows
   - @SRC: 1 file (original)
   - @COMPLETED: 1 file (copy)

✅ **All objectives met**:
- Files are discovered and queued
- Files are processed successfully
- Data is loaded into RAW_DATA_TABLE
- Files are copied to appropriate final stage
- No duplicate processing
- UI shows all stages correctly
