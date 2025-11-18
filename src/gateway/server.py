"""
LLM Gateway Proxy Server.

Provides OpenAI-compatible API endpoints that translate to AWS Bedrock.
"""

import json
import logging
import os
from typing import Dict, Any, Optional, AsyncGenerator
from datetime import datetime

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import StreamingResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from ..auth import get_authenticator

logger = logging.getLogger(__name__)

app = FastAPI(
    title="Claude Code Bedrock Gateway",
    description="OpenAI-compatible API for AWS Bedrock",
    version="1.0.0"
)

# CORS middleware for Cursor IDE
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict to Cursor domains
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global authenticator
authenticator = None


class ChatMessage(BaseModel):
    """Chat message model."""
    role: str = Field(..., description="Message role (user, assistant, system)")
    content: str = Field(..., description="Message content")


class ChatCompletionRequest(BaseModel):
    """Chat completion request (OpenAI format)."""
    model: str = Field(..., description="Model identifier")
    messages: list[ChatMessage] = Field(..., description="Conversation messages")
    temperature: float = Field(default=1.0, ge=0.0, le=2.0)
    max_tokens: Optional[int] = Field(default=None, ge=1)
    stream: bool = Field(default=False, description="Enable streaming")
    top_p: Optional[float] = Field(default=None, ge=0.0, le=1.0)
    stop: Optional[list[str]] = Field(default=None)


class ChatCompletionResponse(BaseModel):
    """Chat completion response (OpenAI format)."""
    id: str
    object: str = "chat.completion"
    created: int
    model: str
    choices: list[Dict[str, Any]]
    usage: Optional[Dict[str, int]] = None


def initialize_authenticator(region: str = "us-east-1"):
    """Initialize AWS authenticator."""
    global authenticator
    authenticator = get_authenticator(region=region)
    authenticator.authenticate()
    logger.info("Authenticator initialized")


@app.on_event("startup")
async def startup_event():
    """Initialize on startup."""
    region = os.getenv("AWS_REGION", "us-east-1")
    initialize_authenticator(region)
    logger.info("Gateway server started")


@app.get("/")
async def root():
    """Health check endpoint."""
    return {
        "status": "ok",
        "service": "claude-code-bedrock-gateway",
        "version": "1.0.0"
    }


@app.get("/health")
async def health():
    """Health check with AWS connectivity."""
    try:
        if authenticator:
            client = authenticator.get_bedrock_control_client()
            # Test connection
            client.list_foundation_models()
            return {"status": "healthy", "aws": "connected"}
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return {"status": "unhealthy", "error": str(e)}
    
    return {"status": "healthy"}


@app.get("/v1/models")
async def list_models():
    """
    List available models (OpenAI-compatible endpoint).
    
    Returns list of available Claude models from Bedrock.
    """
    try:
        client = authenticator.get_bedrock_control_client()
        
        # Get Anthropic models
        response = client.list_foundation_models(
            byProvider="Anthropic"
        )
        
        models = []
        for model in response.get("modelSummaries", []):
            models.append({
                "id": model["modelId"],
                "object": "model",
                "created": int(datetime.now().timestamp()),
                "owned_by": "anthropic"
            })
        
        return {
            "object": "list",
            "data": models
        }
    except Exception as e:
        logger.error(f"Error listing models: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/v1/chat/completions")
