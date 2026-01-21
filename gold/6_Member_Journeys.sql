-- ============================================
-- GOLD LAYER: MEMBER JOURNEYS
-- ============================================
-- Purpose: Track member healthcare journeys and care episodes
-- 
-- This script creates:
--   1. Member Journeys table (tracks complete care episodes)
--   2. Journey Events table (tracks individual events within journeys)
--   3. Journey Analytics views
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================

USE ROLE SYSADMIN;
USE DATABASE &{DATABASE_NAME};
USE SCHEMA &{GOLD_SCHEMA_NAME};

-- ============================================
-- TABLE 1: MEMBER_JOURNEYS (HYBRID TABLE)
-- ============================================
-- Tracks complete healthcare journeys for members
-- Examples: Chronic disease management, surgical procedures, preventive care

CREATE HYBRID TABLE IF NOT EXISTS member_journeys (
    journey_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(100) NOT NULL,
    tpa VARCHAR(100) NOT NULL,
    journey_type VARCHAR(100) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    current_stage VARCHAR(50) NOT NULL,
    primary_diagnosis VARCHAR(50),
    primary_provider_id VARCHAR(100),
    total_cost NUMBER(18,2) DEFAULT 0,
    num_visits NUMBER(10,0) DEFAULT 0,
    num_providers NUMBER(10,0) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    quality_score NUMBER(5,2),
    patient_satisfaction NUMBER(5,2),
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    INDEX idx_member_journeys_member (member_id),
    INDEX idx_member_journeys_tpa (tpa),
    INDEX idx_member_journeys_type (journey_type),
    INDEX idx_member_journeys_active (is_active)
)
COMMENT = 'Member healthcare journeys and care episodes';

-- ============================================
-- TABLE 2: JOURNEY_EVENTS (HYBRID TABLE)
-- ============================================
-- Tracks individual events within each journey

CREATE HYBRID TABLE IF NOT EXISTS journey_events (
    event_id VARCHAR(50) PRIMARY KEY,
    journey_id VARCHAR(50) NOT NULL,
    event_date DATE NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    event_stage VARCHAR(50) NOT NULL,
    provider_id VARCHAR(100),
    diagnosis_code VARCHAR(50),
    procedure_code VARCHAR(50),
    cost NUMBER(18,2) DEFAULT 0,
    notes VARCHAR(4000),
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (journey_id) REFERENCES member_journeys(journey_id),
    INDEX idx_journey_events_journey (journey_id),
    INDEX idx_journey_events_date (event_date),
    INDEX idx_journey_events_type (event_type)
)
COMMENT = 'Individual events within member healthcare journeys';

-- ============================================
-- VIEW 1: ACTIVE_JOURNEYS
-- ============================================
-- Shows currently active journeys with key metrics

CREATE OR REPLACE VIEW v_active_journeys AS
SELECT 
    j.journey_id,
    j.member_id,
    j.tpa,
    j.journey_type,
    j.start_date,
    j.current_stage,
    j.primary_diagnosis,
    j.total_cost,
    j.num_visits,
    j.num_providers,
    DATEDIFF(day, j.start_date, CURRENT_DATE()) as days_in_journey,
    COUNT(e.event_id) as total_events,
    MAX(e.event_date) as last_event_date
FROM member_journeys j
LEFT JOIN journey_events e ON j.journey_id = e.journey_id
WHERE j.is_active = TRUE
GROUP BY 
    j.journey_id, j.member_id, j.tpa, j.journey_type,
    j.start_date, j.current_stage, j.primary_diagnosis,
    j.total_cost, j.num_visits, j.num_providers
ORDER BY j.start_date DESC;

-- ============================================
-- VIEW 2: JOURNEY_SUMMARY_BY_TYPE
-- ============================================
-- Aggregates journey metrics by type and TPA

