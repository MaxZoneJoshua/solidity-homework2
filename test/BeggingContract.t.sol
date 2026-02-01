// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../src/BeggingContract.sol";

contract Donor {
    function donate(BeggingContract target) external payable {
        target.donate{value: msg.value}();
    }
}

contract NonOwnerCaller {
    function attemptWithdraw(BeggingContract target) external {
        target.withdraw();
    }
}

contract OwnerHarness {
    BeggingContract public target;

    constructor() {
        target = new BeggingContract();
    }

    function donateToTarget() external payable {
        target.donate{value: msg.value}();
    }

    function withdrawFromTarget() external {
        target.withdraw();
    }

    receive() external payable {}
}

contract BeggingContractTest {
    BeggingContract private begging;

    function setUp() public {
        begging = new BeggingContract();
    }

    function testDonateRecordsAmount() public {
        uint256 amount = 1 ether;
        begging.donate{value: amount}();

        require(begging.getDonation(address(this)) == amount, "donation not recorded");
        require(begging.donorsCount() == 1, "donor count should be 1");
    }

    function testReceiveRecordsAmount() public {
        uint256 amount = 0.5 ether;
        (bool ok, ) = address(begging).call{value: amount}("");
        require(ok, "direct send failed");

        require(begging.getDonation(address(this)) == amount, "receive not recorded");
    }

    function testUniqueDonorList() public {
        begging.donate{value: 0.2 ether}();
        begging.donate{value: 0.3 ether}();

        require(begging.donorsCount() == 1, "duplicate donor added");
    }

    function testWithdrawOnlyOwner() public {
        NonOwnerCaller nonOwner = new NonOwnerCaller();

        bool reverted;
        try nonOwner.attemptWithdraw(begging) {
            reverted = false;
        } catch {
            reverted = true;
        }

        require(reverted, "non-owner was able to withdraw");
    }

    function testWithdrawTransfersAllFunds() public {
        OwnerHarness harness = new OwnerHarness();
        BeggingContract target = harness.target();

        uint256 amount = 2 ether;
        harness.donateToTarget{value: amount}();

        uint256 beforeBalance = address(harness).balance;
        harness.withdrawFromTarget();
        uint256 afterBalance = address(harness).balance;

        require(address(target).balance == 0, "contract balance not zero");
        require(afterBalance - beforeBalance == amount, "owner did not receive funds");
    }

    function testTimeLimitAllowsWithinWindow() public {
        uint256 nowTs = block.timestamp;
        begging.setTimeLimit(true, nowTs - 1, nowTs + 1);

        begging.donate{value: 1 ether}();
    }

    function testTimeLimitBlocksOutsideWindow() public {
        uint256 nowTs = block.timestamp;
        begging.setTimeLimit(true, nowTs + 10, nowTs + 20);

        bool reverted;
        try begging.donate{value: 1 ether}() {
            reverted = false;
        } catch {
            reverted = true;
        }

        require(reverted, "donation should be blocked");
    }

    function testTopDonors() public {
        Donor donorA = new Donor();
        Donor donorB = new Donor();
        Donor donorC = new Donor();
        Donor donorD = new Donor();

        donorA.donate{value: 1 ether}(begging);
        donorB.donate{value: 3 ether}(begging);
        donorC.donate{value: 2 ether}(begging);
        donorD.donate{value: 0.5 ether}(begging);

        (address[3] memory addrs, uint256[3] memory amounts) = begging.topDonors();

        require(addrs[0] == address(donorB) && amounts[0] == 3 ether, "top #1 incorrect");
        require(addrs[1] == address(donorC) && amounts[1] == 2 ether, "top #2 incorrect");
        require(addrs[2] == address(donorA) && amounts[2] == 1 ether, "top #3 incorrect");
    }
}
