# File Movement Issue and Solution

## Problem
The `discover_files()` procedure is successfully:
1. Finding files in @SRC stage
2. Adding them to the `file_processing_queue` table

But it's failing to:
3. Move files from @SRC to @PROCESSING stage

## Root Cause
The `COPY FILES ... FROM ...` and `REMOVE` commands in Snowpark Python are not working as expected. The files remain in @SRC after the procedure runs.

## Solution
Instead of trying to physically move files between stages, we'll:
1. Keep files in their original location (@SRC/tpa/filename)
2. Update the processing logic to read from @SRC
3. Only move files AFTER successful processing to @COMPLETED or @ERROR

This approach:
- Simplifies the workflow
- Reduces points of failure
- Ensures files are only moved once (after processing)
- Maintains the queue status as the source of truth

## Implementation
1. Remove the COPY/REMOVE logic from `discover_files()`
2. Update `process_queued_files()` to read from @SRC
3. Keep `move_processed_files()` and `move_failed_files()` to move to final destinations

## File Flow
- **@SRC**: Source files (uploaded, waiting to be processed)
- **@PROCESSING**: Not used (can be deprecated or used for future enhancements)
- **@COMPLETED**: Successfully processed files
- **@ERROR**: Failed files (after max retries)
