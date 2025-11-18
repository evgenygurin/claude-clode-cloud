"""
Token usage and cost tracking for AWS Bedrock.
"""

import logging
import json
from datetime import datetime, timedelta
from typing import Dict, Any, Optional
from dataclasses import dataclass, asdict

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)


@dataclass
class TokenUsage:
    """Token usage metrics."""
    input_tokens: int = 0
    output_tokens: int = 0
    total_tokens: int = 0
    timestamp: str = ""
    
    def __post_init__(self):
        if not self.timestamp:
            self.timestamp = datetime.utcnow().isoformat()
        if not self.total_tokens:
            self.total_tokens = self.input_tokens + self.output_tokens


@dataclass
class CostMetrics:
    """Cost metrics for model usage."""
    model_id: str
    input_cost: float = 0.0
    output_cost: float = 0.0
    total_cost: float = 0.0
    timestamp: str = ""
    
    def __post_init__(self):
        if not self.timestamp:
            self.timestamp = datetime.utcnow().isoformat()
        if not self.total_cost:
            self.total_cost = self.input_cost + self.output_cost


class UsageTracker:
    """
    Track token usage for AWS Bedrock requests.
    """
    
    # Pricing per 1M tokens (as of 2025-01-18)
    PRICING = {
        "anthropic.claude-sonnet-4-5-20250929-v1:0": {
            "input": 3.00,   # $3 per 1M input tokens
            "output": 15.00  # $15 per 1M output tokens
        },
        "anthropic.claude-haiku-4-5-20251001-v1:0": {
            "input": 0.25,   # $0.25 per 1M input tokens
            "output": 1.25   # $1.25 per 1M output tokens
        }
    }
    
    def __init__(self, log_group: Optional[str] = None):
        """
        Initialize usage tracker.
        
        Args:
            log_group: CloudWatch log group name (optional)
        """
        self.log_group = log_group
        self.usage_history: list[TokenUsage] = []
        self.cost_history: list[CostMetrics] = []
    
    def record_usage(
        self,
        model_id: str,
        input_tokens: int,
        output_tokens: int
    ) -> Dict[str, Any]:
        """
        Record token usage for a request.
        
        Args:
            model_id: Model identifier
            input_tokens: Number of input tokens
            output_tokens: Number of output tokens
            
        Returns:
            Dictionary with usage and cost metrics
        """
        usage = TokenUsage(
            input_tokens=input_tokens,
            output_tokens=output_tokens
        )
        
        self.usage_history.append(usage)
        
        # Calculate cost
        cost = self._calculate_cost(model_id, input_tokens, output_tokens)
        cost_metrics = CostMetrics(
            model_id=model_id,
            input_cost=cost["input_cost"],
            output_cost=cost["output_cost"],
            total_cost=cost["total_cost"]
        )
        self.cost_history.append(cost_metrics)
        
        logger.info(
            f"Usage recorded: {input_tokens} input + {output_tokens} output tokens, "
            f"Cost: ${cost['total_cost']:.4f}"
        )
        
        return {
            "usage": asdict(usage),
            "cost": asdict(cost_metrics)
        }
    
    def _calculate_cost(
        self,
        model_id: str,
        input_tokens: int,
        output_tokens: int
    ) -> Dict[str, float]:
        """
        Calculate cost based on token usage.
        
        Args:
            model_id: Model identifier
            input_tokens: Number of input tokens
            output_tokens: Number of output tokens
            
        Returns:
            Dictionary with input_cost, output_cost, total_cost
        """
        pricing = self.PRICING.get(model_id, self.PRICING["anthropic.claude-haiku-4-5-20251001-v1:0"])
        
        input_cost = (input_tokens / 1_000_000) * pricing["input"]
        output_cost = (output_tokens / 1_000_000) * pricing["output"]
        total_cost = input_cost + output_cost
        
        return {
            "input_cost": input_cost,
            "output_cost": output_cost,
            "total_cost": total_cost
        }
    
    def get_total_usage(self, days: int = 30) -> Dict[str, Any]:
        """
        Get total usage for the last N days.
        
        Args:
            days: Number of days to look back
            
        Returns:
            Dictionary with total usage metrics
        """
        cutoff = datetime.utcnow() - timedelta(days=days)
        
        recent_usage = [
            u for u in self.usage_history
            if datetime.fromisoformat(u.timestamp) >= cutoff
        ]
        
        total_input = sum(u.input_tokens for u in recent_usage)
        total_output = sum(u.output_tokens for u in recent_usage)
        total_tokens = sum(u.total_tokens for u in recent_usage)
        
        return {
            "period_days": days,
            "total_input_tokens": total_input,
            "total_output_tokens": total_output,
            "total_tokens": total_tokens,
            "request_count": len(recent_usage)
        }
    
    def get_total_cost(self, days: int = 30) -> Dict[str, Any]:
        """
        Get total cost for the last N days.
        
        Args:
            days: Number of days to look back
            
        Returns:
            Dictionary with total cost metrics
        """
        cutoff = datetime.utcnow() - timedelta(days=days)
        
        recent_costs = [
            c for c in self.cost_history
            if datetime.fromisoformat(c.timestamp) >= cutoff
        ]
        
        total_input_cost = sum(c.input_cost for c in recent_costs)
        total_output_cost = sum(c.output_cost for c in recent_costs)
        total_cost = sum(c.total_cost for c in recent_costs)
        
        return {
            "period_days": days,
            "total_input_cost": total_input_cost,
            "total_output_cost": total_output_cost,
            "total_cost": total_cost,
            "request_count": len(recent_costs)
        }


class CostTracker:
    """
    Track costs using AWS Cost Explorer API.
    """
    
    def __init__(self, region: str = "us-east-1"):
        """
        Initialize cost tracker.
        
        Args:
            region: AWS region
        """
        self.region = region
        self.client = boto3.client("ce", region_name=region)
    
    def get_bedrock_costs(
        self,
        start_date: str,
        end_date: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Get Bedrock costs from AWS Cost Explorer.
        
        Args:
            start_date: Start date (YYYY-MM-DD)
            end_date: End date (YYYY-MM-DD), defaults to today
            
        Returns:
            Dictionary with cost data
        """
        if not end_date:
            end_date = datetime.utcnow().strftime("%Y-%m-%d")
        
        try:
            response = self.client.get_cost_and_usage(
                TimePeriod={
                    "Start": start_date,
                    "End": end_date
                },
                Granularity="DAILY",
                Metrics=["UnblendedCost"],
                Filter={
                    "Dimensions": {
                        "Key": "SERVICE",
                        "Values": ["Amazon Bedrock"]
                    }
                }
            )
            
            return {
                "start_date": start_date,
                "end_date": end_date,
                "results": response.get("ResultsByTime", [])
            }
        except ClientError as e:
            logger.error(f"Error getting cost data: {e}")
            return {
                "error": str(e),
                "start_date": start_date,
                "end_date": end_date
            }
