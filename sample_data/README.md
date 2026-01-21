# Sample Data Generator

Comprehensive sample data generator for the Bordereau Processing Pipeline, including support for member healthcare journeys and all new features.

## Features

Generates realistic sample data for:

### Core Data
- **Members**: Patient demographics, enrollment information
- **Providers**: Healthcare providers with specialties and types
- **Claims**: Medical, dental, and pharmacy claims with realistic amounts
- **TPAs**: Third-party administrators

### New Features
- **Member Journeys**: Complete healthcare journey tracking
  - Journey types: Preventive care, chronic disease management, acute episodes, surgical procedures, maternity, mental health, emergency care
  - Journey stages: Initial visit, diagnosis, treatment planning, active treatment, follow-up, maintenance, completed, discontinued
  - Metrics: Total cost, number of visits, providers involved, quality scores, patient satisfaction

- **Journey Events**: Detailed timeline of events within each journey
  - Event types: Appointments, procedures, lab tests, prescriptions, hospital admissions/discharges, follow-ups
  - Cost tracking per event
  - Provider and diagnosis linkage

## Installation

### Prerequisites

- Python 3.7+
- No external dependencies required (uses only Python standard library)

### Setup

```bash
# Make the script executable
chmod +x generate_sample_data.py
```

## Usage

### Basic Usage

Generate 1,000 claims (default):

```bash
python generate_sample_data.py
```

### Custom Configuration

```bash
# Generate 5,000 claims
python generate_sample_data.py --num-claims 5000

# Specify custom output directory
python generate_sample_data.py --output-dir /path/to/output --num-claims 2000
```

### Command-Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--output-dir` | Output directory for CSV files | `./sample_data/output` |
| `--num-claims` | Number of claims to generate | `1000` |

## Output Files

The generator creates the following CSV files:

| File | Description | Typical Size (1K claims) |
|------|-------------|--------------------------|
| `members.csv` | Member demographics | ~100 records |
| `providers.csv` | Healthcare providers | ~50 records |
| `claims.csv` | Claims data | 1,000 records |
| `member_journeys.csv` | Healthcare journeys | ~200 records |
| `journey_events.csv` | Journey timeline events | ~1,000 records |
| `tpas.csv` | TPA reference data | 5 records |

## Data Relationships

```
TPAs (5)
  ├── Members (~10% of claims)
  │     ├── Claims (specified count)
  │     └── Journeys (1-3 per member)
  │           └── Events (2-10 per journey)
  └── Providers (~5% of claims)
```

## Sample Data Statistics

### For 1,000 Claims

- **Members**: ~100 (avg 10 claims per member)
- **Providers**: ~50 (avg 20 claims per provider)
- **Journeys**: ~200-300 (1-3 per member)
- **Journey Events**: ~1,000-2,000 (2-10 per journey)

### Claim Type Distribution

- Medical: ~40%
- Dental: ~30%
- Pharmacy: ~30%

### Journey Type Distribution

- Preventive Care
- Chronic Disease Management
- Acute Episodes
- Surgical Procedures
- Maternity
- Mental Health
- Emergency Care

### Financial Ranges

- **Medical Claims**: $100 - $5,000
- **Dental Claims**: $50 - $2,000
- **Pharmacy Claims**: $10 - $500
- **Discount Rate**: 20-50% (realistic healthcare discounts)

## Loading Data into Snowflake

### Step 1: Generate Data

```bash
python generate_sample_data.py --num-claims 5000
```

### Step 2: Create Journey Tables

```bash
cd ../gold
snow sql -c DEPLOYMENT -f 6_Member_Journeys.sql \
  -D DATABASE_NAME=BORDEREAU_PROCESSING_PIPELINE \
  -D GOLD_SCHEMA_NAME=GOLD
```

### Step 3: Load Data

```bash
cd ../sample_data
snow sql -c DEPLOYMENT -f load_sample_data.sql \
  -D DATABASE_NAME=BORDEREAU_PROCESSING_PIPELINE \
  -D GOLD_SCHEMA_NAME=GOLD
```

