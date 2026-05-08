# --------------------------------------------------------------------------------
# Genentech: ADS Programmer Coding Assessment
# Author: Jay Sminchak
# Date: 05/2026
# Question 4 (BONUS): GenAI Clinical Data Assistant
# --------------------------------------------------------------------------------
# Overview:
#   A clinical safety reviewer can ask plain-English questions about the AE
#   dataset without knowing column names. The agent translates the question to
#   a structured filter and returns the matching subjects.
# 
#
# Pipeline: question -> mock LLM -> parse JSON -> execute pandas filter
#
# The LLM is mocked (no API key required)
#
# --------------------------------------------------------------------------------

import json 
import pandas as pd  
from pathlib import Path

# Load the AE dataset. Path(__file__).parent makes the path relative to
# this script's location, so it runs from any working directory.
adae = pd.read_csv(Path(__file__).parent / "adae.csv")


# --------------------------------------------------------------------------------
#  Schema - what the LLM "knows" about the dataset
# --------------------------------------------------------------------------------
# Gets sent as part of the system prompt so the model
# knows which columns are valid filter targets and what each one means.
# Used example terms from the spec.
SCHEMA = {
    "AESEV":  "Severity or intensity of the AE (MILD, MODERATE, SEVERE)",
    "AESOC":  "MedDRA System Organ Class - the body system the AE belongs to",
    "AETERM": "Verbatim adverse event term as collected on the CRF",
}


# --------------------------------------------------------------------------------
#  Mock LLM — stand-in for a real model call
# --------------------------------------------------------------------------------
def mock_llm_response(question: str) -> str:
    """
    Simulates an LLM. Reads keywords in the user's question, picks the
    relevant column, and returns the answer as a JSON string.

    In production, replace this function body with one API call, e.g.:

        client = anthropic.Anthropic(api_key=...)
        msg = client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=256,
            system=f"Filter the AE dataset. Schema: {SCHEMA}. "
                   f"Return JSON with keys target_column and filter_value.",
            messages=[{"role": "user", "content": question}],
        )
        return msg.content[0].text
    """
    q = question.lower()  # pushes question string to lowercase to prevent case-mismatches

    # Severity / intensity -> AESEV
    if "severe" in q:
        return json.dumps({"target_column": "AESEV", "filter_value": "SEVERE"})
    if "moderate" in q:
        return json.dumps({"target_column": "AESEV", "filter_value": "MODERATE"})
    if "mild" in q:
        return json.dumps({"target_column": "AESEV", "filter_value": "MILD"})

    # Body system -> AESOC
    if "cardiac" in q or "heart" in q:
        return json.dumps({"target_column": "AESOC", "filter_value": "CARDIAC DISORDERS"})
    if "skin" in q:
        return json.dumps({"target_column": "AESOC",
                           "filter_value": "SKIN AND SUBCUTANEOUS TISSUE DISORDERS"})
    if "gastrointestinal" in q or "gut" in q or "stomach" in q:
        return json.dumps({"target_column": "AESOC",
                           "filter_value": "GASTROINTESTINAL DISORDERS"})

    # Default: treat the last word of the question as a verbatim AETERM
    last_word = q.rstrip("?.").split()[-1].upper()
    return json.dumps({"target_column": "AETERM", "filter_value": last_word})


# --------------------------------------------------------------------------------
#  Agent class
# --------------------------------------------------------------------------------
class ClinicalTrialDataAgent:
    """
    Routes natural-language questions about the AE dataset through a
    (mocked) LLM and applies the resulting filter to the dataframe.
    """

    def __init__(self, df: pd.DataFrame, schema: dict):
        """Store the dataframe and schema."""
        self.df = df
        self.schema = schema

    def parse_llm_output(self, llm_response: str) -> dict:
        """Convert the LLM's JSON string into a Python dict."""
        return json.loads(llm_response)

    def execute_query(self, parsed: dict) -> dict:
        """Apply the filter and return matching subjects."""
        col = parsed["target_column"]
        value = parsed["filter_value"]

        # Case-insensitive match. Build a boolean mask, keep only True rows.
        mask = self.df[col].astype(str).str.upper() == value.upper()
        subject_ids = sorted(self.df[mask]["USUBJID"].unique().tolist())

        return {
            "filter_applied": f"{col} == '{value}'",
            "n_subjects": len(subject_ids),
            "subject_ids": subject_ids,
        }

    def ask(self, question: str) -> dict:
        """Full pipeline: question -> mock LLM -> parse -> execute -> print."""
        print(f"\n{'=' * 60}")
        print(f"Question: {question}")

        llm_response = mock_llm_response(question)
        print(f"LLM JSON: {llm_response}")

        parsed = self.parse_llm_output(llm_response)
        result = self.execute_query(parsed)

        print(f"Filter:   {result['filter_applied']}")
        print(f"Matched:  {result['n_subjects']} subjects")
        print(f"First 5:  {result['subject_ids'][:5]}")

        return result


# --------------------------------------------------------------------------------
#  Test queries — covers the three example types named in the spec
# --------------------------------------------------------------------------------
if __name__ == "__main__":
    agent = ClinicalTrialDataAgent(adae, SCHEMA)

    # Severity question -> AESEV
    agent.ask("Give me the subjects who had adverse events of moderate severity.")

    # Body system question -> AESOC
    agent.ask("Which subjects had cardiac adverse events?")

    # Specific condition -> AETERM
    agent.ask("Show me subjects who experienced dizziness.")
