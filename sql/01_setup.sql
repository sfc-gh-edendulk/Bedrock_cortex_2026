/*
================================================================================
 AWS + SNOWFLAKE GENAI WORKSHOP
 Module 1: Environment Setup
 
 This script creates the base infrastructure for the workshop:
 - Database and schemas
 - Virtual warehouse
 - User and role (optional)
 - Stages for data
================================================================================
*/

-- ============================================================================
-- CONFIGURATION VARIABLES
-- Modify these values as needed for your environment
-- ============================================================================

SET WORKSHOP_DB = 'WORKSHOP_DB';
SET WORKSHOP_WH = 'WORKSHOP_WH';
SET WORKSHOP_USER = 'WORKSHOP_USER';
SET WORKSHOP_PWD = 'ChangeMe123!';  -- Change this password!

-- ============================================================================
-- SETUP
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- Create Database
CREATE DATABASE IF NOT EXISTS IDENTIFIER($WORKSHOP_DB);

-- Create Schemas
CREATE SCHEMA IF NOT EXISTS IDENTIFIER($WORKSHOP_DB || '.PUBLIC');
CREATE SCHEMA IF NOT EXISTS IDENTIFIER($WORKSHOP_DB || '.REVENUE_TIMESERIES');
CREATE SCHEMA IF NOT EXISTS IDENTIFIER($WORKSHOP_DB || '.AGENTS');

-- Create Warehouse
CREATE OR REPLACE WAREHOUSE IDENTIFIER($WORKSHOP_WH) WITH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 120
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Workshop warehouse for GenAI demo';

-- ============================================================================
-- USER SETUP (Optional - skip if using existing user)
-- ============================================================================

-- Create workshop user
CREATE USER IF NOT EXISTS IDENTIFIER($WORKSHOP_USER) 
    PASSWORD = $WORKSHOP_PWD
    DEFAULT_ROLE = 'ACCOUNTADMIN'
    DEFAULT_WAREHOUSE = $WORKSHOP_WH
    COMMENT = 'Workshop demo user';

-- Grant privileges
GRANT ROLE ACCOUNTADMIN TO USER IDENTIFIER($WORKSHOP_USER);
GRANT USAGE ON WAREHOUSE IDENTIFIER($WORKSHOP_WH) TO ROLE ACCOUNTADMIN;
GRANT ALL ON DATABASE IDENTIFIER($WORKSHOP_DB) TO ROLE ACCOUNTADMIN;

-- ============================================================================
-- CREATE STAGES FOR DATA
-- ============================================================================

USE DATABASE IDENTIFIER($WORKSHOP_DB);
USE SCHEMA PUBLIC;
USE WAREHOUSE IDENTIFIER($WORKSHOP_WH);

-- Stage for FOMC PDF documents (for Cortex Search)
CREATE OR REPLACE STAGE FOMC_DOCS
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Stage for FOMC meeting minutes PDFs';

-- Stage for loading data from public S3 (read-only)
CREATE OR REPLACE STAGE S3_PUBLIC_DATA
    URL = 's3://aws-agents-lab-public/'
    COMMENT = 'Public S3 bucket with workshop data';

-- Stage for revenue data
USE SCHEMA REVENUE_TIMESERIES;

CREATE OR REPLACE STAGE RAW_DATA
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Stage for revenue CSV files and semantic model';

-- ============================================================================
-- LOAD SAMPLE DATA FROM PUBLIC S3
-- ============================================================================

-- Copy FOMC PDFs to internal stage
USE SCHEMA PUBLIC;

COPY FILES INTO @FOMC_DOCS 
FROM @S3_PUBLIC_DATA/fomc/
PATTERN = '.*\.pdf';

-- Verify files loaded
LIST @FOMC_DOCS;

-- Copy revenue data to internal stage
USE SCHEMA REVENUE_TIMESERIES;

COPY FILES INTO @RAW_DATA 
FROM @S3_PUBLIC_DATA/data/
FILES = (
    'daily_revenue_combined.csv',
    'daily_revenue_by_product_combined.csv', 
    'daily_revenue_by_region_combined.csv'
);

-- Verify files loaded
LIST @RAW_DATA;

-- ============================================================================
-- CREATE BASE TABLES FOR REVENUE DATA
-- ============================================================================

CREATE OR REPLACE TABLE DAILY_REVENUE (
    DATE DATE,
    REVENUE FLOAT,
    COGS FLOAT,
    FORECASTED_REVENUE FLOAT
);

CREATE OR REPLACE TABLE DAILY_REVENUE_BY_PRODUCT (
    DATE DATE,
    PRODUCT_LINE VARCHAR(256),
    REVENUE FLOAT,
    COGS FLOAT,
    FORECASTED_REVENUE FLOAT
);

CREATE OR REPLACE TABLE DAILY_REVENUE_BY_REGION (
    DATE DATE,
    SALES_REGION VARCHAR(256),
    REVENUE FLOAT,
    COGS FLOAT,
    FORECASTED_REVENUE FLOAT
);

-- Load data into tables
COPY INTO DAILY_REVENUE
FROM @RAW_DATA/daily_revenue_combined.csv
FILE_FORMAT = (
    TYPE = CSV,
    SKIP_HEADER = 1,
    FIELD_DELIMITER = ',',
    FIELD_OPTIONALLY_ENCLOSED_BY = '"',
    DATE_FORMAT = 'AUTO',
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
)
ON_ERROR = CONTINUE;

COPY INTO DAILY_REVENUE_BY_PRODUCT
FROM @RAW_DATA/daily_revenue_by_product_combined.csv
FILE_FORMAT = (
    TYPE = CSV,
    SKIP_HEADER = 1,
    FIELD_DELIMITER = ',',
    FIELD_OPTIONALLY_ENCLOSED_BY = '"',
    DATE_FORMAT = 'AUTO',
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
)
ON_ERROR = CONTINUE;

COPY INTO DAILY_REVENUE_BY_REGION
FROM @RAW_DATA/daily_revenue_by_region_combined.csv
FILE_FORMAT = (
    TYPE = CSV,
    SKIP_HEADER = 1,
    FIELD_DELIMITER = ',',
    FIELD_OPTIONALLY_ENCLOSED_BY = '"',
    DATE_FORMAT = 'AUTO',
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
)
ON_ERROR = CONTINUE;

-- Verify data loaded
SELECT 'DAILY_REVENUE' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM DAILY_REVENUE
UNION ALL
SELECT 'DAILY_REVENUE_BY_PRODUCT', COUNT(*) FROM DAILY_REVENUE_BY_PRODUCT
UNION ALL
SELECT 'DAILY_REVENUE_BY_REGION', COUNT(*) FROM DAILY_REVENUE_BY_REGION;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Check database objects
SHOW SCHEMAS IN DATABASE IDENTIFIER($WORKSHOP_DB);
SHOW STAGES IN DATABASE IDENTIFIER($WORKSHOP_DB);
SHOW TABLES IN SCHEMA IDENTIFIER($WORKSHOP_DB || '.REVENUE_TIMESERIES');

SELECT 'Setup complete! Proceed to 02_document_ai_search.sql' AS STATUS;
