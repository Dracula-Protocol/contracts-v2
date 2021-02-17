// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./VampireAdapter.sol";
import "./interfaces/IChiToken.sol";

interface IMasterVampire {
    function drain(uint256 pid) external;
    function poolInfo(uint256 pid) external view returns (Victim victim,
                                                          uint256 victimPoolId,
                                                          uint256 lastRewardBlock,
                                                          uint256 accWethPerShare,
                                                          uint256 wethAccumulator,
                                                          uint256 basePoolShares,
                                                          uint256 baseDeposits);
    function poolLength() external view returns (uint256);
    function pendingVictimReward(uint256 pid) external returns (uint256);
}

/**
* @title Controls the "drain" of pool rewards
*
* optimalMassDrain should be called by a whitelisted node.
* This function calls drain() for each pool in MasterVampire if the reward
* WETH value is greater then the configured threshold.
*
* This contract has "gas treasury" which is funded in ETH by DrainDistributor.
* ETH is refunded to the node to pay for a portion of the gas fee.
* Chi Tokens can be used for any remaining gas discounts if caller holds the tokens.
*
* If the contract needs to be replaced the deployer can destruct the contract and get
* a gas refund, as well as collect any remaining ETH to be deployed to the new contract.
*/
contract DrainController is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using VampireAdapter for Victim;

    IMasterVampire public masterVampire;
    uint256 public wethThreshold = 200000000000000000 wei;
    uint256 public maxGasPrice = 60; // This is the maximum gas price in Gwei that this contract will refund

    mapping(address => bool) internal whitelistedNode;

    constructor() public {
        whitelistedNode[msg.sender] = true;
    }

    /**
     * @notice Allow depositing ether to the contract
     */
    receive() external payable {}

    /**
     * @notice Calculates estimated gas cost of a function and attempts to refund that amount to caller
     */
    modifier refundGasCost() {
        uint256 gasStart = gasleft();
        uint256 ethBalance = address(this).balance;
        uint256 weiGasPriceMax = maxGasPrice.mul(10**9); // The maximum gas price in Wei units
        uint256 weiGasPrice = tx.gasprice; // The gas price for the current transaction
        if (maxGasPrice > 0 && weiGasPrice > weiGasPriceMax){
            // User should not spend more than the gas price max
            weiGasPrice = weiGasPriceMax;
        }
        _;
        uint256 usedGas = 85000 + gasStart - gasleft();
        uint gasCost = usedGas * weiGasPrice;
        // Refund total gas cost if contract has enough funds
        if (ethBalance >= gasCost) {
            msg.sender.transfer(gasCost);
            return;
        }

        // Otherwise send what we can and try use chi to save some gas
        msg.sender.transfer(ethBalance);
        uint256 remainingGasSpent = (gasCost - ethBalance) / weiGasPrice;
        IChiToken chi = IChiToken(0x0000000000004946c0e9F43F4Dee607b0eF1fA1c);
        chi.freeFromUpTo(msg.sender, (remainingGasSpent + 14154) / 41947);
    }

    /**
     * @dev Throws if called by any account other than the whitelister
     */
    modifier onlyWhitelister() {
        require(
            whitelistedNode[msg.sender],
            "account is not whitelisted"
        );
        _;
    }

    /**
     * @dev Adds account to whitelist
     * @param account_ The address to whitelist
     */
    function whitelist(address account_) external onlyOwner {
        whitelistedNode[account_] = true;
    }

    /**
     * @dev Removes account from whitelist
     * @param account_ The address to remove from the whitelist
     */
    function unWhitelist(address account_) external onlyOwner {
        whitelistedNode[account_] = false;
    }

    /**
     * @notice Change MasterVampire contract
     */
    function setMasterVampire(address masterVampire_) external onlyOwner {
        require(masterVampire_ != address(0));
        masterVampire = IMasterVampire(masterVampire_);
    }

    /**
     * @notice Change the WETH drain threshold
     */
    function setWETHThreshold(uint256 wethThreshold_) external onlyOwner {
        wethThreshold = wethThreshold_;
    }

    /**
     * @notice Change the maximum gas price in Gwei for refunds
     */
    function setMaxGasPrice(uint256 maxGasPrice_) external onlyOwner {
        maxGasPrice = maxGasPrice_;
    }

    /**
     * @notice Determines if drain can be performed
     */
    function isDrainable() public returns(bool) {
        uint256 poolLength = masterVampire.poolLength();
        for (uint pid = 0; pid < poolLength; pid++) {
            (Victim victim, uint256 victimPoolId,,,,,) = masterVampire.poolInfo(pid);
            if (address(victim) != address(0)) {
                uint256 pendingReward = masterVampire.pendingVictimReward(pid);
                if (pendingReward > 0) {
                    if (victim.rewardValue(victimPoolId, pendingReward) >= wethThreshold) {
                       return true;
                    }
                }
            }
        }
        return false;
    }

    /**
     * @notice Determines which pools can be drained based on value of rewards available
     */
    function optimalMassDrain() external onlyWhitelister refundGasCost returns(uint32) {
        uint256 poolLength = masterVampire.poolLength();
        uint32 numDrained;
        for (uint pid = 0; pid < poolLength; ++pid) {
            (Victim victim, uint256 victimPoolId,,,,,) = masterVampire.poolInfo(pid);
            if (address(victim) != address(0)) {
                uint256 pendingReward = victim.pendingReward(pid, victimPoolId);
                if (pendingReward > 0) {
                    //IERC20 rewardToken = victim.rewardToken(victimPoolId);
                    uint256 rewardValue_ = victim.rewardValue(victimPoolId, pendingReward);
                    if (rewardValue_ >= wethThreshold) {
                        try masterVampire.drain(pid) {
                            // success
                            ++numDrained;
                        } catch {
                            // ignore failed drain
                        }
                    }
                }
            }
        }

        return numDrained;
    }

    /**
     * @notice Provides a way to remove ETH balance from contract
     * @param to Address to send ETH balance
     */
    function withdrawETH(address payable to) external onlyOwner {
        to.transfer(address(this).balance);
    }

    /**
     * @notice Destruct contract to get a refund and also move any left over ETH to specified address
     * @param to Address to send any remaining ETH to before contract is destroyed
     */
    function kill(address payable to) external onlyOwner {
        to.transfer(address(this).balance);
        selfdestruct(msg.sender);
    }
}
