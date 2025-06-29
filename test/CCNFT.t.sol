// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CommonBase} from "../lib/forge-std/src/Base.sol";
import {StdAssertions} from "../lib/forge-std/src/StdAssertions.sol";
import {StdChains} from "../lib/forge-std/src/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../lib/forge-std/src/StdUtils.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Strings} from "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {BUSD} from "../src/BUSD.sol";
import {CCNFT} from "../src/CCNFT.sol";

// Definición del contrato de prueba CCNFTTest que hereda de Test.
// Declaración de direcciones y dos instancias de contratos (BUSD y CCNFT).
contract CCNFTTest is Test {
  address deployer;
  address c1;
  address c2;
  address funds;
  address fees;
  BUSD busd;
  CCNFT ccnft;

  // Required to be able to run _safe operations from ERC721 contract, which expects interactions with other ERC721 contracts.
  function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
    return this.onERC721Received.selector;
  }

  // Ejecución antes de cada prueba.
  // Inicializar las direcciones y desplgar las instancias de BUSD y CCNFT.
  function setUp() public {
    deployer = address(this);
    c1 = address(0x1);
    c2 = address(0x2);
    funds = address(0x3);
    fees = address(0x4);
    busd = new BUSD();
    ccnft = new CCNFT();

    // Configure the contract with token and collectors
    ccnft.setFundsToken(address(busd));
    ccnft.setFundsCollector(funds);
    ccnft.setFeesCollector(fees);
  }

  // Prueba de "setFundsCollector" del contrato CCNFT.
  // Llamar al método y despues verificar que el valor se haya establecido correctamente.
  function testSetFundsCollector() public {
    ccnft.setFundsCollector(c1);
    assertEq(ccnft.fundsCollector(), c1, "Funds collector should be updated");
  }

  // Prueba de "setFeesCollector" del contrato CCNFT
  // Verificar que el valor se haya establecido correctamente.
  function testSetFeesCollector() public {
    ccnft.setFeesCollector(c2);
    assertEq(ccnft.feesCollector(), c2, "Fees collector should be updated");
  }

  // Prueba de "setProfitToPay" del contrato CCNFT
  // Verificar que el valor se haya establecido correctamente.
  function testSetProfitToPay() public {
    uint32 profit = 500;
    ccnft.setProfitToPay(profit);
    assertEq(ccnft.profitToPay(), profit, "Profit to pay should be updated");
  }

  // Prueba de "setCanBuy" primero estableciéndolo en true y verificando que se establezca correctamente.
  // Despues establecerlo en false verificando nuevamente.
  function testSetCanBuy() public {
    ccnft.setCanBuy(true);
    assertTrue(ccnft.canBuy(), "canBuy should be true");
  }

  // Prueba de método "setCanTrade". Similar a "testSetCanBuy".
  function testSetCanTrade() public {
    ccnft.setCanTrade(true);
    assertTrue(ccnft.canTrade(), "canTrade should be true");
  }

  // Prueba de método "setCanClaim". Similar a "testSetCanBuy".
  function testSetCanClaim() public {
    ccnft.setCanClaim(true);
    assertTrue(ccnft.canClaim(), "canClaim should be true");
  }

  // Prueba de "setMaxValueToRaise" con diferentes valores.
  // Verifica que se establezcan correctamente.
  function testSetMaxValueToRaise() public {
    uint256 maxVal = 1000;
    ccnft.setMaxValueToRaise(maxVal);
    assertEq(ccnft.maxValueToRaise(), maxVal, "Max value to raise should be updated");
  }

  // Prueba de "addValidValues" añadiendo diferentes valores.
  // Verificar que se hayan añadido correctamente.
  function testAddValidValues() public {
    uint256 val1 = 123;
    uint256 val2 = 456;
    ccnft.addValidValues(val1);
    ccnft.addValidValues(val2);
    assertTrue(ccnft.validValues(val1), "Value1 should be valid");
    assertTrue(ccnft.validValues(val2), "Value2 should be valid");
  }

  // Prueba de "setMaxBatchCount".
  // Verifica que el valor se haya establecido correctamente.
  function testSetMaxBatchCount() public {
    uint16 count = 10;
    ccnft.setMaxBatchCount(count);
    assertEq(ccnft.maxBatchCount(), count, "Max batch count should be updated");
  }

  // Prueba de "setBuyFee".
  // Verificar que el valor se haya establecido correctamente.
  function testSetBuyFee() public {
    uint16 fee = 250;
    ccnft.setBuyFee(fee);
    assertEq(ccnft.buyFee(), fee, "Buy fee should be updated");
  }

  // Prueba de "setTradeFee".
  // Verificar que el valor se haya establecido correctamente.
  function testSetTradeFee() public {
    uint16 fee = 125;
    ccnft.setTradeFee(fee);
    assertEq(ccnft.tradeFee(), fee, "Trade fee should be updated");
  }

  // Prueba de que no se pueda comerciar cuando canTrade es false.
  // Verificar que se lance un error esperado.
  function testCannotTradeWhenCanTradeIsFalse() public {
    vm.expectRevert(bytes("Trading is disabled"));
    ccnft.trade(1);
  }

  // Prueba que no se pueda comerciar con un token que no existe, incluso si canTrade es true.
  // Verificar que se lance un error esperado.
  function testCannotTradeWhenTokenDoesNotExist() public {
    ccnft.setCanTrade(true);
    vm.expectRevert(bytes("Token does not exist"));
    ccnft.trade(999);
  }

  function testCannotBuyWhenItIsDisabled() public {
    ccnft.setCanBuy(false);
    vm.expectRevert(bytes("Buying is disabled"));
    ccnft.buy(10, 10);
  }

  function testCannotBuyWhen() public {
    ccnft.setCanBuy(true);
    ccnft.setMaxBatchCount(1);
    vm.expectRevert(bytes(string.concat("Invalid amount, it needs to be greater than 0 and less than ", Strings.toString(1))));
    ccnft.buy(10, 10);
    vm.expectRevert(bytes(string.concat("Invalid amount, it needs to be greater than 0 and less than ", Strings.toString(1))));
    ccnft.buy(10, 0);
  }

  function testCannotBuyWithInvalidValue() public {
    ccnft.setCanBuy(true);
    ccnft.setMaxBatchCount(5);
    ccnft.addValidValues(100);
    vm.expectRevert(bytes("Invalid value, not in valid values"));
    ccnft.buy(200, 1);
  }

  function testCannotBuyWhenMaxValueExceeded() public {
    ccnft.setCanBuy(true);
    ccnft.setMaxBatchCount(5);
    ccnft.addValidValues(100);
    ccnft.setMaxValueToRaise(150);
    vm.expectRevert(bytes("Max value exceeded"));
    ccnft.buy(100, 2);
  }

  function testBuySuccess() public {
    deal(address(busd), address(this), 100);
    busd.approve(address(ccnft), 100);
    ccnft.setCanBuy(true);
    ccnft.setMaxBatchCount(5);
    ccnft.addValidValues(100);
    ccnft.setMaxValueToRaise(1000);
    uint256 expectedTokenId = 0;

    vm.expectEmit(true, true, false, true, address(ccnft));
    emit CCNFT.Buy(address(this), expectedTokenId, 100);

    ccnft.buy(100, 1);

    assertEq(ccnft.ownerOf(expectedTokenId), address(this));
    assertEq(ccnft.values(expectedTokenId), 100);
    assertEq(busd.balanceOf(funds), 100);
  }

  // Prueba: compra con buyFee = 0 (no transfiere fees)
  function testBuyNoFee() public {
    deal(address(busd), address(this), 1000);
    busd.approve(address(ccnft), 100);

    ccnft.setCanBuy(true);
    ccnft.setMaxBatchCount(5);
    ccnft.addValidValues(100);
    ccnft.setMaxValueToRaise(1000);
    ccnft.setBuyFee(0);

    ccnft.buy(100, 1);
    assertEq(busd.balanceOf(fees), 0);
  }

  // Prueba: compra con buyFee > 0 (transfiere fees correctamente)
  function testBuyWithFee() public {
    deal(address(busd), address(this), 1000);
    busd.approve(address(ccnft), 105); // 100 + 5% fee

    ccnft.setCanBuy(true);
    ccnft.setMaxBatchCount(5);
    ccnft.addValidValues(100);
    ccnft.setMaxValueToRaise(1000);
    ccnft.setBuyFee(500); // 5%

    ccnft.buy(100, 1);

    assertEq(busd.balanceOf(fees), 5);
    assertEq(busd.balanceOf(funds), 100);
  }

  // Prueba: compra en lote (batch minting)
  function testBuyBatch() public {
    deal(address(busd), address(this), 1000);
    busd.approve(address(ccnft), 150);

    ccnft.setCanBuy(true);
    ccnft.setMaxBatchCount(3);
    ccnft.addValidValues(50);
    ccnft.setMaxValueToRaise(1000);

    ccnft.buy(50, 3);

    assertEq(ccnft.ownerOf(0), address(this));
    assertEq(ccnft.ownerOf(1), address(this));
    assertEq(ccnft.ownerOf(2), address(this));
    assertEq(busd.balanceOf(funds), 150);
  }

  // Prueba: pone un NFT a la venta correctamente
  function testPutOnSaleSuccess() public {
    ccnft.setCanBuy(true);
    ccnft.setCanTrade(true);
    ccnft.setMaxBatchCount(1);
    ccnft.addValidValues(100);
    ccnft.setMaxValueToRaise(1000);

    deal(address(busd), address(this), 100);
    busd.approve(address(ccnft), 100);
    ccnft.buy(100, 1); // tokenId = 0

    vm.expectEmit(true, false, true, true, address(ccnft));
    emit CCNFT.PutOnSale(0, 250);

    ccnft.putOnSale(0, 250);

    (bool onSale, uint256 price) = ccnft.tokensOnSale(0);
    assertTrue(onSale);
    assertEq(price, 250);
  }

  // Prueba negativa: no permite poner a la venta un token que no existe
  function testPutOnSaleNonexistentToken() public {
    ccnft.setCanTrade(true);
    vm.expectRevert("Token does not exist");
    ccnft.putOnSale(0, 100);
  }

  // Prueba negativa: no permite poner a la venta un token que no es tuyo
  function testPutOnSaleNotOwner() public {
    ccnft.setCanBuy(true);
    ccnft.setCanTrade(true);
    ccnft.setMaxBatchCount(1);
    ccnft.addValidValues(100);
    ccnft.setMaxValueToRaise(1000);

    deal(address(busd), address(this), 100);
    busd.approve(address(ccnft), 100);
    ccnft.buy(100, 1); // crea tokenId 0

    // Atacante intenta ponerlo en venta
    address attacker = address(0xBAD);
    vm.prank(attacker);
    vm.expectRevert("Only owner can put on sale");
    ccnft.putOnSale(0, 100);
  }

  // Prueba: realiza una compra exitosa de NFT a otro usuario usando la función trade()
  function testTradeSuccess() public {
    // Setup: vendedor crea el NFT y lo pone en venta
    deal(address(busd), address(this), 100);
    busd.approve(address(ccnft), 100);
    ccnft.setCanBuy(true);
    ccnft.setCanTrade(true);
    ccnft.setMaxBatchCount(1);
    ccnft.addValidValues(100);
    ccnft.setMaxValueToRaise(1000);
    ccnft.buy(100, 1);
    ccnft.putOnSale(0, 50);

    // Setup: comprador
    address buyer = address(0xBEEF);
    deal(address(busd), buyer, 55); // 50 + 5% fee (if applicable)
    vm.prank(buyer);
    IERC20(address(busd)).approve(address(ccnft), 55);

    // Expect event
    vm.expectEmit(true, true, true, true, address(ccnft));
    emit CCNFT.Trade(buyer, address(this), 0, 50);

    // El comprador ejecuta la compra
    vm.prank(buyer);
    ccnft.trade(0);

    assertEq(ccnft.ownerOf(0), buyer);
    assertEq(busd.balanceOf(address(this)), 50); // vendedor recibió pago
  }

  // Prueba negativa: falla si el token existe pero no está en venta
  function testTradeFailsIfNotOnSale() public {
    ccnft.setCanBuy(true);
    ccnft.setCanTrade(true);
    ccnft.setMaxBatchCount(1);
    ccnft.addValidValues(100);
    ccnft.setMaxValueToRaise(1000);

    // Vendedor crea el token pero no lo pone a la venta
    deal(address(busd), address(this), 100);
    busd.approve(address(ccnft), 100);
    ccnft.buy(100, 1); // tokenId = 0

    // Comprador intenta comprar
    address buyer = address(0xBAD);
    deal(address(busd), buyer, 100);
    vm.prank(buyer);
    IERC20(address(busd)).approve(address(ccnft), 100);

    // Esperamos que falle con "Token not On Sale"
    vm.prank(buyer);
    vm.expectRevert("Token not On Sale");
    ccnft.trade(0);
  }

  // Prueba negativa: falla si el trade está deshabilitado
  function testTradeFailsIfDisabled() public {
    ccnft.setCanTrade(false);
    vm.expectRevert("Trading is disabled");
    ccnft.trade(0);
  }

  // Prueba negativa: falla si el comprador es el mismo que el vendedor
  function testTradeFailsIfBuyerIsSeller() public {
    ccnft.setCanTrade(true);
    deal(address(busd), address(this), 100);
    busd.approve(address(ccnft), 100);
    ccnft.setCanBuy(true);
    ccnft.setMaxBatchCount(1);
    ccnft.addValidValues(100);
    ccnft.setMaxValueToRaise(1000);
    ccnft.buy(100, 1);
    ccnft.putOnSale(0, 100);

    vm.expectRevert("Buyer is the Seller");
    ccnft.trade(0);
  }
  
}