**Note**: The load script will automatically replace `__PROJECT_ROOT__` with the correct path.

## Data Quality

The generator ensures:

- **Referential Integrity**: All foreign keys are valid
- **Realistic Distributions**: Data follows healthcare industry patterns
- **Date Consistency**: Service dates before received dates, journey dates in logical order
- **Financial Accuracy**: Allowed ≤ Billed, Paid ≤ Allowed
- **Journey Completeness**: Active journeys have no end date, completed journeys have quality scores

## Example Queries

### Query Active Journeys

```sql
SELECT * FROM gold.v_active_journeys 
WHERE tpa = 'provider_a'
ORDER BY total_cost DESC
LIMIT 10;
```

### Journey Summary by Type

```sql
SELECT * FROM gold.v_journey_summary_by_type
ORDER BY avg_cost DESC;
```

### High-Cost Journeys

```sql
SELECT * FROM gold.v_high_cost_journeys
LIMIT 20;
```

### Journey Event Timeline

```sql
SELECT * FROM gold.v_journey_event_timeline
WHERE journey_id = 'JRN123456789012'
ORDER BY event_date;
```

## Customization

### Adding New Journey Types

Edit `generate_sample_data.py`:

```python
JOURNEY_TYPES = [
    "PREVENTIVE_CARE",
    "CHRONIC_DISEASE_MANAGEMENT",
    "YOUR_NEW_TYPE",  # Add here
]
```

### Adjusting Data Volumes

Modify the ratios in `generate_members()` and `generate_providers()`:

```python
# More members per claim
num_members = max(100, self.num_claims // 5)  # 5 claims per member

# More providers per claim
num_providers = max(50, self.num_claims // 10)  # 10 claims per provider
```

### Custom Financial Ranges

Adjust amounts in `generate_claims()`:

```python
if claim_type == "MEDICAL":
    billed = random.uniform(200, 10000)  # Increase range
```

## Troubleshooting

### Issue: "Permission denied"

```bash
chmod +x generate_sample_data.py
```

### Issue: "Output directory not found"

The script automatically creates the output directory. If you see this error, check parent directory permissions.

### Issue: "No module named 'csv'"

This should not happen as `csv` is part of Python standard library. Ensure you're using Python 3.7+:

```bash
python --version
```

### Issue: Data not loading into Snowflake

1. Check that tables exist: `SHOW TABLES IN gold;`
2. Verify stage exists: `SHOW STAGES IN bronze;`
3. Check file upload: `LIST @bronze.sample_data;`
4. Review error messages in COPY INTO output

## Performance

### Generation Speed

- 1,000 claims: ~2 seconds
- 10,000 claims: ~15 seconds
- 100,000 claims: ~2 minutes

### File Sizes

- 1,000 claims: ~500 KB total
- 10,000 claims: ~5 MB total
- 100,000 claims: ~50 MB total

## Future Enhancements

Planned features:

- [ ] Support for multiple file formats (JSON, Parquet)
- [ ] Configurable data distributions
- [ ] Anomaly injection for testing quality rules
- [ ] Time-series data generation
- [ ] Network analysis data (provider referrals)
- [ ] Prescription refill patterns
- [ ] Seasonal variation in claims

## Contributing

To add new features:

1. Update `generate_sample_data.py` with new data generation logic
2. Update `load_sample_data.sql` with new COPY INTO statements
3. Update this README with new features and examples
4. Test with various data volumes

## Support

For issues or questions:

1. Check this README
2. Review sample queries in `load_sample_data.sql`
3. Check Gold layer documentation in `../gold/6_Member_Journeys.sql`

## Version History

### v1.0.0 (2026-01-21)
- Initial release
- Support for members, providers, claims
- Member journey tracking
- Journey events timeline
- Comprehensive analytics views

---

**Generated with ❤️ for the Bordereau Processing Pipeline**
