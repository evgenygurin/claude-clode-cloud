#!/usr/bin/env python3
"""
Main entry point for LLM Gateway Proxy server.
"""

import os
import sys
import argparse
import logging

from .server import run_server

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)

logger = logging.getLogger(__name__)


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description="Claude Code Bedrock Gateway")
    parser.add_argument(
        "--host",
        default=os.getenv("GATEWAY_HOST", "0.0.0.0"),
        help="Host to bind to"
    )
    parser.add_argument(
        "--port",
        type=int,
        default=int(os.getenv("GATEWAY_PORT", "8000")),
        help="Port to bind to"
    )
    parser.add_argument(
        "--region",
        default=os.getenv("AWS_REGION", "us-east-1"),
        help="AWS region"
    )
    
    args = parser.parse_args()
    
    logger.info(f"Starting gateway server on {args.host}:{args.port}")
    logger.info(f"AWS Region: {args.region}")
    
    try:
        run_server(host=args.host, port=args.port, region=args.region)
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
        sys.exit(0)
    except Exception as e:
        logger.error(f"Server error: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
