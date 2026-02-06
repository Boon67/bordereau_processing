-- ============================================
-- SILVER LAYER FIELD MAPPING PROCEDURES
-- ============================================
-- Purpose: Field mapping engine with multiple approaches
-- 
-- This script creates procedures for:
--   1. Manual CSV-based field mappings
--   2. ML/Pattern matching for automated field discovery
--   3. LLM-assisted mapping using Snowflake Cortex AI
--
-- Mapping Methods:
--   - MANUAL: User-defined mappings from CSV
--   - ML_AUTO: Pattern matching with confidence scores
--   - LLM_CORTEX: AI-powered semantic understanding
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================

SET DATABASE_NAME = '$DATABASE_NAME';
SET SILVER_SCHEMA_NAME = '$SILVER_SCHEMA_NAME';
SET SNOWFLAKE_ROLE = '$SNOWFLAKE_ROLE';
SET BRONZE_SCHEMA_NAME = '$BRONZE_SCHEMA_NAME';

-- Set role name

USE ROLE IDENTIFIER($SNOWFLAKE_ROLE);
USE DATABASE IDENTIFIER($DATABASE_NAME);
USE SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);

-- ============================================
-- PROCEDURE: Load Field Mappings from CSV
-- ============================================
-- Purpose: Load manual field mappings from CSV file
-- Input: stage_path - Path to CSV file (e.g., '@SILVER_CONFIG/field_mappings.csv')
-- Output: Number of mappings loaded

