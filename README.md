# AWS + Snowflake GenAI Workshop

Build a conversational AI solution using **Snowflake Cortex** and optionally **Amazon Bedrock Agents**. This workshop showcases modern Snowflake AI capabilities including Document AI, Semantic Views, Cortex Agents, and Snowflake Notebooks.

---

## 📚 Workshop Guide

**👉 [Start the Workshop Here](https://sfc-gh-edendulk.github.io/Bedrock_cortex_2026/) 👈**

The full step-by-step guide with instructions for beginners is hosted at the link above.

---

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

## Workshop Modules

| Module | Topic | Time |
|--------|-------|------|
| [0. Prerequisites](https://sfc-gh-edendulk.github.io/Bedrock_cortex_2026/00-prerequisites.html) | Account setup & registration | 10 min |
| [1. Overview](https://sfc-gh-edendulk.github.io/Bedrock_cortex_2026/01-overview.html) | Technology introduction | 5 min |
| [2. Snowflake Setup](https://sfc-gh-edendulk.github.io/Bedrock_cortex_2026/02-snowflake-setup.html) | Database, warehouse, data loading | 10 min |
| [3. Document AI](https://sfc-gh-edendulk.github.io/Bedrock_cortex_2026/03-document-ai.html) | PDF parsing & Cortex Search | 15 min |
| [4. Semantic View](https://sfc-gh-edendulk.github.io/Bedrock_cortex_2026/04-semantic-view.html) | Natural language SQL | 15 min |
| [5. AI Agents](https://sfc-gh-edendulk.github.io/Bedrock_cortex_2026/05-agents.html) | Cortex Agent or Bedrock Agent | 20 min |
| [6. Application](https://sfc-gh-edendulk.github.io/Bedrock_cortex_2026/06-application.html) | Chat interface | 15 min |
| [7. Cleanup](https://sfc-gh-edendulk.github.io/Bedrock_cortex_2026/07-cleanup.html) | Remove resources | 5 min |

**Total time: ~90 minutes**

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
  - Cortex AI features enabled ([regional availability](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions#region-availability))
- (Optional for Bedrock) AWS account with:
  - Administrator access
  - Bedrock model access in `us-west-2`

## Quick Start (for experienced users)

If you're already familiar with Snowflake, run the SQL scripts in order:

```sql
-- 1. Setup environment
@sql/01_setup.sql

-- 2. Document AI & Cortex Search
@sql/02_document_ai_search.sql

-- 3. Semantic View
@sql/03_semantic_view.sql

-- 4. Choose your agent:
@sql/04a_cortex_agent.sql    -- Option A: Cortex Agent
-- OR
@sql/04b_bedrock_agent.sql   -- Option B: Bedrock Agent
```

## Project Structure

```
├── docs/                        # 📚 Workshop guide (GitHub Pages)
│   ├── index.html              # Landing page
│   ├── 00-prerequisites.html   # Account setup
│   ├── 01-overview.html        # Technology intro
│   ├── 02-snowflake-setup.html # Database setup
│   ├── 03-document-ai.html     # Document AI & Search
│   ├── 04-semantic-view.html   # Semantic View
│   ├── 05-agents.html          # AI Agents
│   ├── 06-application.html     # Chat interface
│   └── 07-cleanup.html         # Cleanup
├── sql/
│   ├── 01_setup.sql            # Database, warehouse, roles
│   ├── 02_document_ai_search.sql
│   ├── 03_semantic_view.sql
│   ├── 04a_cortex_agent.sql    # Snowflake Cortex Agent
│   ├── 04b_bedrock_agent.sql   # Bedrock External Access
│   └── 99_cleanup.sql
├── aws/
│   └── bedrock_agent_stack.yaml
├── notebooks/
│   └── workshop_demo.ipynb
├── streamlit/
│   ├── app.py
│   └── environment.yml
└── data/
    └── sample_queries.txt
```

## Sample Queries

Once configured, try these:

**📄 Document Search (FOMC):**
- "What did the Fed say about inflation?"
- "Summarize the March 2024 meeting"

**📊 Data Analysis (Revenue):**
- "What was total revenue last quarter?"
- "Compare profit by region"
- "Show revenue trend over 6 months"

## Resources

- [Snowflake Cortex Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex)
- [Cortex Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents)
- [Document AI](https://docs.snowflake.com/en/user-guide/snowflake-cortex/document-ai)
- [Semantic Views](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst/semantic-view)
- [Amazon Bedrock Agents](https://docs.aws.amazon.com/bedrock/latest/userguide/agents.html)

## License

MIT-0 License
