# Documentation Structure

**Project**: Bordereau Processing Pipeline  
**Last Updated**: January 21, 2026  
**Version**: 3.0

---

## Overview

This document provides a complete map of all documentation in the Bordereau Processing Pipeline project. All documentation has been consolidated and organized for easy navigation.

---

## Quick Links

### Essential Documents

- **[README.md](README.md)** - Project overview and quick start
- **[QUICK_START.md](QUICK_START.md)** - Getting started guide
- **[docs/IMPLEMENTATION_LOG.md](docs/IMPLEMENTATION_LOG.md)** - Complete project history
- **[docs/README.md](docs/README.md)** - Documentation hub

### Visual Documentation (with Mermaid Diagrams)

- **[docs/DIAGRAMS_GUIDE.md](docs/DIAGRAMS_GUIDE.md)** - How to use diagrams
- **[docs/DATA_FLOW_DIAGRAMS.md](docs/DATA_FLOW_DIAGRAMS.md)** - Data flow visualizations
- **[docs/ARCHITECTURE_DIAGRAMS.md](docs/ARCHITECTURE_DIAGRAMS.md)** - System architecture diagrams

---

## Documentation by Category

### 1. Project Overview

| Document | Description | Location |
|----------|-------------|----------|
| README.md | Project overview, features, tech stack | Root |
| QUICK_START.md | Quick start guide for new users | Root |
| PROJECT_GENERATION_PROMPT.md | Original project generation prompt | Root |
| MIGRATION_GUIDE.md | Migration instructions | Root |

### 2. Implementation History

