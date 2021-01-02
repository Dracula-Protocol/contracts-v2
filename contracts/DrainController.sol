// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./VampireAdapter.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./libraries/UniswapV2Library.sol";
import "./ChiGasSaver.sol";

interface IMasterVampire {
    function drain(uint256 pid) external;
    function poolInfo(uint256 pid) external view returns (Victim victim,
                                                          uint256 victimPoolId,
                                                          uint256 lastRewardBlock,
                                                          uint256 accDrcPerShare,
                                                          uint256 rewardDrainModifier,
                                                          uint256 wethDrainModifier);
    function poolLength() external view returns (uint256);
}

interface IDrainDistributor {
    function distribute() external;
}

/**
* @title Controls the "drain" of pool rewards
*/
contract DrainController is Ownable, ChiGasSaver {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using VampireAdapter for Victim;

    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Factory constant UNI_FACTORY = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

    IMasterVampire public masterVampire;
    IDrainDistributor public drainDistributor;
    uint256 public wethThreshold;

    mapping(address => bool) internal whitelistedNode;

    constructor(address drainDistributor_) public {
        whitelistedNode[msg.sender] = true;
        drainDistributor = IDrainDistributor(drainDistributor_);
        wethThreshold = 200000000000000000 wei;
    }

    /**
     * @notice Allow depositing ether to the contract
     */
    receive() external payable {}

    /**
     * @notice Calculates estimated gas cost of a function and attempts to refund that amount to caller
     */
    modifier refundGasCost() {
        uint gasStart = gasleft();
        address payable self = address(this);
        if (self.balance == 0) {
            _;
        } else {
            _;
            // Add intrinsic gas and transfer gas.
            uint256 usedGas = 85000 + gasStart - gasleft();
            uint gasCost = usedGas * tx.gasprice;
            // Refund gas cost
            if (self.balance < gasCost) {
                tx.origin.transfer(self.balance);
                return;
            }
            tx.origin.transfer(gasCost);
        }
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
     * @notice Change drain distributor
     */
    function setDrainDistributor(address drainDistributor_) external onlyOwner {
        drainDistributor = IDrainDistributor(drainDistributor_);
    }

    /**
     * @notice Change MasterVampire contract
     */
    function setMasterVampire(address masterVampire_) external onlyOwner {
        masterVampire = IMasterVampire(masterVampire_);
    }

    /**
     * @notice Change the WETH drain threshold
     */
    function setWETHThreshold(uint256 wethThreshold_) external onlyOwner {
        wethThreshold = wethThreshold_;
    }

    /**
     * @notice Determines if drain can be performed
     */
    function isDrainable() public view returns(bool) {
        uint256 poolLength = masterVampire.poolLength();
        for (uint pid = 1; pid < poolLength; pid++) {
            (Victim victim, uint256 victimPoolId,,,,) = masterVampire.poolInfo(pid);
            if (address(victim) != address(0)) {
                uint256 pendingReward = victim.pendingReward(victimPoolId);
                if (pendingReward > 0) {
                    if (_rewardValue(pendingReward, victim.rewardToken()) >= wethThreshold) {
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
    function optimalMassDrain() external onlyWhitelister saveGas(1) refundGasCost {
        uint256 poolLength = masterVampire.poolLength();
        uint32 numDrained;
        for (uint pid = 1; pid < poolLength; ++pid) {
            (Victim victim, uint256 victimPoolId,,,,) = masterVampire.poolInfo(pid);
            if (address(victim) != address(0)) {
                uint256 pendingReward = victim.pendingReward(victimPoolId);
                if (pendingReward > 0) {
                    IERC20 rewardToken = victim.rewardToken();
                    uint256 rewardValue_ = _rewardValue(pendingReward, rewardToken);
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

        if (numDrained > 0) {
            drainDistributor.distribute();
        }
    }

    /**
     * @notice Calculates the WETH value for an amount of specified token
     */
    function _rewardValue(uint256 amount, IERC20 rewardToken) internal view returns(uint256) {
        address token = address(rewardToken);

        IUniswapV2Pair pair = IUniswapV2Pair(UNI_FACTORY.getPair(address(token), address(WETH)));
        if (address(pair) != address(0)) {
             (uint tokenReserve, uint wethReserve,) = pair.getReserves();
             return UniswapV2Library.getAmountOut(amount, tokenReserve, wethReserve);
        }

        require(
            address(pair) != address(0),
            "Neither token-weth nor weth-token pair exists");
        pair = IUniswapV2Pair(UNI_FACTORY.getPair(address(WETH), address(token)));
        (uint wethReserve, uint tokenReserve,) = pair.getReserves();
        return UniswapV2Library.getAmountOut(amount, tokenReserve, wethReserve);
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
