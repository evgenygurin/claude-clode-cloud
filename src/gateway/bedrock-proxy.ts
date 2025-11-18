/**
 * AWS Bedrock Proxy Server
 * OpenAI-compatible API wrapper for AWS Bedrock Claude models
 *
 * Phase: WOR-9 - Claude Code Configuration
 * Purpose: Provides OpenAI-compatible endpoints for Bedrock models
 */

import Anthropic from "@anthropic-ai/sdk";
import { BedrockRuntime } from "@aws-sdk/client-bedrock-runtime";
import express, { Request, Response } from "express";
import cors from "cors";
import dotenv from "dotenv";
import { v4 as uuidv4 } from "uuid";

dotenv.config();

// Types for OpenAI-compatible API
interface OpenAIMessage {
  role: "user" | "assistant" | "system";
  content: string;
}

interface OpenAIChatRequest {
  model: string;
  messages: OpenAIMessage[];
  max_tokens?: number;
  temperature?: number;
  top_p?: number;
  stream?: boolean;
}

interface OpenAIChatResponse {
  id: string;
  object: string;
  created: number;
  model: string;
  choices: {
    index: number;
    message: {
      role: string;
      content: string;
    };
    finish_reason: string;
  }[];
  usage: {
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
  };
}

// Model mapping between OpenAI and Bedrock
const MODEL_MAPPING: Record<string, string> = {
  "gpt-4": "anthropic.claude-3-5-sonnet-20241022-v2:0",
  "gpt-4-turbo": "anthropic.claude-3-5-sonnet-20241022-v2:0",
  "gpt-3.5-turbo": "anthropic.claude-3-5-haiku-20241022-v1:0",
  "claude-3-opus": "anthropic.claude-3-opus-20240229-v1:0",
  "claude-3-sonnet": "anthropic.claude-3-5-sonnet-20241022-v2:0",
  "claude-3-haiku": "anthropic.claude-3-5-haiku-20241022-v1:0",
};

interface ServerConfig {
  port: number;
  awsRegion: string;
  debug: boolean;
}

class BedrockProxyServer {
  private app: express.Application;
  private client: BedrockRuntime;
  private config: ServerConfig;

  constructor(config: Partial<ServerConfig> = {}) {
    this.config = {
      port: parseInt(process.env.PORT || "3000", 10),
      awsRegion: process.env.AWS_REGION || "us-east-1",
      debug: process.env.DEBUG === "true",
      ...config,
    };

    this.app = express();
    this.client = new BedrockRuntime({ region: this.config.awsRegion });

    this.setupMiddleware();
    this.setupRoutes();
  }

  private setupMiddleware(): void {
    this.app.use(cors());
    this.app.use(express.json({ limit: "10mb" }));

    // Logging middleware
    this.app.use((req: Request, res: Response, next) => {
      if (this.config.debug) {
        console.log(`${req.method} ${req.path}`, {
          timestamp: new Date().toISOString(),
          headers: req.headers,
        });
      }
      next();
    });
  }

  private setupRoutes(): void {
    // Health check
    this.app.get("/health", (req: Request, res: Response) => {
      res.json({
        status: "healthy",
        timestamp: new Date().toISOString(),
        region: this.config.awsRegion,
      });
    });

    // Models endpoint (OpenAI compatible)
    this.app.get("/v1/models", (req: Request, res: Response) => {
      const models = Object.keys(MODEL_MAPPING).map((id) => ({
        id,
        object: "model",
        owned_by: "anthropic",
        permission: [],
      }));

      res.json({
        object: "list",
        data: models,
      });
    });

    // Chat completions endpoint (OpenAI compatible)
    this.app.post(
      "/v1/chat/completions",
      this.handleChatCompletion.bind(this)
    );

    // Bedrock specific endpoint for metadata
    this.app.get("/v1/bedrock/models", this.getBedrockModels.bind(this));

    // Error handling
    this.app.use((err: Error, req: Request, res: Response, next) => {
      console.error("Error:", err);
      res.status(500).json({
        error: {
          message: err.message,
          type: "internal_error",
        },
      });
    });
  }

