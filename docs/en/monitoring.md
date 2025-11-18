# Monitoring & Cost Optimization

Guide for monitoring usage and optimizing costs.

## Token Usage Tracking

The `UsageTracker` class tracks token usage for all requests.

### Usage

```python
from src.monitoring import UsageTracker

tracker = UsageTracker()

# Record usage
tracker.record_usage(
    model_id="anthropic.claude-sonnet-4-5-20250929-v1:0",
    input_tokens=100,
    output_tokens=50
)

# Get totals
usage = tracker.get_total_usage(days=30)
print(f"Total tokens: {usage['total_tokens']}")
```

### Cost Calculation

Costs are automatically calculated based on model pricing:

- **Sonnet 4.5**: $3/1M input, $15/1M output
- **Haiku 4.5**: $0.25/1M input, $1.25/1M output

```python
cost = tracker.get_total_cost(days=30)
print(f"Total cost: ${cost['total_cost']:.2f}")
```

## AWS Cost Explorer Integration

Use `CostTracker` to get costs from AWS Cost Explorer:

```python
from src.monitoring import CostTracker

tracker = CostTracker(region="us-east-1")
costs = tracker.get_bedrock_costs(
    start_date="2025-01-01",
    end_date="2025-01-31"
)
```

## CloudWatch Logs

Terraform creates a CloudWatch log group for monitoring:

```bash
aws logs tail /aws/bedrock/claude-code-dev --follow
```

## Cost Optimization Tips

### 1. Use Appropriate Models

- **Haiku** for simple tasks (10x cheaper)
- **Sonnet** for complex tasks (better quality)

### 2. Set Token Limits

```bash
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=2048  # Instead of 4096
```

### 3. Regional Optimization

Compare costs between regions:
- `us-east-1` vs `us-west-2`

### 4. Monitor Usage

Set up alerts for:
- Daily cost thresholds
- Unusual usage patterns
- Token limit breaches

## Dashboards

### CloudWatch Dashboard

Create a CloudWatch dashboard to visualize:
- Request count
- Token usage
- Costs
- Error rates

### Custom Dashboard

Build a custom dashboard using the monitoring APIs:

```python
# Example dashboard data
usage = tracker.get_total_usage(days=7)
cost = tracker.get_total_cost(days=7)

dashboard_data = {
    "period": "7 days",
    "requests": usage["request_count"],
    "tokens": usage["total_tokens"],
    "cost": cost["total_cost"]
}
```

## Alerts

### Cost Alerts

Set up AWS Budgets to alert on spending:

```bash
aws budgets create-budget \
  --account-id YOUR_ACCOUNT_ID \
  --budget file://budget.json
```

### Usage Alerts

Monitor token usage and set thresholds:

```python
if usage["total_tokens"] > 1_000_000:
    send_alert("High token usage detected")
```

## Best Practices

1. **Monitor Daily** - Check usage and costs daily
2. **Set Budgets** - Use AWS Budgets for cost control
3. **Optimize Models** - Use Haiku when possible
4. **Review Logs** - Check CloudWatch logs regularly
5. **Track Trends** - Monitor usage patterns over time

## Troubleshooting

### High Costs

1. Check which model is being used
2. Review token usage patterns
3. Consider switching to Haiku for simple tasks
4. Set lower token limits

### Missing Data

1. Verify CloudWatch log group exists
2. Check IAM permissions for Cost Explorer
3. Ensure monitoring code is running
