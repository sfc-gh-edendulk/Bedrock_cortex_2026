"""
AWS + Snowflake GenAI Workshop - Streamlit Application

This Streamlit app provides a production-ready chat interface for the workshop,
supporting both Snowflake Cortex Agent and Amazon Bedrock Agent backends.
"""

import streamlit as st
import pandas as pd
import json
import requests
from typing import Optional, Dict, Any, List

# Page configuration
st.set_page_config(
    page_title="AWS + Snowflake GenAI Workshop",
    page_icon="🤖",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS
st.markdown("""
<style>
    .stApp {
        max-width: 1200px;
        margin: 0 auto;
    }
    .chat-message {
        padding: 1rem;
        border-radius: 0.5rem;
        margin-bottom: 1rem;
    }
    .user-message {
        background-color: #e3f2fd;
    }
    .assistant-message {
        background-color: #f5f5f5;
    }
    .source-citation {
        font-size: 0.8rem;
        color: #666;
        border-left: 3px solid #1976d2;
        padding-left: 0.5rem;
        margin-top: 0.5rem;
    }
</style>
""", unsafe_allow_html=True)


def get_snowflake_session():
    """Get or create Snowflake session."""
    from snowflake.snowpark.context import get_active_session
    return get_active_session()


def chat_with_cortex_agent(session, message: str, thread_id: Optional[str] = None) -> Dict[str, Any]:
    """Send a message to the Snowflake Cortex Agent."""
    try:
        result = session.sql(f"""
            CALL WORKSHOP_DB.AGENTS.CHAT_WITH_AGENT('{message.replace("'", "''")}')
        """).collect()
        
        if result:
            return json.loads(result[0][0])
        return {"response": "No response received", "error": True}
    except Exception as e:
        return {"response": f"Error: {str(e)}", "error": True}


def chat_with_bedrock_agent(session, message: str, session_id: str = "streamlit-session") -> Dict[str, Any]:
    """Send a message to the Amazon Bedrock Agent via External Access."""
    try:
        result = session.sql(f"""
            SELECT WORKSHOP_DB.PUBLIC.INVOKE_BEDROCK_AGENT(
                '{message.replace("'", "''")}',
                '{session_id}'
            ) as RESPONSE
        """).collect()
        
        if result:
            return {"response": result[0]['RESPONSE']}
        return {"response": "No response received", "error": True}
    except Exception as e:
        return {"response": f"Bedrock Agent error: {str(e)}", "error": True}


def search_fomc_documents(session, query: str, num_results: int = 5) -> pd.DataFrame:
    """Search FOMC documents using Cortex Search."""
    try:
        results = session.sql(f"""
            SELECT * FROM TABLE(WORKSHOP_DB.PUBLIC.SEARCH_FOMC_DOCS('{query}', {num_results}))
        """).to_pandas()
        return results
    except Exception as e:
        st.error(f"Search error: {str(e)}")
        return pd.DataFrame()


def get_revenue_summary(session) -> Dict[str, pd.DataFrame]:
    """Get revenue data summaries."""
    summaries = {}
    
    try:
        summaries['total'] = session.sql("""
            SELECT 
                SUM(REVENUE) as TOTAL_REVENUE,
                SUM(COGS) as TOTAL_COGS,
                SUM(REVENUE - COGS) as TOTAL_PROFIT,
                MIN(DATE) as START_DATE,
                MAX(DATE) as END_DATE
            FROM WORKSHOP_DB.REVENUE_TIMESERIES.DAILY_REVENUE
        """).to_pandas()
        
        summaries['by_region'] = session.sql("""
            SELECT 
                SALES_REGION,
                SUM(REVENUE) as REVENUE,
                SUM(REVENUE - COGS) as PROFIT
            FROM WORKSHOP_DB.REVENUE_TIMESERIES.DAILY_REVENUE_BY_REGION
            GROUP BY SALES_REGION
            ORDER BY REVENUE DESC
        """).to_pandas()
        
        summaries['by_product'] = session.sql("""
            SELECT 
                PRODUCT_LINE,
                SUM(REVENUE) as REVENUE,
                SUM(REVENUE - COGS) as PROFIT
            FROM WORKSHOP_DB.REVENUE_TIMESERIES.DAILY_REVENUE_BY_PRODUCT
            GROUP BY PRODUCT_LINE
            ORDER BY REVENUE DESC
        """).to_pandas()
        
        summaries['monthly_trend'] = session.sql("""
            SELECT 
                DATE_TRUNC('month', DATE) as MONTH,
                SUM(REVENUE) as REVENUE,
                SUM(REVENUE - COGS) as PROFIT
            FROM WORKSHOP_DB.REVENUE_TIMESERIES.DAILY_REVENUE
            GROUP BY 1
            ORDER BY 1
        """).to_pandas()
        
    except Exception as e:
        st.error(f"Error fetching revenue data: {str(e)}")
    
    return summaries


def main():
    """Main application."""
    
    # Initialize session state
    if 'messages' not in st.session_state:
        st.session_state.messages = []
    if 'agent_type' not in st.session_state:
        st.session_state.agent_type = 'cortex'
    if 'session' not in st.session_state:
        st.session_state.session = None
    
    # Sidebar
    with st.sidebar:
        st.title("⚙️ Configuration")
        
        # Agent selection
        st.subheader("Agent Backend")
        agent_type = st.radio(
            "Choose your agent:",
            options=['cortex', 'bedrock'],
            format_func=lambda x: "🏔️ Snowflake Cortex Agent" if x == 'cortex' else "☁️ Amazon Bedrock Agent",
            index=0 if st.session_state.agent_type == 'cortex' else 1,
            help="Cortex Agent runs natively in Snowflake. Bedrock Agent uses AWS via External Access."
        )
        st.session_state.agent_type = agent_type
        
        st.divider()
        
        # Sample questions
        st.subheader("💡 Sample Questions")
        
        st.markdown("**FOMC / Fed Questions:**")
        fomc_questions = [
            "What did the Fed say about inflation?",
            "Summarize the March 2024 FOMC meeting",
            "What is the Fed's outlook on employment?",
            "What decisions were made about interest rates?"
        ]
        for q in fomc_questions:
            if st.button(q, key=f"fomc_{q[:20]}", use_container_width=True):
                st.session_state.pending_question = q
        
        st.markdown("**Revenue Questions:**")
        revenue_questions = [
            "What was total revenue last month?",
            "Show profit by region",
            "Which product line has the highest margin?",
            "Compare Q3 vs Q4 revenue"
        ]
        for q in revenue_questions:
            if st.button(q, key=f"rev_{q[:20]}", use_container_width=True):
                st.session_state.pending_question = q
        
        st.divider()
        
        # Clear chat
        if st.button("🗑️ Clear Chat", use_container_width=True):
            st.session_state.messages = []
            st.rerun()
    
    # Main content
    st.title("🤖 AWS + Snowflake GenAI Workshop")
    st.markdown(f"Using: **{'Snowflake Cortex Agent' if agent_type == 'cortex' else 'Amazon Bedrock Agent'}**")
    
    # Tabs for different views
    tab_chat, tab_search, tab_data = st.tabs(["💬 Chat", "🔍 Document Search", "📊 Revenue Data"])
    
    with tab_chat:
        # Chat container
        chat_container = st.container()
        
        # Display chat history
        with chat_container:
            for message in st.session_state.messages:
                with st.chat_message(message["role"]):
                    st.markdown(message["content"])
                    if "sources" in message:
                        with st.expander("📚 Sources"):
                            for source in message["sources"]:
                                st.markdown(f"- {source}")
        
        # Handle pending question from sidebar
        if 'pending_question' in st.session_state:
            user_input = st.session_state.pending_question
            del st.session_state.pending_question
        else:
            user_input = st.chat_input("Ask about FOMC meetings or revenue data...")
        
        # Process user input
        if user_input:
            # Add user message
            st.session_state.messages.append({"role": "user", "content": user_input})
            
            with st.chat_message("user"):
                st.markdown(user_input)
            
            # Get response
            with st.chat_message("assistant"):
                with st.spinner("Thinking..."):
                    try:
                        session = get_snowflake_session()
                        
                        if st.session_state.agent_type == 'cortex':
                            response = chat_with_cortex_agent(session, user_input)
                        else:
                            response = chat_with_bedrock_agent(session, user_input)
                        
                        answer = response.get("response", "No response")
                        st.markdown(answer)
                        
                        # Add to history
                        st.session_state.messages.append({
                            "role": "assistant",
                            "content": answer
                        })
                        
                    except Exception as e:
                        error_msg = f"Error: {str(e)}"
                        st.error(error_msg)
                        st.session_state.messages.append({
                            "role": "assistant",
                            "content": error_msg
                        })
            
            st.rerun()
    
    with tab_search:
        st.subheader("🔍 Search FOMC Documents")
        st.markdown("Search the Federal Reserve meeting minutes directly using Cortex Search.")
        
        search_query = st.text_input("Enter search query:", placeholder="e.g., inflation expectations, interest rate decisions")
        num_results = st.slider("Number of results:", 1, 10, 5)
        
        if st.button("Search", type="primary"):
            if search_query:
                with st.spinner("Searching..."):
                    try:
                        session = get_snowflake_session()
                        results = search_fomc_documents(session, search_query, num_results)
                        
                        if not results.empty:
                            for idx, row in results.iterrows():
                                with st.expander(f"📄 {row['FILE_NAME']} (Score: {row['RELEVANCE_SCORE']:.3f})"):
                                    st.markdown(f"**Meeting Date:** {row['MEETING_DATE']}")
                                    st.markdown(row['CHUNK'])
                        else:
                            st.info("No results found.")
                    except Exception as e:
                        st.error(f"Search error: {str(e)}")
            else:
                st.warning("Please enter a search query.")
    
    with tab_data:
        st.subheader("📊 Revenue Data Explorer")
        
        try:
            session = get_snowflake_session()
            summaries = get_revenue_summary(session)
            
            if summaries:
                # KPIs
                col1, col2, col3 = st.columns(3)
                if 'total' in summaries and not summaries['total'].empty:
                    total = summaries['total'].iloc[0]
                    col1.metric("Total Revenue", f"${total['TOTAL_REVENUE']:,.0f}")
                    col2.metric("Total Profit", f"${total['TOTAL_PROFIT']:,.0f}")
                    col3.metric("Profit Margin", f"{(total['TOTAL_PROFIT']/total['TOTAL_REVENUE']*100):.1f}%")
                
                # Charts
                col_left, col_right = st.columns(2)
                
                with col_left:
                    st.markdown("**Revenue by Region**")
                    if 'by_region' in summaries and not summaries['by_region'].empty:
                        st.bar_chart(summaries['by_region'].set_index('SALES_REGION')['REVENUE'])
                
                with col_right:
                    st.markdown("**Revenue by Product**")
                    if 'by_product' in summaries and not summaries['by_product'].empty:
                        st.bar_chart(summaries['by_product'].set_index('PRODUCT_LINE')['REVENUE'])
                
                # Trend chart
                st.markdown("**Monthly Revenue Trend**")
                if 'monthly_trend' in summaries and not summaries['monthly_trend'].empty:
                    st.line_chart(summaries['monthly_trend'].set_index('MONTH')[['REVENUE', 'PROFIT']])
                    
        except Exception as e:
            st.error(f"Error loading data: {str(e)}")
            st.info("Make sure you've run the setup scripts first.")


if __name__ == "__main__":
    main()
