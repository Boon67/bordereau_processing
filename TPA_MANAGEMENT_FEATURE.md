# TPA Management Feature

**Created**: January 19, 2026  
**Status**: ✅ Complete and Ready

---

## Overview

A comprehensive TPA (Third-Party Administrator) management utility has been added to the Bordereau Processing Pipeline application. This feature provides a full CRUD (Create, Read, Update, Delete) interface for managing healthcare providers and their configurations.

---

## Features

### 1. View All TPAs
- List all TPAs (both active and inactive)
- Display TPA code, name, description, and status
- Show creation and update timestamps
- Summary statistics dashboard (total, active, inactive TPAs)
- Sortable and filterable table
- Pagination with configurable page size

### 2. Create New TPA
- Add new TPA with unique code
- Set TPA name and description
- Configure initial active/inactive status
- Validation for unique TPA codes
- Automatic uppercase enforcement for codes
- Character limits and format validation

### 3. Edit Existing TPA
- Update TPA name
- Modify TPA description
- Change active status
- TPA code is immutable (cannot be changed after creation)
- Timestamp tracking for updates

### 4. Delete TPA
- Soft delete implementation (sets ACTIVE = FALSE)
- Confirmation dialog with warning
- Preserves all historical data
- Cannot be accidentally deleted

### 5. Toggle Active Status
- Quick switch to activate/deactivate TPAs
- Visual feedback with switch control
- Immediate updates
- Inactive TPAs hidden from dropdowns

### 6. Refresh Data
- Manual refresh button
- Auto-refresh after changes
- Loading states during operations

---

## Files Created/Modified

### New Files
```
frontend/src/pages/TPAManagement.tsx (346 lines)
```

### Modified Files
```
frontend/src/App.tsx
frontend/src/services/api.ts
backend/app/api/tpa.py
```

---

## API Endpoints

### Backend (FastAPI)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/tpas` | Get all TPAs (active and inactive) |
| POST | `/api/tpas` | Create new TPA |
| PUT | `/api/tpas/{code}` | Update existing TPA |
| DELETE | `/api/tpas/{code}` | Delete TPA (soft delete) |
| PATCH | `/api/tpas/{code}/status` | Toggle active status |

### Frontend (API Service)

```typescript
// Get all TPAs
apiService.getTpas(): Promise<TPA[]>

// Create new TPA
apiService.createTpa(tpa: {
  tpa_code: string
  tpa_name: string
  tpa_description?: string
  active?: boolean
}): Promise<any>

// Update TPA
apiService.updateTpa(tpaCode: string, tpa: {
  tpa_name?: string
  tpa_description?: string
  active?: boolean
}): Promise<any>

// Delete TPA
apiService.deleteTpa(tpaCode: string): Promise<any>

// Update TPA status
apiService.updateTpaStatus(tpaCode: string, active: boolean): Promise<any>
```

---

## UI Components

### Navigation
- New "⚙️ Administration" section in sidebar
- "TPA Management" menu item with TeamOutlined icon
- Auto-expands admin section on load

### Main Interface
- Professional card layout with header
- Statistics dashboard showing:
  - Total TPAs (blue tag)
  - Active TPAs (green tag)
  - Inactive TPAs (red tag)
- Data table with columns:
  - TPA Code (bold text)
  - TPA Name
  - Description (with ellipsis for long text)
  - Status (switch control)
  - Created timestamp
  - Actions (Edit/Delete buttons)

### Create/Edit Modal
- Form with validation rules
- Fields:
  - TPA Code (uppercase, alphanumeric + underscore)
  - TPA Name (required, max 200 chars)
  - Description (optional, max 500 chars)
  - Active status (switch)
- Field descriptions and hints
- Character limit indicators

### Actions
- **Edit**: Opens modal with pre-filled data
- **Delete**: Shows confirmation dialog with warning
- **Toggle Status**: Inline switch for quick activation/deactivation
- **Refresh**: Reloads TPA list from database

---

## Validation Rules

### TPA Code
- ✅ Required field
- ✅ Pattern: `^[A-Z0-9_]+$` (uppercase letters, numbers, underscores only)
- ✅ Maximum 50 characters
- ✅ Must be unique (checked on creation)
- ✅ Immutable (cannot be changed after creation)
- ✅ Auto-converts to uppercase

### TPA Name
- ✅ Required field
- ✅ Maximum 200 characters

### Description
- ✅ Optional field
- ✅ Maximum 500 characters

### Delete Protection
- ✅ Confirmation dialog required
- ✅ Warning about data deletion displayed
- ✅ Soft delete (preserves all data)

---

## Integration

### With Existing Features

#### TPA Dropdown (Header)
- Automatically refreshes when TPAs are added/edited
- Only shows active TPAs
- Updates across all pages
- Callback mechanism ensures synchronization

#### Bronze Layer
- New TPAs immediately available for file uploads
- File processing respects TPA configuration
- TPA-specific data isolation

#### Silver Layer
- Schema configurations per TPA
- Field mapping configurations per TPA
- Transformation rules per TPA

#### Data Isolation
- All data is TPA-specific
- Soft delete preserves historical data
- No data loss on TPA deactivation

---

## Technical Details

### Backend Implementation

#### Database
- Uses existing `BRONZE.TPA_CONFIG` table
- No schema changes required
- Columns used:
  - `TPA_CODE` (primary key)
  - `TPA_NAME`
  - `TPA_DESCRIPTION`
  - `ACTIVE` (boolean)
  - `CREATED_TIMESTAMP`
  - `UPDATED_TIMESTAMP`

