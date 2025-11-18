/**
 * LLM Gateway - Unified Interface for Multiple LLM Backends
 * Integrates Bedrock, OpenAI, and other LLM providers
 * Optimized for Cursor IDE integration
 *
 * Phase: WOR-11 - Cursor Integration & LLM Gateway
 * Purpose: Route requests to optimal LLM backend based on config
 */

import { Request, Response, NextFunction } from "express";

/**
 * LLM Provider types
 */
export type LLMProvider = "bedrock" | "openai" | "anthropic" | "local";

/**
 * Request routing strategy
 */
export type RoutingStrategy = "direct" | "load-balance" | "failover" | "cost-optimize";

/**
 * LLM Gateway request metrics
 */
export interface RequestMetrics {
  requestId: string;
  provider: LLMProvider;
  model: string;
  startTime: number;
  endTime?: number;
  duration?: number;
  inputTokens: number;
  outputTokens: number;
  totalTokens: number;
  costUsd: number;
  statusCode: number;
  cached: boolean;
  cacheKey?: string;
}

/**
 * Model configuration with performance and cost metrics
 */
export interface ModelConfig {
  id: string;
  provider: LLMProvider;
  displayName: string;
  maxTokens: number;
  contextWindow: number;
  costPerInputToken: number; // $ per 1M tokens
  costPerOutputToken: number; // $ per 1M tokens
  averageLatencyMs: number; // estimated
  reliability: number; // 0-100
  maxConcurrentRequests: number;
  supportedCapabilities: string[]; // e.g., ["vision", "function-calling"]
}

/**
 * LLM Gateway configuration
 */
export interface GatewayConfig {
  defaultProvider: LLMProvider;
  routingStrategy: RoutingStrategy;
  enableCaching: boolean;
  cacheTtlSeconds: number;
  enableMetrics: boolean;
  enableFailover: boolean;
  providers: {
    bedrock?: {
      region: string;
      endpoint?: string;
    };
    openai?: {
      apiKey: string;
      baseUrl?: string;
    };
    anthropic?: {
      apiKey: string;
      baseUrl?: string;
    };
    local?: {
      endpoint: string;
      port: number;
    };
  };
  models: ModelConfig[];
}

/**
 * Model selection criteria
 */
export interface SelectionCriteria {
  preferredProvider?: LLMProvider;
  maxCostPerRequest?: number;
  minReliability?: number;
  requireCapability?: string;
  maxLatencyMs?: number;
}

/**
 * Main LLM Gateway class
 * Routes requests to optimal LLM backend
 */
export class LLMGateway {
  private config: GatewayConfig;
  private metrics: Map<string, RequestMetrics> = new Map();
  private cache: Map<string, any> = new Map();
  private cacheTimers: Map<string, NodeJS.Timeout> = new Map();
  private modelStats: Map<string, any> = new Map();

  constructor(config: GatewayConfig) {
    this.config = config;
    this.initializeModelStats();
  }

  /**
   * Initialize model statistics tracking
   */
  private initializeModelStats(): void {
    for (const model of this.config.models) {
      this.modelStats.set(model.id, {
        totalRequests: 0,
        totalTokens: 0,
        totalCost: 0,
        averageLatency: model.averageLatencyMs,
        successCount: 0,
        errorCount: 0,
        lastUsed: null,
        uptime: 100,
      });
    }
  }

  /**
   * Select optimal model based on criteria and request
   */
  selectModel(
    criteria: SelectionCriteria,
    requestTokens: number
  ): ModelConfig | null {
    let candidates = this.config.models;

    // Filter by provider preference
    if (criteria.preferredProvider) {
      candidates = candidates.filter(
        (m) => m.provider === criteria.preferredProvider
      );
    }

    // Filter by cost
    if (criteria.maxCostPerRequest) {
      const maxInputCost = criteria.maxCostPerRequest * 0.7; // Assume 70% input
      const maxOutputCost = criteria.maxCostPerRequest * 0.3; // Assume 30% output
      candidates = candidates.filter((m) => {
        const estimatedCost =
          (requestTokens * m.costPerInputToken) / 1000000 +
          (requestTokens * m.costPerOutputToken) / 1000000;
        return estimatedCost <= criteria.maxCostPerRequest;
      });
    }

    // Filter by reliability
    if (criteria.minReliability) {
      candidates = candidates.filter(
        (m) => m.reliability >= criteria.minReliability
      );
    }

    // Filter by capability
    if (criteria.requireCapability) {
      candidates = candidates.filter((m) =>
        m.supportedCapabilities.includes(criteria.requireCapability!)
      );
    }

    // Filter by latency
    if (criteria.maxLatencyMs) {
      candidates = candidates.filter(
        (m) => m.averageLatencyMs <= criteria.maxLatencyMs
      );
    }

    if (candidates.length === 0) {
      // Fallback to default model
      return this.config.models.find(
        (m) => m.provider === this.config.defaultProvider
      ) || null;
    }

    // Score and rank candidates
    return this.scoreModels(candidates, criteria)[0] || null;
  }

