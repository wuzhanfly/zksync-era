// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract StressTest {
    uint256 public counter;
    mapping(address => uint256) public balances;
    
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event CounterIncremented(uint256 newValue);
    
    function increment() public {
        counter++;
        emit CounterIncremented(counter);
    }
    
    function batchIncrement(uint256 times) public {
        for (uint256 i = 0; i < times; i++) {
            counter++;
        }
        emit CounterIncremented(counter);
    }
    
    function deposit() public payable {
        balances[msg.sender] += msg.value;
        emit Transfer(address(0), msg.sender, msg.value);
    }
    
    function withdraw(uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        emit Transfer(msg.sender, address(0), amount);
    }
    
    function complexOperation(uint256 iterations) public {
        for (uint256 i = 0; i < iterations; i++) {
            counter += i;
            balances[msg.sender] += i;
        }
    }
}
