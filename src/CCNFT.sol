// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {ERC721Enumerable} from "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Counters} from "../lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import {Strings} from "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";


contract CCNFT is ERC721Enumerable, Ownable, ReentrancyGuard {
  
  // EVENTOS
  // indexed: Permiten realizar búsquedas en los registros de eventos.
  
  // Compra NFTs
  // buyer: La dirección del comprador.
  // tokenId: El ID único del NFT comprado.
  // value: El valor asociado al NFT comprado.
  event Buy(address indexed buyer, uint256 indexed tokenId, uint256 value);
  
  // Reclamo NFTs.
  // claimer: La dirección del usuario que reclama los NFTs.
  // tokenId: El ID único del NFT reclamado.
  event Claim(address indexed claimer, uint256 indexed tokenId);
  
  // Transferencia de NFT de un usuario a otro.
  // buyer: La dirección del comprador del NFT.
  // seller: La dirección del vendedor del NFT.
  // tokenId: El ID único del NFT que se transfiere.
  // value: El valor pagado por el comprador al vendedor por el NFT (No indexed).
  event Trade(address indexed buyer, address indexed seller, uint256 indexed tokenId, uint256 value);
  
  // Venta de un NFT.
  // tokenId: El ID único del NFT que se pone en venta.
  // price: El precio al cual se pone en venta el NFT (No indexed).
  event PutOnSale(uint256 indexed tokenId, uint256 price);
  
  // Estructura del estado de venta de un NFT.
  struct TokenSale {
    // Indicamos si el NFT está en venta.
    bool onSale;
    // Indicamos el precio del NFT si está en venta.
    uint256 price;
  }
  
  // Biblioteca Counters de OpenZeppelin para manejar contadores de manera segura.
  using Counters for Counters.Counter;
  
  // Contador para asignar IDs únicos a cada NFT que se crea.
  Counters.Counter private tokenIdTracker;
  
  // Mapeo del ID de un token (NFT) a un valor específico.
  mapping(uint256 => uint256) public values;
  
  // Mapeo de un valor a un booleano para indicar si el valor es válido o no.
  mapping(uint256 => bool) public validValues;
  
  // Mapeo del ID de un token (NFT) a su estado de venta (TokenSale).
  mapping(uint256 => TokenSale) public tokensOnSale;
  
  // Lista que contiene los IDs de los NFTs que están actualmente en venta.
  uint256[] public listTokensOnSale;
  
  // Dirección de los fondos de las ventas de los NFTs
  address public fundsCollector;
  // Dirección de las tarifas de transacción (compra y venta de los NFTs)
  address public feesCollector;
  // Booleano que indica si las compras de NFTs están permitidas.
  bool public canBuy;
  // Booleano que indica si la reclamación (quitar) de NFTs está permitida.
  bool public canClaim;
  // Booleano que indica si la transferencia de NFTs está permitida.
  bool public canTrade;
  // Valor total acumulado de todos los NFTs en circulación.
  uint256 public totalValue;
  // Valor máximo permitido para recaudar a través de compras de NFTs.
  uint256 public maxValueToRaise;
  // Tarifa aplicada a las compras de NFTs.
  uint16 public buyFee;
  // Tarifa aplicada a las transferencias de NFTs.
  uint16 public tradeFee;
  // Límite en la cantidad de NFTs por operación (evitar exceder el límite de gas en una transacción).
  uint16 public maxBatchCount;
  // Porcentaje adicional a pagar en las reclamaciones.
  uint32 public profitToPay;
  
  // Referencia al contrato ERC20 manejador de fondos.
  IERC20 public fundsToken;
  
  // Constructor (nombre y símbolo del NFT).
  constructor() ERC721("CC", "CCNFT") {}
  
  // PUBLIC FUNCTIONS
  
  // Funcion de compra de NFTs.
  // Parametro value: El valor de cada NFT que se está comprando.
  // Parametro amount: La cantidad de NFTs que se quieren comprar.
  function buy(uint256 value, uint256 amount) external nonReentrant {
    // Verificación de permisos de la compra con "canBuy". Incluir un mensaje de falla.
    require(canBuy, "Buying is disabled");
    // Verificacón de la cantidad de NFTs a comprar sea mayor que 0 y menor o igual al máximo permitido (maxBatchCount). Incluir un mensaje de falla.
    require(amount > 0 && amount <= maxBatchCount, string.concat("Invalid amount, it needs to be greater than 0 and less than ", Strings.toString(maxBatchCount)));
    // Verificación del valor especificado para los NFTs según los valores permitidos en validValues. Incluir un mensaje de falla.
    require(validValues[value], "Invalid value, not in valid values");
    // Verificación del valor total después de la compra (no debe exeder el valor máximo permitido "maxValueToRaise"). Incluir un mensaje de falla.
    require(totalValue + value * amount <= maxValueToRaise, "Max value exceeded");
    // Incremento del valor total acumulado por el valor de los NFTs comprados.
    totalValue += value * amount;
    
    for (uint256 i = 0; i < amount; i++) {
      uint256 newTokenId = tokenIdTracker.current();
      values[newTokenId] = value;
      _safeMint(_msgSender(), newTokenId);
      emit Buy(_msgSender(), newTokenId, value);
      tokenIdTracker.increment();
    }
    
    // Transfencia de fondos desde el comprador (_msgSender()) al recolector de fondos (fundsCollector) por el valor total de los NFTs comprados.
    require(fundsToken.transferFrom(_msgSender(), fundsCollector, value * amount), "Cannot send funds tokens");
    
    // Transferencia de tarifas de compra desde el comprador (_msgSender()) al recolector de tarifas (feesCollector).
    // Tarifa = fracción del valor total de la compra (value * amount * buyFee / 10000).
    uint256 feeAmount = (value * amount * buyFee) / 10000;
    if (feeAmount > 0) {
      require(fundsToken.transferFrom(_msgSender(), feesCollector, feeAmount), "Cannot send fees tokens");
    }
  }
  
  // Funcion de "reclamo" de NFTs
  // Parámetros: Lista de IDs de tokens de reclamo (utilizar calldata).
  function claim(uint256[] calldata listTokenId) external nonReentrant {
    // Verificacón habilitación de "reclamo" (canClaim). Incluir un mensaje de falla.
    require(canClaim, "Claiming is disabled");
    // Verificación de la cantidad de tokens a reclamar (mayor que 0 y menor o igual a maxBatchCount). Incluir un mensaje de falla.
    require(listTokenId.length > 0 && listTokenId.length <= maxBatchCount, "Invalid amount of tokens to claim");
    
    // Inicializacion de claimValue a 0.
    uint256 claimValue = 0;
    // Variable tokenSale.
    TokenSale storage tokenSale;
    
    // Bucle para iterar a través de cada token ID en listTokenId.
    for (uint256 i = 0; i < listTokenId.length; i++) {
      // Verificación listTokenId[i] exista. Incluir un mensaje de falla.
      uint256 tokenId = listTokenId[i];
      require(_exists(tokenId), "Token does not exist");
      // Verificamos que el llamador de la función (_msgSender()) sea el propietario del token. Si no es así, la transacción falla con el mensaje "Only owner can Claim".
      require(ownerOf(tokenId) == _msgSender(), "Only owner can Claim");
      // Suma de el valor del token al claimValue acumulado.
      claimValue += values[tokenId];
      // Reseteo del valor del token a 0.
      values[tokenId] = 0;
      
      // Acceso a la información de venta del token
      tokenSale = tokensOnSale[tokenId];
      // Desactivacion del estado de venta.
      tokenSale.onSale = false;
      // Desactivacion del estado de venta.
      tokenSale.price = 0;
      
      // Remover el token de la lista de tokens en venta.
      removeFromArray(listTokensOnSale, tokenId);
      // Quemar el token, eliminándolo permanentemente de la circulación.
      _burn(tokenId);
      // Registrar el ID y propietario del token reclamado.
      emit Claim(_msgSender(), tokenId);
    }
    
    totalValue -= claimValue;
    
    // Calculo del monto total a transferir (claimValue + (claimValue * profitToPay / 10000)).
    // Transferir los fondos desde fundsCollector al (_msgSender()).
    uint256 totalPayout = claimValue + ((claimValue * profitToPay) / 10000);
    require(fundsToken.transferFrom(fundsCollector, _msgSender(), totalPayout), "cannot send funds");
  }
  
  // Eliminar un valor del array.
  function removeFromArray(uint256[] storage list, uint256 value) private {
    uint256 index = find(list, value);
    if (index < list.length) {
      list[index] = list[list.length - 1];
      list.pop();
    }
  }
  
  // Buscar un valor en un array y retornar su índice o la longitud del array si no se encuentra.
  function find(uint256[] storage list, uint256 value) private view returns (uint256) {
    for (uint256 i = 0; i < list.length; i++) {
      if (list[i] == value) {
        return i;
      }
    }
    return list.length;
  }
  
  // Funcion de compra de NFT que esta en venta.
  function trade(uint256 tokenId) external nonReentrant { // Parámetro: ID del token.
    // Verificación del comercio de NFTs (canTrade). Incluir un mensaje de falla.
    require(canTrade, "Trading is disabled");
    // Verificación de existencia del tokenId (_exists). Incluir un mensaje de falla.
    require(_exists(tokenId), "Token does not exist");
    // Verificamos que el comprador (el que llama a la función) no sea el propietario actual del NFT. Si lo es,
    // la transacción falla con el mensaje "Buyer is the Seller".
    address seller = ownerOf(tokenId);
    require(seller != _msgSender(), "Buyer is the Seller");
    
    // Estado de venta del NFT.
    TokenSale storage tokenSale = tokensOnSale[tokenId];
    // Verifica que el NFT esté actualmente en venta (onSale es true). Si no lo está,
    // la transacción falla con el mensaje "Token not On Sale".
    require(tokenSale.onSale, "Token not On Sale");
    
    uint256 price = tokenSale.price;
    
    // Transferencia del precio de venta del comprador al propietario actual del NFT usando fundsToken.
    require(fundsToken.transferFrom(_msgSender(), seller, price), "Cannot send funds to seller");
    // Transferencia de tarifa de comercio (calculada como un porcentaje del valor del NFT) del comprador al feesCollector.
    uint256 feeAmount = (price * tradeFee) / 10000;
    if (feeAmount > 0) {
      require(fundsToken.transferFrom(_msgSender(), feesCollector, feeAmount), "Cannot send fees tokens");
    }
    
    // Registro de dirección del comprador, dirección del vendedor, tokenId, y precio de venta.
    emit Trade(_msgSender(), seller, tokenId, price);
    
    // Transferencia del NFT del propietario actual al comprador.
    _safeTransfer(seller, _msgSender(), tokenId, "");
    
    // NFT no disponible para la venta.
    tokenSale.onSale = false;
    // Reseteo del precio de venta del NFT.
    tokenSale.price = 0;
    // Remover el tokenId de la lista listTokensOnSale de NFTs.
    removeFromArray(listTokensOnSale, tokenId);
  }
  
  // Función para poner en venta un NFT.
  function putOnSale(uint256 tokenId, uint256 price) external { // Parámetros: ID y precio del token.
    // Verificación de operaciones de comercio (canTrade). Incluir un mensaje de falla.
    require(canTrade, "Trading is disabled");
    // Verificción de existencia del tokenId mediante "_exists". Incluir un mensaje de falla.
    require(_exists(tokenId), "Token does not exist");
    // Verificación remitente de la transacción es propietario del token. Incluir un mensaje de falla.
    require(ownerOf(tokenId) == _msgSender(), "Only owner can put on sale");
    
    // Variable de almacenamiento de datos para el token.
    TokenSale storage tokenSale = tokensOnSale[tokenId];
    // Indicar que el token está en venta.
    tokenSale.onSale = true;
    // Indicar precio de venta del token.
    tokenSale.price = price;
    
    // Añadir token a la lista.
    addToArray(listTokensOnSale, tokenId);
    
    // Notificar que el token ha sido puesto a la venta (token y precio).
    emit PutOnSale(tokenId, price);
  }
  
  // Verificar duplicados en el array antes de agregar un nuevo valor.
  function addToArray(uint256[] storage list, uint256 value) private {
    uint256 index = find(list, value);
    if (index == list.length) {
      list.push(value);
    }
  }
  
  // SETTERS
  
  // Utilización del token ERC20 para transacciones.
  function setFundsToken(address token) external onlyOwner {
    require(token != address(0), "Invalid token address");
    fundsToken = IERC20(token);
  }
  
  // Dirección para colectar los fondos de las ventas de NFTs.
  function setFundsCollector(address _address) external onlyOwner {
    require(_address != address(0), "Invalid fund collector address");
    fundsCollector = _address;
  }
  
  // Dirección para colectar las tarifas de transacción.
  function setFeesCollector(address _address) external onlyOwner {
    require(_address != address(0), "Invalid fees collector address");
    feesCollector = _address;
  }
  
  // Porcentaje de beneficio a pagar en las reclamaciones.
  function setProfitToPay(uint32 _profitToPay) external onlyOwner {
    profitToPay = _profitToPay;
  }
  
  // Función que Habilita o deshabilita la compra de NFTs.
  function setCanBuy(bool _canBuy) external onlyOwner {
    canBuy = _canBuy;
  }
  
  // Función que Habilita o deshabilita la reclamación de NFTs.
  function setCanClaim(bool _canClaim) external onlyOwner {
    canClaim = _canClaim;
  }
  
  // Función que Habilita o deshabilita el intercambio de NFTs.
  function setCanTrade(bool _canTrade) external onlyOwner {
    canTrade = _canTrade;
  }
  
  // Valor máximo que se puede recaudar de venta de NFTs.
  function setMaxValueToRaise(uint256 _maxValueToRaise) external onlyOwner {
    maxValueToRaise = _maxValueToRaise;
  }
  
  // Función para agregar un valor válido para NFTs.
  function addValidValues(uint256 value) external onlyOwner {
    validValues[value] = true;
  }
  
  // Función para establecer la cantidad máxima de NFTs por operación.
  function setMaxBatchCount(uint16 _maxBatchCount) external onlyOwner {
    maxBatchCount = _maxBatchCount;
  }
  
  // Tarifa aplicada a las compras de NFTs.
  function setBuyFee(uint16 _buyFee) external onlyOwner {
    buyFee = _buyFee;
  }
  
  // Tarifa aplicada a las transacciones de NFTs.
  function setTradeFee(uint16 _tradeFee) external onlyOwner {
    tradeFee = _tradeFee;
  }
  
  // NOT SUPPORTED FUNCTIONS
  // Funciones para deshabilitar las transferencias de NFTs,
  function transferFrom(address, address, uint256) public pure override(ERC721, IERC721) {
    revert("Not Allowed");
  }
  
  function safeTransferFrom(address, address, uint256) public pure override(ERC721, IERC721)
  {
    revert("Not Allowed");
  }
  
  function safeTransferFrom(address, address, uint256, bytes memory) public pure override(ERC721, IERC721) {
    revert("Not Allowed");
  }
  
  // Compliance required by Solidity
  // Funciones para asegurar que el contrato cumple con los estándares requeridos por ERC721 y ERC721Enumerable.
  function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }
  
}