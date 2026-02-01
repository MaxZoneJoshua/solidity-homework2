// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract BeggingContract {
    address public owner;

    // 记录地址的累计捐赠金额
    mapping(address => uint256) public donations;

    // 记录所有捐赠者地址（不重复）
    address[] private donors;
    mapping(address => bool) private isDonor;

    // 时间限制
    bool public timeLimitEnabled;
    uint256 public donateStart;
    uint256 public donateEnd;

    event Donation(address indexed donor, uint256 amount);
    event Withdrawal(address indexed owner, uint256 amount);
    event TimeLimitUpdated(bool enabled, uint256 start, uint256 end);

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function donate() external payable {
        _checkTimeLimit();
        _recordDonation(msg.sender, msg.value);
    }

    function getDonation(address donor) external view returns (uint256) {
        return donations[donor];
    }

    function withdraw() external onlyOwner {
        uint256 amount = address(this).balance;
        require(amount > 0, "no funds");
        payable(owner).transfer(amount);
        emit Withdrawal(owner, amount);
    }

    function setTimeLimit(bool enabled, uint256 start, uint256 end) external onlyOwner {
        if (enabled) {
            require(start <= end, "invalid window");
        }
        timeLimitEnabled = enabled;
        donateStart = start;
        donateEnd = end;
        emit TimeLimitUpdated(enabled, start, end);
    }

    function donorsCount() external view returns (uint256) {
        return donors.length;
    }

    function topDonors()
        external
        view
        returns (address[3] memory topAddresses, uint256[3] memory topAmounts)
    {
        for (uint256 i = 0; i < donors.length; i++) {
            address donor = donors[i];
            uint256 amount = donations[donor];

            if (amount > topAmounts[0]) {
                topAmounts[2] = topAmounts[1];
                topAddresses[2] = topAddresses[1];
                topAmounts[1] = topAmounts[0];
                topAddresses[1] = topAddresses[0];
                topAmounts[0] = amount;
                topAddresses[0] = donor;
            } else if (amount > topAmounts[1]) {
                topAmounts[2] = topAmounts[1];
                topAddresses[2] = topAddresses[1];
                topAmounts[1] = amount;
                topAddresses[1] = donor;
            } else if (amount > topAmounts[2]) {
                topAmounts[2] = amount;
                topAddresses[2] = donor;
            }
        }
    }

    receive() external payable {
        _checkTimeLimit();
        _recordDonation(msg.sender, msg.value);
    }

    function _recordDonation(address donor, uint256 amount) internal {
        require(amount > 0, "zero amount");

        if (!isDonor[donor]) {
            isDonor[donor] = true;
            donors.push(donor);
        }

        donations[donor] += amount;
        emit Donation(donor, amount);
    }

    function _checkTimeLimit() internal view {
        if (timeLimitEnabled) {
            require(block.timestamp >= donateStart && block.timestamp <= donateEnd, "donation closed");
        }
    }
}
