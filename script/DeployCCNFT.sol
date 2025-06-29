// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CommonBase} from "../lib/forge-std/src/Base.sol";
import {Script} from "../lib/forge-std/src/Script.sol";
import {StdChains} from "../lib/forge-std/src/StdChains.sol";
import {StdCheatsSafe} from "../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../lib/forge-std/src/StdUtils.sol";
import {CCNFT} from "../src/CCNFT.sol";

contract DeployCCNFT is Script {
  CCNFT public nft;
  
  function setUp() public {}
  
  function run() public {
    vm.startBroadcast();
    nft = new CCNFT();
    vm.stopBroadcast();
  }
}