CREATE OR REPLACE PROCEDURE load_field_mappings_from_csv(stage_path VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    rows_loaded INTEGER DEFAULT 0;
    result_msg VARCHAR;
BEGIN
    -- Create temporary table for CSV data
    CREATE OR REPLACE TEMPORARY TABLE temp_field_mappings (
        source_field VARCHAR(500),
        source_table VARCHAR(500),
        target_table VARCHAR(500),
        target_column VARCHAR(500),
        tpa VARCHAR(500),
        transformation_logic VARCHAR(5000),
        description VARCHAR(5000)
    );
    
    -- Load CSV into temporary table
    EXECUTE IMMEDIATE 'COPY INTO temp_field_mappings FROM ' || :stage_path || '
        FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = ''"'')';
    
    -- Merge into field_mappings table (prevents duplicates)
    MERGE INTO field_mappings fm
    USING (
        SELECT 
            UPPER(source_field) as source_field,
            COALESCE(UPPER(source_table), 'RAW_DATA_TABLE') as source_table,
            UPPER(target_table) as target_table,
            UPPER(target_column) as target_column,
            tpa as tpa,  -- Keep TPA as-is (lowercase) to match TPA_MASTER
            'MANUAL' as mapping_method,
            1.0 as confidence_score, -- Manual mappings have 100% confidence
            transformation_logic,
            description,
            TRUE as approved -- Manual mappings are pre-approved
        FROM temp_field_mappings
    ) src
    ON fm.source_field = src.source_field 
       AND fm.source_table = src.source_table
       AND fm.target_table = src.target_table
       AND fm.target_column = src.target_column
       AND fm.tpa = src.tpa
    WHEN MATCHED THEN UPDATE SET
        mapping_method = src.mapping_method,
        confidence_score = src.confidence_score,
        transformation_logic = src.transformation_logic,
        description = src.description,
        approved = src.approved,
        updated_timestamp = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (
        source_field, source_table, target_table, target_column, tpa,
        mapping_method, confidence_score, transformation_logic, description,
        approved
    ) VALUES (
        src.source_field, src.source_table, src.target_table, src.target_column, src.tpa,
        src.mapping_method, src.confidence_score, src.transformation_logic, src.description,
        src.approved
    );
    
    rows_loaded := SQLROWCOUNT;
    
    -- Clean up
    DROP TABLE IF EXISTS temp_field_mappings;
    
    result_msg := 'Successfully loaded ' || rows_loaded || ' field mappings from ' || :stage_path;
    RETURN result_msg;
END;
$$;

-- ============================================
-- PROCEDURE: ML Pattern Matching for Field Mapping
-- ============================================
-- Purpose: Auto-map fields using ML algorithms (adapted from field_matcher_advanced)
-- Input: source_table - Bronze table to analyze (default: RAW_DATA_TABLE)
--        top_n - Number of top matches per field
--        min_confidence - Minimum confidence threshold
-- Output: Number of mappings generated

CREATE OR REPLACE PROCEDURE auto_map_fields_ml(
    source_table VARCHAR DEFAULT 'RAW_DATA_TABLE',
    target_table VARCHAR DEFAULT NULL,
    tpa VARCHAR DEFAULT NULL,
    top_n INTEGER DEFAULT 3,
    min_confidence FLOAT DEFAULT 0.6
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python', 'pandas', 'scikit-learn')
HANDLER = 'auto_map_fields_ml'
AS
$$
import pandas as pd
from difflib import SequenceMatcher
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
import re

def normalize_field_name(field_name):
    """Normalize field name for comparison"""
    if not field_name:
        return ""
    # Remove special characters and convert to lowercase
    normalized = re.sub(r'[^a-zA-Z0-9]', ' ', str(field_name))
    return normalized.lower().strip()

def calculate_exact_match(source, target):
    """Exact match score (case-insensitive)"""
    source_norm = normalize_field_name(source)
    target_norm = normalize_field_name(target)
    return 1.0 if source_norm == target_norm else 0.0

def calculate_substring_match(source, target):
    """Substring match score"""
    source_norm = normalize_field_name(source)
    target_norm = normalize_field_name(target)
    if not source_norm or not target_norm:
        return 0.0
    if source_norm in target_norm or target_norm in source_norm:
        return 1.0
    return 0.0

def calculate_sequence_similarity(source, target):
    """Sequence similarity using difflib"""
    source_norm = normalize_field_name(source)
    target_norm = normalize_field_name(target)
    if not source_norm or not target_norm:
        return 0.0
    return SequenceMatcher(None, source_norm, target_norm).ratio()

def calculate_word_overlap(source, target):
    """Jaccard similarity of word sets"""
    source_words = set(normalize_field_name(source).split())
    target_words = set(normalize_field_name(target).split())
    if not source_words or not target_words:
        return 0.0
    intersection = source_words.intersection(target_words)
    union = source_words.union(target_words)
    return len(intersection) / len(union) if union else 0.0

def auto_map_fields_ml(session, source_table, target_table, tpa, top_n, min_confidence):
    """Main function for ML-based field mapping"""
    
    if not tpa:
        return "Error: TPA parameter is required"
    
    # Get source fields from Bronze table (analyze VARIANT column structure)
    bronze_schema = session.get_current_schema()
    database = session.get_current_database()
    
    # Determine the full table path
    if '.' in source_table:
        # Already qualified
        full_source_table = source_table
    else:
        # Need to qualify - assume BRONZE schema
        full_source_table = f"{database}.BRONZE.{source_table}"
    
    bronze_query = f"""
        SELECT DISTINCT 
            f.key as field_name
        FROM {full_source_table},
        LATERAL FLATTEN(input => RAW_DATA) f
        WHERE RAW_DATA IS NOT NULL
          AND TPA = '{tpa}'
        LIMIT 1000
    """
    
    try:
        source_fields_df = session.sql(bronze_query).to_pandas()
        source_fields = source_fields_df['FIELD_NAME'].tolist()
    except Exception as e:
        return f"Error extracting source fields: {str(e)}"
    
    if not source_fields:
        return "No source fields found in Bronze table"
    
    # Get target fields from target_schemas (filter by target_table if specified)
    target_query = """
        SELECT DISTINCT 
            table_name,
            column_name,
            description
        FROM target_schemas
        WHERE active = TRUE
    """
    
    if target_table:
        target_query += f" AND table_name = '{target_table.upper()}'"
    
    target_fields_df = session.sql(target_query).to_pandas()
    
    if target_fields_df.empty:
        return "No target fields found in target_schemas"
    
    # Prepare data for TF-IDF
    all_fields = source_fields + target_fields_df['COLUMN_NAME'].tolist()
    normalized_fields = [normalize_field_name(f) for f in all_fields]
    
    # Calculate TF-IDF similarity
    vectorizer = TfidfVectorizer(analyzer='char', ngram_range=(2, 3))
    tfidf_matrix = vectorizer.fit_transform(normalized_fields)
    
    # Calculate all similarity scores
    results = []
    
    for source_field in source_fields:
        source_idx = all_fields.index(source_field)
        
        for _, target_row in target_fields_df.iterrows():
            target_field = target_row['COLUMN_NAME']
            target_table = target_row['TABLE_NAME']
            target_idx = all_fields.index(target_field)
            
            # Calculate individual scores
            exact_score = calculate_exact_match(source_field, target_field)
            substring_score = calculate_substring_match(source_field, target_field)
            sequence_score = calculate_sequence_similarity(source_field, target_field)
            word_overlap = calculate_word_overlap(source_field, target_field)
            
            # TF-IDF cosine similarity
            tfidf_score = cosine_similarity(
                tfidf_matrix[source_idx:source_idx+1],
                tfidf_matrix[target_idx:target_idx+1]
            )[0][0]
            
            # Combined score (weighted average)
            basic_score = (
                exact_score * 0.4 +
                substring_score * 0.2 +
                sequence_score * 0.2 +
                word_overlap * 0.2
            )
            combined_score = basic_score * 0.7 + tfidf_score * 0.3
            
            if combined_score >= min_confidence:
                results.append({
                    'SOURCE_FIELD': source_field,
                    'TARGET_TABLE': target_table,
                    'TARGET_COLUMN': target_field,
                    'COMBINED_SCORE': round(combined_score, 4),
                    'EXACT_SCORE': round(exact_score, 4),
                    'SUBSTRING_SCORE': round(substring_score, 4),
                    'SEQUENCE_SCORE': round(sequence_score, 4),
                    'WORD_OVERLAP': round(word_overlap, 4),
                    'TFIDF_SCORE': round(tfidf_score, 4)
                })
    
    if not results:
        return "No mappings found above confidence threshold"
    
    # Convert to DataFrame and rank
    results_df = pd.DataFrame(results)
    results_df['MATCH_RANK'] = results_df.groupby('SOURCE_FIELD')['COMBINED_SCORE'].rank(
        ascending=False, method='first'
    ).astype(int)
    
    # Filter to top N per source field
    results_df = results_df[results_df['MATCH_RANK'] <= top_n]
    
    # Filter by minimum confidence
    results_df = results_df[results_df['COMBINED_SCORE'] >= min_confidence]
    
    if results_df.empty:
        return f"No mappings found above confidence threshold {min_confidence}"
    
    # Insert directly into field_mappings table
    rows_inserted = 0
    for _, row in results_df.iterrows():
        transformation_logic = f"Scores: Exact={row['EXACT_SCORE']}, Substring={row['SUBSTRING_SCORE']}, Sequence={row['SEQUENCE_SCORE']}, WordOverlap={row['WORD_OVERLAP']}, TFIDF={row['TFIDF_SCORE']}, Rank={row['MATCH_RANK']}"
        
        insert_query = f"""
            INSERT INTO field_mappings (
                source_field, source_table, target_table, target_column, tpa,
                mapping_method, confidence_score, approved,
                transformation_logic
            )
            VALUES (
                '{row['SOURCE_FIELD']}',
                '{source_table}',
                '{row['TARGET_TABLE']}',
                '{row['TARGET_COLUMN']}',
                '{tpa}',
                'ML_AUTO',
                {row['COMBINED_SCORE']},
                FALSE,
                '{transformation_logic}'
            )
        """
        
        try:
            session.sql(insert_query).collect()
            rows_inserted += 1
        except Exception as e:
            # Skip duplicates or other errors
            pass
    
    table_msg = f" for {target_table}" if target_table else " for all tables"
    return f"Successfully generated {rows_inserted} ML-based field mappings{table_msg} (top {top_n} per field, min confidence {min_confidence})"
$$;

-- ============================================
-- PROCEDURE: LLM-Assisted Field Mapping
-- ============================================
-- Purpose: Use Snowflake Cortex AI for semantic field mapping
-- Input: source_table - Bronze table to analyze
--        model_name - Cortex AI model to use
--        custom_prompt_id - Optional custom prompt template ID
-- Output: Number of mappings generated

CREATE OR REPLACE PROCEDURE auto_map_fields_llm(
    source_table VARCHAR DEFAULT 'RAW_DATA_TABLE',
    target_table VARCHAR DEFAULT NULL,
    tpa VARCHAR DEFAULT NULL,
    model_name VARCHAR DEFAULT 'llama3.1-70b',
    custom_prompt_id VARCHAR DEFAULT 'DEFAULT_FIELD_MAPPING'
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python', 'pandas')
HANDLER = 'auto_map_fields_llm'
AS
$$
import json
import re

def auto_map_fields_llm(session, source_table, target_table, tpa, model_name, custom_prompt_id):
    """Main function for LLM-based field mapping"""
    
    if not tpa:
        return "Error: TPA parameter is required"
    
    # Get source fields from Bronze table
    database = session.get_current_database()
    
    # Determine the full table path
    if '.' in source_table:
        # Already qualified
        full_source_table = source_table
    else:
        # Need to qualify - assume BRONZE schema
        full_source_table = f"{database}.BRONZE.{source_table}"
    
    bronze_query = f"""
        SELECT DISTINCT 
            f.key as field_name
        FROM {full_source_table},
        LATERAL FLATTEN(input => RAW_DATA) f
        WHERE RAW_DATA IS NOT NULL
          AND TPA = '{tpa}'
        LIMIT 1000
    """
    
    try:
        source_fields_df = session.sql(bronze_query).to_pandas()
        source_fields = source_fields_df['FIELD_NAME'].tolist()
    except Exception as e:
        return f"Error extracting source fields: {str(e)}"
    
    if not source_fields:
        return "No source fields found in Bronze table"
    
    # Get target fields from target_schemas (filter by target_table if specified)
    target_query = """
        SELECT DISTINCT 
            table_name,
            column_name,
            description
        FROM target_schemas
        WHERE active = TRUE
    """
    
    if target_table:
        target_query += f" AND table_name = '{target_table.upper()}'"
    
    target_fields_df = session.sql(target_query).to_pandas()
    
    if target_fields_df.empty:
        return "No target fields found in target_schemas"
    
    # Build target fields description
    target_fields_desc = []
    for _, row in target_fields_df.iterrows():
        desc = f"{row['TABLE_NAME']}.{row['COLUMN_NAME']}"
        if row['DESCRIPTION']:
            desc += f" ({row['DESCRIPTION']})"
        target_fields_desc.append(desc)
    
    # Get prompt template
    prompt_query = f"""
        SELECT template_text
        FROM llm_prompt_templates
        WHERE template_id = '{custom_prompt_id}'
          AND active = TRUE
    """
    prompt_df = session.sql(prompt_query).to_pandas()
    
    if prompt_df.empty:
        return f"Prompt template '{custom_prompt_id}' not found"
    
    prompt_template = prompt_df['TEMPLATE_TEXT'].iloc[0]
    
    # Format prompt with actual fields
    prompt = prompt_template.replace(
        '{source_fields}',
        '\n'.join([f"- {f}" for f in source_fields])
    ).replace(
        '{target_fields}',
        '\n'.join([f"- {f}" for f in target_fields_desc])
    )
    
    # Call Cortex AI
    cortex_query = f"""
        SELECT SNOWFLAKE.CORTEX.COMPLETE(
            '{model_name}',
            ?
        ) as llm_response
    """
    
    try:
        # Execute LLM call
        result = session.sql(cortex_query, params=[prompt]).collect()
        llm_response = result[0]['LLM_RESPONSE']
        
        # Parse JSON response - try multiple strategies
        mappings = None
        
        # Strategy 1: Try to parse entire response as JSON
        try:
            mappings = json.loads(llm_response)
        except:
            pass
        
        # Strategy 2: Extract JSON array from response (handle markdown code blocks)
        if mappings is None:
            # Remove markdown code blocks
            cleaned_response = re.sub(r'```json\s*', '', llm_response)
            cleaned_response = re.sub(r'```\s*', '', cleaned_response)
            
            # Try to find JSON array
            json_match = re.search(r'\[[\s\S]*\]', cleaned_response)
            if json_match:
                try:
                    mappings = json.loads(json_match.group(0))
                except:
                    pass
        
        # Strategy 3: Try to find JSON objects and build array
        if mappings is None:
            json_objects = re.findall(r'\{[^{}]*\}', llm_response)
            if json_objects:
                try:
                    mappings = [json.loads(obj) for obj in json_objects]
                except:
                    pass
        
        if mappings is None:
            return f"Could not parse LLM response as JSON array. Response preview: {llm_response[:500]}"
        
        if not isinstance(mappings, list):
            return "LLM response is not a JSON array"
        
        # Validate target_table was provided
        if not target_table:
            return f"Error: target_table parameter is required for validation"
        
        # Get valid target columns for validation
        valid_columns_query = f"""
            SELECT DISTINCT column_name
            FROM target_schemas
            WHERE table_name = '{target_table.upper()}'
              AND active = TRUE
        """
        valid_columns_df = session.sql(valid_columns_query).to_pandas()
        valid_columns = set(valid_columns_df['COLUMN_NAME'].str.upper().tolist())
        
        # Insert mappings into field_mappings table
        rows_inserted = 0
        rows_skipped = 0
        skipped_columns = []
        
        for mapping in mappings:
            if not all(k in mapping for k in ['source_field', 'target_field', 'confidence']):
                continue
            
            # Parse target_field (format: TABLE.COLUMN)
            target_parts = mapping['target_field'].split('.')
            if len(target_parts) != 2:
                continue
            
            target_table_name = target_parts[0].upper()
            target_column = target_parts[1].upper()
            source_field = mapping['source_field'].upper()
            confidence = float(mapping['confidence'])
            reasoning = mapping.get('reasoning', '')
            
            # Validate that target column exists in target_schemas
            if target_column not in valid_columns:
                rows_skipped += 1
                skipped_columns.append(f"{target_column} (suggested by LLM but not in schema)")
                continue
            
            # Escape single quotes for SQL
            source_field_escaped = source_field.replace("'", "''")
            source_table_escaped = source_table.replace("'", "''")
            target_table_escaped = target_table_name.replace("'", "''")
            target_column_escaped = target_column.replace("'", "''")
            tpa_escaped = tpa.replace("'", "''")
            reasoning_escaped = reasoning.replace("'", "''")
            
            insert_query = f"""
                INSERT INTO field_mappings (
                    source_field, source_table, target_table, target_column, tpa,
                    mapping_method, confidence_score, approved,
                    description
                )
                VALUES (
                    '{source_field_escaped}',
                    '{source_table_escaped}',
                    '{target_table_escaped}',
                    '{target_column_escaped}',
                    '{tpa_escaped}',
                    'LLM_CORTEX',
                    {confidence},
                    FALSE,
                    'LLM: {model_name} - {reasoning_escaped}'
                )
            """
            
            try:
                session.sql(insert_query).collect()
                rows_inserted += 1
            except Exception as e:
                # Skip duplicates or errors
                rows_skipped += 1
                continue
        
        # Build result message
        result_msg = f"Successfully generated {rows_inserted} LLM-based field mappings using {model_name}"
        
        if rows_skipped > 0:
            result_msg += f". Skipped {rows_skipped} invalid mappings (columns not in target schema)"
            if skipped_columns:
                result_msg += f": {', '.join(skipped_columns[:5])}"
                if len(skipped_columns) > 5:
                    result_msg += f" and {len(skipped_columns) - 5} more"
        
        return result_msg
        
    except Exception as e:
        return f"Error calling Cortex AI: {str(e)}"
$$;

-- ============================================
-- PROCEDURE: Get Available Cortex Models
-- ============================================
-- Purpose: Fetch list of available Cortex AI models
-- Output: List of available models

CREATE OR REPLACE PROCEDURE get_available_cortex_models()
RETURNS TABLE (model_name VARCHAR)
LANGUAGE SQL
AS
$$
DECLARE
    result RESULTSET;
BEGIN
    -- Show available models
    SHOW MODELS IN SNOWFLAKE.MODELS;
    
    -- Return models of type CORTEX_BASE
    result := (
        SELECT "name" AS model_name
        FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
        WHERE "model_type" = 'CORTEX_BASE'
        ORDER BY "name"
    );
    
    RETURN TABLE(result);
END;
$$;

-- ============================================
-- PROCEDURE: Approve Field Mapping
-- ============================================
-- Purpose: Approve a field mapping for use in transformations
-- Input: mapping_id - ID of the mapping to approve
-- Output: Success message

CREATE OR REPLACE PROCEDURE approve_field_mapping(mapping_id INTEGER)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    result_msg VARCHAR;
BEGIN
    UPDATE field_mappings
    SET approved = TRUE,
        updated_timestamp = CURRENT_TIMESTAMP()
    WHERE field_mappings.mapping_id = :mapping_id;
    
    IF (SQLROWCOUNT = 0) THEN
        result_msg := 'Mapping ID ' || :mapping_id || ' not found';
    ELSE
        result_msg := 'Successfully approved mapping ID ' || :mapping_id;
    END IF;
    
    RETURN result_msg;
END;
$$;

-- ============================================
-- PROCEDURE: Approve All Mappings for Table
-- ============================================
-- Purpose: Approve all mappings for a specific target table
-- Input: target_table - Name of the target table
--        min_confidence - Minimum confidence threshold
-- Output: Number of mappings approved

CREATE OR REPLACE PROCEDURE approve_mappings_for_table(
    target_table VARCHAR,
    min_confidence FLOAT DEFAULT 0.8
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    rows_updated INTEGER;
    result_msg VARCHAR;
BEGIN
    UPDATE field_mappings
    SET approved = TRUE,
        approved_by = CURRENT_USER(),
        approved_timestamp = CURRENT_TIMESTAMP(),
        updated_timestamp = CURRENT_TIMESTAMP()
    WHERE field_mappings.target_table = UPPER(:target_table)
      AND confidence_score >= :min_confidence
      AND approved = FALSE;
    
    rows_updated := SQLROWCOUNT;
    result_msg := 'Approved ' || rows_updated || ' mappings for table ' || 
                  UPPER(:target_table) || ' (min confidence: ' || :min_confidence || ')';
    
    RETURN result_msg;
END;
$$;

-- ============================================
-- VIEW: Field Mapping Summary
-- ============================================
-- Purpose: Summary of field mappings by method and approval status

CREATE OR REPLACE VIEW v_field_mapping_summary AS
SELECT 
    mapping_method,
    approved,
    COUNT(*) as mapping_count,
    AVG(confidence_score) as avg_confidence,
    MIN(confidence_score) as min_confidence,
    MAX(confidence_score) as max_confidence
FROM field_mappings
GROUP BY mapping_method, approved
ORDER BY mapping_method, approved DESC;

COMMENT ON VIEW v_field_mapping_summary IS 'Summary of field mappings by method (MANUAL, ML_AUTO, LLM_CORTEX, SYSTEM) and approval status. Shows mapping counts and confidence score statistics for each method.';

-- ============================================
-- VIEW: Duplicate Target Mappings
-- ============================================
-- Purpose: Identify duplicate mappings to the same target field

CREATE OR REPLACE VIEW v_duplicate_target_mappings AS
SELECT 
    target_table,
    target_column,
    COUNT(*) as mapping_count,
    LISTAGG(source_field || ' (' || mapping_method || ', conf=' || 
            confidence_score || ')', ', ') as source_fields
FROM field_mappings
GROUP BY target_table, target_column
HAVING COUNT(*) > 1
ORDER BY mapping_count DESC, target_table, target_column;

COMMENT ON VIEW v_duplicate_target_mappings IS 'Identifies duplicate mappings where multiple source fields map to the same target column. Shows mapping count and lists all source fields with their methods and confidence scores for conflict resolution.';

-- ============================================
-- VIEW: Unmapped Target Fields
-- ============================================
-- Purpose: Show target fields that have no mappings

CREATE OR REPLACE VIEW v_unmapped_target_fields AS
SELECT 
    ts.table_name,
    ts.column_name,
    ts.description
FROM target_schemas ts
WHERE ts.active = TRUE
  AND NOT EXISTS (
      SELECT 1 
      FROM field_mappings fm
      WHERE fm.target_table = ts.table_name
        AND fm.target_column = ts.column_name
  )
ORDER BY ts.table_name, ts.column_name;

COMMENT ON VIEW v_unmapped_target_fields IS 'Shows target table columns that have no field mappings defined. Useful for identifying gaps in mapping coverage and ensuring all required fields are mapped from Bronze sources.';

-- ============================================
-- PROCEDURE: Validate Field Mappings
-- ============================================
-- Purpose: Validate field mapping definitions
-- Input: target_table - Optional table name to validate (NULL for all)
-- Output: Validation result message

CREATE OR REPLACE PROCEDURE validate_field_mappings(target_table VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    validation_errors VARCHAR DEFAULT '';
    duplicate_count INTEGER;
    orphan_count INTEGER;
    invalid_method_count INTEGER;
    result_msg VARCHAR;
    table_filter VARCHAR;
BEGIN
    -- Set table filter
    table_filter := COALESCE(:target_table, '%');
    
    -- Check for duplicate mappings
    SELECT COUNT(*) INTO duplicate_count
    FROM (
        SELECT source_field, source_table, target_table, target_column, COUNT(*) as cnt
        FROM field_mappings
        WHERE target_table LIKE UPPER(:table_filter)
        GROUP BY source_field, source_table, target_table, target_column
        HAVING COUNT(*) > 1
    );
    
    IF (duplicate_count > 0) THEN
        validation_errors := validation_errors || duplicate_count || ' duplicate mapping(s) detected. ';
    END IF;
    
    -- Check for mappings to non-existent target columns
    SELECT COUNT(*) INTO orphan_count
    FROM field_mappings fm
    WHERE fm.target_table LIKE UPPER(:table_filter)
      AND NOT EXISTS (
          SELECT 1 
          FROM target_schemas ts
          WHERE ts.table_name = fm.target_table
            AND ts.column_name = fm.target_column
            AND ts.active = TRUE
      );
    
    IF (orphan_count > 0) THEN
        validation_errors := validation_errors || orphan_count || ' mapping(s) to non-existent target columns. ';
    END IF;
    
    -- Check for invalid mapping methods
    SELECT COUNT(*) INTO invalid_method_count
    FROM field_mappings
    WHERE target_table LIKE UPPER(:table_filter)
      AND mapping_method NOT IN ('MANUAL', 'ML_AUTO', 'LLM_CORTEX', 'SYSTEM');
    
    IF (invalid_method_count > 0) THEN
        validation_errors := validation_errors || invalid_method_count || ' mapping(s) with invalid method. ';
    END IF;
    
    -- Return validation result
    IF (validation_errors = '') THEN
        IF (:target_table IS NULL) THEN
            result_msg := 'Validation passed for all field mappings';
        ELSE
            result_msg := 'Validation passed for table: ' || UPPER(:target_table);
        END IF;
    ELSE
        IF (:target_table IS NULL) THEN
            result_msg := 'Validation FAILED for field mappings - Errors: ' || validation_errors;
        ELSE
            result_msg := 'Validation FAILED for table: ' || UPPER(:target_table) || ' - Errors: ' || validation_errors;
        END IF;
    END IF;
    
    RETURN result_msg;
END;
$$;

