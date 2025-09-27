#!/bin/bash

# KidsViewer Smart Contracts Run Script
# This script provides commands for building, testing, and deploying smart contracts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "${BLUE}🚀 KidsViewer Smart Contracts - $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Check dependencies
check_dependencies() {
    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js not found, please install Node.js 18+"
        exit 1
    fi

    # Check npm
    if ! command -v npm &> /dev/null; then
        print_error "npm not found, please install npm"
        exit 1
    fi

    # Check Node.js version
    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        print_error "Node.js version too low, requires 18+, current: $(node -v)"
        exit 1
    fi

    print_success "Node.js version check passed: $(node -v)"
}

# Ethereum contracts functions
ethereum_build() {
    print_header "Building Ethereum Contracts"
    
    # Check if forge is installed
    if ! command -v forge &> /dev/null; then
        print_error "Forge not found, please install Foundry first"
        print_info "Install Foundry: curl -L https://foundry.paradigm.xyz | bash"
        print_info "Then run: foundryup"
        exit 1
    fi
    
    # Navigate to ethereum contracts directory
    if [ ! -d "ethereum" ]; then
        print_error "Ethereum contracts directory not found"
        exit 1
    fi
    
    cd ethereum
    
    print_info "Building Ethereum contracts with forge..."
    forge build
    
    if [ $? -ne 0 ]; then
        print_error "Ethereum contracts build failed"
        cd ..
        exit 1
    fi
    
    print_success "Ethereum contracts built successfully"
    cd ..
}

ethereum_test() {
    print_header "Testing Ethereum Contracts"
    
    # Check if forge is installed
    if ! command -v forge &> /dev/null; then
        print_error "Forge not found, please install Foundry first"
        print_info "Install Foundry: curl -L https://foundry.paradigm.xyz | bash"
        print_info "Then run: foundryup"
        exit 1
    fi
    
    # Navigate to ethereum contracts directory
    if [ ! -d "ethereum" ]; then
        print_error "Ethereum contracts directory not found"
        exit 1
    fi
    
    cd ethereum
    
    print_info "Running Ethereum contract tests with forge..."
    forge test
    
    if [ $? -ne 0 ]; then
        print_error "Ethereum contract tests failed"
        cd ..
        exit 1
    fi
    
    print_success "Ethereum contract tests passed"
    cd ..
}

ethereum_deploy() {
    print_header "Deploying Ethereum Contracts"
    
    # Check if forge is installed
    if ! command -v forge &> /dev/null; then
        print_error "Forge not found, please install Foundry first"
        print_info "Install Foundry: curl -L https://foundry.paradigm.xyz | bash"
        print_info "Then run: foundryup"
        exit 1
    fi
    
    # Navigate to ethereum contracts directory
    if [ ! -d "ethereum" ]; then
        print_error "Ethereum contracts directory not found"
        exit 1
    fi
    
    cd ethereum
    
    # Check if RPC URL is provided
    if [ -z "$RPC_URL" ]; then
        print_error "RPC_URL environment variable not set"
        print_info "Example: RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY ./run.sh ethereum-deploy"
        cd ..
        exit 1
    fi
    
    # Check if private key is provided
    if [ -z "$PRIVATE_KEY" ]; then
        print_error "PRIVATE_KEY environment variable not set"
        print_info "Example: PRIVATE_KEY=0x... ./run.sh ethereum-deploy"
        cd ..
        exit 1
    fi
    
    print_info "Deploying Ethereum contracts..."
    print_info "RPC URL: $RPC_URL"
    print_warning "Make sure you have enough ETH for gas fees"
    
    forge script script/DeployKRCScript.s.sol --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --broadcast
    
    if [ $? -ne 0 ]; then
        print_error "Ethereum contracts deployment failed"
        cd ..
        exit 1
    fi
    
    print_success "Ethereum contracts deployed successfully"
    cd ..
}

