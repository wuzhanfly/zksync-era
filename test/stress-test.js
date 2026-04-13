const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("🔥 tMai Chain 压力测试", function () {
  let stressTest;
  let owner;
  let accounts;

  before(async function () {
    console.log("\n📋 部署压测合约...");
    [owner, ...accounts] = await ethers.getSigners();
    
    const StressTest = await ethers.getContractFactory("StressTest");
    stressTest = await StressTest.deploy();
    await stressTest.waitForDeployment();
    
    const address = await stressTest.getAddress();
    console.log(`✅ 合约部署成功: ${address}`);
    console.log(`👤 测试账户: ${owner.address}`);
  });

  describe("📊 基础性能测试", function () {
    it("单次交易延迟测试", async function () {
      const start = Date.now();
      const tx = await stressTest.increment();
      await tx.wait();
      const duration = Date.now() - start;
      
      console.log(`   ⏱️  单次交易耗时: ${duration}ms`);
      expect(duration).to.be.lessThan(5000);
    });

    it("批量交易测试 (10笔)", async function () {
      const count = 10;
      const start = Date.now();
      
      const promises = [];
      for (let i = 0; i < count; i++) {
        promises.push(stressTest.increment());
      }
      
      await Promise.all(promises.map(p => p.then(tx => tx.wait())));
      const duration = Date.now() - start;
      const tps = (count / (duration / 1000)).toFixed(2);
      
      console.log(`   📈 ${count}笔交易耗时: ${duration}ms`);
      console.log(`   🚀 TPS: ${tps}`);
    });

    it("批量交易测试 (50笔)", async function () {
      this.timeout(120000);
      const count = 50;
      const start = Date.now();
      
      const promises = [];
      for (let i = 0; i < count; i++) {
        promises.push(stressTest.increment());
      }
      
      await Promise.all(promises.map(p => p.then(tx => tx.wait())));
      const duration = Date.now() - start;
      const tps = (count / (duration / 1000)).toFixed(2);
      
      console.log(`   📈 ${count}笔交易耗时: ${duration}ms`);
      console.log(`   🚀 TPS: ${tps}`);
    });
  });

  describe("💰 转账压力测试", function () {
    it("批量转账测试 (20笔)", async function () {
      this.timeout(120000);
      const count = 20;
      const amount = ethers.parseEther("0.01");
      const start = Date.now();
      
      const promises = [];
      for (let i = 0; i < count; i++) {
        promises.push(stressTest.deposit({ value: amount }));
      }
      
      await Promise.all(promises.map(p => p.then(tx => tx.wait())));
      const duration = Date.now() - start;
      const tps = (count / (duration / 1000)).toFixed(2);
      
      console.log(`   📈 ${count}笔转账耗时: ${duration}ms`);
      console.log(`   🚀 TPS: ${tps}`);
    });
  });

  describe("⛽ Gas 消耗测试", function () {
    it("简单操作 Gas 消耗", async function () {
      const tx = await stressTest.increment();
      const receipt = await tx.wait();
      
      console.log(`   ⛽ Gas Used: ${receipt.gasUsed.toString()}`);
      console.log(`   💵 Gas Price: ${receipt.gasPrice.toString()}`);
      console.log(`   💰 Total Cost: ${ethers.formatEther(receipt.gasUsed * receipt.gasPrice)} tMai`);
    });

    it("复杂操作 Gas 消耗", async function () {
      const tx = await stressTest.complexOperation(10);
      const receipt = await tx.wait();
      
      console.log(`   ⛽ Gas Used: ${receipt.gasUsed.toString()}`);
      console.log(`   💵 Gas Price: ${receipt.gasPrice.toString()}`);
      console.log(`   💰 Total Cost: ${ethers.formatEther(receipt.gasUsed * receipt.gasPrice)} tMai`);
    });
  });

  describe("🔥 极限压力测试", function () {
    it("100笔并发交易", async function () {
      this.timeout(300000);
      const count = 100;
      const start = Date.now();
      
      const promises = [];
      for (let i = 0; i < count; i++) {
        promises.push(
          stressTest.increment().catch(err => {
            console.log(`   ⚠️  交易 ${i} 失败: ${err.message}`);
            return null;
          })
        );
      }
      
      const results = await Promise.all(promises);
      const successful = results.filter(r => r !== null);
      
      await Promise.all(successful.map(tx => tx.wait()));
      
      const duration = Date.now() - start;
      const tps = (successful.length / (duration / 1000)).toFixed(2);
      
      console.log(`   📈 ${count}笔交易耗时: ${duration}ms`);
      console.log(`   ✅ 成功: ${successful.length}/${count}`);
      console.log(`   🚀 TPS: ${tps}`);
    });
  });
});