  /**
   * Score models based on criteria and historical performance
   */
  private scoreModels(
    models: ModelConfig[],
    criteria: SelectionCriteria
  ): ModelConfig[] {
    const scored = models.map((model) => {
      let score = 100;

      // Cost optimization score (lower cost = higher score)
      if (criteria.maxCostPerRequest) {
        const costScore = (1 - model.costPerInputToken / 1000) * 20;
        score += costScore;
      }

      // Reliability score
      score += model.reliability * 0.3;

      // Latency score (lower latency = higher score)
      const latencyScore = (100 - model.averageLatencyMs / 2) * 0.2;
      score += Math.max(0, latencyScore);

      // Historical uptime score
      const stats = this.modelStats.get(model.id);
      if (stats) {
        score += stats.uptime * 0.2;
      }

      return { model, score };
    });

    return scored
      .sort((a, b) => b.score - a.score)
      .map((s) => s.model);
  }

  /**
   * Middleware for request routing
   */
  routingMiddleware() {
    return async (req: Request, res: Response, next: NextFunction) => {
      const requestId = this.generateRequestId();
      const startTime = Date.now();

      // Extract model and request details
      const { model: requestedModel, messages } = req.body;

      // Determine token count (estimation)
      const inputTokens = this.estimateTokens(messages);

      // Select optimal model
      const selectedModel = this.selectModel(
        {
          preferredProvider: this.config.defaultProvider,
          maxCostPerRequest: 0.10, // $0.10 per request max
          minReliability: 95,
        },
        inputTokens
      );

      if (!selectedModel) {
        return res.status(503).json({
          error: {
            message: "No suitable model found",
            type: "model_selection_error",
          },
        });
      }

      // Check cache
      const cacheKey = this.generateCacheKey(
        requestedModel,
        messages
      );
      const cachedResponse = this.cache.get(cacheKey);

      if (this.config.enableCaching && cachedResponse) {
        // Return cached response
        const metrics: RequestMetrics = {
          requestId,
          provider: selectedModel.provider,
          model: selectedModel.id,
          startTime,
          endTime: Date.now(),
          duration: Date.now() - startTime,
          inputTokens,
          outputTokens: 0,
          totalTokens: inputTokens,
          costUsd: 0,
          statusCode: 200,
          cached: true,
          cacheKey,
        };

        if (this.config.enableMetrics) {
          this.metrics.set(requestId, metrics);
        }

        return res.json({
          ...cachedResponse,
          cached: true,
        });
      }

      // Store in request context for provider middleware
      (req as any).llmGateway = {
        requestId,
        selectedModel,
        inputTokens,
        startTime,
        cacheKey,
      };

      next();
    };
  }

  /**
   * Handle successful response
   */
  recordSuccess(
    requestId: string,
    outputTokens: number,
    response: any
  ): void {
    const metrics = this.metrics.get(requestId);
    if (!metrics) return;

    metrics.endTime = Date.now();
    metrics.duration = metrics.endTime - metrics.startTime;
    metrics.outputTokens = outputTokens;
    metrics.totalTokens = metrics.inputTokens + outputTokens;

    // Calculate cost
    const model = this.config.models.find((m) => m.id === metrics.model);
    if (model) {
      metrics.costUsd =
        (metrics.inputTokens * model.costPerInputToken) / 1000000 +
        (metrics.outputTokens * model.costPerOutputToken) / 1000000;
    }

    metrics.statusCode = 200;

    // Cache response
    const llmGateway = (global as any).llmGateway;
    if (this.config.enableCaching && llmGateway?.cacheKey) {
      this.cache.set(llmGateway.cacheKey, response);

      // Set TTL
      const timer = setTimeout(() => {
        this.cache.delete(llmGateway.cacheKey);
        this.cacheTimers.delete(llmGateway.cacheKey);
      }, this.config.cacheTtlSeconds * 1000);

      this.cacheTimers.set(llmGateway.cacheKey, timer);
    }

    // Update model stats
    this.updateModelStats(metrics.model, metrics);
  }

  /**
   * Handle error response
   */
  recordError(
    requestId: string,
    statusCode: number,
    error: Error
  ): void {
    const metrics = this.metrics.get(requestId);
    if (!metrics) return;

    metrics.endTime = Date.now();
    metrics.duration = metrics.endTime - metrics.startTime;
    metrics.statusCode = statusCode;

    const stats = this.modelStats.get(metrics.model);
    if (stats) {
      stats.errorCount++;
      stats.uptime = (stats.successCount / (stats.successCount + stats.errorCount)) * 100;
    }
  }

