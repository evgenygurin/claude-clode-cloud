"""
Unit tests for authentication module.
"""

import os
import pytest
from unittest.mock import patch, MagicMock

from src.auth import AWSAuthenticator, get_authenticator, AuthMethod


class TestAWSAuthenticator:
    """Test AWSAuthenticator class."""
    
    def test_init(self):
        """Test authenticator initialization."""
        auth = AWSAuthenticator(region="us-east-1")
        assert auth.region == "us-east-1"
        assert auth._session is None
        assert auth._method is None
    
    def test_detect_auth_method_api_key(self):
        """Test detection of API key method."""
        with patch.dict(os.environ, {"AWS_BEARER_TOKEN_BEDROCK": "test-key"}):
            auth = AWSAuthenticator()
            method = auth._detect_auth_method()
            assert method == AuthMethod.BEDROCK_API_KEY
    
    def test_detect_auth_method_profile(self):
        """Test detection of SSO profile method."""
        with patch.dict(os.environ, {"AWS_PROFILE": "test-profile"}, clear=True):
            auth = AWSAuthenticator()
            method = auth._detect_auth_method()
            assert method == AuthMethod.SSO_PROFILE
    
    def test_detect_auth_method_env_vars(self):
        """Test detection of environment variables method."""
        with patch.dict(
            os.environ,
            {
                "AWS_ACCESS_KEY_ID": "test-key",
                "AWS_SECRET_ACCESS_KEY": "test-secret"
            },
            clear=True
        ):
            auth = AWSAuthenticator()
            method = auth._detect_auth_method()
            assert method == AuthMethod.ENV_VARS
    
    def test_detect_auth_method_cli(self):
        """Test detection of CLI method (default)."""
        with patch.dict(os.environ, {}, clear=True):
            auth = AWSAuthenticator()
            method = auth._detect_auth_method()
            assert method == AuthMethod.AWS_CLI
    
    @patch("boto3.Session")
    def test_authenticate_with_cli(self, mock_session):
        """Test CLI authentication."""
        mock_session_instance = MagicMock()
        mock_sts = MagicMock()
        mock_sts.get_caller_identity.return_value = {"Arn": "arn:aws:iam::123:user/test"}
        mock_session_instance.client.return_value = mock_sts
        mock_session.return_value = mock_session_instance
        
        auth = AWSAuthenticator()
        session = auth._authenticate_with_cli()
        
        assert session is not None
        mock_session.assert_called_once()
    
    def test_authenticate_with_env_vars_missing(self):
        """Test env var authentication with missing vars."""
        with patch.dict(os.environ, {}, clear=True):
            auth = AWSAuthenticator()
            with pytest.raises(ValueError):
                auth._authenticate_with_env_vars()
    
    @patch("boto3.Session")
    def test_authenticate_with_env_vars(self, mock_session):
        """Test env var authentication."""
        mock_session_instance = MagicMock()
        mock_session.return_value = mock_session_instance
        
        with patch.dict(
            os.environ,
            {
                "AWS_ACCESS_KEY_ID": "test-key",
                "AWS_SECRET_ACCESS_KEY": "test-secret",
                "AWS_REGION": "us-east-1"
            }
        ):
            auth = AWSAuthenticator()
            session = auth._authenticate_with_env_vars()
            
            assert session is not None
            mock_session.assert_called_once_with(
                aws_access_key_id="test-key",
                aws_secret_access_key="test-secret",
                region_name="us-east-1"
            )


class TestGetAuthenticator:
    """Test factory function."""
    
    def test_get_authenticator(self):
        """Test authenticator factory."""
        auth = get_authenticator(region="us-west-2")
        assert isinstance(auth, AWSAuthenticator)
        assert auth.region == "us-west-2"
