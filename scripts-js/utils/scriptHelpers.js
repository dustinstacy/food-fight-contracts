import fs from "fs";
import path from "path";
import toml from "toml";
import { ethers } from "ethers";
import { fileURLToPath } from "url";

/**
 * @notice Get the Asset Factory contract address from the deployment.
 * @param {string} filePath Path to the deployment data JSON.
 * @returns {Promise<string|null>} The Contract contract address.
 */
export async function getContractAddress(filePath, contractName) {
  // Read the deployment data JSON file
  const deploymentData = JSON.parse(fs.readFileSync(filePath, "utf8"));
  // Iterate through the transactions in the deployment data
  for (const transaction of deploymentData.transactions) {
    if (transaction.contractName === contractName) {
      return transaction.contractAddress;
    }
  }
  // Return null if the contract address is not found
  return null;
}

/**
 * @notice Get the chain ID from the deployment data file path.
 * @param {string} filePath Path to the deployment data JSON file.
 * @returns {number} The chain ID.
 */
export function getChainId(filePath) {
  return parseInt(path.basename(path.dirname(filePath)));
}

/**
 * @notice Get a network name from a chain ID.
 * @param {number} chainId The chain ID.
 * @returns {string} The network name.
 * @dev Update this function to add support for additional networks.
 */
export function getNetworkName(chainId) {
  // Map the chain ID to the network name using a switch statement
  switch (chainId) {
    case 1:
      return "mainnet";
    case 11155111:
      return "sepolia";
    case 31337:
      return "localhost";
    default:
      return "default_network";
  }
}

/**
 * @notice Get the RPC URL for a given network name.
 * @param {string} networkName The network name.
 * @returns {string} The RPC URL.
 */
export function getRpcUrl(networkName) {
  // Read the foundry.toml file
  const tomlData = fs.readFileSync("foundry.toml", "utf8");
  // Parse the TOML data
  const config = toml.parse(tomlData);

  return config.rpc_endpoints[networkName];
}

/**
 * @notice Get the signer for the deployment.
 * @param {string} rpcUrl The RPC URL.
 * @returns {ethers.Wallet} The ethers.Wallet signer.
 * @dev Update to keystore or other secure method for production.
 */
export function getSigner(rpcUrl) {
  const privateKey = process.env.DEPLOYER_PRIVATE_KEY;
  // Check if the private key is set
  if (!privateKey) {
    throw new Error("DEPLOYER_PRIVATE_KEY not set.");
  }
  // Create a provider from the RPC URL
  const provider = new ethers.providers.JsonRpcProvider(rpcUrl);
  // Create and return a signer from the private key and provider
  return new ethers.Wallet(privateKey, provider);
}

/**
 * @notice Create a contract instance for a contract address and signer.
 * @param {string} contractAddress The contract address.
 * @param {ethers.Wallet} signer The ethers.Wallet signer.
 * @param {string} contractName The name of the contract.
 * @returns {ethers.Contract} The ethers.Contract instance.
 */
export function getContract(contractAddress, signer, contractName) {
  // Get the current file's filename and directory
  const __filename = fileURLToPath(import.meta.url);
  const __dirname = path.dirname(__filename);
  // Construct the path to the ABI JSON file
  const abiPath = path.join(__dirname, `../../out/${contractName}.sol/${contractName}.json`);
  // Read the ABI JSON file
  const abiData = fs.readFileSync(abiPath, "utf8");
  // Parse the ABI JSON data
  const contractABI = JSON.parse(abiData);
  // Create and return an ethers.Contract instance
  return new ethers.Contract(contractAddress, contractABI.abi, signer);
}