| Document | Description | Location |
|----------|-------------|----------|
| **IMPLEMENTATION_LOG.md** | **Complete project history** | **docs/** |

**Contents**:
- Initial Deployment
- Hybrid Tables Implementation
- Gold Layer Implementation
- Frontend Features
- Documentation Consolidation
- Container Deployment and TPA Fixes
- Sample Data Generator
- Documentation Reorganization

### 3. Visual Documentation (Mermaid Diagrams)

| Document | Description | Location |
|----------|-------------|----------|
| **DIAGRAMS_GUIDE.md** | How to use Mermaid diagrams | **docs/** |
| **DATA_FLOW_DIAGRAMS.md** | Data flow visualizations | **docs/** |
| **ARCHITECTURE_DIAGRAMS.md** | System architecture diagrams | **docs/** |

**Diagram Types**:
- System architecture
- Data flow (Bronze → Silver → Gold)
- Component interactions
- Deployment architecture
- User workflows

### 4. Technical Documentation

| Document | Description | Location |
|----------|-------------|----------|
| SYSTEM_DESIGN.md | Technical design document | docs/ |
| SYSTEM_ARCHITECTURE.md | Architecture details | docs/ |
| DATA_FLOW.md | Data flow documentation | docs/ |
| DEPLOYMENT_AND_OPERATIONS.md | Operations guide | docs/ |

### 5. User Documentation

| Document | Description | Location |
|----------|-------------|----------|
| USER_GUIDE.md | End-user guide | docs/ |
| TPA_COMPLETE_GUIDE.md | TPA management guide | docs/guides/ |

### 6. Deployment Documentation

| Document | Description | Location |
|----------|-------------|----------|
| README.md | Deployment overview | deployment/ |
| QUICK_REFERENCE.md | Quick command reference | deployment/ |
| DEPLOY_SCRIPT_UPDATE.md | Script enhancements | deployment/ |
| TPA_API_FIX.md | TPA API fixes | deployment/ |
| CONTAINER_DEPLOYMENT_FIX.md | Container deployment fixes | deployment/ |
| TROUBLESHOOT_SERVICE_CREATION.md | Troubleshooting guide | deployment/ |
| diagnose_service.sh | Diagnostic automation script | deployment/ |
| SNOWPARK_CONTAINER_DEPLOYMENT.md | SPCS deployment guide | deployment/ |
| AUTHENTICATION_SETUP.md | Auth configuration | deployment/ |

### 7. Layer-Specific Documentation

#### Bronze Layer

| Document | Description | Location |
|----------|-------------|----------|
| README.md | Bronze layer overview | bronze/ |
| TPA_UPLOAD_GUIDE.md | File upload guide | bronze/ |

#### Silver Layer

| Document | Description | Location |
|----------|-------------|----------|
| README.md | Silver layer overview | silver/ |

#### Gold Layer

| Document | Description | Location |
|----------|-------------|----------|
| README.md | Gold layer overview | gold/ |
| HYBRID_TABLES_GUIDE.md | Hybrid tables guide | gold/ |
| PERFORMANCE_OPTIMIZATION_GUIDE.md | Performance optimization | gold/ |
| 6_Member_Journeys.sql | Journey tables (with docs) | gold/ |

### 8. Sample Data Documentation

| Document | Description | Location |
|----------|-------------|----------|
| README.md | Sample data generator guide | sample_data/ |
| generate_sample_data.py | Generator script (with docs) | sample_data/ |
| quick_start.sh | Automation script | sample_data/ |
| load_sample_data.sql | Loading script (with docs) | sample_data/ |

### 9. Backend Documentation

| Document | Description | Location |
|----------|-------------|----------|
| README.md | Backend API documentation | backend/ |

### 10. Testing Documentation

| Document | Description | Location |
|----------|-------------|----------|
| TEST_PLAN_DEPLOYMENT_SCRIPTS.md | Deployment test plan | docs/testing/ |
| README.md | Test documentation | tests/deployment/ |

---

## Documentation Hierarchy

```
bordereau/
├── README.md                           # Project overview
├── QUICK_START.md                      # Getting started
├── DOCUMENTATION_STRUCTURE.md          # This file
├── PROJECT_GENERATION_PROMPT.md        # Project history
├── MIGRATION_GUIDE.md                  # Migration guide
│
├── docs/                               # Main documentation
│   ├── README.md                       # Documentation hub
│   ├── IMPLEMENTATION_LOG.md           # ⭐ Complete history
│   ├── DIAGRAMS_GUIDE.md               # 📊 Diagram usage
│   ├── DATA_FLOW_DIAGRAMS.md           # 📊 Data flow visuals
│   ├── ARCHITECTURE_DIAGRAMS.md        # 📊 Architecture visuals
│   ├── SYSTEM_DESIGN.md                # Technical design
│   ├── SYSTEM_ARCHITECTURE.md          # Architecture details
│   ├── DATA_FLOW.md                    # Data flow details
│   ├── USER_GUIDE.md                   # User documentation
│   ├── DEPLOYMENT_AND_OPERATIONS.md    # Operations guide
│   ├── guides/
│   │   └── TPA_COMPLETE_GUIDE.md       # TPA guide
│   └── testing/
│       └── TEST_PLAN_DEPLOYMENT_SCRIPTS.md
│
├── deployment/                         # Deployment docs
│   ├── README.md
│   ├── QUICK_REFERENCE.md
│   ├── DEPLOY_SCRIPT_UPDATE.md
│   ├── TPA_API_FIX.md
│   ├── CONTAINER_DEPLOYMENT_FIX.md
│   ├── TROUBLESHOOT_SERVICE_CREATION.md
│   ├── diagnose_service.sh
│   └── ... (other deployment guides)
│
├── bronze/                             # Bronze layer docs
│   ├── README.md
│   └── TPA_UPLOAD_GUIDE.md
│
├── silver/                             # Silver layer docs
│   └── README.md
│
├── gold/                               # Gold layer docs
│   ├── README.md
│   ├── HYBRID_TABLES_GUIDE.md
│   ├── PERFORMANCE_OPTIMIZATION_GUIDE.md
│   └── 6_Member_Journeys.sql
│
├── sample_data/                        # Sample data docs
│   ├── README.md
│   ├── generate_sample_data.py
│   ├── quick_start.sh
│   └── load_sample_data.sql
│
├── backend/                            # Backend docs
│   └── README.md
│
└── tests/                              # Test docs
    └── deployment/
        └── README.md
```

---

## Finding What You Need

### I want to...

#### Get Started
→ [README.md](README.md) or [QUICK_START.md](QUICK_START.md)

#### See Project History
→ [docs/IMPLEMENTATION_LOG.md](docs/IMPLEMENTATION_LOG.md)

#### Understand the Architecture
→ [docs/ARCHITECTURE_DIAGRAMS.md](docs/ARCHITECTURE_DIAGRAMS.md)

#### Understand Data Flow
→ [docs/DATA_FLOW_DIAGRAMS.md](docs/DATA_FLOW_DIAGRAMS.md)

#### Deploy the Application
→ [deployment/README.md](deployment/README.md)

#### Troubleshoot Deployment
→ [deployment/TROUBLESHOOT_SERVICE_CREATION.md](deployment/TROUBLESHOOT_SERVICE_CREATION.md)

#### Generate Sample Data
→ [sample_data/README.md](sample_data/README.md)

#### Optimize Performance
→ [gold/PERFORMANCE_OPTIMIZATION_GUIDE.md](gold/PERFORMANCE_OPTIMIZATION_GUIDE.md)

#### Manage TPAs
→ [docs/guides/TPA_COMPLETE_GUIDE.md](docs/guides/TPA_COMPLETE_GUIDE.md)

#### Use Hybrid Tables
→ [gold/HYBRID_TABLES_GUIDE.md](gold/HYBRID_TABLES_GUIDE.md)

#### Upload Files
→ [bronze/TPA_UPLOAD_GUIDE.md](bronze/TPA_UPLOAD_GUIDE.md)

---

## Documentation Standards

### File Naming

- **Descriptive names**: Use clear, descriptive names (e.g., `ARCHITECTURE_DIAGRAMS.md` not `ARCH.md`)
- **UPPERCASE for root**: Root-level docs use UPPERCASE (e.g., `README.md`, `QUICK_START.md`)
- **Category prefixes**: Use prefixes for related docs (e.g., `TPA_*`, `DEPLOYMENT_*`)

### Content Structure

All documentation should include:
1. **Title and metadata** (date, status, version)
2. **Overview** (what this document covers)
3. **Table of contents** (for long documents)
4. **Main content** (well-organized sections)
5. **Examples** (where applicable)
6. **References** (links to related docs)

### Diagram Standards

- Use Mermaid for all diagrams
- Include both diagram code and rendered image
- Provide legend and explanations
- Keep diagrams focused and readable

---

## Maintenance

### Adding New Documentation

1. **Determine category**: Which category does it belong to?
2. **Choose location**: Place in appropriate directory
3. **Follow naming**: Use consistent naming conventions
4. **Update this file**: Add entry to relevant section
5. **Update README**: Add to docs/README.md if major doc

### Updating Documentation

1. **Update content**: Make necessary changes
2. **Update metadata**: Change "Last Updated" date
3. **Update version**: Increment version if major changes
4. **Update IMPLEMENTATION_LOG**: Add entry if significant change

### Deprecating Documentation

1. **Mark as deprecated**: Add deprecation notice at top
2. **Provide alternative**: Link to replacement document
3. **Wait period**: Keep for 30 days
4. **Remove**: Delete after wait period
5. **Update references**: Remove from this file and README

---

## Version History

### v3.0 (January 21, 2026)
- Renamed Mermaid diagram files for clarity
- Consolidated root-level summaries into IMPLEMENTATION_LOG
- Moved feature docs to appropriate directories
- Cleaned up redundant files
- Updated documentation structure

### v2.0 (January 19, 2026)
- Created IMPLEMENTATION_LOG
- Consolidated multiple summary files
- Organized documentation by category

### v1.0 (Initial)
- Created documentation structure
- Established naming conventions
- Set up directory organization

---

## Statistics

**Total Documentation Files**: 47

**By Category**:
- Root-level: 5 files
- Main docs: 11 files
- Deployment: 15+ files
- Layer-specific: 10 files
- Sample data: 4 files
- Testing: 2 files

**Special Files**:
- **3 files with Mermaid diagrams** 📊
- **1 comprehensive history** (IMPLEMENTATION_LOG)
- **5 essential root files**

---

## Support

For questions about documentation:
1. Check this structure document
2. Review [docs/README.md](docs/README.md)
3. Search [docs/IMPLEMENTATION_LOG.md](docs/IMPLEMENTATION_LOG.md)
4. Check relevant layer/feature README

---

**Last Updated**: January 21, 2026  
**Version**: 3.0  
**Status**: ✅ Current
