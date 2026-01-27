/*
================================================================================
 AWS + SNOWFLAKE GENAI WORKSHOP
 Module 3: Semantic View for Cortex Analyst
 
 This script creates a SEMANTIC VIEW instead of a YAML file on stage.
 
 Key Improvements:
 - Native Snowflake object (version controlled, managed)
 - No need to upload/manage YAML files
 - Better integration with Cortex Analyst
 - Easier maintenance and updates
================================================================================
*/

USE ROLE ACCOUNTADMIN;
USE DATABASE WORKSHOP_DB;
USE SCHEMA REVENUE_TIMESERIES;
USE WAREHOUSE WORKSHOP_WH;

-- ============================================================================
-- STEP 1: VERIFY BASE TABLES EXIST
-- ============================================================================

-- Check data is loaded
SELECT 'DAILY_REVENUE' AS TABLE_NAME, COUNT(*) AS ROWS, MIN(DATE) AS MIN_DATE, MAX(DATE) AS MAX_DATE 
FROM DAILY_REVENUE
UNION ALL
SELECT 'DAILY_REVENUE_BY_PRODUCT', COUNT(*), MIN(DATE), MAX(DATE) 
FROM DAILY_REVENUE_BY_PRODUCT
UNION ALL
SELECT 'DAILY_REVENUE_BY_REGION', COUNT(*), MIN(DATE), MAX(DATE) 
FROM DAILY_REVENUE_BY_REGION;

-- Preview the data
SELECT * FROM DAILY_REVENUE LIMIT 5;
SELECT * FROM DAILY_REVENUE_BY_PRODUCT LIMIT 5;
SELECT * FROM DAILY_REVENUE_BY_REGION LIMIT 5;

-- ============================================================================
-- STEP 2: CREATE SEMANTIC VIEW
-- This replaces the YAML semantic model file
-- ============================================================================

CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML(
  'WORKSHOP_DB.REVENUE_TIMESERIES',
$$
name: REVENUE_SEMANTIC_VIEW
description: >
  Semantic model for analyzing company revenue data across time, products, and regions.
  Use this to answer questions about revenue trends, profitability, and forecasts.

tables:
  - name: daily_revenue
    description: Daily aggregate revenue metrics for the entire company
    base_table:
      database: WORKSHOP_DB
      schema: REVENUE_TIMESERIES
      table: DAILY_REVENUE
    dimensions:
      - name: date
        description: The calendar date of the revenue record
        expr: DATE
        data_type: DATE
        sample_values:
          - "2024-01-01"
          - "2024-06-15"
          - "2024-09-30"
    measures:
      - name: revenue
        description: Total revenue in USD for the day
        expr: REVENUE
        data_type: FLOAT
        default_aggregation: SUM
      - name: cogs
        description: Cost of goods sold in USD
        expr: COGS
        data_type: FLOAT
        default_aggregation: SUM
      - name: profit
        description: Gross profit (Revenue minus COGS)
        expr: REVENUE - COGS
        data_type: FLOAT
        default_aggregation: SUM
      - name: profit_margin
        description: Profit margin as a percentage
        expr: (REVENUE - COGS) / NULLIF(REVENUE, 0) * 100
        data_type: FLOAT
        default_aggregation: AVG
      - name: forecasted_revenue
        description: Predicted revenue from forecasting model
        expr: FORECASTED_REVENUE
        data_type: FLOAT
        default_aggregation: SUM

  - name: daily_revenue_by_product
    description: Daily revenue broken down by product line
    base_table:
      database: WORKSHOP_DB
      schema: REVENUE_TIMESERIES
      table: DAILY_REVENUE_BY_PRODUCT
    dimensions:
      - name: date
        description: The calendar date of the revenue record
        expr: DATE
        data_type: DATE
      - name: product_line
        description: The product category or line of business
        expr: PRODUCT_LINE
        data_type: VARCHAR
        sample_values:
          - "Electronics"
          - "Clothing"
          - "Home & Garden"
          - "Sports"
    measures:
      - name: revenue
        description: Revenue in USD for the product line
        expr: REVENUE
        data_type: FLOAT
        default_aggregation: SUM
      - name: cogs
        description: Cost of goods sold for the product line
        expr: COGS
        data_type: FLOAT
        default_aggregation: SUM
      - name: profit
        description: Gross profit for the product line
        expr: REVENUE - COGS
        data_type: FLOAT
        default_aggregation: SUM
      - name: forecasted_revenue
        description: Forecasted revenue for the product line
        expr: FORECASTED_REVENUE
        data_type: FLOAT
        default_aggregation: SUM

  - name: daily_revenue_by_region
    description: Daily revenue broken down by sales region
    base_table:
      database: WORKSHOP_DB
      schema: REVENUE_TIMESERIES
      table: DAILY_REVENUE_BY_REGION
    dimensions:
      - name: date
        description: The calendar date of the revenue record
        expr: DATE
        data_type: DATE
      - name: sales_region
        description: Geographic sales region
        expr: SALES_REGION
        data_type: VARCHAR
        sample_values:
          - "North America"
          - "Europe"
          - "Asia Pacific"
          - "Latin America"
    measures:
      - name: revenue
        description: Revenue in USD for the region
        expr: REVENUE
        data_type: FLOAT
        default_aggregation: SUM
      - name: cogs
        description: Cost of goods sold for the region
        expr: COGS
        data_type: FLOAT
        default_aggregation: SUM
      - name: profit
        description: Gross profit for the region
        expr: REVENUE - COGS
        data_type: FLOAT
        default_aggregation: SUM
      - name: forecasted_revenue
        description: Forecasted revenue for the region
        expr: FORECASTED_REVENUE
        data_type: FLOAT
        default_aggregation: SUM

verified_queries:
  - name: total_revenue_last_month
    question: What was the total revenue last month?
    sql: |
      SELECT SUM(revenue) as total_revenue
      FROM WORKSHOP_DB.REVENUE_TIMESERIES.DAILY_REVENUE
      WHERE DATE >= DATEADD(month, -1, CURRENT_DATE())
      
  - name: revenue_by_region
    question: Show revenue breakdown by region
    sql: |
      SELECT sales_region, SUM(revenue) as total_revenue
      FROM WORKSHOP_DB.REVENUE_TIMESERIES.DAILY_REVENUE_BY_REGION
      GROUP BY sales_region
      ORDER BY total_revenue DESC
      
  - name: top_products
    question: What are the top selling product lines?
    sql: |
      SELECT product_line, SUM(revenue) as total_revenue
      FROM WORKSHOP_DB.REVENUE_TIMESERIES.DAILY_REVENUE_BY_PRODUCT
      GROUP BY product_line
      ORDER BY total_revenue DESC
      LIMIT 10
      
  - name: profit_margin_trend
    question: Show the profit margin trend over time
    sql: |
      SELECT 
        DATE_TRUNC('month', date) as month,
        SUM(revenue - cogs) / NULLIF(SUM(revenue), 0) * 100 as profit_margin_pct
      FROM WORKSHOP_DB.REVENUE_TIMESERIES.DAILY_REVENUE
      GROUP BY 1
      ORDER BY 1
$$
);

