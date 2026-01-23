/*
================================================================================
 AWS + SNOWFLAKE GENAI WORKSHOP
 Module 4B: Amazon Bedrock Agent (AWS OPTION)
 
 This script configures Snowflake External Access to call Amazon Bedrock Agents.
 Use this if you want to leverage AWS Bedrock instead of native Cortex Agents.
 
 Prerequisites:
 - Deploy aws/bedrock_agent_stack.yaml CloudFormation stack first
 - Note the AgentId and AliasId from CloudFormation outputs
================================================================================
*/

USE ROLE ACCOUNTADMIN;
USE DATABASE WORKSHOP_DB;
USE SCHEMA PUBLIC;
USE WAREHOUSE WORKSHOP_WH;

-- ============================================================================
-- CONFIGURATION
-- Update these values from your CloudFormation stack outputs
-- ============================================================================

SET BEDROCK_AGENT_ID = '<YOUR_AGENT_ID>';           -- From CloudFormation output
SET BEDROCK_AGENT_ALIAS_ID = '<YOUR_ALIAS_ID>';     -- From CloudFormation output
SET AWS_REGION = 'us-west-2';                        -- Must match CloudFormation region
SET AWS_ACCESS_KEY_ID = '<YOUR_ACCESS_KEY>';         -- AWS credentials
SET AWS_SECRET_ACCESS_KEY = '<YOUR_SECRET_KEY>';     -- AWS credentials
SET AWS_SESSION_TOKEN = '';                          -- Optional, for temporary credentials

-- ============================================================================
-- STEP 1: CREATE SECRETS FOR AWS CREDENTIALS
-- ============================================================================

-- Store AWS access key and secret
CREATE OR REPLACE SECRET AWS_CREDENTIALS
    TYPE = PASSWORD
    USERNAME = $AWS_ACCESS_KEY_ID
    PASSWORD = $AWS_SECRET_ACCESS_KEY
    COMMENT = 'AWS credentials for Bedrock Agent access';

-- Store session token (if using temporary credentials)
CREATE OR REPLACE SECRET AWS_SESSION_TOKEN_SECRET
    TYPE = PASSWORD
    USERNAME = 'session'
    PASSWORD = $AWS_SESSION_TOKEN
    COMMENT = 'AWS session token (leave blank if not using temporary credentials)';

-- ============================================================================
-- STEP 2: CREATE NETWORK RULE FOR BEDROCK
-- ============================================================================

CREATE OR REPLACE NETWORK RULE BEDROCK_NETWORK_RULE
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = (
        'bedrock-agent-runtime.us-west-2.amazonaws.com',
        'bedrock-runtime.us-west-2.amazonaws.com'
    )
    COMMENT = 'Allow outbound access to AWS Bedrock endpoints';

-- ============================================================================
-- STEP 3: CREATE EXTERNAL ACCESS INTEGRATION
-- ============================================================================

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION BEDROCK_INTEGRATION
    ALLOWED_NETWORK_RULES = (BEDROCK_NETWORK_RULE)
    ALLOWED_AUTHENTICATION_SECRETS = (AWS_CREDENTIALS, AWS_SESSION_TOKEN_SECRET)
    ENABLED = TRUE
    COMMENT = 'External access integration for AWS Bedrock Agent';

-- ============================================================================
-- STEP 4: CREATE UDF TO INVOKE BEDROCK AGENT
-- ============================================================================

