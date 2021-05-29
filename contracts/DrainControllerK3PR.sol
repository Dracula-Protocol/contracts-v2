// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./VampireAdapter.sol";
import "./interfaces/IChiToken.sol";
import "./interfaces/KeeperCompatibleInterface.sol";

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
    function pendingVictimReward(uint256 pid) external view returns (uint256);
}

/**
* @title Controls the "drain" of pool rewards
*
*/
contract DrainControllerK3PR is Ownable, KeeperCompatibleInterface {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using VampireAdapter for Victim;

    IMasterVampire public masterVampire;
    uint256 public wethThreshold = 200000000000000000 wei;
    address public registryContractAddress;

    constructor(address _registryContractAddress) {
        registryContractAddress = _registryContractAddress;
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



    function checkUpkeep(bytes calldata checkData) external override returns (bool upkeepNeeded, bytes memory performData) {

    }

    function performUpkeep(bytes calldata performData) external override {
        require(msg.sender == registryContractAddress);

    }



    /**
     * @notice Determines if drain can be performed
     */
    function isDrainable() external view returns(int32[] memory) {
        uint256 poolLength = masterVampire.poolLength();
        int32[] memory drainablePools = new int32[](poolLength);
        for (uint pid = 0; pid < poolLength; pid++) {
            drainablePools[pid] = -1;
            (Victim victim, uint256 victimPoolId,,,,,) = masterVampire.poolInfo(pid);
            if (address(victim) != address(0)) {
                uint256 pendingReward = masterVampire.pendingVictimReward(pid);
                if (pendingReward > 0) {
                    if (victim.rewardValue(victimPoolId, pendingReward) >= wethThreshold) {
                        drainablePools[pid] = int32(pid);
                    }
                }
            }
        }
        return drainablePools;
    }

    /**
     * @notice Determines which pools can be drained based on value of rewards available
     */
    function drainPools(uint256[] memory pids) external returns(uint32) {
        uint256 poolLength = pids.length;
        uint32 numDrained;
        for (uint i = 0; i < poolLength; ++i) {
            uint pid = pids[i];
            (Victim victim, uint256 victimPoolId,,,,,) = masterVampire.poolInfo(pid);
            if (address(victim) != address(0)) {
                uint256 pendingReward = victim.pendingReward(pid, victimPoolId);
                if (pendingReward > 0) {
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
}
