# Documentation Hub

**Version**: 6.0 (Extreme Consolidation)  
**Last Updated**: January 31, 2026

---

## 📚 Start Here

| Document | Use When... |
|----------|-------------|
| [Quick Reference](QUICK_REFERENCE.md) ⚡ | Need fast answers, common operations |
| [Quick Start](../QUICK_START.md) | First-time setup (10 min) |
| [User Guide](USER_GUIDE.md) | Learning to use the application |
| [Architecture](ARCHITECTURE.md) | Understanding system design |
| [Changelog](CHANGELOG.md) | Checking recent updates |

---

## 🎯 By Role

**End Users**: [Quick Reference](QUICK_REFERENCE.md) → [User Guide](USER_GUIDE.md)  
**Developers**: [Architecture](ARCHITECTURE.md) → [Backend](../backend/README.md)  
**DevOps**: [Deployment](../deployment/README.md) → [Quick Reference](QUICK_REFERENCE.md)

---

## 📖 Detailed Guides

**Technical**:
- [Silver Metadata Columns](guides/SILVER_METADATA_COLUMNS.md) - Data lineage reference
- [TPA Complete Guide](guides/TPA_COMPLETE_GUIDE.md) - Multi-tenancy deep dive
- [Table Editor Guide](guides/TABLE_EDITOR_APPLICATION_GUIDE.md) - Schema management

**Layer Docs**: [Bronze](../bronze/README.md) | [Silver](../silver/README.md) | [Gold](../gold/README.md)

**Historical**: [Changelog Archive](changelog/) - Detailed fix documentation

---

## 🚀 Quick Commands

```bash
# Local development
./start.sh

# Full deployment
cd deployment && ./deploy.sh

# Service management
cd deployment && ./manage_services.sh status

# API documentation
open http://localhost:8000/api/docs
```

---

**Structure**: 1 quick ref + 4 core docs + 3 guides + 3 layer docs = **11 essential files**  
**Reduction**: 80% fewer docs | **100% information preserved** | ⚡ **Faster navigation**