CREATE OR REPLACE FUNCTION INVOKE_BEDROCK_AGENT(
    user_prompt VARCHAR,
    session_id VARCHAR DEFAULT 'default-session'
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('boto3', 'botocore')
HANDLER = 'invoke_agent'
EXTERNAL_ACCESS_INTEGRATIONS = (BEDROCK_INTEGRATION)
SECRETS = ('aws_creds' = AWS_CREDENTIALS, 'session_token' = AWS_SESSION_TOKEN_SECRET)
AS
$$
import boto3
import botocore
from botocore.config import Config
import _snowflake

def invoke_agent(user_prompt: str, session_id: str = 'default-session') -> str:
    """
    Invoke the Bedrock Agent with a user prompt and return the response.
    """
    # Get AWS credentials from Snowflake secrets
    aws_creds = _snowflake.get_username_password('aws_creds')
    session_token_obj = _snowflake.get_username_password('session_token')
    
    # Configuration
    agent_id = '<YOUR_AGENT_ID>'      # Replace with actual agent ID
    agent_alias_id = '<YOUR_ALIAS_ID>' # Replace with actual alias ID
    region = 'us-west-2'
    
    # Build boto3 session arguments
    session_args = {
        'aws_access_key_id': aws_creds.username,
        'aws_secret_access_key': aws_creds.password,
        'region_name': region
    }
    
    # Add session token if present
    if session_token_obj.password:
        session_args['aws_session_token'] = session_token_obj.password
    
    # Create boto3 session and client
    session = boto3.Session(**session_args)
    
    config = Config(
        read_timeout=300,
        connect_timeout=60,
        retries={'max_attempts': 3}
    )
    
    client = session.client(
        'bedrock-agent-runtime',
        region_name=region,
        config=config
    )
    
    # Invoke the agent
    try:
        response = client.invoke_agent(
            agentId=agent_id,
            agentAliasId=agent_alias_id,
            sessionId=session_id,
            inputText=user_prompt
        )
        
        # Collect the streaming response
        completion = ""
        for event in response.get('completion', []):
            if 'chunk' in event:
                chunk_data = event['chunk']
                if 'bytes' in chunk_data:
                    completion += chunk_data['bytes'].decode('utf-8')
        
        return completion
        
    except Exception as e:
        return f"Error invoking Bedrock Agent: {str(e)}"
$$;

-- ============================================================================
-- STEP 5: CREATE WRAPPER PROCEDURE FOR EASIER USE
-- ============================================================================

CREATE OR REPLACE PROCEDURE CHAT_WITH_BEDROCK_AGENT(
    user_message VARCHAR
)
RETURNS TABLE (
    question VARCHAR,
    response VARCHAR
)
LANGUAGE SQL
AS
$$
DECLARE
    agent_response VARCHAR;
BEGIN
    SELECT INVOKE_BEDROCK_AGENT(:user_message, 'workshop-session') INTO agent_response;
    
    RETURN TABLE(
        SELECT 
            :user_message AS question,
            agent_response AS response
    );
END;
$$;

-- ============================================================================
-- STEP 6: TEST THE BEDROCK AGENT
-- ============================================================================

-- NOTE: Update the agent_id and agent_alias_id in the INVOKE_BEDROCK_AGENT function
-- before running these tests!

-- Test with a FOMC question
SELECT INVOKE_BEDROCK_AGENT(
    'What did the Fed say about inflation in their most recent meeting?',
    'test-session-1'
) AS RESPONSE;

-- Test with a revenue question
SELECT INVOKE_BEDROCK_AGENT(
    'What was the total revenue last quarter by region?',
    'test-session-2'
) AS RESPONSE;

-- Test using the wrapper procedure
CALL CHAT_WITH_BEDROCK_AGENT('Show me the profit margin trend over the past 6 months');

-- ============================================================================
-- STEP 7: ALTERNATIVE - DIRECT CORTEX + BEDROCK HYBRID
-- Use Snowflake Cortex for data access, Bedrock for orchestration
-- ============================================================================

CREATE OR REPLACE FUNCTION HYBRID_CORTEX_BEDROCK(
    user_prompt VARCHAR
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('boto3', 'botocore', 'snowflake-snowpark-python')
HANDLER = 'hybrid_query'
EXTERNAL_ACCESS_INTEGRATIONS = (BEDROCK_INTEGRATION)
SECRETS = ('aws_creds' = AWS_CREDENTIALS, 'session_token' = AWS_SESSION_TOKEN_SECRET)
EXECUTE AS CALLER
AS
$$
import boto3
import json
from botocore.config import Config
import _snowflake
from snowflake.snowpark import Session

def hybrid_query(user_prompt: str) -> str:
    """
    Hybrid approach: Use Bedrock for reasoning, Cortex for data access.
    
    1. Bedrock analyzes the question and determines what data is needed
    2. Calls Snowflake Cortex Search or Analyst
    3. Bedrock synthesizes the final answer
    """
    # Get credentials
    aws_creds = _snowflake.get_username_password('aws_creds')
    session_token_obj = _snowflake.get_username_password('session_token')
    
    session_args = {
        'aws_access_key_id': aws_creds.username,
        'aws_secret_access_key': aws_creds.password,
        'region_name': 'us-west-2'
    }
    if session_token_obj.password:
        session_args['aws_session_token'] = session_token_obj.password
    
    # Create Bedrock client
    session = boto3.Session(**session_args)
    bedrock = session.client('bedrock-runtime', region_name='us-west-2')
    
    # First, use Bedrock to classify the question
    classification_prompt = f"""Classify this question into one of these categories:
    - FOMC: Questions about Federal Reserve, interest rates, monetary policy, inflation
    - REVENUE: Questions about company revenue, sales, profit, financial metrics
    - BOTH: Questions that need both FOMC and revenue data
    - GENERAL: General questions not requiring specific data
    
    Question: {user_prompt}
    
    Respond with just the category name."""
    
    response = bedrock.converse(
        modelId='amazon.nova-pro-v1:0',
        messages=[
            {'role': 'user', 'content': [{'text': classification_prompt}]}
        ],
        inferenceConfig={'maxTokens': 50}
    )
    
    category = response['output']['message']['content'][0]['text'].strip().upper()
    
    # Based on category, this would call the appropriate Cortex tools
    # (In practice, you'd use Snowpark to call Cortex Search or Analyst)
    
    return f"Question classified as: {category}. Hybrid Cortex+Bedrock processing would happen here."
$$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

SELECT 
    'External Access Integration' AS COMPONENT,
    'BEDROCK_INTEGRATION' AS NAME,
    'Created' AS STATUS
UNION ALL
SELECT 
    'Network Rule',
    'BEDROCK_NETWORK_RULE',
    'Configured for us-west-2'
UNION ALL
SELECT
    'UDF',
    'INVOKE_BEDROCK_AGENT',
    'Ready (update agent IDs before use)';

SELECT 'Bedrock Agent integration complete! Update agent IDs and proceed to 05_create_notebook.sql' AS STATUS;
