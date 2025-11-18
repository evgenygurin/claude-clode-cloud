"""
AWS Authentication handlers for Claude Code Bedrock integration.

Supports multiple authentication methods as specified in the requirements.
"""

import os
import logging
from typing import Optional, Dict, Any
from enum import Enum

import boto3
from botocore.credentials import Credentials
from botocore.exceptions import ClientError, NoCredentialsError

logger = logging.getLogger(__name__)


class AuthMethod(Enum):
    """Supported authentication methods."""
    AWS_CLI = "aws_cli"
    ENV_VARS = "env_vars"
    SSO_PROFILE = "sso_profile"
    BEDROCK_API_KEY = "bedrock_api_key"


class AWSAuthenticator:
    """
    Handles AWS authentication for Bedrock access.
    
    Supports multiple authentication methods:
    1. AWS CLI Configuration (default profile)
    2. Environment Variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
    3. SSO Profile (AWS_PROFILE)
    4. Bedrock API Keys (AWS_BEARER_TOKEN_BEDROCK)
    """
    
    def __init__(self, region: str = "us-east-1"):
        """
        Initialize authenticator.
        
        Args:
            region: AWS region for Bedrock
        """
        self.region = region
        self._session: Optional[boto3.Session] = None
        self._method: Optional[AuthMethod] = None
    
    def authenticate(self, method: Optional[AuthMethod] = None) -> boto3.Session:
        """
        Authenticate using the specified method or auto-detect.
        
        Args:
            method: Authentication method to use (None for auto-detect)
            
        Returns:
            Authenticated boto3.Session
            
        Raises:
            NoCredentialsError: If no valid credentials found
            ValueError: If invalid authentication method
        """
        if method:
            self._method = method
        else:
            self._method = self._detect_auth_method()
        
        logger.info(f"Using authentication method: {self._method.value}")
        
        if self._method == AuthMethod.BEDROCK_API_KEY:
            # For API key, we'll use custom headers
            self._session = self._authenticate_with_api_key()
        elif self._method == AuthMethod.SSO_PROFILE:
            self._session = self._authenticate_with_profile()
        elif self._method == AuthMethod.ENV_VARS:
            self._session = self._authenticate_with_env_vars()
        else:  # AWS_CLI (default)
            self._session = self._authenticate_with_cli()
        
        # Verify credentials
        self._verify_credentials()
        
        return self._session
    
    def _detect_auth_method(self) -> AuthMethod:
        """
        Auto-detect authentication method based on available credentials.
        
        Returns:
            Detected authentication method
        """
        # Check for Bedrock API key first (most specific)
        if os.getenv("AWS_BEARER_TOKEN_BEDROCK"):
            return AuthMethod.BEDROCK_API_KEY
        
        # Check for SSO profile
        if os.getenv("AWS_PROFILE"):
            return AuthMethod.SSO_PROFILE
        
        # Check for environment variables
        if os.getenv("AWS_ACCESS_KEY_ID") and os.getenv("AWS_SECRET_ACCESS_KEY"):
            return AuthMethod.ENV_VARS
        
        # Default to AWS CLI
        return AuthMethod.AWS_CLI
    
    def _authenticate_with_cli(self) -> boto3.Session:
        """Authenticate using AWS CLI configuration."""
        try:
            session = boto3.Session(region_name=self.region)
            # Test credentials
            session.client("sts").get_caller_identity()
            return session
        except NoCredentialsError:
            raise NoCredentialsError(
                "AWS CLI credentials not found. Run 'aws configure' or set environment variables."
            )
    
    def _authenticate_with_env_vars(self) -> boto3.Session:
        """Authenticate using environment variables."""
        access_key = os.getenv("AWS_ACCESS_KEY_ID")
        secret_key = os.getenv("AWS_SECRET_ACCESS_KEY")
        region = os.getenv("AWS_REGION", self.region)
        
        if not access_key or not secret_key:
            raise NoCredentialsError(
                "AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be set"
            )
        
        session = boto3.Session(
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            region_name=region
        )
        
        return session
    
    def _authenticate_with_profile(self) -> boto3.Session:
        """Authenticate using SSO profile."""
        profile = os.getenv("AWS_PROFILE")
        if not profile:
            raise ValueError("AWS_PROFILE environment variable not set")
        
        try:
            session = boto3.Session(profile_name=profile, region_name=self.region)
            # Test credentials
            session.client("sts").get_caller_identity()
            return session
        except NoCredentialsError:
            raise NoCredentialsError(
                f"Profile '{profile}' not found or credentials expired. "
                "Run 'aws sso login' if using SSO."
            )
    
    def _authenticate_with_api_key(self) -> boto3.Session:
        """
        Authenticate using Bedrock API key.
        
        Note: This is a placeholder for future API key support.
        Currently, Bedrock uses standard AWS credentials.
        """
        api_key = os.getenv("AWS_BEARER_TOKEN_BEDROCK")
        if not api_key:
            raise ValueError("AWS_BEARER_TOKEN_BEDROCK environment variable not set")
        
        # For now, fall back to standard AWS auth
        # In the future, this could use custom request signing
        logger.warning(
            "Bedrock API key authentication not fully implemented. "
            "Falling back to standard AWS authentication."
        )
        return self._authenticate_with_cli()
    
    def _verify_credentials(self) -> None:
        """Verify that credentials are valid."""
        if not self._session:
            raise ValueError("Session not initialized")
        
        try:
            sts = self._session.client("sts")
            identity = sts.get_caller_identity()
            logger.info(f"Authenticated as: {identity.get('Arn', 'Unknown')}")
        except ClientError as e:
            raise NoCredentialsError(f"Invalid credentials: {e}")
    
    def get_bedrock_client(self):
        """
        Get authenticated Bedrock client.
        
        Returns:
            boto3 Bedrock client
        """
        if not self._session:
            self.authenticate()
        
        return self._session.client("bedrock-runtime", region_name=self.region)
    
    def get_bedrock_control_client(self):
        """
        Get authenticated Bedrock control plane client.
        
        Returns:
            boto3 Bedrock client (control plane)
        """
        if not self._session:
            self.authenticate()
        
        return self._session.client("bedrock", region_name=self.region)
    
    @property
    def method(self) -> Optional[AuthMethod]:
        """Get current authentication method."""
        return self._method


def get_authenticator(region: str = "us-east-1") -> AWSAuthenticator:
    """
    Factory function to get an authenticator instance.
    
    Args:
        region: AWS region
        
    Returns:
        AWSAuthenticator instance
    """
    return AWSAuthenticator(region=region)
