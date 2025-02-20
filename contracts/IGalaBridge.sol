// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IGalaBridge {
    /// @notice Interact with this method to start the bridging out process. The bridge has to be approved to transfer tokens to be bridged.
    /// @param token the address of the token contract, must be non-zero
    /// @param amount the amount of tokens to bridge out, must be 1 for ERC-721
    /// @param tokenId the id of the token to bridge out, disregarded for ERC-20 tokens
    /// @param destinationChainId chain id of the destination (for routing purposes)
    /// @param recipient the recipient on the Play blockchain, formatted in a way understandable by it
    function bridgeOut(
        address token, 
        uint256 amount, 
        uint256 tokenId, 
        uint16 destinationChainId, 
        bytes calldata recipient
    ) external;
}