# Starknet contracts functions
starknet_build() {
    print_header "Building Starknet Contracts"
    
    # Check if scarb is installed
    if ! command -v scarb &> /dev/null; then
        print_error "Scarb not found, please install Scarb first"
        print_info "Install Scarb: curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh"
        exit 1
    fi
    
    # Navigate to starknet contracts directory
    if [ ! -d "starknet" ]; then
        print_error "Starknet contracts directory not found"
        exit 1
    fi
    
    cd starknet
    
    print_info "Building Starknet contracts with scarb..."
    scarb build
    
    if [ $? -ne 0 ]; then
        print_error "Starknet contracts build failed"
        cd ..
        exit 1
    fi
    
    print_success "Starknet contracts built successfully"
    cd ..
}

starknet_test() {
    print_header "Testing Starknet Contracts"
    
    # Check if snforge is installed
    if ! command -v snforge &> /dev/null; then
        print_error "snforge not found, please install Starknet Foundry first"
        print_info "Install Starknet Foundry: curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/foundry-rs/starknet-foundry/master/scripts/install.sh | sh"
        exit 1
    fi
    
    # Navigate to starknet contracts directory
    if [ ! -d "starknet" ]; then
        print_error "Starknet contracts directory not found"
        exit 1
    fi
    
    cd starknet
    
    print_info "Running Starknet contract tests with snforge..."
    snforge test
    
    if [ $? -ne 0 ]; then
        print_error "Starknet contract tests failed"
        cd ..
        exit 1
    fi
    
    print_success "Starknet contract tests passed"
    cd ..
}

starknet_deploy() {
    print_header "Deploying Starknet Contracts"
    
    # Check if scarb is installed
    if ! command -v scarb &> /dev/null; then
        print_error "Scarb not found, please install Scarb first"
        print_info "Install Scarb: curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh"
        exit 1
    fi
    
    # Navigate to starknet contracts directory
    if [ ! -d "starknet" ]; then
        print_error "Starknet contracts directory not found"
        exit 1
    fi
    
    cd starknet
    
    # Check if gateway URL is provided
    if [ -z "$GATEWAY_URL" ]; then
        print_error "GATEWAY_URL environment variable not set"
        print_info "Example: GATEWAY_URL=https://starknet-sepolia.infura.io/v3/YOUR_KEY ./run.sh starknet-deploy"
        cd ..
        exit 1
    fi
    
    # Check if account is provided
    if [ -z "$ACCOUNT" ]; then
        print_error "ACCOUNT environment variable not set"
        print_info "Example: ACCOUNT=0x... ./run.sh starknet-deploy"
        cd ..
        exit 1
    fi
    
    print_info "Building contracts first..."
    scarb build
    
    if [ $? -ne 0 ]; then
        print_error "Build failed, cannot deploy"
        cd ..
        exit 1
    fi
    
    print_info "Deploying Starknet contracts..."
    print_info "Gateway URL: $GATEWAY_URL"
    print_warning "Make sure you have enough STRK for gas fees"
    
    # Deploy each contract
    print_info "Deploying KRC contract..."
    starknet deploy --gateway-url "$GATEWAY_URL" --account "$ACCOUNT" --class-hash $(scarb metadata --format-version 1 | jq -r '.contracts[] | select(.name == "KRC") | .class_hash')
    
    print_info "Deploying KidsViewerVault contract..."
    starknet deploy --gateway-url "$GATEWAY_URL" --account "$ACCOUNT" --class-hash $(scarb metadata --format-version 1 | jq -r '.contracts[] | select(.name == "KidsViewerVault") | .class_hash')
    
    print_info "Deploying KidsViewerPiggyBank contract..."
    starknet deploy --gateway-url "$GATEWAY_URL" --account "$ACCOUNT" --class-hash $(scarb metadata --format-version 1 | jq -r '.contracts[] | select(.name == "KidsViewerPiggyBank") | .class_hash')
    
    print_success "Starknet contracts deployed successfully"
    cd ..
}

# Combined contracts functions
contracts_build() {
    print_header "Building All Contracts"
    
    ethereum_build
    starknet_build
    
    print_success "All contracts built successfully"
}

contracts_test() {
    print_header "Testing All Contracts"
    
    ethereum_test
    starknet_test
    
    print_success "All contract tests passed"
}

