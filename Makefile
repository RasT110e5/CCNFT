-include .env

FORGE_DEPLOY_ARGS := --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify -vvvv --etherscan-api-key $(ETHERSCAN_API_KEY)

deployERC20AndVerify:
	@echo "Deploying ERC20 contract and verifying..."
	@forge script script/DeployBUSD.sol $(FORGE_DEPLOY_ARGS)

deployERC721AndVerify:
	@echo "Deploying ERC721 contract and verifying..."
	@forge script script/DeployCCNFT.sol $(FORGE_DEPLOY_ARGS)

print-args:
	@echo "RPC_URL  = '$(RPC_URL)'"
	@echo "PRIVATE_KEY = '$(PRIVATE_KEY)'"