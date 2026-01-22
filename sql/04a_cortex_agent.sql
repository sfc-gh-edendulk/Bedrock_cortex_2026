/*
================================================================================
 AWS + SNOWFLAKE GENAI WORKSHOP
 Module 4A: Snowflake Cortex Agent (NATIVE OPTION)
 
 This script creates a Snowflake Cortex Agent that orchestrates:
 - Cortex Search (for FOMC document RAG)
 - Cortex Analyst (for revenue data SQL generation)
 
 This is the RECOMMENDED option as it runs entirely within Snowflake.
================================================================================
*/

USE ROLE ACCOUNTADMIN;
USE DATABASE WORKSHOP_DB;
USE SCHEMA AGENTS;
USE WAREHOUSE WORKSHOP_WH;

-- ============================================================================
-- STEP 1: VERIFY PREREQUISITES
-- ============================================================================

-- Check that Cortex Search service exists
SHOW CORTEX SEARCH SERVICES IN SCHEMA WORKSHOP_DB.PUBLIC;

-- Check that Semantic View exists
SHOW SEMANTIC VIEWS IN SCHEMA WORKSHOP_DB.REVENUE_TIMESERIES;

-- ============================================================================
-- STEP 2: CREATE THE CORTEX AGENT
-- Uses SQL DDL to create an agent with multiple tools
-- ============================================================================

CREATE OR REPLACE AGENT WORKSHOP_DB.AGENTS.WORKSHOP_AGENT
    COMMENT = 'Workshop agent combining FOMC document search and revenue analytics'
    PROFILE = '{
        "display_name": "AWS-Snowflake Workshop Assistant",
        "description": "AI assistant for FOMC meeting analysis and revenue data queries",
        "avatar": "📊"
    }'
    FROM SPECIFICATION $$
    {
        "models": {
            "orchestration": "claude-3-5-sonnet"
        },
        "instructions": {
            "orchestration": "You are a helpful assistant that can answer questions about Federal Reserve (FOMC) meeting minutes and company revenue data. Use the fomc_search tool for questions about Fed meetings, interest rates, inflation, and monetary policy. Use the revenue_analyst tool for questions about revenue, sales, profit, and financial metrics.",
            "response": "Provide clear, concise answers. When showing data, format numbers nicely. Always cite sources when referencing FOMC documents (include the meeting date). For revenue data, explain any SQL queries you generate."
        },
        "tools": [
            {
                "tool_spec": {
                    "type": "cortex_search",
                    "name": "fomc_search",
                    "description": "Search FOMC (Federal Open Market Committee) meeting minutes for information about Federal Reserve decisions, interest rates, inflation expectations, economic outlook, and monetary policy. Use this for any questions about Fed meetings or economic policy."
                }
            },
            {
                "tool_spec": {
                    "type": "cortex_analyst_text_to_sql",
                    "name": "revenue_analyst",
                    "description": "Query company revenue data using natural language. Can answer questions about total revenue, revenue by product line, revenue by region, profit margins, forecasts, and trends over time. Use this for any questions about company financial performance."
                }
            }
        ],
        "tool_resources": {
            "fomc_search": {
                "search_service": "WORKSHOP_DB.PUBLIC.FOMC_SEARCH_SERVICE",
                "max_results": 5,
                "columns": ["CHUNK", "FILE_NAME", "MEETING_DATE"]
            },
            "revenue_analyst": {
                "semantic_view": "WORKSHOP_DB.REVENUE_TIMESERIES.REVENUE_SEMANTIC_VIEW",
                "execution_environment": {
                    "type": "warehouse",
                    "warehouse": "WORKSHOP_WH"
                },
                "query_timeout": 60
            }
        }
    }
    $$;

-- ============================================================================
-- STEP 3: GRANT PERMISSIONS
-- ============================================================================

-- Grant usage on the agent
GRANT USAGE ON AGENT WORKSHOP_DB.AGENTS.WORKSHOP_AGENT TO ROLE ACCOUNTADMIN;

