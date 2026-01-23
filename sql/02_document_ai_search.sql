/*
================================================================================
 AWS + SNOWFLAKE GENAI WORKSHOP
 Module 2: Document AI & Cortex Search
 
 This script demonstrates MODERN PDF processing using Snowflake Document AI
 instead of custom PyPDF2/LangChain UDFs.
 
 Key Improvements:
 - Uses SNOWFLAKE.CORTEX.PARSE_DOCUMENT() for native PDF parsing
 - No external Python dependencies
 - Better extraction quality
 - Automatic OCR for scanned documents
================================================================================
*/

USE ROLE ACCOUNTADMIN;
USE DATABASE WORKSHOP_DB;
USE SCHEMA PUBLIC;
USE WAREHOUSE WORKSHOP_WH;

-- ============================================================================
-- STEP 1: PARSE PDFs USING DOCUMENT AI
-- Uses native PARSE_DOCUMENT function instead of PyPDF2
-- ============================================================================

-- First, let's see what files we have
LIST @FOMC_DOCS;

-- Create a table to store parsed document content
CREATE OR REPLACE TABLE FOMC_DOCUMENTS_RAW (
    FILE_NAME VARCHAR,
    FILE_URL VARCHAR,
    PARSED_CONTENT VARIANT,
    EXTRACTED_TEXT VARCHAR,
    PARSED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Parse all PDF documents using Document AI
-- PARSE_DOCUMENT extracts text, tables, and structure from PDFs
INSERT INTO FOMC_DOCUMENTS_RAW (FILE_NAME, FILE_URL, PARSED_CONTENT, EXTRACTED_TEXT)
SELECT 
    METADATA$FILENAME AS FILE_NAME,
    BUILD_SCOPED_FILE_URL(@FOMC_DOCS, METADATA$FILENAME) AS FILE_URL,
    SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
        @FOMC_DOCS,
        METADATA$FILENAME,
        {'mode': 'LAYOUT'}  -- Options: 'LAYOUT' (preserves structure) or 'OCR' (for scanned docs)
    ) AS PARSED_CONTENT,
    SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
        @FOMC_DOCS,
        METADATA$FILENAME,
        {'mode': 'LAYOUT'}
    ):content::VARCHAR AS EXTRACTED_TEXT
FROM @FOMC_DOCS
WHERE METADATA$FILENAME LIKE '%.pdf';

-- Verify parsing results
SELECT 
    FILE_NAME,
    LENGTH(EXTRACTED_TEXT) AS TEXT_LENGTH,
    LEFT(EXTRACTED_TEXT, 500) AS TEXT_PREVIEW
FROM FOMC_DOCUMENTS_RAW
LIMIT 5;

-- ============================================================================
-- STEP 2: CHUNK DOCUMENTS FOR SEARCH
-- Split large documents into searchable chunks
-- ============================================================================

-- Create chunking function using CORTEX
-- This replaces the custom LangChain RecursiveCharacterTextSplitter
CREATE OR REPLACE FUNCTION CHUNK_TEXT(
    input_text VARCHAR,
    chunk_size INT DEFAULT 2000,
    chunk_overlap INT DEFAULT 300
)
RETURNS TABLE (
    chunk_index INT,
    chunk_text VARCHAR
)
LANGUAGE SQL
AS
$$
    WITH RECURSIVE chunks AS (
        SELECT 
            0 AS chunk_index,
            SUBSTRING(input_text, 1, chunk_size) AS chunk_text,
            chunk_size - chunk_overlap AS next_start
        UNION ALL
        SELECT
            chunk_index + 1,
            SUBSTRING(input_text, next_start + 1, chunk_size),
            next_start + chunk_size - chunk_overlap
        FROM chunks
        WHERE next_start < LENGTH(input_text) AND chunk_index < 1000
    )
    SELECT chunk_index, chunk_text
    FROM chunks
    WHERE LENGTH(chunk_text) > 100
$$;

