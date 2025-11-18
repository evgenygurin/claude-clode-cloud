# ============================================================================
# Makefile for Claude Code Bedrock Integration
# ============================================================================

.PHONY: help install test lint format docker-build docker-up docker-down terraform-init terraform-plan terraform-apply clean

help:
	@echo "Available targets:"
	@echo "  install         - Install Python dependencies"
	@echo "  test           - Run tests"
	@echo "  lint           - Run linters"
	@echo "  format         - Format code"
	@echo "  docker-build   - Build Docker image"
	@echo "  docker-up      - Start Docker containers"
	@echo "  docker-down    - Stop Docker containers"
	@echo "  terraform-init - Initialize Terraform"
	@echo "  terraform-plan - Plan Terraform changes"
	@echo "  terraform-apply - Apply Terraform changes"
	@echo "  clean          - Clean temporary files"

install:
	pip install uv
	uv pip install --system -r requirements.txt
	uv pip install --system -r requirements-dev.txt

test:
	pytest tests/ -v

lint:
	ruff check src/
	mypy src/ --ignore-missing-imports

format:
	ruff format src/
	black src/
	isort src/

docker-build:
	docker build -t claude-code-bedrock .

docker-up:
	docker-compose up -d

docker-down:
	docker-compose down

terraform-init:
	cd terraform && terraform init

terraform-plan:
	cd terraform/environments/dev && terraform plan

terraform-apply:
	cd terraform/environments/dev && terraform apply

clean:
	find . -type d -name __pycache__ -exec rm -r {} +
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete
	rm -rf .pytest_cache
	rm -rf .coverage
	rm -rf htmlcov
	rm -rf dist
	rm -rf build
	rm -rf *.egg-info
