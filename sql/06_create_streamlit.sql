/*
================================================================================
 AWS + SNOWFLAKE GENAI WORKSHOP
 Module 6: Create Streamlit App in Snowflake
 
 This script deploys the Streamlit application to Snowflake.
================================================================================
*/

USE ROLE ACCOUNTADMIN;
USE DATABASE WORKSHOP_DB;
USE SCHEMA PUBLIC;
USE WAREHOUSE WORKSHOP_WH;

-- ============================================================================
-- STEP 1: CREATE STAGE FOR STREAMLIT FILES
-- ============================================================================

CREATE OR REPLACE STAGE STREAMLIT_STAGE
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Stage for Streamlit application files';

-- ============================================================================
-- STEP 2: UPLOAD STREAMLIT FILES
-- Upload using one of these methods:
-- 1. Snowflake CLI: snow stage copy streamlit/app.py @STREAMLIT_STAGE
-- 2. Snowsight UI: Upload files to STREAMLIT_STAGE
-- 3. PUT command (from SnowSQL)
-- ============================================================================

-- Verify files uploaded
LIST @STREAMLIT_STAGE;

-- ============================================================================
-- STEP 3: CREATE THE STREAMLIT APP
-- ============================================================================

CREATE OR REPLACE STREAMLIT WORKSHOP_DB.PUBLIC.WORKSHOP_APP
    ROOT_LOCATION = '@WORKSHOP_DB.PUBLIC.STREAMLIT_STAGE'
    MAIN_FILE = 'app.py'
    QUERY_WAREHOUSE = 'WORKSHOP_WH'
    COMMENT = 'AWS + Snowflake GenAI Workshop Chat Application';

-- ============================================================================
-- STEP 4: GRANT ACCESS
-- ============================================================================

GRANT USAGE ON STREAMLIT WORKSHOP_DB.PUBLIC.WORKSHOP_APP TO ROLE ACCOUNTADMIN;

-- For broader access:
-- GRANT USAGE ON STREAMLIT WORKSHOP_DB.PUBLIC.WORKSHOP_APP TO ROLE PUBLIC;

-- ============================================================================
-- STEP 5: GET THE APP URL
-- ============================================================================

SHOW STREAMLITS IN SCHEMA WORKSHOP_DB.PUBLIC;

-- The URL will be shown in the output above
-- Format: https://<account>.snowflakecomputing.com/...

SELECT 'Streamlit app created! Find it in Snowsight under Projects > Streamlit' AS STATUS;
