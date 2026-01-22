# AWS + Snowflake GenAI Workshop

Build a conversational AI solution using **Snowflake Cortex** and optionally **Amazon Bedrock Agents**. This workshop showcases modern Snowflake AI capabilities including Document AI, Semantic Views, Cortex Agents, and Snowflake Notebooks.

## Architecture Options

```
┌─────────────────────────────────────────────────────────────────┐
│                     User Interface                               │
│     (Snowflake Notebook  OR  Streamlit in Snowflake)            │
└─────────────────────────┬───────────────────────────────────────┘
                          │
         ┌────────────────┴────────────────┐
         │         CHOOSE ONE:             │
         ▼                                 ▼
┌─────────────────────┐      ┌─────────────────────────────────┐
│  OPTION A:          │      │  OPTION B:                      │
│  Snowflake Cortex   │      │  Amazon Bedrock Agents          │
│  Agent (Native)     │      │  (via External Access)          │
└─────────┬───────────┘      └───────────────┬─────────────────┘
          │                                  │
          └────────────┬─────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│                    Snowflake Cortex Tools                        │
│  ┌────────────────┐  ┌─────────────────┐  ┌──────────────────┐  │
│  │ Cortex Search  │  │ Cortex Analyst  │  │   Document AI    │  │
│  │ (RAG/Vector)   │  │ (Semantic View) │  │  (PDF Parsing)   │  │
│  └────────────────┘  └─────────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## What's New vs. Original Workshop

| Original Workshop | This Workshop |
|-------------------|---------------|
| PyPDF2 + LangChain UDF for PDF parsing | **Document AI** (`SNOWFLAKE.CORTEX.PARSE_DOCUMENT`) |
| YAML semantic model on stage | **Semantic View** (native Snowflake object) |
| Bedrock Agents only | **Choice: Cortex Agent OR Bedrock Agent** |
| Streamlit app only | **Snowflake Notebook + Streamlit options** |

## Prerequisites

- Snowflake account with:
  - ACCOUNTADMIN role access
  - Cortex AI features enabled (check [regional availability](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions#region-availability))
- (Optional for Bedrock) AWS account with:
  - Administrator access
  - Bedrock model access in `us-west-2`

## Quick Start

### 1. Setup Snowflake Environment
```bash
# Run in Snowflake worksheet
sql/01_setup.sql
```

### 2. Load Data with Document AI
```bash
sql/02_document_ai_search.sql
```

### 3. Create Semantic View
```bash
sql/03_semantic_view.sql
```

### 4. Choose Your Agent

**Option A: Snowflake Cortex Agent (Recommended)**
```bash
sql/04a_cortex_agent.sql
```

**Option B: Amazon Bedrock Agent**
```bash
# Deploy CloudFormation stack first
aws/bedrock_agent_stack.yaml

# Then configure External Access
sql/04b_bedrock_agent.sql
```

### 5. Build the Interface

**Option A: Snowflake Notebook**
- Upload `notebooks/workshop_demo.ipynb` to Snowflake
- Or run `sql/05_create_notebook.sql`

**Option B: Streamlit App**
- Deploy `streamlit/app.py` as Streamlit in Snowflake
- Or run `sql/06_create_streamlit.sql`

## Project Structure

```
├── README.md
├── sql/
│   ├── 01_setup.sql                 # Database, warehouse, roles
│   ├── 02_document_ai_search.sql    # Cortex Search with Document AI
│   ├── 03_semantic_view.sql         # Semantic View for Cortex Analyst
│   ├── 04a_cortex_agent.sql         # Snowflake Cortex Agent
│   ├── 04b_bedrock_agent.sql        # Bedrock External Access
│   ├── 05_create_notebook.sql       # Deploy notebook
│   ├── 06_create_streamlit.sql      # Deploy Streamlit app
│   └── 99_cleanup.sql               # Cleanup resources
├── aws/
│   └── bedrock_agent_stack.yaml     # CloudFormation for Bedrock
├── notebooks/
│   └── workshop_demo.ipynb          # Snowflake Notebook
├── streamlit/
│   ├── app.py                       # Main Streamlit app
│   └── environment.yml              # Dependencies
└── data/
    └── sample_queries.txt           # Test queries
```

## Workshop Modules

### Module 1: Environment Setup (~10 min)
- Create database, warehouse, and roles
- Set up stages for data

### Module 2: Document AI & Cortex Search (~15 min)
- Use `PARSE_DOCUMENT` to extract text from PDFs
- Create chunked documents table
- Build Cortex Search service

### Module 3: Semantic View & Cortex Analyst (~15 min)
- Load revenue timeseries data
- Create Semantic View (replaces YAML)
- Test natural language queries

### Module 4: Agent Configuration (~20 min)
Choose one:
- **4A**: Create Snowflake Cortex Agent with both tools
- **4B**: Deploy Bedrock Agent + External Access Integration

### Module 5: Interactive Interface (~15 min)
Choose one:
- **5A**: Snowflake Notebook for exploration
- **5B**: Streamlit app for production UI

## Sample Queries

Once configured, try these queries:

**Cortex Search (FOMC Documents):**
- "What did the Fed say about inflation in early 2024?"
- "Summarize the key decisions from the March 2024 meeting"

**Cortex Analyst (Revenue Data):**
- "What was total revenue last quarter?"
- "Compare profit by region for September 2024"
- "Show revenue trend over the past 6 months"

## Cleanup

```sql
-- Remove all workshop resources
@sql/99_cleanup.sql
```

## Troubleshooting

### Document AI not available
Check if your Snowflake region supports Cortex AI features.

### Semantic View creation fails
Ensure you have the latest Snowflake features enabled. Contact your account team if needed.

### Bedrock connection timeout
Verify AWS credentials and network rules allow egress to Bedrock endpoints.

## Additional Resources

- [Snowflake Cortex Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex)
- [Cortex Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents)
- [Document AI](https://docs.snowflake.com/en/user-guide/snowflake-cortex/document-ai)
- [Semantic Views](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst/semantic-view)
- [Amazon Bedrock Agents](https://docs.aws.amazon.com/bedrock/latest/userguide/agents.html)

## License

MIT-0 License