  /**
   * Update model statistics
   */
  private updateModelStats(modelId: string, metrics: RequestMetrics): void {
    const stats = this.modelStats.get(modelId);
    if (!stats) return;

    stats.totalRequests++;
    stats.totalTokens += metrics.totalTokens;
    stats.totalCost += metrics.costUsd;
    stats.successCount++;
    stats.lastUsed = new Date();

    // Update average latency (exponential moving average)
    const alpha = 0.1;
    stats.averageLatency =
      alpha * metrics.duration + (1 - alpha) * stats.averageLatency;
  }

  /**
   * Estimate token count from messages
   */
  private estimateTokens(messages: any[]): number {
    // Simple estimation: ~4 characters per token
    return messages.reduce((total, msg) => {
      return total + Math.ceil((msg.content?.length || 0) / 4);
    }, 0);
  }

  /**
   * Generate cache key from request
   */
  private generateCacheKey(model: string, messages: any[]): string {
    const content = JSON.stringify({ model, messages });
    // Simple hash (in production, use crypto.createHash)
    return `cache_${model}_${content.length}_${content.charCodeAt(0)}`;
  }

  /**
   * Generate unique request ID
   */
  private generateRequestId(): string {
    return `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Get gateway metrics
   */
  getMetrics() {
    return {
      totalRequests: this.metrics.size,
      metrics: Array.from(this.metrics.values()),
      modelStats: Object.fromEntries(this.modelStats),
      cacheSize: this.cache.size,
      totalCost: Array.from(this.metrics.values()).reduce(
        (sum, m) => sum + m.costUsd,
        0
      ),
    };
  }

  /**
   * Clear old metrics (for memory management)
   */
  clearOldMetrics(olderThanSeconds: number = 3600): void {
    const cutoff = Date.now() - olderThanSeconds * 1000;
    const keysToDelete = Array.from(this.metrics.entries())
      .filter(([_, metrics]) => (metrics.endTime || metrics.startTime) < cutoff)
      .map(([key, _]) => key);

    keysToDelete.forEach((key) => this.metrics.delete(key));
  }

  /**
   * Get gateway health status
   */
  getHealth() {
    const modelHealths = this.config.models.map((model) => {
      const stats = this.modelStats.get(model.id);
      return {
        model: model.id,
        status: stats.uptime >= 95 ? "healthy" : "degraded",
        uptime: stats.uptime,
        lastUsed: stats.lastUsed,
        totalRequests: stats.totalRequests,
        totalCost: stats.totalCost,
      };
    });

    return {
      status: modelHealths.every((h) => h.status === "healthy")
        ? "healthy"
        : "degraded",
      models: modelHealths,
      cacheSize: this.cache.size,
      metricsTracked: this.metrics.size,
    };
  }
}

/**
 * Factory function for creating gateway with common configurations
 */
export function createLLMGateway(config: Partial<GatewayConfig> = {}): LLMGateway {
  const defaultConfig: GatewayConfig = {
    defaultProvider: "bedrock",
    routingStrategy: "cost-optimize",
    enableCaching: true,
    cacheTtlSeconds: 3600,
    enableMetrics: true,
    enableFailover: true,
    providers: {
      bedrock: {
        region: process.env.AWS_REGION || "us-east-1",
      },
      local: {
        endpoint: "http://localhost",
        port: 3000,
      },
    },
    models: [
      {
        id: "claude-3-5-sonnet-20241022",
        provider: "bedrock",
        displayName: "Claude 3.5 Sonnet",
        maxTokens: 200000,
        contextWindow: 200000,
        costPerInputToken: 3,
        costPerOutputToken: 15,
        averageLatencyMs: 800,
        reliability: 99.5,
        maxConcurrentRequests: 100,
        supportedCapabilities: [
          "vision",
          "code-generation",
          "function-calling",
        ],
      },
      {
        id: "claude-3-5-haiku-20241022",
        provider: "bedrock",
        displayName: "Claude 3.5 Haiku",
        maxTokens: 200000,
        contextWindow: 200000,
        costPerInputToken: 0.8,
        costPerOutputToken: 2.4,
        averageLatencyMs: 300,
        reliability: 99.8,
        maxConcurrentRequests: 500,
        supportedCapabilities: ["code-generation"],
      },
      {
        id: "claude-3-opus-20240229",
        provider: "bedrock",
        displayName: "Claude 3 Opus",
        maxTokens: 200000,
        contextWindow: 200000,
        costPerInputToken: 15,
        costPerOutputToken: 75,
        averageLatencyMs: 2000,
        reliability: 99.9,
        maxConcurrentRequests: 50,
        supportedCapabilities: [
          "vision",
          "code-generation",
          "function-calling",
          "complex-reasoning",
        ],
      },
    ],
    ...config,
  };

  return new LLMGateway(defaultConfig);
}

export default LLMGateway;
