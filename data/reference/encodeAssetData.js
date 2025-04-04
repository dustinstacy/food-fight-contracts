import ethers from "ethers";

// Encode asset data for the Foundry contract
// @param {Array} assets - Array of asset objects
function encodeAssetData(assets) {
  // Standard prefix for hex data in Ethereum
  let encodedData = "0x";

  for (const asset of assets) {
    // Convert asset ID to Big Number, then convert to hex string, then pad with zeros, then slice off the 0x prefix
    const assetId = ethers.utils
      .hexZeroPad(ethers.BigNumber.from(asset.id).toHexString(), 32)
      .slice(2);
    // Convert the URI into a byte array
    const uriBytes = ethers.utils.toUtf8Bytes(asset.uri);
    // Convert the number of bytes in the URI to a hex string, pad with zeros, and slice off the 0x prefix
    const uriLength = ethers.utils
      .hexZeroPad(ethers.BigNumber.from(uriBytes.length).toHexString(), 32)
      .slice(2);
    // Convert the URI byte array to a hex string, slice off the 0x prefix
    const uriHex = ethers.utils.hexlify(uriBytes).slice(2);
    // Convert the asset price to a Big Number, then convert to hex string, then pad with zeros, then slice off the 0x prefix
    const price = ethers.utils
      .hexZeroPad(ethers.BigNumber.from(asset.price).toHexString(), 32)
      .slice(2);

    // Concatenate the asset ID, URI length, URI, and price
    encodedData += assetId + uriLength + uriHex + price;
  }

  return encodedData;
}

export default encodeAssetData;
