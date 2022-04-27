// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.7 ;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error Stacking_TransferFailed();
error Stacking_NeedsMoreThanZero();

contract Stacking {
        IERC20 public s_stakingToken;
        IERC20 public s_rewardToken;
        
        // someones address -> how much they staked,
        mapping(address => uint256) public s_balances;


        //  mapping of how much  each address have been paid 
        mapping (address => uint256) public s_userRewardPerTokenPaid;
        //a mapping of how much rewards each address has to claim
        mapping (address => uint256) public s_rewards;

        uint256 public constant REWARD_RATE = 100;
        uint256 public s_totalSupply;
        uint256 public s_rewardPerTokenStored;
        uint256 public s_lastUpdateTime;
        

        modifier updateReward(address account) {
            // how much reward per token ?
            // last timestamp
            // 12 - 1, user earned x tokens
            s_rewardPerTokenStored = rewardPerToken();
            s_lastUpdateTime = block.timestamp;
            s_rewards[account] = earned(account);
            s_userRewardPerTokenPaid[account] = s_rewardPerTokenStored;
            _;
        }

        modifier moreThanZero (uint256 amount) {
            if( amount == 0 ) {
                revert Stacking_NeedsMoreThanZero();
            }
            _;
            
        }
        
        constructor(address stakingToken, address rewardToken) {
            s_stakingToken = IERC20(stakingToken);
            s_rewardToken = IERC20(rewardToken);

        }

        function earned(address account) public view returns(uint256)  {
            uint256 currentBalance = s_balances[account];
            //how much they have been paid already
            uint256 amountPaid = s_userRewardPerTokenPaid[account];
            uint256 currentRewardsPerToken = rewardPerToken();
            uint256 pastRewards = s_rewards[account];
            uint256 _earned = ((currentBalance * (currentRewardsPerToken - amountPaid)) /1e18) + pastRewards;
              
            return _earned;
        }

        function rewardPerToken() public view returns(uint256) {
            if (s_totalSupply == 0) {
                return s_rewardPerTokenStored;
            }
            return s_rewardPerTokenStored + (((block.timestamp) - s_lastUpdateTime) * REWARD_RATE * 1E18 )/ s_totalSupply;
        }

    // do we allow any tokens? - not allow any token.
    //   Chainlink Stff to convert prices between tokens
    // or just a specific token?
        function stake (uint256 amount) external updateReward(msg.sender) moreThanZero(amount) {
            // keep track how much user has stake
            //keep track how much user has total
            //transfer the tokens to contract
            s_balances[msg.sender] = s_balances[msg.sender] + amount;
            s_totalSupply = s_totalSupply + amount;

            //emit event
            bool success = s_stakingToken.transferFrom(msg.sender, address(this), amount);
            //require(success,"failed")
            if(!success) {
                revert Stacking_TransferFailed();
            }
        }
        function withdraw (uint256 amount) external updateReward(msg.sender) moreThanZero(amount) {
            s_balances[msg.sender] = s_balances[msg.sender] - amount;
            s_totalSupply = s_totalSupply - amount;

            bool success = s_stakingToken.transfer(msg.sender, amount);
            //bool success = s_stakingToken.transferFrom(address(this),msg.sender, amount)
            if (!success) {
                revert Stacking_TransferFailed();
            }
        }


        function claimReward() external updateReward(msg.sender) {
            uint256 reward = s_rewards[msg.sender];
            bool success = s_rewardToken.transfer(msg.sender, reward);
            if(!success) {
                revert Stacking_TransferFailed();
            }
            // how much reward do they get?
            //The contract is going to emit x tokens per second
            //And disperse them to all token stakers 

            //100 reward tokens / second 
            // staked: 50 staked tokens, 20 staked tokens, 30 stakes tokens
            // rewards: 50 rewards tokens, 20 reward tokens, 30 rewar tokens 

            //staked: 100,50,20,20 (total = 200)
            // ewards:50, 25,10,15

            // why not 1 to 1 ? - bankrupt protocol!!

            // 5 seconds, 1person had 100 token staked = reward 500 tokens
            // 6 seconds, 2nd person have 100 tokens staked each
            //          person 1: 550
            //          person 2: 50 

            //ok between seconds 1 and 5, person 1 got 500 tokens 
            // ok at second 6 on, person 1 gets 50 tokens now

            //ok between seconds 1 and 5, person 1 got 500 tokens
            //ok at second 6 on, person 1 gets 50 tokens now

            // time = 0;
            // Person A: 100 staked,
            // Person B: 10 staked,

            // Time = 1
            // Pa: 80 staked, earned, 80, withdrawn: 0
            // Pb: 20 staked, earned, 20, withdrawn: 0

            // Time = 2
            // Pa: 80 staked, earned, 160, withdrawn: 0
            // Pb: 20 staked, earned, 40, withdrawn: 0

            // Time = 3
            // Pa: 80 staked, earned, 240, withdrawn: 0
            // Pb: 20 staked, earned, 60, withdrawn: 0

            // New person enters!
            // stake 100

            // Time = 4
            // Pa: 80 staked, earned 240 + (80 / 200)* 100), , withdrawn: 0
            // Pb: 20 staked, earned 60 + (20/200)* 100), , withdrawn: 0
            // Pc: 100 staked, earned 50, witdrawn: 0


            //Pa withdraw everything 
            //
            // Time = 5
            // Pa: 0 staked, earned 0, withdrawn: 280
            // Pb: 20 staked, earned 60 + (20/200)* 100), , withdrawn: 0
            // Pc: 100 staked, earned 50, witdrawn: 0



        }

}
// stake: lock tokens into our smart contact ✅
// withdraw/unstake: unlock tokens and pulls out of the contract
//claimReward: users get their reward tokens
// what's a good reward mechanism?
// what is a good reward mathc?