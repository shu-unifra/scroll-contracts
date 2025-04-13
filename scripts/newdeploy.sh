#!/bin/bash
set -e

echo "=== SCROLL CONTRACT DEPLOYMENT SCRIPT ==="

# 设置环境变量
export FOUNDRY_EVM_VERSION="cancun"
export FOUNDRY_BYTECODE_HASH="none"
export BATCH_SIZE=100

export NETWORK="sepolia"

# 显示配置信息
echo "配置信息:"
echo "- FOUNDRY_EVM_VERSION: $FOUNDRY_EVM_VERSION"
echo "- FOUNDRY_BYTECODE_HASH: $FOUNDRY_BYTECODE_HASH"
echo "- BATCH_SIZE: $BATCH_SIZE"
echo "- L1_RPC_ENDPOINT: $L1_RPC_ENDPOINT"
echo "- L2_RPC_ENDPOINT: $L2_RPC_ENDPOINT"
echo "- NETWORK: $NETWORK"


yq -p=toml -o=props "volume/config.toml" > "volume/config.env"
cat volume/config.env | sed 's/.*\.\([^.]*\) = /\1=/' | grep -v "^$" | sed 's/^/export /' > volume/config.shell.env



cat volume/config-contracts.toml | grep -v '^\[' | grep -v '^#' | grep '=' | sed 's/^\s*\([A-Z0-9_]*\)\s*=\s*\(.*\)$/export \1=\2/' | sed 's/=\s*"/="/' | sed 's/"\s*$/"/; s/\([^"]\)$/"\1"/' > volume/config-contracts.env

source "volume/config.shell.env"
source "volume/config-contracts.env"
export L1_RPC_ENDPOINT=http://l1-devnet.scrollsdk
export L2_RPC_ENDPOINT=http://l2-rpc.scrollsdk


# 定义部署脚本
L1_SCRIPTS=(
    "DeployL1ScrollOwner.s.sol:DeployL1ScrollOwner"
    "DeployL1BridgeProxyPlaceholder.s.sol:DeployL1BridgeProxyPlaceholder"
    "DeployFallbackContracts.s.sol:DeployFallbackContracts"
    "DeployL1BridgeContracts.s.sol:DeployL1BridgeContracts"
    "InitializeL1BridgeContracts.s.sol:InitializeL1BridgeContracts"
    "InitializeL1ScrollOwner.s.sol:InitializeL1ScrollOwner"
)

L2_SCRIPTS=(
    "DeployL2ScrollOwner.s.sol:DeployL2ScrollOwner"
    "DeployL2BridgeProxyPlaceholder.s.sol:DeployL2BridgeProxyPlaceholder"
    "DeployL2BridgeContracts.s.sol:DeployL2BridgeContracts"
    "DeployLidoGateway.s.sol:DeployLidoGateway"
    "DeployScrollChainCommitmentVerifier.s.sol:DeployScrollChainCommitmentVerifier"
    "DeployWeth.s.sol:DeployWeth"
    "InitializeL2BridgeContracts.s.sol:InitializeL2BridgeContracts"
    "InitializeL2ScrollOwner.s.sol:InitializeL2ScrollOwner"
)

# 运行脚本函数
run_scripts() {
  local mode=$1
  local broadcast_flag=""
  
  if [ "$mode" = "broadcast" ]; then
    broadcast_flag="--broadcast"
    echo "=== 执行广播部署 ==="
  else
    echo "=== 执行模拟部署 ==="
  fi

  echo ">> 执行 L1 脚本..."
  for script in "${L1_SCRIPTS[@]}"; do
    echo "运行: $script"
    forge script "scripts/foundry/$script" --rpc-url "$L1_RPC_ENDPOINT" --sig "run()" --legacy $broadcast_flag || { 
      echo "错误: $script 执行失败" >&2
      exit 1
    }
  done

  echo ">> 执行 L2 脚本..."
  for script in "${L2_SCRIPTS[@]}"; do
    echo "运行: $script"
    forge script "scripts/foundry/$script" --rpc-url "$L2_RPC_ENDPOINT" --sig "run()" --legacy $broadcast_flag || {
      echo "错误: $script 执行失败" >&2
      exit 1
    }
  done
  
  echo "=== $mode 模式完成 ==="
  echo ""
}

# 查看广播文件
display_broadcast_files() {
  echo "=== 查看广播文件 ==="
  echo "当前目录: $(pwd)"
  
  local BROADCAST_DIR="broadcast"
  
  if [ ! -d "$BROADCAST_DIR" ]; then
    echo "广播目录不存在!"
    return
  fi
  
  # 查找所有脚本目录
  echo "广播脚本目录:"
  find "$BROADCAST_DIR" -mindepth 1 -maxdepth 1 -type d | sort
  
  # 查找最新的run文件并显示
  echo "最新部署结果:"
  LATEST_FILES=$(find "$BROADCAST_DIR" -name "run-latest.json" | sort)
  
  if [ -z "$LATEST_FILES" ]; then
    echo "未找到广播文件!"
  else
    for file in $LATEST_FILES; do
      echo "文件: $file"
      if command -v jq &> /dev/null; then
        jq '.transactions[] | {hash: .hash, contractName: .contractName, contractAddress: .contractAddress}' "$file" 2>/dev/null || cat "$file" | head -20
      else
        grep -E '"(hash|contractName|contractAddress)"' "$file" | head -20
        echo "[...内容过多，已截断...]"
      fi
      echo ""
    done
  fi

  echo "部署摘要:"
  grep -r '"contractAddress"' "$BROADCAST_DIR" --include="run-latest.json" | sort
}

# 主流程
main() {
  # 模拟部署
  run_scripts "simulation"
  
  # # 广播部署
  # run_scripts "broadcast"
  
  # # 显示广播文件
  # display_broadcast_files
  
  echo "=== 部署脚本执行完成 ==="
}

# 执行主函数
main