CREATE OR REPLACE VIEW v_journey_summary_by_type AS
SELECT 
    tpa,
    journey_type,
    COUNT(*) as total_journeys,
    SUM(CASE WHEN is_active THEN 1 ELSE 0 END) as active_journeys,
    SUM(CASE WHEN NOT is_active THEN 1 ELSE 0 END) as completed_journeys,
    AVG(total_cost) as avg_cost,
    AVG(num_visits) as avg_visits,
    AVG(num_providers) as avg_providers,
    AVG(CASE 
        WHEN end_date IS NOT NULL 
        THEN DATEDIFF(day, start_date, end_date)
        ELSE NULL
    END) as avg_duration_days,
    AVG(quality_score) as avg_quality_score,
    AVG(patient_satisfaction) as avg_satisfaction
FROM member_journeys
GROUP BY tpa, journey_type
ORDER BY tpa, journey_type;

-- ============================================
-- VIEW 3: HIGH_COST_JOURNEYS
-- ============================================
-- Identifies high-cost journeys for case management

CREATE OR REPLACE VIEW v_high_cost_journeys AS
SELECT 
    j.journey_id,
    j.member_id,
    j.tpa,
    j.journey_type,
    j.start_date,
    j.current_stage,
    j.total_cost,
    j.num_visits,
    j.num_providers,
    DATEDIFF(day, j.start_date, COALESCE(j.end_date, CURRENT_DATE())) as duration_days,
    j.total_cost / NULLIF(j.num_visits, 0) as cost_per_visit,
    COUNT(e.event_id) as total_events
FROM member_journeys j
LEFT JOIN journey_events e ON j.journey_id = e.journey_id
WHERE j.total_cost > 10000  -- High cost threshold
GROUP BY 
    j.journey_id, j.member_id, j.tpa, j.journey_type,
    j.start_date, j.current_stage, j.total_cost,
    j.num_visits, j.num_providers, j.end_date
ORDER BY j.total_cost DESC;

-- ============================================
-- VIEW 4: JOURNEY_EVENT_TIMELINE
-- ============================================
-- Detailed timeline of events for each journey

CREATE OR REPLACE VIEW v_journey_event_timeline AS
SELECT 
    j.journey_id,
    j.member_id,
    j.tpa,
    j.journey_type,
    e.event_id,
    e.event_date,
    e.event_type,
    e.event_stage,
    e.provider_id,
    e.diagnosis_code,
    e.procedure_code,
    e.cost,
    DATEDIFF(day, j.start_date, e.event_date) as days_from_start,
    ROW_NUMBER() OVER (PARTITION BY j.journey_id ORDER BY e.event_date) as event_sequence
FROM member_journeys j
JOIN journey_events e ON j.journey_id = e.journey_id
ORDER BY j.journey_id, e.event_date;

-- ============================================
-- PROCEDURE: UPDATE_JOURNEY_METRICS
-- ============================================
-- Recalculates journey metrics from events

