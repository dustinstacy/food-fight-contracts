.PHONY: dev build deploy generate-abis verify-keystore account chain compile flatten fork format lint test verify

DEPLOY_SCRIPT ?= script/Deploy.s.sol
NODE_PORT ?= 8545
RPC_URL ?= localhost
LOCALHOST_PK=0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6

# Start dev environment
dev: setup-anvil-wallet start-anvil-bg wait-for-node deploy-and-generate-abis

# setup wallet for anvil
setup-anvil-wallet:
	shx rm ~/.foundry/keystores/scaffold-eth-default 2>/dev/null; 	shx rm -rf broadcast/Deploy.s.sol/31337
	cast wallet import --private-key 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6 --unsafe-password 'localhost' scaffold-eth-default

# Start anvil in the background
start-anvil-bg:
	@echo "Starting anvil in the background..."
	anvil &

# Chain delay
wait-for-node:
	@echo "Waiting for node on port $(NODE_PORT)..."
	@while ! nc -z localhost $(NODE_PORT); do sleep 1; done
	@echo "Node ready."

# Start local chain
chain: setup-anvil-wallet
	anvil

# Start a fork
fork: setup-anvil-wallet
	anvil --fork-url ${FORK_URL} --chain-id 31337

# Deploy and generate ABIs
deploy-and-generate-abis: deploy generate-abis 

# Deploy the contracts
deploy: 
	@echo "Running make deploy target (RPC_URL=$(RPC_URL), DEPLOY_SCRIPT=$(DEPLOY_SCRIPT))"
	@if [ ! -f "$(DEPLOY_SCRIPT)" ]; then echo "Error: Deploy script '$(DEPLOY_SCRIPT)' not found"; exit 1; fi

	@if [ "$(RPC_URL)" = "localhost" ]; then \
		echo "Deploying to localhost using default account/password..."; \
		forge script $(DEPLOY_SCRIPT) --rpc-url localhost --password localhost --broadcast --legacy --ffi; \
	else \
 		echo "Deploying to $(RPC_URL)..."; \
    	forge script $(DEPLOY_SCRIPT) --rpc-url $(RPC_URL) --broadcast --legacy --ffi; \
    	echo "Setting asset data for $(RPC_URL)..."; \
		node scripts-js/setAssetData.js; \
	fi



# Generate TypeScript ABIs
generate-abis:
	node scripts-js/generateTsAbis.js

# Verify keystore
verify-keystore:
	if grep -q "scaffold-eth-default" .env; then 		cast wallet address --password localhost; 	else 		cast wallet address; 	fi

# List account
account:
	@node scripts-js/ListAccount.js $$(make verify-keystore)

# Generate a new account
account-generate:
	@cast wallet import $(ACCOUNT_NAME) --private-key $$(cast wallet new | grep 'Private key:' | awk '{print $$3}')
	@echo "Please update .env file with ETH_KEYSTORE_ACCOUNT=$(ACCOUNT_NAME)"

# Import an existing account
account-import:
	@cast wallet import ${ACCOUNT_NAME} --interactive


# Verify contracts
verify:
	forge script script/VerifyAll.s.sol --ffi --rpc-url $(RPC_URL)



