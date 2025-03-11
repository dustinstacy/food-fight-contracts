// setAssetData.js
import assetData from "../data/assetData.js"
import {
    getContractAddress,
    getChainId,
    getNetworkName,
    getRpcUrl,
    getSigner,
    getContract,
} from "./utils/scriptHelpers.js"

/**
 * @dev Update this to match the chain ID of the deployment.
 */
const DEPLOYMENT_CHAIN_ID = 31337

/**
 * @notice Set the asset data for the Asset Factory contract.
 */
async function main() {
    try {
        const filePath = `broadcast/Deploy.s.sol/${DEPLOYMENT_CHAIN_ID}/run-latest.json`

        const assetFactoryAddress = await getContractAddress(filePath, "AssetFactory")
        if (!assetFactoryAddress) {
            console.error("AssetFactory contract address not found.")
            process.exit(1)
        }

        const chainId = getChainId(filePath)
        const networkName = getNetworkName(chainId)
        const rpcUrl = getRpcUrl(networkName)

        if (!rpcUrl) {
            console.error(`RPC URL not found for network: ${networkName}`)
            process.exit(1)
        }

        const signer = getSigner(rpcUrl)
        const assetFactory = getContract(assetFactoryAddress, signer, "AssetFactory")

        for (const asset of assetData) {
            const tx = await assetFactory.setAssetData(asset.id, asset.uri, asset.price)
            await tx.wait()
            console.log(`Set data for asset ${asset.id}`)
        }

        console.log("Asset data set successfully!")
        process.exit(0)
    } catch (error) {
        console.error(error)
        process.exit(1)
    }
}

main()