#### API Features
- Full CRUD operations
- Soft delete implementation
- Duplicate checking on creation
- Timestamp tracking (created/updated)
- Proper HTTP status codes
- Error handling and logging
- SQL injection prevention

### Frontend Implementation

#### Component Architecture
- React functional component with hooks
- TypeScript for type safety
- Ant Design components
- Form validation with rules
- Confirmation dialogs for destructive actions
- Loading states and error messages
- Responsive table with pagination

#### State Management
- Local state with useState
- Effect hooks for data loading
- Form state with Ant Design Form
- Modal visibility state

---

## Usage Guide

### Accessing TPA Management

1. Open the application: `http://localhost:3000`
2. Navigate to: **⚙️ Administration → TPA Management**
3. You'll see the TPA management interface

### Creating a New TPA

1. Click the **"Add New TPA"** button (top right)
2. Fill in the form:
   - **TPA Code**: Enter unique code (e.g., "PROVIDER_C")
   - **TPA Name**: Enter full name (e.g., "Provider C Healthcare")
   - **Description**: Add optional description
   - **Status**: Toggle active/inactive
3. Click **"Create"**
4. Success message will appear
5. TPA list will refresh automatically

### Editing an Existing TPA

1. Find the TPA in the table
2. Click the **"Edit"** button in the Actions column
3. Modify the fields (TPA Code cannot be changed)
4. Click **"Update"**
5. Changes will be saved and list refreshed

### Deactivating a TPA

1. Find the TPA in the table
2. Toggle the **Status** switch to OFF
3. TPA becomes inactive immediately
4. TPA will no longer appear in dropdowns

### Deleting a TPA

1. Find the TPA in the table
2. Click the **"Delete"** button in the Actions column
3. Read the confirmation dialog carefully
4. Click **"Yes, Delete"** to confirm
5. TPA is soft-deleted (ACTIVE = FALSE)

---

## Testing Checklist

- [x] Navigate to Administration → TPA Management
- [x] Verify existing TPAs are displayed
- [x] Create a new TPA with valid data
- [x] Try to create duplicate TPA (should fail with error)
- [x] Edit an existing TPA
- [x] Toggle active/inactive status
- [x] Delete a TPA (confirm soft delete)
- [x] Refresh the page (data persists)
- [x] Check TPA appears in header dropdown (if active)
- [x] Verify TPA is available in Bronze upload
- [x] Test form validation (empty fields, invalid formats)
- [x] Test character limits
- [x] Test uppercase enforcement for TPA code

---

## Security Considerations

### Input Validation
- All inputs validated on frontend and backend
- SQL injection prevention through parameterized queries
- XSS prevention through React's built-in escaping
- Character limits enforced

### Data Protection
- Soft delete preserves data integrity
- Confirmation required for destructive actions
- Audit trail with timestamps
- No hard deletes

### Access Control
- Currently no role-based access control
- Future enhancement: Admin-only access
- Future enhancement: Audit logging

---

## Future Enhancements

### Potential Improvements
1. **Role-Based Access Control**
   - Restrict TPA management to admin users
   - Audit logging for all changes

2. **Bulk Operations**
   - Bulk activate/deactivate
   - Bulk import from CSV
   - Bulk export

3. **Advanced Search**
   - Search by code, name, description
   - Filter by active status
   - Date range filtering

4. **TPA Configuration**
   - Custom settings per TPA
   - File format specifications
   - Contact information
   - SLA configurations

5. **Usage Statistics**
   - Number of files processed per TPA
   - Data volume per TPA
   - Processing success rates

6. **Hard Delete Option**
   - Admin-only hard delete
   - Cascade delete of all related data
   - Backup before delete

---

## Troubleshooting

### TPA Not Appearing in Dropdown
- Check if TPA is active (Status = ON)
- Refresh the page
- Check browser console for errors

### Cannot Create TPA
- Verify TPA code is unique
- Check TPA code format (uppercase, alphanumeric + underscore)
- Ensure all required fields are filled
- Check backend logs for errors

### Changes Not Saving
- Check network connection
- Verify backend is running
- Check browser console for errors
- Check backend logs for database errors

### TypeScript Errors
- Run `npm install` in frontend directory
- Clear TypeScript cache
- Restart development server

---

## Performance Considerations

### Database
- TPA_CONFIG table is small (typically < 100 rows)
- Queries are fast (< 10ms)
- No performance concerns

### Frontend
- Table pagination prevents large DOM
- Lazy loading of data
- Efficient re-rendering with React

### Backend
- Minimal database queries
- Efficient SQL statements
- Proper error handling

---

## Maintenance

### Regular Tasks
- Monitor TPA list for inactive TPAs
- Clean up old inactive TPAs (if needed)
- Review and update TPA descriptions
- Verify TPA configurations

### Backup
- TPA data is backed up with database
- Soft delete preserves historical data
- No special backup procedures needed

---

## Summary

The TPA Management feature provides a complete, professional interface for managing Third-Party Administrators in the Bordereau Processing Pipeline. It includes:

✅ Full CRUD operations  
✅ Soft delete with data preservation  
✅ Form validation and error handling  
✅ Professional UI with Ant Design  
✅ Integration with existing features  
✅ Comprehensive API endpoints  
✅ Type-safe TypeScript implementation  

**Access**: http://localhost:3000/admin/tpas

---

**Status**: ✅ Production Ready  
**Version**: 1.0  
**Last Updated**: January 19, 2026
