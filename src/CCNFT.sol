// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
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
    require(ownerOf(tokenId) == _msgSender());
    
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
  
//
//    // SETTERS
//
//    // Utilización del token ERC20 para transacciones.
//    function setFundsToken() external onlyOwner { // Parámetro, token: Que va a ser la Dirección del contrato del token ERC20.
//        // La dirección no puede ser la dirección cero (address(0)). Incluir un mensaje de falla.
//        require();
//        fundsToken = IERC20(token); // Contrato ERC20 a variable fundsToken.
//    }
//
//    // Dirección para colectar los fondos de las ventas de NFTs.
//    function setFundsCollector() external onlyOwner { // Parámetro, dirección de colector de fondos.
//        // La dirección no puede ser la dirección cero (address(0))
//        require();
//        fundsCollector = _address; // Dirección proporcionada a la variable fundsCollector.
//    }
//
//    // Dirección para colectar las tarifas de transacción.
//    function setFeesCollector() external onlyOwner { // Parámetro, dirección del colector de tarifas.
//        // La dirección no puede ser la dirección cero (address(0))
//        require();
//        feesCollector = _address; // Dirección proporcionada a la variable feesCollector.
//    }
//
//    // Porcentaje de beneficio a pagar en las reclamaciones.
//    function setProfitToPay() external onlyOwner { // Parámetro, porcentaje de beneficio a pagar.
//        profitToPay = _profitToPay; // Valor proporcionado a la variable profitToPay.
//    }
//
//    // Función que Habilita o deshabilita la compra de NFTs.
//    function setCanBuy() external onlyOwner { // Parámetro, booleano que indica si la compra está permitida.
//        canBuy = _canBuy;  // Valor proporcionado a la variable canBuy.
//    }
//
//    // Función que Habilita o deshabilita la reclamación de NFTs.
//    function setCanClaim() external onlyOwner { // Parámetro, booleano que indica si la reclamacion está permitida.
//        canClaim = _canClaim; // Valor proporcionado a la variable canClaim.
//    }
//
//    // Función que Habilita o deshabilita el intercambio de NFTs.
//    function setCanTrade() external onlyOwner { // Parámetro, booleano que indica si la intercambio está permitido.
//        canTrade = _canTrade; // Valor proporcionado a la variable canTrade.
//    }
//
//    // Valor máximo que se puede recaudar de venta de NFTs.
//    function setMaxValueToRaise() external onlyOwner { // Parámetro, valor máximo a recaudar.
//        maxValueToRaise = _maxValueToRaise; // Valor proporcionado a la variable maxValueToRaise.
//    }
//
//    // Función para agregar un valor válido para NFTs.
//    function addValidValues() external onlyOwner { // Parámetro, valor que se quiere agregar como válido.
//        validValues[value] = true; // Valor como válido en el mapeo validValues.
//    }
//
//    // Función para establecer la cantidad máxima de NFTs por operación.
//    function setMaxBatchCount() external onlyOwner { // Parámetro, cantidad máxima de NFTs por operación.
//        maxBatchCount = _maxBatchCount; // Valor proporcionado a la variable maxBatchCount.
//    }
//
//    // Tarifa aplicada a las compras de NFTs.
//    function setBuyFee() external onlyOwner { // Parámetro, porcentaje de tarifa para compras.
//        buyFee = _buyFee; // Valor proporcionado a la variable buyFee.
//    }
//
//    // Tarifa aplicada a las transacciones de NFTs.
//    function setTradeFee(uint16 _tradeFee) external onlyOwner { // Parámetro, porcentaje de tarifa para transacciones.
//        tradeFee = _tradeFee; // Valor proporcionado a la variable tradeFee.
//    }
//
//    // ARRAYS
//
//    // Verificar duplicados en el array antes de agregar un nuevo valor.
//    function addToArray() private { // Parámetro, array de enteros donde se añadirá el valor y valor que se añadirá al array.
//
//        // Posición del value en el array list usando la función find.
//        uint256 index = find();
//        if () { // Si el valor no está en el array, push al final del array.
//        }
//    }
//
//    // Eliminar un valor del array.
//    function removeFromArray() private { // Parámetros, array de enteros del cual se eliminará el valor y valor que se eliminara al array.
//        // Posición del value en el array list usando la función find.
//        uint256 index = find(list, value);
//        if () { // Si el valor está en el array, reemplazar el valor con el último valor en el array y despues reducir el tamaño del array.
//        }
//    }
//
//    // Buscar un valor en un array y retornar su índice o la longitud del array si no se encuentra.
//    function find() private pure returns (uint)  { // Parámetros, array de enteros en el cual se buscará el valor y valor que se buscará en el array..
//
//        for () { // Retornar la posición del valor en el array.
//            if () {
//            }
//        }
//        return; // Si no se encuentra, retornar la longitud del array.
//    }
//
//    // NOT SUPPORTED FUNCTIONS
//
//    // Funciones para deshabilitar las transferencias de NFTs,
//
//    function transferFrom(address, address, uint256) public pure override(ERC721, IERC721) {
//        revert("Not Allowed");
//    }
//
//    function safeTransferFrom(address, address, uint256) public pure override(ERC721, IERC721)
//    {
//        revert("Not Allowed");
//    }
//
//    function safeTransferFrom(address, address, uint256, bytes memory) public pure override(ERC721, IERC721) {
//        revert("Not Allowed");
//    }
//
//    // Compliance required by Solidity
//
//    // Funciones para asegurar que el contrato cumple con los estándares requeridos por ERC721 y ERC721Enumerable.
//
//    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
//    internal
//    override(ERC721Enumerable)
//    {
//        super._beforeTokenTransfer(from, to, tokenId);
//    }

}