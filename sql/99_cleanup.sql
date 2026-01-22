/*
================================================================================
 AWS + SNOWFLAKE GENAI WORKSHOP
 Module 99: Cleanup
 
 This script removes all workshop resources from Snowflake.
 Run this when you're done with the workshop.
================================================================================
*/

USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- WARNING: This will delete ALL workshop resources!
-- ============================================================================

-- Prompt for confirmation (comment out the line below to actually run cleanup)
SELECT 'WARNING: Uncomment the cleanup commands below to delete all workshop resources' AS MESSAGE;

/*
-- ============================================================================
-- CLEANUP COMMANDS (uncomment to execute)
-- ============================================================================

-- Drop Streamlit app
DROP STREAMLIT IF EXISTS WORKSHOP_DB.PUBLIC.WORKSHOP_APP;

-- Drop Notebook
DROP NOTEBOOK IF EXISTS WORKSHOP_DB.PUBLIC.WORKSHOP_NOTEBOOK;

-- Drop Agent
DROP AGENT IF EXISTS WORKSHOP_DB.AGENTS.WORKSHOP_AGENT;

-- Drop Cortex Search Service
DROP CORTEX SEARCH SERVICE IF EXISTS WORKSHOP_DB.PUBLIC.FOMC_SEARCH_SERVICE;

-- Drop Semantic View
DROP SEMANTIC VIEW IF EXISTS WORKSHOP_DB.REVENUE_TIMESERIES.REVENUE_SEMANTIC_VIEW;

-- Drop Functions and Procedures
DROP FUNCTION IF EXISTS WORKSHOP_DB.PUBLIC.SEARCH_FOMC_DOCS(VARCHAR, INT);
DROP FUNCTION IF EXISTS WORKSHOP_DB.PUBLIC.CHUNK_TEXT(VARCHAR, INT, INT);
DROP FUNCTION IF EXISTS WORKSHOP_DB.PUBLIC.INVOKE_BEDROCK_AGENT(VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS WORKSHOP_DB.PUBLIC.HYBRID_CORTEX_BEDROCK(VARCHAR);
DROP PROCEDURE IF EXISTS WORKSHOP_DB.AGENTS.CHAT_WITH_AGENT(VARCHAR, VARCHAR);
DROP PROCEDURE IF EXISTS WORKSHOP_DB.PUBLIC.CHAT_WITH_BEDROCK_AGENT(VARCHAR);

-- Drop External Access Integration (for Bedrock)
DROP EXTERNAL ACCESS INTEGRATION IF EXISTS BEDROCK_INTEGRATION;
DROP NETWORK RULE IF EXISTS BEDROCK_NETWORK_RULE;
DROP SECRET IF EXISTS AWS_CREDENTIALS;
DROP SECRET IF EXISTS AWS_SESSION_TOKEN_SECRET;

-- Drop Tables
DROP TABLE IF EXISTS WORKSHOP_DB.PUBLIC.FOMC_DOCUMENTS_RAW;
DROP TABLE IF EXISTS WORKSHOP_DB.PUBLIC.FOMC_DOCS_CHUNKS;
DROP TABLE IF EXISTS WORKSHOP_DB.REVENUE_TIMESERIES.DAILY_REVENUE;
DROP TABLE IF EXISTS WORKSHOP_DB.REVENUE_TIMESERIES.DAILY_REVENUE_BY_PRODUCT;
DROP TABLE IF EXISTS WORKSHOP_DB.REVENUE_TIMESERIES.DAILY_REVENUE_BY_REGION;

-- Drop Stages
DROP STAGE IF EXISTS WORKSHOP_DB.PUBLIC.FOMC_DOCS;
DROP STAGE IF EXISTS WORKSHOP_DB.PUBLIC.S3_PUBLIC_DATA;
DROP STAGE IF EXISTS WORKSHOP_DB.PUBLIC.NOTEBOOK_STAGE;
DROP STAGE IF EXISTS WORKSHOP_DB.PUBLIC.STREAMLIT_STAGE;
DROP STAGE IF EXISTS WORKSHOP_DB.REVENUE_TIMESERIES.RAW_DATA;

-- Drop Schemas
DROP SCHEMA IF EXISTS WORKSHOP_DB.AGENTS;
DROP SCHEMA IF EXISTS WORKSHOP_DB.REVENUE_TIMESERIES;
DROP SCHEMA IF EXISTS WORKSHOP_DB.PUBLIC;

-- Drop Database
DROP DATABASE IF EXISTS WORKSHOP_DB;

-- Drop Warehouse
DROP WAREHOUSE IF EXISTS WORKSHOP_WH;

-- Drop User (optional - uncomment if you created a workshop user)
-- DROP USER IF EXISTS WORKSHOP_USER;

SELECT 'Cleanup complete! All workshop resources have been removed.' AS STATUS;

*/

-- ============================================================================
-- AWS CLEANUP REMINDER
-- ============================================================================

SELECT 'Remember to also delete AWS resources:' AS REMINDER
UNION ALL
SELECT '1. Delete CloudFormation stack (bedrock_agent_stack)'
UNION ALL
SELECT '2. Delete S3 bucket with Lambda layer'
UNION ALL
SELECT '3. Delete any Secrets Manager secrets'
UNION ALL
SELECT '4. Review IAM roles created by the stack';
