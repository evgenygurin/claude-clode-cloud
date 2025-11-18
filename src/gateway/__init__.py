"""
LLM Gateway Proxy - OpenAI-compatible API for AWS Bedrock.

This module provides an OpenAI-compatible API that translates requests
to AWS Bedrock, allowing Cursor IDE to connect seamlessly.
"""

from .server import create_app, run_server

__all__ = ["create_app", "run_server"]