-- Create the chunks table
CREATE OR REPLACE TABLE FOMC_DOCS_CHUNKS AS
SELECT 
    d.FILE_NAME,
    d.FILE_URL,
    c.CHUNK_INDEX,
    -- Include file name in chunk for context
    d.FILE_NAME || ': ' || c.CHUNK_TEXT AS CHUNK,
    'English' AS LANGUAGE,
    -- Extract meeting date from filename (e.g., FOMC_Minutes_2024-01-31.pdf)
    TRY_TO_DATE(
        REGEXP_SUBSTR(d.FILE_NAME, '\\d{4}-\\d{2}-\\d{2}'),
        'YYYY-MM-DD'
    ) AS MEETING_DATE
FROM FOMC_DOCUMENTS_RAW d,
     TABLE(CHUNK_TEXT(d.EXTRACTED_TEXT, 2000, 300)) c;

-- Verify chunks created
SELECT 
    FILE_NAME,
    COUNT(*) AS NUM_CHUNKS,
    AVG(LENGTH(CHUNK)) AS AVG_CHUNK_LENGTH
FROM FOMC_DOCS_CHUNKS
GROUP BY FILE_NAME
ORDER BY FILE_NAME;

-- ============================================================================
-- STEP 3: CREATE CORTEX SEARCH SERVICE
-- Build the vector search index for RAG
-- ============================================================================

CREATE OR REPLACE CORTEX SEARCH SERVICE FOMC_SEARCH_SERVICE
    ON CHUNK
    ATTRIBUTES LANGUAGE, MEETING_DATE
    WAREHOUSE = WORKSHOP_WH
    TARGET_LAG = '1 hour'
    COMMENT = 'Search service for FOMC meeting minutes using Document AI'
AS (
    SELECT
        CHUNK,
        FILE_NAME,
        FILE_URL,
        CHUNK_INDEX,
        LANGUAGE,
        MEETING_DATE
    FROM FOMC_DOCS_CHUNKS
);

-- ============================================================================
-- STEP 4: TEST THE SEARCH SERVICE
-- ============================================================================

-- Test search using SQL (for debugging)
-- Note: In production, use the Python SDK or REST API

-- Simple keyword search
SELECT 
    CHUNK,
    FILE_NAME,
    MEETING_DATE
FROM TABLE(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'FOMC_SEARCH_SERVICE',
        '{
            "query": "inflation expectations",
            "columns": ["CHUNK", "FILE_NAME", "MEETING_DATE"],
            "limit": 3
        }'
    )
);

-- ============================================================================
-- STEP 5: CREATE HELPER FUNCTION FOR SEARCH
-- Wraps the search service for easy use in agents
-- ============================================================================

CREATE OR REPLACE FUNCTION SEARCH_FOMC_DOCS(
    query_text VARCHAR,
    num_results INT DEFAULT 5
)
RETURNS TABLE (
    chunk VARCHAR,
    file_name VARCHAR,
    meeting_date DATE,
    relevance_score FLOAT
)
LANGUAGE SQL
AS
$$
    SELECT 
        result:CHUNK::VARCHAR AS chunk,
        result:FILE_NAME::VARCHAR AS file_name,
        result:MEETING_DATE::DATE AS meeting_date,
        result:_score::FLOAT AS relevance_score
    FROM (
        SELECT VALUE AS result
        FROM TABLE(
            SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
                'FOMC_SEARCH_SERVICE',
                OBJECT_CONSTRUCT(
                    'query', query_text,
                    'columns', ARRAY_CONSTRUCT('CHUNK', 'FILE_NAME', 'MEETING_DATE'),
                    'limit', num_results
                )::VARCHAR
            )
        )
    )
$$;

-- Test the helper function
SELECT * FROM TABLE(SEARCH_FOMC_DOCS('What decisions were made about interest rates?', 3));

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Summary of what we built
SELECT 'FOMC_DOCUMENTS_RAW' AS OBJECT, 'Table' AS TYPE, COUNT(*) AS COUNT FROM FOMC_DOCUMENTS_RAW
UNION ALL
SELECT 'FOMC_DOCS_CHUNKS', 'Table', COUNT(*) FROM FOMC_DOCS_CHUNKS
UNION ALL
SELECT 'FOMC_SEARCH_SERVICE', 'Cortex Search', NULL;

SELECT 'Document AI & Cortex Search setup complete! Proceed to 03_semantic_view.sql' AS STATUS;
