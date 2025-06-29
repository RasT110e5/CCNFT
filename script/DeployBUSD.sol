// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CommonBase} from "../lib/forge-std/src/Base.sol";
import {Script} from "../lib/forge-std/src/Script.sol";
import {StdChains} from "../lib/forge-std/src/StdChains.sol";
import {StdCheatsSafe} from "../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../lib/forge-std/src/StdUtils.sol";
import {BUSD} from "../src/BUSD.sol";

contract DeployBUSD is Script {
  BUSD public busd;
  
  function setUp() public {}
  
  function run() public {
    vm.startBroadcast();
    busd = new BUSD();
    vm.stopBroadcast();
  }
}