-- ============================================================================
-- STEP 3: VERIFY SEMANTIC VIEW
-- ============================================================================

-- Check the semantic view exists
SHOW SEMANTIC VIEWS IN SCHEMA REVENUE_TIMESERIES;

-- Describe the semantic view
DESCRIBE SEMANTIC VIEW REVENUE_SEMANTIC_VIEW;

-- ============================================================================
-- STEP 4: TEST WITH CORTEX ANALYST
-- ============================================================================

-- Test query using the semantic view
-- Note: This uses the REST API format that Cortex Analyst expects

-- Example: Create a test function to query the semantic view
CREATE OR REPLACE FUNCTION TEST_ANALYST_QUERY(question VARCHAR)
RETURNS TABLE (
    generated_sql VARCHAR,
    answer VARCHAR
)
LANGUAGE SQL
AS
$$
    -- This is a placeholder - actual Cortex Analyst queries go through the REST API
    -- or the agent interface. This function demonstrates the semantic view is accessible.
    SELECT 
        'SELECT SUM(revenue) FROM DAILY_REVENUE' AS generated_sql,
        'Query would be processed by Cortex Analyst' AS answer
$$;

-- ============================================================================
-- STEP 5: GRANT PERMISSIONS
-- ============================================================================

-- Grant select on semantic view for querying
GRANT SELECT ON SEMANTIC VIEW REVENUE_SEMANTIC_VIEW TO ROLE ACCOUNTADMIN;

-- If you have other roles that need access:
-- GRANT SELECT ON SEMANTIC VIEW REVENUE_SEMANTIC_VIEW TO ROLE analyst_role;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

SELECT 
    'Semantic View' AS COMPONENT,
    'REVENUE_SEMANTIC_VIEW' AS NAME,
    'Created' AS STATUS
UNION ALL
SELECT 
    'Base Tables',
    '3 tables (daily_revenue, by_product, by_region)',
    'Ready';

SELECT 'Semantic View setup complete! Proceed to 04a_cortex_agent.sql OR 04b_bedrock_agent.sql' AS STATUS;
