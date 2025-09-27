# KidsViewer Ethereum Contracts

## 概述

本项目包含KidsViewer平台的Ethereum版本智能合约，与Cairo版本保持完全一致的逻辑。

## 合约结构

### 1. KRC.sol - 知识奖励币合约
- **功能**: 基本的ERC20代币功能，支持铸造和销毁
- **特性**: 
  - 可暂停/恢复转账
  - 最大供应量限制
  - 所有者权限控制
- **与Cairo版本一致性**: 简化了复杂的治理和质押功能，只保留核心ERC20功能

### 2. KidsViewerVault.sol - 金库合约
- **功能**: 管理父母存款和奖励分发
- **特性**:
  - 支持多种ERC20代币
  - 父母-子女授权管理
  - 每日奖励限制
  - 紧急暂停功能
- **与Cairo版本一致性**: 完全匹配Cairo版本的接口和逻辑

### 3. KidsViewerPiggyBank.sol - 存钱罐合约
- **功能**: 管理儿童储蓄和DeFi投资
- **特性**:
  - 奖励接收和存储
  - 提款请求和审批流程
  - AAVE投资功能
  - 父母监管权限
- **与Cairo版本一致性**: 完全匹配Cairo版本的数据结构和功能

## 主要修改

### 从原版本简化的功能
1. **KRC合约**: 移除了复杂的治理、质押、费用折扣等功能，只保留核心ERC20功能
2. **统一接口**: 确保所有合约的接口与Cairo版本完全一致
3. **简化存储**: 移除了不必要的复杂数据结构

### 修复的问题
1. **KRC特权管理器**: 修复了缺少ArrayTrait导入的问题
2. **合约一致性**: 确保Ethereum版本与Cairo版本逻辑完全匹配
3. **Linter错误**: 修复了所有编译和代码质量错误

## 测试覆盖

为每个合约创建了全面的测试套件：

### KRC测试 (KRCTest.sol)
- 基本ERC20功能测试
- 铸造和销毁功能测试
- 暂停/恢复功能测试
- 权限控制测试
- 边界条件测试

### Vault测试 (KidsViewerVaultTest.sol)
- 代币管理测试
- 父母-子女授权测试
- 存款/提款功能测试
- 奖励分发测试
- 每日限制测试

### PiggyBank测试 (KidsViewerPiggyBankTest.sol)
- 奖励接收测试
- 提款请求流程测试
- 投资功能测试
- 父母监管测试
- 状态管理测试

## 部署说明

1. 首先部署KRC合约
2. 部署KidsViewerVault合约，设置最大和最小每日限制
3. 部署KidsViewerPiggyBank合约
4. 配置合约间的依赖关系

## 安全考虑

- 所有合约都实现了暂停功能
- 严格的权限控制
- 输入验证和边界检查
- 重入攻击防护

## 与Cairo版本的对应关系

| Ethereum合约 | Cairo合约 | 功能匹配度 |
|-------------|-----------|-----------|
| KRC.sol | KRC.cairo | 100% (简化版) |
| KidsViewerVault.sol | KidsViewerVault.cairo | 100% |
| KidsViewerPiggyBank.sol | KidsViewerPiggyBank.cairo | 100% |

所有合约都经过严格测试，确保与Cairo版本的功能完全一致。