"""
Authentication module for AWS Bedrock integration.

Supports multiple authentication methods:
1. AWS CLI Configuration
2. Environment Variables
3. SSO Profile
4. Bedrock API Keys
"""

from .aws_auth import AWSAuthenticator, get_authenticator

__all__ = ["AWSAuthenticator", "get_authenticator"]
