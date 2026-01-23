-- ============================================
-- CONTAINER SERVICE ACCOUNT-LEVEL PRIVILEGES
-- ============================================
-- Purpose: Grant account-level privileges required for Snowpark Container Services
-- 
-- IMPORTANT: This script MUST be run by ACCOUNTADMIN role
-- Run this ONCE during initial setup, before deploying containers
--
-- These privileges allow the admin role to:
--   1. Create compute pools for container services
--   2. Bind service endpoints for public access
--
-- After running this script, SYSADMIN can create compute pools and image repositories,
-- and grant object-level permissions to the admin role.
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================

SET DATABASE_NAME = '$DATABASE_NAME';
SET ADMIN_ROLE_NAME = $DATABASE_NAME || '_ADMIN';

-- ============================================
-- GRANT ACCOUNT-LEVEL PRIVILEGES
-- ============================================

-- Step 1: ACCOUNTADMIN grants privileges to SYSADMIN
USE ROLE ACCOUNTADMIN;

-- Grant CREATE COMPUTE POOL privilege to SYSADMIN
-- This allows SYSADMIN to create compute pools and delegate to other roles
GRANT CREATE COMPUTE POOL ON ACCOUNT TO ROLE SYSADMIN;

-- Grant BIND SERVICE ENDPOINT privilege to SYSADMIN
-- This allows SYSADMIN to create public endpoints and delegate to other roles
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE SYSADMIN;

-- Step 2: SYSADMIN grants privileges to admin role
USE ROLE SYSADMIN;

-- Grant CREATE COMPUTE POOL privilege to admin role
-- This allows the admin role to create compute pools for container services
GRANT CREATE COMPUTE POOL ON ACCOUNT TO ROLE IDENTIFIER($ADMIN_ROLE_NAME);

-- Grant BIND SERVICE ENDPOINT privilege to admin role
-- This allows the admin role to create public endpoints for services
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE IDENTIFIER($ADMIN_ROLE_NAME);

-- ============================================
-- VERIFICATION
-- ============================================

-- Show grants to SYSADMIN
SHOW GRANTS TO ROLE SYSADMIN;

-- Show grants to admin role
SHOW GRANTS TO ROLE IDENTIFIER($ADMIN_ROLE_NAME);

-- Display success message
SELECT 'Container service account-level privileges granted successfully' AS status,
       'SYSADMIN → ' || $ADMIN_ROLE_NAME AS privilege_flow,
       'CREATE COMPUTE POOL, BIND SERVICE ENDPOINT' AS privileges_granted;

-- ============================================
-- NEXT STEPS
-- ============================================
-- After running this script:
-- 1. SYSADMIN has CREATE COMPUTE POOL and BIND SERVICE ENDPOINT privileges
-- 2. Admin role has CREATE COMPUTE POOL and BIND SERVICE ENDPOINT privileges
-- 3. SYSADMIN can create compute pools and image repositories
-- 4. SYSADMIN can grant USAGE/MONITOR/OPERATE on compute pools to admin role
-- 5. SYSADMIN can grant READ/WRITE on image repositories to admin role
-- 6. Admin role can deploy container services using deploy_container.sh
--
-- Privilege Flow:
--   ACCOUNTADMIN → SYSADMIN → BORDEREAU_PROCESSING_PIPELINE_ADMIN
-- ============================================
