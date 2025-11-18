"""
Linear GraphQL API client for task management.
"""

import os
import logging
from typing import Dict, Any, Optional, List
from datetime import datetime

import httpx

logger = logging.getLogger(__name__)

LINEAR_API_URL = "https://api.linear.app/graphql"


class LinearClient:
    """
    Client for Linear GraphQL API.
    """
    
    def __init__(self, api_key: Optional[str] = None):
        """
        Initialize Linear client.
        
        Args:
            api_key: Linear API key (or from LINEAR_API_KEY env var)
        """
        self.api_key = api_key or os.getenv("LINEAR_API_KEY")
        if not self.api_key:
            raise ValueError("LINEAR_API_KEY not provided")
        
        self.headers = {
            "Authorization": self.api_key,
            "Content-Type": "application/json"
        }
        self.client = httpx.AsyncClient(
            base_url=LINEAR_API_URL,
            headers=self.headers,
            timeout=30.0
        )
    
    async def get_issue(self, issue_id: str) -> Dict[str, Any]:
        """
        Get issue by ID.
        
        Args:
            issue_id: Linear issue ID
            
        Returns:
            Issue data
        """
        query = """
        query GetIssue($id: String!) {
          issue(id: $id) {
            id
            identifier
            title
            description
            status {
              id
              name
            }
            progress
            updatedAt
          }
        }
        """
        
        response = await self.client.post(
            "",
            json={"query": query, "variables": {"id": issue_id}}
        )
        response.raise_for_status()
        data = response.json()
        
        if "errors" in data:
            raise ValueError(f"GraphQL errors: {data['errors']}")
        
        return data.get("data", {}).get("issue", {})
    
    async def update_progress(self, issue_id: str, progress: float) -> Dict[str, Any]:
        """
        Update issue progress.
        
        Args:
            issue_id: Linear issue ID
            progress: Progress (0.0 to 1.0)
            
        Returns:
            Updated issue data
        """
        mutation = """
        mutation UpdateProgress($id: String!, $progress: Float!) {
          issueUpdate(id: $id, input: { progress: $progress }) {
            issue {
              id
              identifier
              progress
            }
          }
        }
        """
        
        response = await self.client.post(
            "",
            json={
                "query": mutation,
                "variables": {"id": issue_id, "progress": progress}
            }
        )
        response.raise_for_status()
        data = response.json()
        
        if "errors" in data:
            raise ValueError(f"GraphQL errors: {data['errors']}")
        
        return data.get("data", {}).get("issueUpdate", {}).get("issue", {})
    
    async def add_comment(self, issue_id: str, body: str) -> Dict[str, Any]:
        """
        Add comment to issue.
        
        Args:
            issue_id: Linear issue ID
            body: Comment body
            
        Returns:
            Created comment data
        """
        mutation = """
        mutation AddComment($issueId: String!, $body: String!) {
          commentCreate(input: { issueId: $issueId, body: $body }) {
            comment {
              id
              body
              createdAt
            }
          }
        }
        """
        
        response = await self.client.post(
            "",
            json={
                "query": mutation,
                "variables": {"issueId": issue_id, "body": body}
            }
        )
        response.raise_for_status()
        data = response.json()
        
        if "errors" in data:
            raise ValueError(f"GraphQL errors: {data['errors']}")
        
        return data.get("data", {}).get("commentCreate", {}).get("comment", {})
    
    async def update_status(
        self,
        issue_id: str,
        status_id: str
    ) -> Dict[str, Any]:
        """
        Update issue status.
        
        Args:
            issue_id: Linear issue ID
            status_id: New status ID
            
        Returns:
            Updated issue data
        """
        mutation = """
        mutation UpdateStatus($id: String!, $statusId: String!) {
          issueUpdate(id: $id, input: { statusId: $statusId }) {
            issue {
              id
              identifier
              status {
                id
                name
              }
            }
          }
        }
        """
        
        response = await self.client.post(
            "",
            json={
                "query": mutation,
                "variables": {"id": issue_id, "statusId": status_id}
            }
        )
        response.raise_for_status()
        data = response.json()
        
        if "errors" in data:
            raise ValueError(f"GraphQL errors: {data['errors']}")
        
        return data.get("data", {}).get("issueUpdate", {}).get("issue", {})
    
    async def close(self):
        """Close HTTP client."""
        await self.client.aclose()