CREATE OR REPLACE PROCEDURE update_journey_metrics(
    p_journey_id VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- Update metrics for specific journey or all journeys
    MERGE INTO member_journeys j
    USING (
        SELECT 
            journey_id,
            COUNT(*) as event_count,
            SUM(cost) as total_event_cost,
            MIN(event_date) as first_event,
            MAX(event_date) as last_event,
            COUNT(DISTINCT provider_id) as provider_count
        FROM journey_events
        WHERE (:p_journey_id IS NULL OR journey_id = :p_journey_id)
        GROUP BY journey_id
    ) e
    ON j.journey_id = e.journey_id
    WHEN MATCHED THEN
        UPDATE SET
            j.num_visits = e.event_count,
            j.total_cost = e.total_event_cost,
            j.num_providers = e.provider_count,
            j.updated_at = CURRENT_TIMESTAMP();
    
    RETURN 'Journey metrics updated for: ' || 
           COALESCE(:p_journey_id, 'ALL journeys');
END;
$$;

-- ============================================
-- PROCEDURE: CLOSE_JOURNEY
-- ============================================
-- Marks a journey as completed

CREATE OR REPLACE PROCEDURE close_journey(
    p_journey_id VARCHAR,
    p_end_date DATE DEFAULT NULL,
    p_quality_score NUMBER DEFAULT NULL,
    p_patient_satisfaction NUMBER DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    UPDATE member_journeys
    SET 
        end_date = COALESCE(:p_end_date, CURRENT_DATE()),
        is_active = FALSE,
        current_stage = 'COMPLETED',
        quality_score = :p_quality_score,
        patient_satisfaction = :p_patient_satisfaction,
        updated_at = CURRENT_TIMESTAMP()
    WHERE journey_id = :p_journey_id;
    
    RETURN 'Journey closed: ' || :p_journey_id;
END;
$$;

-- ============================================
-- PROCEDURE: CREATE_JOURNEY_EVENT
-- ============================================
-- Adds a new event to a journey

CREATE OR REPLACE PROCEDURE create_journey_event(
    p_journey_id VARCHAR,
    p_event_date DATE,
    p_event_type VARCHAR,
    p_event_stage VARCHAR,
    p_provider_id VARCHAR DEFAULT NULL,
    p_diagnosis_code VARCHAR DEFAULT NULL,
    p_procedure_code VARCHAR DEFAULT NULL,
    p_cost NUMBER DEFAULT 0,
    p_notes VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_event_id VARCHAR;
BEGIN
    -- Generate event ID
    SET v_event_id = 'EVT' || SUBSTR(UUID_STRING(), 1, 12);
    
    -- Insert event
    INSERT INTO journey_events (
        event_id, journey_id, event_date, event_type, event_stage,
        provider_id, diagnosis_code, procedure_code, cost, notes
    )
    VALUES (
        :v_event_id, :p_journey_id, :p_event_date, :p_event_type, :p_event_stage,
        :p_provider_id, :p_diagnosis_code, :p_procedure_code, :p_cost, :p_notes
    );
    
    -- Update journey metrics
    CALL update_journey_metrics(:p_journey_id);
    
    RETURN 'Event created: ' || :v_event_id;
END;
$$;

-- ============================================
-- VERIFICATION
-- ============================================

SELECT 'Member Journeys Table Created' AS status;
SELECT 'Journey Events Table Created' AS status;
SELECT 'Journey Views Created' AS status;
SELECT 'Journey Procedures Created' AS status;

-- Show table structures
DESCRIBE TABLE member_journeys;
DESCRIBE TABLE journey_events;

-- ============================================
-- USAGE EXAMPLES
-- ============================================

/*
-- Example 1: Create a new journey
INSERT INTO member_journeys (
    journey_id, member_id, tpa, journey_type, start_date, current_stage, primary_diagnosis
)
VALUES (
    'JRN' || SUBSTR(UUID_STRING(), 1, 12),
    'MEM000001',
    'provider_a',
    'CHRONIC_DISEASE_MANAGEMENT',
    CURRENT_DATE(),
    'INITIAL_VISIT',
    'E11.9'
);

-- Example 2: Add an event to a journey
CALL create_journey_event(
    'JRN123456789012',
    CURRENT_DATE(),
    'APPOINTMENT',
    'FOLLOW_UP',
    'PRV000001',
    'E11.9',
    '99213',
    150.00,
    'Routine diabetes follow-up'
);

-- Example 3: Update journey metrics
CALL update_journey_metrics('JRN123456789012');

-- Example 4: Close a journey
CALL close_journey(
    'JRN123456789012',
    CURRENT_DATE(),
    4.5,
    4.8
);

-- Example 5: Query active journeys
SELECT * FROM v_active_journeys WHERE tpa = 'provider_a';

-- Example 6: Journey summary by type
SELECT * FROM v_journey_summary_by_type ORDER BY avg_cost DESC;

-- Example 7: High-cost journeys for case management
SELECT * FROM v_high_cost_journeys LIMIT 10;

-- Example 8: Event timeline for a specific journey
SELECT * FROM v_journey_event_timeline WHERE journey_id = 'JRN123456789012';
*/