async def chat_completions(request: ChatCompletionRequest):
    """
    Chat completions endpoint (OpenAI-compatible).
    
    Translates OpenAI-format requests to AWS Bedrock format.
    """
    if not authenticator:
        raise HTTPException(status_code=500, detail="Authenticator not initialized")
    
    try:
        # Map OpenAI model names to Bedrock model IDs
        model_id = map_model_name(request.model)
        
        # Convert messages to Bedrock format
        bedrock_messages = convert_messages(request.messages)
        
        # Prepare Bedrock request
        bedrock_request = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": request.max_tokens or 4096,
            "messages": bedrock_messages,
            "temperature": request.temperature,
        }
        
        if request.top_p:
            bedrock_request["top_p"] = request.top_p
        
        if request.stop:
            bedrock_request["stop_sequences"] = request.stop
        
        # Get Bedrock client
        client = authenticator.get_bedrock_client()
        
        if request.stream:
            # Streaming response
            return StreamingResponse(
                stream_bedrock_response(client, model_id, bedrock_request),
                media_type="text/event-stream"
            )
        else:
            # Non-streaming response
            response = client.invoke_model(
                modelId=model_id,
                body=json.dumps(bedrock_request)
            )
            
            response_body = json.loads(response["body"].read())
            
            # Convert to OpenAI format
            return convert_to_openai_format(
                response_body,
                model_id,
                request.model
            )
    
    except Exception as e:
        logger.error(f"Error in chat completion: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


def map_model_name(openai_model: str) -> str:
    """
    Map OpenAI-style model names to Bedrock model IDs.
    
    Args:
        openai_model: Model name from request (e.g., "claude-sonnet-4.5")
        
    Returns:
        Bedrock model ID
    """
    model_mapping = {
        "claude-sonnet-4.5": "anthropic.claude-sonnet-4-5-20250929-v1:0",
        "claude-haiku-4.5": "anthropic.claude-haiku-4-5-20251001-v1:0",
        "gpt-4": "anthropic.claude-sonnet-4-5-20250929-v1:0",  # Fallback
        "gpt-3.5-turbo": "anthropic.claude-haiku-4-5-20251001-v1:0",  # Fallback
    }
    
    # Check if it's already a Bedrock model ID
    if "anthropic.claude" in openai_model:
        return openai_model
    
    # Map from OpenAI name
    return model_mapping.get(openai_model, "anthropic.claude-sonnet-4-5-20250929-v1:0")


def convert_messages(messages: list[ChatMessage]) -> list[Dict[str, Any]]:
    """
    Convert OpenAI format messages to Bedrock format.
    
    Args:
        messages: List of ChatMessage objects
        
    Returns:
        List of Bedrock-format messages
    """
    bedrock_messages = []
    system_message = None
    
    for msg in messages:
        if msg.role == "system":
            system_message = msg.content
        elif msg.role in ["user", "assistant"]:
            bedrock_messages.append({
                "role": msg.role,
                "content": msg.content
            })
    
    result = {"messages": bedrock_messages}
    if system_message:
        result["system"] = system_message
    
    return bedrock_messages


async def stream_bedrock_response(
    client,
    model_id: str,
    request_body: Dict[str, Any]
) -> AsyncGenerator[str, None]:
    """
    Stream responses from Bedrock.
    
    Args:
        client: Bedrock client
        model_id: Model identifier
        request_body: Request body in Bedrock format
        
    Yields:
        SSE-formatted chunks
    """
    try:
        response = client.invoke_model_with_response_stream(
            modelId=model_id,
            body=json.dumps(request_body)
        )
        
        stream = response.get("body")
        if not stream:
            yield f"data: {json.dumps({'error': 'No response stream'})}\n\n"
            return
        
        for event in stream:
            if "chunk" in event:
                chunk = json.loads(event["chunk"]["bytes"])
                
                # Convert to OpenAI SSE format
                if "delta" in chunk:
                    delta = chunk["delta"]
                    if "text" in delta:
                        sse_data = {
                            "id": "chatcmpl-" + str(int(datetime.now().timestamp())),
                            "object": "chat.completion.chunk",
                            "created": int(datetime.now().timestamp()),
                            "model": model_id,
                            "choices": [{
                                "index": 0,
                                "delta": {"content": delta["text"]},
                                "finish_reason": None
                            }]
                        }
                        yield f"data: {json.dumps(sse_data)}\n\n"
                
                if chunk.get("type") == "message_stop":
                    yield "data: [DONE]\n\n"
                    break
    
    except Exception as e:
        logger.error(f"Streaming error: {e}")
        error_data = {"error": str(e)}
        yield f"data: {json.dumps(error_data)}\n\n"


def convert_to_openai_format(
    bedrock_response: Dict[str, Any],
    model_id: str,
    original_model: str
) -> ChatCompletionResponse:
    """
    Convert Bedrock response to OpenAI format.
    
    Args:
        bedrock_response: Response from Bedrock
        model_id: Bedrock model ID
        original_model: Original model name from request
        
    Returns:
        OpenAI-format response
    """
    content = ""
    if "content" in bedrock_response:
        for block in bedrock_response["content"]:
            if block["type"] == "text":
                content += block["text"]
    
    return ChatCompletionResponse(
        id=f"chatcmpl-{int(datetime.now().timestamp())}",
        created=int(datetime.now().timestamp()),
        model=original_model,
        choices=[{
            "index": 0,
            "message": {
                "role": "assistant",
                "content": content
            },
            "finish_reason": "stop"
        }],
        usage={
            "prompt_tokens": bedrock_response.get("usage", {}).get("input_tokens", 0),
            "completion_tokens": bedrock_response.get("usage", {}).get("output_tokens", 0),
            "total_tokens": bedrock_response.get("usage", {}).get("input_tokens", 0) + 
                          bedrock_response.get("usage", {}).get("output_tokens", 0)
        }
    )


def create_app(region: str = "us-east-1") -> FastAPI:
    """
    Create and configure FastAPI app.
    
    Args:
        region: AWS region
        
    Returns:
        Configured FastAPI app
    """
    initialize_authenticator(region)
    return app


def run_server(host: str = "0.0.0.0", port: int = 8000, region: str = "us-east-1"):
    """
    Run the gateway server.
    
    Args:
        host: Host to bind to
        port: Port to bind to
        region: AWS region
    """
    import uvicorn
    
    initialize_authenticator(region)
    uvicorn.run(app, host=host, port=port)
