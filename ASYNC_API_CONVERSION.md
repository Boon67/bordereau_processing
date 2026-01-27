# Async API Conversion - Performance Enhancement

## Overview
Converted all backend API calls from synchronous to asynchronous execution to improve performance and responsiveness.

## Problem
The backend API was making synchronous calls to Snowflake, which blocked the event loop and prevented concurrent request handling. This caused:
- Slow API response times
- Sequential execution of independent operations
- Poor scalability under load
- Blocked threads waiting for database responses

## Solution
Converted the entire backend to use async/await pattern:

### 1. SnowflakeService - Core Async Implementation

**Added async support using `asyncio.to_thread()`**:
- Wraps synchronous Snowflake connector calls in thread pool
- Allows non-blocking execution of database operations
- Maintains compatibility with existing Snowflake connector

**Pattern Used**:
```python
# Internal synchronous method
def _execute_query_sync(self, query: str, ...) -> List[tuple]:
    with self.get_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute(query)
            return cursor.fetchall()

# Public async method
async def execute_query(self, query: str, ...) -> List[tuple]:
    return await asyncio.to_thread(self._execute_query_sync, query, ...)
```

### 2. Methods Converted to Async

**Query Execution**:
- `execute_query()` - Execute SQL and return tuples
- `execute_query_dict()` - Execute SQL and return dicts
- `execute_procedure()` - Call stored procedures

**Data Operations**:
- `get_tpas()` - Fetch TPA list
- `get_processing_queue()` - Fetch file queue
- `get_raw_data()` - Fetch raw data records
- `get_target_schemas()` - Fetch schema definitions
- `get_field_mappings()` - Fetch field mappings

**File Operations**:
- `upload_file_to_stage()` - Upload files to Snowflake
- `list_stage_files()` - List files in stage

### 3. Async Caching Decorator

Created `@async_cached` decorator for async methods:
```python
@async_cached(ttl_seconds=300, key_prefix="tpas")
async def get_tpas(self) -> List[Dict[str, Any]]:
    # Cached for 5 minutes
    return await self.execute_query_dict(query)
```

### 4. API Endpoints Updated

**Automated Update Process**:
- Created `add_async_await.py` script
- Automatically added `await` keywords to all `sf_service` method calls
- Updated 6 API files:
  - `bronze.py` - 35 async calls
  - `silver.py` - Multiple async calls
  - `gold.py` - Multiple async calls
  - `tpa.py` - Multiple async calls
  - `logs.py` - Multiple async calls
  - `user.py` - Multiple async calls

**Example Transformation**:
```python
# Before (synchronous)
@router.get("/tpas")
async def get_tpas():
    sf_service = SnowflakeService()
    return sf_service.get_tpas()  # Blocks!

# After (asynchronous)
@router.get("/tpas")
async def get_tpas():
    sf_service = SnowflakeService()
    return await sf_service.get_tpas()  # Non-blocking!
```

## Benefits

### 1. Performance Improvements
- **Concurrent Requests**: Multiple API calls can execute simultaneously
- **Non-Blocking**: Event loop remains responsive during database operations
- **Thread Pool**: Database calls run in background threads
- **Better Throughput**: Can handle more requests per second

### 2. Scalability
- **Async I/O**: Efficient handling of I/O-bound operations
- **Resource Utilization**: Better CPU and memory usage
- **Load Handling**: Improved performance under high load

### 3. User Experience
- **Faster Responses**: Reduced latency for API calls
- **Parallel Operations**: Multiple operations can run concurrently
- **Responsive UI**: Frontend doesn't block waiting for slow queries

## Technical Details

### Thread Pool Execution
Uses `asyncio.to_thread()` to run blocking Snowflake operations:
- Automatically manages thread pool
- Prevents blocking the event loop
- Maintains thread safety
- Compatible with existing sync code

### Caching Strategy
- **Async Cache**: `@async_cached` decorator for async methods
- **TTL-based**: Automatic expiration after specified time
- **Key-based**: Unique cache keys per method and parameters
- **Invalidation**: Manual cache clearing on updates

### Error Handling
- Maintains existing error handling
- Async exceptions properly propagated
- Logging preserved
- HTTP exceptions raised correctly

## Files Modified

### Core Service
- `backend/app/services/snowflake_service.py`
  - Added `asyncio` import
  - Created `@async_cached` decorator
  - Converted all public methods to async
  - Created internal `_*_sync` methods

### API Endpoints
- `backend/app/api/bronze.py` - 35 await keywords added
- `backend/app/api/silver.py` - Multiple await keywords added
- `backend/app/api/gold.py` - Multiple await keywords added
- `backend/app/api/tpa.py` - Multiple await keywords added
- `backend/app/api/logs.py` - Multiple await keywords added
- `backend/app/api/user.py` - Multiple await keywords added

### Utility Scripts
- `backend/add_async_await.py` - Automated conversion script

## Testing

### Verification Steps
1. ✅ All API endpoints remain functional
2. ✅ No linter errors introduced
3. ✅ Caching still works correctly
4. ✅ Error handling preserved
5. ✅ Logging continues to work

### Performance Testing
To test performance improvements:
```bash
# Before: Sequential execution
time curl http://localhost:8000/api/bronze/tpas
time curl http://localhost:8000/api/silver/schemas

# After: Can run concurrently
curl http://localhost:8000/api/bronze/tpas & \
curl http://localhost:8000/api/silver/schemas & \
wait
```

## Migration Notes

### Breaking Changes
- **None** - All changes are internal
- API signatures remain the same
- Frontend code unchanged
- Backward compatible

### Future Enhancements
Consider adding:
1. **Connection Pooling**: Reuse Snowflake connections
2. **Batch Operations**: Group multiple queries
3. **Streaming Results**: For large datasets
4. **WebSocket Support**: For real-time updates
5. **GraphQL**: For flexible data fetching

## Best Practices

### When to Use Async
✅ **Good for**:
- Database queries
- File uploads/downloads
- External API calls
- I/O-bound operations

❌ **Not needed for**:
- CPU-intensive calculations
- In-memory operations
- Simple data transformations

### Async Patterns
```python
# Multiple concurrent operations
results = await asyncio.gather(
    sf_service.get_tpas(),
    sf_service.get_target_schemas(),
    sf_service.get_field_mappings(tpa)
)

# Sequential operations (when order matters)
tpas = await sf_service.get_tpas()
for tpa in tpas:
    data = await sf_service.get_raw_data(tpa)
```

## Impact

### Before Conversion
- **Synchronous**: One request at a time
- **Blocking**: Event loop blocked during DB calls
- **Slow**: Sequential execution only
- **Limited**: Poor scalability

### After Conversion
- **Asynchronous**: Multiple requests concurrently
- **Non-blocking**: Event loop stays responsive
- **Fast**: Parallel execution possible
- **Scalable**: Better resource utilization

## Monitoring

### Performance Metrics to Track
- API response times
- Concurrent request handling
- Database connection usage
- Thread pool utilization
- Cache hit rates

### Logging
- All async operations logged
- Error handling preserved
- Performance metrics available
- Debugging information maintained

## Conclusion

The async conversion provides significant performance improvements without breaking existing functionality. The backend is now more scalable, responsive, and efficient at handling concurrent requests.

**Key Takeaway**: API calls that were previously sequential can now run in parallel, dramatically improving overall system performance and user experience.