-- If you want other roles to use the agent:
-- GRANT USAGE ON AGENT WORKSHOP_DB.AGENTS.WORKSHOP_AGENT TO ROLE analyst_role;

-- ============================================================================
-- STEP 4: VERIFY AGENT CREATION
-- ============================================================================

-- List agents in the schema
SHOW AGENTS IN SCHEMA WORKSHOP_DB.AGENTS;

-- Describe the agent
DESCRIBE AGENT WORKSHOP_DB.AGENTS.WORKSHOP_AGENT;

-- ============================================================================
-- STEP 5: CREATE HELPER FUNCTION TO INVOKE AGENT
-- This simplifies calling the agent from Notebooks/Streamlit
-- ============================================================================

CREATE OR REPLACE PROCEDURE WORKSHOP_DB.AGENTS.CHAT_WITH_AGENT(
    user_message VARCHAR,
    thread_id VARCHAR DEFAULT NULL
)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python', 'requests')
HANDLER = 'chat_with_agent'
EXECUTE AS CALLER
AS
$$
import json
import requests
from snowflake.snowpark import Session

def chat_with_agent(session, user_message: str, thread_id: str = None) -> dict:
    """
    Send a message to the workshop agent and get a response.
    
    Args:
        session: Snowpark session
        user_message: The user's question
        thread_id: Optional thread ID for conversation continuity
    
    Returns:
        dict with response text and metadata
    """
    # Get connection details
    connection = session.connection
    
    # Get the REST token
    token = connection.rest.token
    host = connection.host
    
    # Create thread if not provided
    if thread_id is None:
        thread_response = requests.post(
            f"https://{host}/api/v2/cortex/threads",
            headers={
                "Authorization": f'Snowflake Token="{token}"',
                "Content-Type": "application/json"
            },
            json={"origin_application": "workshop_demo"}
        )
        thread_data = thread_response.json()
        thread_id = thread_data.get("thread_id")
    
    # Call the agent
    agent_response = requests.post(
        f"https://{host}/api/v2/databases/WORKSHOP_DB/schemas/AGENTS/agents/WORKSHOP_AGENT:run",
        headers={
            "Authorization": f'Snowflake Token="{token}"',
            "Content-Type": "application/json"
        },
        json={
            "thread_id": thread_id,
            "parent_message_id": "0",
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": user_message}
                    ]
                }
            ]
        }
    )
    
    result = agent_response.json()
    
    # Extract the response text
    response_text = ""
    if "message" in result and "content" in result["message"]:
        for item in result["message"]["content"]:
            if item.get("type") == "text":
                response_text += item.get("text", "")
    
    return {
        "response": response_text,
        "thread_id": thread_id,
        "raw_response": result
    }
$$;

-- ============================================================================
-- STEP 6: TEST THE AGENT
-- ============================================================================

-- Test with a FOMC question
CALL WORKSHOP_DB.AGENTS.CHAT_WITH_AGENT(
    'What did the Fed say about inflation in their most recent meeting?'
);

-- Test with a revenue question
CALL WORKSHOP_DB.AGENTS.CHAT_WITH_AGENT(
    'What was the total revenue last quarter by region?'
);

-- Test a combined question
CALL WORKSHOP_DB.AGENTS.CHAT_WITH_AGENT(
    'Based on the Fed\'s economic outlook, how might our regional revenue be affected?'
);

-- ============================================================================
-- VERIFICATION
-- ============================================================================

SELECT 
    'Cortex Agent' AS COMPONENT,
    'WORKSHOP_AGENT' AS NAME,
    'Created and ready' AS STATUS
UNION ALL
SELECT 
    'Tools Configured',
    'fomc_search, revenue_analyst',
    '2 tools active';

SELECT 'Cortex Agent setup complete! Proceed to 05_create_notebook.sql or 06_create_streamlit.sql' AS STATUS;
