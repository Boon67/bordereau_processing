# Documentation Hub

**Version**: 8.0 (Consolidated)  
**Last Updated**: January 31, 2026

---

## 📚 Start Here

| Document | Use When... |
|----------|-------------|
| [Quick Reference](QUICK_REFERENCE.md) ⚡ | Need fast answers (80% of questions) |
| [Quick Start](../QUICK_START.md) | First-time setup (10 min) |
| [User Guide](USER_GUIDE.md) | Learning to use the application |
| [Architecture](ARCHITECTURE.md) | Understanding system design |
| [Technical Reference](TECHNICAL_REFERENCE.md) | Advanced topics and troubleshooting |
| [Changelog](CHANGELOG.md) | Recent updates and fixes |

---

## 🎯 By Role

**End Users**: [Quick Reference](QUICK_REFERENCE.md) → [User Guide](USER_GUIDE.md)  
**Developers**: [Architecture](ARCHITECTURE.md) → [Technical Reference](TECHNICAL_REFERENCE.md) → [Backend](../backend/README.md)  
**DevOps**: [Deployment](../deployment/README.md) → [Quick Reference](QUICK_REFERENCE.md)

---

## 📖 Component Documentation

**Layer Docs**: [Bronze](../bronze/README.md) | [Silver](../silver/README.md) | [Gold](../gold/README.md)  
**Infrastructure**: [Deployment](../deployment/README.md) | [Backend](../backend/README.md)

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

## 📝 Documentation Structure

**Root Level** (2 files):
- `README.md` - Project overview
- `QUICK_START.md` - Fast setup guide

**Core Docs** (6 files in `docs/`):
- `README.md` - This hub
- `QUICK_REFERENCE.md` - One-page cheat sheet
- `USER_GUIDE.md` - Complete usage guide
- `ARCHITECTURE.md` - System design
- `TECHNICAL_REFERENCE.md` - Advanced topics
- `CHANGELOG.md` - Updates and fixes

**Component READMEs** (5 files):
- `bronze/README.md` - Bronze layer
- `silver/README.md` - Silver layer
- `gold/README.md` - Gold layer
- `backend/README.md` - Backend API
- `deployment/README.md` - Deployment guide

**Total**: **13 markdown files** (down from 19)  
**Reduction**: 32% fewer files | **100% information preserved** | ⚡ **Faster navigation**