contracts_deploy() {
    print_header "Deploying All Contracts"
    
    print_warning "This will deploy to both Ethereum and Starknet networks"
    print_warning "Make sure you have set the required environment variables"
    echo ""
    read -p "Continue with deployment? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Deployment cancelled"
        exit 0
    fi
    
    ethereum_deploy
    starknet_deploy
    
    print_success "All contracts deployed successfully"
}

# Install dependencies
install_deps() {
    print_header "Installing Dependencies"
    
    check_dependencies
    
    # Install Foundry if not present
    if ! command -v forge &> /dev/null; then
        print_info "Installing Foundry..."
        curl -L https://foundry.paradigm.xyz | bash
        foundryup
    fi
    
    # Install Scarb if not present
    if ! command -v scarb &> /dev/null; then
        print_info "Installing Scarb..."
        curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh
    fi
    
    # Install Starknet Foundry if not present
    if ! command -v snforge &> /dev/null; then
        print_info "Installing Starknet Foundry..."
        curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/foundry-rs/starknet-foundry/master/scripts/install.sh | sh
    fi
    
    print_success "All dependencies installed successfully"
}

# Clean build artifacts
clean() {
    print_header "Cleaning Build Artifacts"
    
    # Clean Ethereum artifacts
    if [ -d "ethereum" ]; then
        cd ethereum
        print_info "Cleaning Ethereum build artifacts..."
        forge clean
        cd ..
    fi
    
    # Clean Starknet artifacts
    if [ -d "starknet" ]; then
        cd starknet
        print_info "Cleaning Starknet build artifacts..."
        scarb clean
        cd ..
    fi
    
    print_success "Build artifacts cleaned successfully"
}

# Show help
show_help() {
    echo -e "${BLUE}KidsViewer Smart Contracts Run Script${NC}"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Build Commands:"
    echo "  ethereum-build            Build Ethereum contracts (forge build)"
    echo "  starknet-build            Build Starknet contracts (scarb build)"
    echo "  contracts-build           Build all contracts (Ethereum + Starknet)"
    echo ""
    echo "Test Commands:"
    echo "  ethereum-test             Test Ethereum contracts (forge test)"
    echo "  starknet-test             Test Starknet contracts (snforge test)"
    echo "  contracts-test            Test all contracts (Ethereum + Starknet)"
    echo ""
    echo "Deploy Commands:"
    echo "  ethereum-deploy           Deploy Ethereum contracts (requires RPC_URL and PRIVATE_KEY)"
    echo "  starknet-deploy           Deploy Starknet contracts (requires GATEWAY_URL and ACCOUNT)"
    echo "  contracts-deploy          Deploy all contracts (requires all environment variables)"
    echo ""
    echo "Utility Commands:"
    echo "  install-deps              Install all required dependencies"
    echo "  clean                     Clean build artifacts"
    echo "  help                      Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  RPC_URL                   Ethereum RPC endpoint for deployment"
    echo "  PRIVATE_KEY               Ethereum private key for deployment"
    echo "  GATEWAY_URL               Starknet gateway URL for deployment"
    echo "  ACCOUNT                   Starknet account for deployment"
    echo ""
    echo "Examples:"
    echo "  $0 contracts-build        Build all contracts"
    echo "  $0 contracts-test         Test all contracts"
    echo "  RPC_URL=https://... PRIVATE_KEY=0x... $0 ethereum-deploy"
    echo "  GATEWAY_URL=https://... ACCOUNT=0x... $0 starknet-deploy"
    echo ""
}

# Main script logic
case "${1:-help}" in
    "ethereum-build")
        ethereum_build
        ;;
    "ethereum-test")
        ethereum_test
        ;;
    "ethereum-deploy")
        ethereum_deploy
        ;;
    "starknet-build")
        starknet_build
        ;;
    "starknet-test")
        starknet_test
        ;;
    "starknet-deploy")
        starknet_deploy
        ;;
    "contracts-build")
        contracts_build
        ;;
    "contracts-test")
        contracts_test
        ;;
    "contracts-deploy")
        contracts_deploy
        ;;
    "install-deps")
        install_deps
        ;;
    "clean")
        clean
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
