// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

// Import all deployment scripts
import {DeployFallbackContracts} from "./DeployFallbackContracts.s.sol";
import {DeployL1BridgeContracts} from "./DeployL1BridgeContracts.s.sol";
import {DeployL1BridgeProxyPlaceholder} from "./DeployL1BridgeProxyPlaceholder.s.sol";
import {DeployL1ScrollOwner} from "./DeployL1ScrollOwner.s.sol";
import {DeployL2BridgeContracts} from "./DeployL2BridgeContracts.s.sol";
import {DeployL2BridgeProxyPlaceholder} from "./DeployL2BridgeProxyPlaceholder.s.sol";
import {DeployL2ScrollOwner} from "./DeployL2ScrollOwner.s.sol";
import {DeployL2Weth} from "./DeployL2Weth.s.sol";
import {DeployLidoGateway} from "./DeployLidoGateway.s.sol";
import {DeployScrollChainCommitmentVerifier} from "./DeployScrollChainCommitmentVerifier.s.sol";
import {DeployWeth} from "./DeployWeth.s.sol";

// Import all initialization scripts
import {InitializeL1BridgeContracts} from "./InitializeL1BridgeContracts.s.sol";
import {InitializeL1ScrollOwner} from "./InitializeL1ScrollOwner.s.sol";
import {InitializeL2BridgeContracts} from "./InitializeL2BridgeContracts.s.sol";
import {InitializeL2ScrollOwner} from "./InitializeL2ScrollOwner.s.sol";

contract NewDeploy is Script {
    function run() external {
        console.log("=== Start Unified Deployment Process ===");

        // 1. Deploy L2 & L1 Scroll Owner
        console.log("== Deploying Scroll Owners ==");
        new DeployL2ScrollOwner().run();
        new DeployL1ScrollOwner().run();

        // 2. Deploy L1 Fallback Contracts
        console.log("== Deploying Fallback Contracts ==");
        new DeployFallbackContracts().run();

        // 3. Deploy Bridge Proxy Placeholders
        console.log("== Deploying Bridge Proxy Placeholders ==");
        new DeployL2BridgeProxyPlaceholder().run();
        new DeployL1BridgeProxyPlaceholder().run();

        // 4. Deploy WETH on L2 & L1
        console.log("== Deploying WETH Contracts ==");
        new DeployL2Weth().run();
        new DeployWeth().run();

        // 5. Deploy Bridge Contracts
        console.log("== Deploying Bridge Contracts ==");
        new DeployL2BridgeContracts().run();
        new DeployL1BridgeContracts().run();

        // 6. Deploy Lido Gateway & Commitment Verifier
        console.log("== Deploying Lido Gateway & Verifier ==");
        new DeployLidoGateway().run();
        new DeployScrollChainCommitmentVerifier().run();

        // 7. Initialize all contracts
        console.log("== Initializing Contracts ==");
        new InitializeL1BridgeContracts().run();
        new InitializeL1ScrollOwner().run();
        new InitializeL2BridgeContracts().run();
        new InitializeL2ScrollOwner().run();

        console.log("=== Deployment Process Completed ===");
    }
}
