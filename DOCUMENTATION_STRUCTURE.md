# Documentation Structure

This document describes the consolidated documentation structure for the Bordereau Processing Pipeline.

## 📚 Documentation Hierarchy

### Root Level Documentation

```
/
├── README.md                    # Main project overview (streamlined)
├── QUICK_START.md              # 10-minute quick start guide
├── MIGRATION_GUIDE.md          # Streamlit to React migration
└── APPLICATION_GENERATION_PROMPT.md  # AI generation context
```

### Documentation Hub

**Primary Entry Point**: `docs/README.md`

```
docs/
├── README.md                   # 📖 MAIN DOCUMENTATION HUB
├── USER_GUIDE.md              # Complete user guide
├── DEPLOYMENT_AND_OPERATIONS.md  # Operations guide
├── guides/
│   └── TPA_COMPLETE_GUIDE.md  # Multi-tenant guide
└── testing/
    └── TEST_PLAN_DEPLOYMENT_SCRIPTS.md  # Test plans
```

### Backend Documentation

```
backend/
└── README.md                   # Backend API, authentication, development
```

### Deployment Documentation

```
deployment/
├── README.md                   # Main deployment guide
├── DEPLOYMENT_SNOW_CLI.md     # Snow CLI deployment
├── SNOWPARK_CONTAINER_DEPLOYMENT.md  # Container deployment
├── SNOWPARK_QUICK_START.md    # Quick container reference
├── AUTHENTICATION_SETUP.md    # Auth configuration
└── DEPLOYMENT_SUMMARY.md      # Deployment checklist
```

### Layer-Specific Documentation

```
bronze/
├── README.md                   # Bronze layer architecture
└── TPA_UPLOAD_GUIDE.md        # File upload conventions

silver/
└── README.md                   # Silver layer architecture

sample_data/
└── README.md                   # Sample data guide
```

## 🗺️ Navigation Guide

### For New Users
1. Start: [README.md](README.md)
2. Setup: [QUICK_START.md](QUICK_START.md)
3. Usage: [docs/USER_GUIDE.md](docs/USER_GUIDE.md)

### For Developers
1. Overview: [README.md](README.md)
2. Backend: [backend/README.md](backend/README.md)
3. Hub: [docs/README.md](docs/README.md)

### For DevOps
1. Deployment: [deployment/README.md](deployment/README.md)
2. Operations: [docs/DEPLOYMENT_AND_OPERATIONS.md](docs/DEPLOYMENT_AND_OPERATIONS.md)
3. Testing: [docs/testing/TEST_PLAN_DEPLOYMENT_SCRIPTS.md](docs/testing/TEST_PLAN_DEPLOYMENT_SCRIPTS.md)

## 🧹 Cleanup Summary

### Files Removed (Redundant)
- ❌ `DOCUMENTATION_INDEX.md` → Replaced by `docs/README.md`
- ❌ `PROJECT_SUMMARY.md` → Consolidated into `README.md`
- ❌ `BACKEND_SETUP.md` → Merged into `backend/README.md`
- ❌ `README_REACT.md` → Content distributed to relevant docs

### Files Streamlined
- ✅ `README.md` - Now concise with clear navigation
- ✅ `docs/README.md` - New comprehensive documentation hub
- ✅ `deployment/README.md` - Consolidated deployment guide

### Cross-References Updated
- ✅ All references to removed files updated
- ✅ Consistent linking to `docs/README.md` as hub
- ✅ Broken links fixed

## 📊 Documentation Matrix

| Topic | Primary Doc | Secondary Docs |
|-------|-------------|----------------|
| **Getting Started** | README.md | QUICK_START.md |
| **Usage** | docs/USER_GUIDE.md | bronze/TPA_UPLOAD_GUIDE.md |
| **Deployment** | deployment/README.md | deployment/SNOWPARK_*.md |
| **Development** | backend/README.md | docs/README.md |
| **Architecture** | docs/README.md | bronze/README.md, silver/README.md |
| **Operations** | docs/DEPLOYMENT_AND_OPERATIONS.md | deployment/README.md |
| **Migration** | MIGRATION_GUIDE.md | docs/README.md |

## 🎯 Key Principles

1. **Single Source of Truth**: `docs/README.md` is the main hub
2. **Clear Hierarchy**: Root → Hub → Specific topics
3. **No Duplication**: Each topic covered once, linked from multiple places
4. **Consistent Navigation**: Every doc links to the hub
5. **Role-Based Paths**: Clear paths for users, developers, and DevOps

## 🔄 Maintenance Guidelines

### When Adding New Documentation

1. **Determine Scope**:
   - User-facing → `docs/`
   - Deployment → `deployment/`
   - Layer-specific → `bronze/` or `silver/`
   - Development → `backend/` or `frontend/`

2. **Update Hub**: Add entry to `docs/README.md`

3. **Add Cross-Links**: Link from related documents

4. **Update This File**: Add to the structure above

### When Updating Documentation

1. Check for references in other docs
2. Update cross-links if structure changes
3. Maintain consistent formatting
4. Update "Last Updated" dates

## 📝 Document Templates

### Standard Header
```markdown
# Document Title

Brief description of what this document covers.

> **📖 For complete documentation, see [docs/README.md](../docs/README.md)**
```

### Standard Footer
```markdown
---

**Version**: X.X | **Last Updated**: YYYY-MM-DD | **Status**: ✅ Production Ready
```

## 🔍 Quick Reference

### Most Important Documents

1. **[docs/README.md](docs/README.md)** - Documentation hub (START HERE)
2. **[README.md](README.md)** - Project overview
3. **[QUICK_START.md](QUICK_START.md)** - Fast setup
4. **[deployment/README.md](deployment/README.md)** - Deployment guide
5. **[backend/README.md](backend/README.md)** - Backend API

### By User Type

**End Users**:
- [docs/USER_GUIDE.md](docs/USER_GUIDE.md)
- [bronze/TPA_UPLOAD_GUIDE.md](bronze/TPA_UPLOAD_GUIDE.md)
- [docs/guides/TPA_COMPLETE_GUIDE.md](docs/guides/TPA_COMPLETE_GUIDE.md)

**Developers**:
- [backend/README.md](backend/README.md)
- [docs/README.md](docs/README.md)
- [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)

**DevOps/Admins**:
- [deployment/README.md](deployment/README.md)
- [docs/DEPLOYMENT_AND_OPERATIONS.md](docs/DEPLOYMENT_AND_OPERATIONS.md)
- [deployment/AUTHENTICATION_SETUP.md](deployment/AUTHENTICATION_SETUP.md)

---

**Version**: 1.0  
**Created**: January 19, 2026  
**Status**: ✅ Documentation Cleanup Complete
