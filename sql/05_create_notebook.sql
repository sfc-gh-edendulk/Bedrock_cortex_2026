/*
================================================================================
 AWS + SNOWFLAKE GENAI WORKSHOP
 Module 5: Create Snowflake Notebook
 
 This script uploads the workshop notebook to Snowflake.
================================================================================
*/

USE ROLE ACCOUNTADMIN;
USE DATABASE WORKSHOP_DB;
USE SCHEMA PUBLIC;
USE WAREHOUSE WORKSHOP_WH;

-- ============================================================================
-- STEP 1: CREATE STAGE FOR NOTEBOOK
-- ============================================================================

CREATE OR REPLACE STAGE NOTEBOOK_STAGE
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Stage for Snowflake Notebooks';

-- ============================================================================
-- STEP 2: UPLOAD NOTEBOOK
-- You can upload the notebook file using:
-- 1. Snowflake CLI: snow stage copy notebooks/workshop_demo.ipynb @NOTEBOOK_STAGE
-- 2. Snowsight UI: Upload to the NOTEBOOK_STAGE
-- 3. PUT command (from SnowSQL)
-- ============================================================================

-- After uploading, verify the file is there
LIST @NOTEBOOK_STAGE;

-- ============================================================================
-- STEP 3: CREATE THE NOTEBOOK
-- ============================================================================

-- Create notebook from the uploaded file
CREATE OR REPLACE NOTEBOOK WORKSHOP_DB.PUBLIC.WORKSHOP_NOTEBOOK
    FROM '@NOTEBOOK_STAGE'
    MAIN_FILE = 'workshop_demo.ipynb'
    COMMENT = 'Interactive workshop notebook for AWS + Snowflake GenAI';

-- ============================================================================
-- STEP 4: GRANT ACCESS
-- ============================================================================

GRANT USAGE ON NOTEBOOK WORKSHOP_DB.PUBLIC.WORKSHOP_NOTEBOOK TO ROLE ACCOUNTADMIN;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

SHOW NOTEBOOKS IN SCHEMA WORKSHOP_DB.PUBLIC;

SELECT 'Notebook created! Open it in Snowsight under Projects > Notebooks' AS STATUS;
