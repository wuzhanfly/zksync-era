# Makefile for tMai Chain Deployment
# Provides convenient commands for managing the tMai chain

.PHONY: help setup mint deploy-contracts start stop restart verify test clean logs

# Default target
help:
	@echo "tMai Chain Deployment Commands"
	@echo "==============================="
	@echo ""
	@echo "Setup and Deployment:"
	@echo "  make setup           - Setup chain configuration"
	@echo "  make mint            - Mint tMai tokens to governance addresses"
	@echo "  make deploy-contracts - Deploy L1 and L2 contracts"
	@echo "  make deploy-full     - Run complete deployment (setup + mint + deploy + start)"
	@echo ""
	@echo "Service Management:"
	@echo "  make start           - Start tMai chain services"
	@echo "  make stop            - Stop tMai chain services"
	@echo "  make restart         - Restart tMai chain services"
	@echo ""
	@echo "Testing and Verification:"
	@echo "  make verify          - Verify deployment"
	@echo "  make test            - Run integration tests"
	@echo "  make test-bridge     - Test bridge functionality"
	@echo ""
	@echo "Maintenance:"
	@echo "  make logs            - View service logs"
	@echo "  make clean           - Clean up logs and temporary files"
	@echo "  make status          - Check service status"
	@echo ""
	@echo "Development:"
	@echo "  make install         - Install dependencies"
	@echo "  make build           - Build zkstack CLI"
	@echo ""

# Check if .env.tmai exists
check-env:
	@if [ ! -f .env.tmai ]; then \
		echo "❌ .env.tmai not found!"; \
		echo "Please copy .env.tmai.example to .env.tmai and configure it"; \
		exit 1; \
	fi

# Make scripts executable
make-executable:
	@chmod +x scripts/*.sh

# Setup chain configuration
setup: check-env make-executable
	@echo "🚀 Setting up tMai chain..."
	@./scripts/setup_tmai_chain.sh

# Mint tMai tokens
mint: check-env make-executable
	@echo "💰 Minting tMai tokens..."
	@./scripts/mint_tmai_tokens.sh

# Deploy contracts
deploy-contracts: check-env make-executable
	@echo "📝 Deploying contracts..."
	@./scripts/deploy_tmai_contracts.sh

# Full deployment
deploy-full: check-env make-executable
	@echo "🚀 Running full deployment..."
	@./scripts/full_deployment.sh

# Start services
start: check-env make-executable
	@echo "▶️  Starting tMai chain services..."
	@./scripts/start_tmai_chain.sh

# Stop services
stop: make-executable
	@echo "⏹️  Stopping tMai chain services..."
	@./scripts/stop_tmai_chain.sh

# Restart services
restart: stop start

# Verify deployment
verify: check-env make-executable
	@echo "🔍 Verifying deployment..."
	@./scripts/verify_deployment.sh

# Run tests
test: check-env
	@echo "🧪 Running integration tests..."
	@npm test

# Test bridge
test-bridge: check-env
	@echo "🌉 Testing bridge functionality..."
	@npm run test:bridge

# View logs
logs:
	@if [ -f logs/tmai-chain.pid ]; then \
		tail -f logs/tmai-chain-*.log; \
	else \
		echo "❌ No running instance found"; \
		echo "Recent logs:"; \
		ls -t logs/tmai-chain-*.log 2>/dev/null | head -1 | xargs tail -n 50; \
	fi

# Check status
status:
	@echo "📊 Service Status:"
	@echo ""
	@if [ -f logs/tmai-chain.pid ]; then \
		PID=$$(cat logs/tmai-chain.pid); \
		if kill -0 $$PID 2>/dev/null; then \
			echo "✅ Service is running (PID: $$PID)"; \
			echo ""; \
			echo "Health Check:"; \
			curl -s http://localhost:3081/health | jq . || echo "Health check failed"; \
		else \
			echo "❌ Service is not running (stale PID file)"; \
		fi; \
	else \
		echo "❌ Service is not running"; \
	fi

# Clean up
clean:
	@echo "🧹 Cleaning up..."
	@rm -f logs/*.log
	@rm -f logs/*.pid
	@echo "✅ Cleanup complete"

# Install dependencies
install:
	@echo "📦 Installing dependencies..."
	@npm install
	@echo "✅ Dependencies installed"

# Build zkstack CLI
build:
	@echo "🔨 Building zkstack CLI..."
	@cd zkstack_cli && cargo build --release
	@echo "✅ Build complete"

# Quick health check
health:
	@curl -sf http://localhost:3081/health > /dev/null && echo "✅ Service is healthy" || echo "❌ Service is unhealthy"

# Check chain ID
chain-id:
	@curl -s -X POST -H "Content-Type: application/json" \
		--data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
		http://localhost:3050 | jq -r '.result'

# Check base token
base-token:
	@curl -s -X POST -H "Content-Type: application/json" \
		--data '{"jsonrpc":"2.0","method":"zks_getBaseTokenL1Address","params":[],"id":1}' \
		http://localhost:3050 | jq -r '.result'

# Show configuration
config: check-env
	@echo "📋 Current Configuration:"
	@echo ""
	@grep -E "^(L1_NETWORK|L1_CHAIN_ID|BASE_TOKEN_ADDRESS|CHAIN_NAME|CHAIN_ID)=" .env.tmai | sed 's/^/  /'

# Backup configuration
backup:
	@echo "💾 Creating backup..."
	@mkdir -p backups
	@BACKUP_NAME="backup_$$(date +%Y%m%d_%H%M%S)"; \
	tar -czf "backups/$$BACKUP_NAME.tar.gz" \
		chains/ \
		.env.tmai \
		2>/dev/null || true
	@echo "✅ Backup created in backups/"

# Show help by default
.DEFAULT_GOAL := help