  private async handleChatCompletion(
    req: Request,
    res: Response
  ): Promise<void> {
    try {
      const body = req.body as OpenAIChatRequest;

      // Validate request
      if (!body.messages || body.messages.length === 0) {
        res.status(400).json({
          error: {
            message: "Messages are required",
            type: "invalid_request_error",
          },
        });
        return;
      }

      // Map model name
      const bedrockModel = MODEL_MAPPING[body.model] || body.model;

      if (this.config.debug) {
        console.log("Chat request:", {
          model: body.model,
          bedrockModel,
          messagesCount: body.messages.length,
        });
      }

      // Prepare messages for Anthropic/Bedrock
      const messages = body.messages
        .filter((m) => m.role !== "system")
        .map((m) => ({
          role: m.role as "user" | "assistant",
          content: m.content,
        }));

      // Get system message if present
      const systemMessage = body.messages.find((m) => m.role === "system");

      // Call Bedrock
      const response = await this.client.invokeModel({
        modelId: bedrockModel,
        contentType: "application/json",
        accept: "application/json",
        body: JSON.stringify({
          anthropic_version: "bedrock-2023-06-01",
          max_tokens: body.max_tokens || 1024,
          system: systemMessage?.content,
          messages: messages,
          temperature: body.temperature || 0.7,
          top_p: body.top_p || 0.9,
        }),
      });

      // Parse response
      const responseBody = JSON.parse(
        new TextDecoder().decode(response.body)
      );

      // Convert to OpenAI format
      const openAIResponse: OpenAIChatResponse = {
        id: `chatcmpl-${uuidv4()}`,
        object: "chat.completion",
        created: Math.floor(Date.now() / 1000),
        model: body.model,
        choices: [
          {
            index: 0,
            message: {
              role: "assistant",
              content:
                responseBody.content[0].text ||
                responseBody.content[0].type === "text"
                  ? responseBody.content[0].text
                  : "",
            },
            finish_reason: responseBody.stop_reason || "stop",
          },
        ],
        usage: {
          prompt_tokens: responseBody.usage?.input_tokens || 0,
          completion_tokens: responseBody.usage?.output_tokens || 0,
          total_tokens:
            (responseBody.usage?.input_tokens || 0) +
            (responseBody.usage?.output_tokens || 0),
        },
      };

      res.json(openAIResponse);
    } catch (error) {
      console.error("Chat completion error:", error);
      const err = error as Error;
      res.status(500).json({
        error: {
          message: err.message,
          type: "server_error",
        },
      });
    }
  }

  private async getBedrockModels(
    req: Request,
    res: Response
  ): Promise<void> {
    try {
      // This would call bedrock:ListFoundationModels in production
      // For now, return known models
      const models = Object.entries(MODEL_MAPPING).map(([openaiId, bedrockId]) => ({
        openaiId,
        bedrockId,
        provider: "anthropic",
        available: true,
      }));

      res.json({
        models,
        region: this.config.awsRegion,
      });
    } catch (error) {
      console.error("Error fetching Bedrock models:", error);
      res.status(500).json({
        error: {
          message: "Failed to fetch models",
        },
      });
    }
  }

  public start(): void {
    this.app.listen(this.config.port, () => {
      console.log(`🚀 Bedrock Proxy Server started on port ${this.config.port}`);
      console.log(`Region: ${this.config.awsRegion}`);
      console.log(`Debug mode: ${this.config.debug}`);
      console.log(`Health check: http://localhost:${this.config.port}/health`);
      console.log(
        `OpenAI-compatible API: http://localhost:${this.config.port}/v1/chat/completions`
      );
    });
  }
}

// Start server if this is the main module
if (require.main === module) {
  const server = new BedrockProxyServer();
  server.start();
}

export default BedrockProxyServer;
export { OpenAIChatRequest, OpenAIChatResponse, ServerConfig };
