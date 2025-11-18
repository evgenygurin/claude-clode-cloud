#!/usr/bin/env python3
"""
Example usage of Claude Code Bedrock Integration.

This script demonstrates how to use the authentication and gateway components.
"""

import asyncio
import os
from src.auth import get_authenticator
from src.monitoring import UsageTracker


def example_authentication():
    """Example: Using AWS authentication."""
    print("=== Authentication Example ===")
    
    # Get authenticator (auto-detects auth method)
    auth = get_authenticator(region="us-east-1")
    
    # Authenticate
    session = auth.authenticate()
    print(f"✅ Authenticated using method: {auth.method.value}")
    
    # Get Bedrock client
    bedrock = auth.get_bedrock_client()
    print("✅ Bedrock client ready")
    
    return bedrock


def example_usage_tracking():
    """Example: Tracking token usage and costs."""
    print("\n=== Usage Tracking Example ===")
    
    tracker = UsageTracker()
    
    # Record some usage
    tracker.record_usage(
        model_id="anthropic.claude-sonnet-4-5-20250929-v1:0",
        input_tokens=1000,
        output_tokens=500
    )
    
    tracker.record_usage(
        model_id="anthropic.claude-haiku-4-5-20251001-v1:0",
        input_tokens=500,
        output_tokens=200
    )
    
    # Get totals
    usage = tracker.get_total_usage(days=30)
    cost = tracker.get_total_cost(days=30)
    
    print(f"Total tokens: {usage['total_tokens']:,}")
    print(f"Total cost: ${cost['total_cost']:.4f}")
    print(f"Requests: {usage['request_count']}")


async def example_linear_integration():
    """Example: Linear API integration."""
    print("\n=== Linear Integration Example ===")
    
    api_key = os.getenv("LINEAR_API_KEY")
    if not api_key:
        print("⚠️  LINEAR_API_KEY not set, skipping Linear example")
        return
    
    from src.linear_integration import LinearClient
    
    client = LinearClient(api_key=api_key)
    
    # Example: Get issue (replace with actual issue ID)
    # issue = await client.get_issue("your-issue-id")
    # print(f"Issue: {issue.get('title')}")
    
    # Example: Update progress
    # await client.update_progress("your-issue-id", 0.5)
    
    # Example: Add comment
    # await client.add_comment("your-issue-id", "🤖 Cursor Agent: Task completed!")
    
    await client.close()
    print("✅ Linear client ready (examples commented out)")


def main():
    """Run all examples."""
    print("🚀 Claude Code Bedrock Integration Examples\n")
    
    # Authentication example
    try:
        example_authentication()
    except Exception as e:
        print(f"❌ Authentication failed: {e}")
        print("   Make sure AWS credentials are configured")
    
    # Usage tracking example
    example_usage_tracking()
    
    # Linear integration example
    asyncio.run(example_linear_integration())
    
    print("\n✅ Examples complete!")
    print("\nNext steps:")
    print("  1. Start the gateway: docker-compose up -d")
    print("  2. Test the API: curl http://localhost:8000/health")
    print("  3. Configure Cursor to use the gateway")
    print("  4. See docs/en/ for detailed guides")


if __name__ == "__main__":
    main()
