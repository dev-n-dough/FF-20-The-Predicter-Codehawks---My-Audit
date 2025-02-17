# Aderyn Analysis Report

This report was generated by [Aderyn](https://github.com/Cyfrin/aderyn), a static analysis tool built by [Cyfrin](https://cyfrin.io), a blockchain security company. This report is not a substitute for manual audit or security review. It should not be relied upon for any purpose other than to assist in the identification of potential security vulnerabilities.
# Table of Contents

- [Summary](#summary)
  - [Files Summary](#files-summary)
  - [Files Details](#files-details)
  - [Issue Summary](#issue-summary)
- [Low Issues](#low-issues)
  - [L-1: Centralization Risk for trusted owners](#l-1-centralization-risk-for-trusted-owners)
  - [L-2: Missing checks for `address(0)` when assigning values to address state variables](#l-2-missing-checks-for-address0-when-assigning-values-to-address-state-variables)
  - [L-3: `public` functions not used internally could be marked `external`](#l-3-public-functions-not-used-internally-could-be-marked-external)
  - [L-4: Define and use `constant` variables instead of using literals](#l-4-define-and-use-constant-variables-instead-of-using-literals)
  - [L-5: PUSH0 is not supported by all chains](#l-5-push0-is-not-supported-by-all-chains)


# Summary

## Files Summary

| Key | Value |
| --- | --- |
| .sol Files | 2 |
| Total nSLOC | 201 |


## Files Details

| Filepath | nSLOC |
| --- | --- |
| src/ScoreBoard.sol | 83 |
| src/ThePredicter.sol | 118 |
| **Total** | **201** |


## Issue Summary

| Category | No. of Issues |
| --- | --- |
| High | 0 |
| Low | 5 |


# Low Issues

## L-1: Centralization Risk for trusted owners

Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

<details><summary>2 Found Instances</summary>


- Found in src/ScoreBoard.sol [Line: 53](src/ScoreBoard.sol#L53)

	```solidity
	    function setThePredicter(address _thePredicter) public onlyOwner {
	```

- Found in src/ScoreBoard.sol [Line: 57](src/ScoreBoard.sol#L57)

	```solidity
	    function setResult(uint256 matchNumber, Result result) public onlyOwner {
	```

</details>



## L-2: Missing checks for `address(0)` when assigning values to address state variables

Check for `address(0)` when assigning values to address state variables.

<details><summary>2 Found Instances</summary>


- Found in src/ScoreBoard.sol [Line: 54](src/ScoreBoard.sol#L54)

	```solidity
	        thePredicter = _thePredicter;
	```

- Found in src/ThePredicter.sol [Line: 52](src/ThePredicter.sol#L52)

	```solidity
	        scoreBoard = ScoreBoard(_scoreBoard); // e 'new' keyword wont come (ethernaut OP :) )
	```

</details>



## L-3: `public` functions not used internally could be marked `external`

Instead of marking a function as `public`, consider marking it as `external` if it is not used internally.

<details><summary>13 Found Instances</summary>


- Found in src/ScoreBoard.sol [Line: 53](src/ScoreBoard.sol#L53)

	```solidity
	    function setThePredicter(address _thePredicter) public onlyOwner {
	```

- Found in src/ScoreBoard.sol [Line: 57](src/ScoreBoard.sol#L57)

	```solidity
	    function setResult(uint256 matchNumber, Result result) public onlyOwner {
	```

- Found in src/ScoreBoard.sol [Line: 64](src/ScoreBoard.sol#L64)

	```solidity
	    function confirmPredictionPayment(
	```

- Found in src/ScoreBoard.sol [Line: 75](src/ScoreBoard.sol#L75)

	```solidity
	    function setPrediction(
	```

- Found in src/ScoreBoard.sol [Line: 105](src/ScoreBoard.sol#L105)

	```solidity
	    function clearPredictionsCount(address player) public onlyThePredicter {
	```

- Found in src/ScoreBoard.sol [Line: 111](src/ScoreBoard.sol#L111)

	```solidity
	    function getPlayerScore(address player) public view returns (int8 score) {
	```

- Found in src/ScoreBoard.sol [Line: 124](src/ScoreBoard.sol#L124)

	```solidity
	    function isEligibleForReward(address player) public view returns (bool) {
	```

- Found in src/ThePredicter.sol [Line: 59](src/ThePredicter.sol#L59)

	```solidity
	    function register() public payable {
	```

- Found in src/ThePredicter.sol [Line: 76](src/ThePredicter.sol#L76)

	```solidity
	    function cancelRegistration() public {
	```

- Found in src/ThePredicter.sol [Line: 87](src/ThePredicter.sol#L87)

	```solidity
	    function approvePlayer(address player) public {
	```

- Found in src/ThePredicter.sol [Line: 101](src/ThePredicter.sol#L101)

	```solidity
	    function makePrediction(
	```

- Found in src/ThePredicter.sol [Line: 119](src/ThePredicter.sol#L119)

	```solidity
	    function withdrawPredictionFees() public {
	```

- Found in src/ThePredicter.sol [Line: 135](src/ThePredicter.sol#L135)

	```solidity
	    function withdraw() public {
	```

</details>



## L-4: Define and use `constant` variables instead of using literals

If the same constant literal value is used multiple times, create a constant state variable and reference it throughout the contract.

<details><summary>4 Found Instances</summary>


- Found in src/ScoreBoard.sol [Line: 81](src/ScoreBoard.sol#L81)

	```solidity
	        if (block.timestamp <= START_TIME + matchNumber * 68400 - 68400)
	```

- Found in src/ThePredicter.sol [Line: 110](src/ThePredicter.sol#L110)

	```solidity
	        if (block.timestamp > START_TIME + matchNumber * 68400 - 68400) {
	```

</details>



## L-5: PUSH0 is not supported by all chains

Solc compiler version 0.8.20 switches the default target EVM version to Shanghai, which means that the generated bytecode will include PUSH0 opcodes. Be sure to select the appropriate EVM version in case you intend to deploy on a chain other than mainnet like L2 chains that may not support PUSH0, otherwise deployment of your contracts will fail.

<details><summary>2 Found Instances</summary>


- Found in src/ScoreBoard.sol [Line: 2](src/ScoreBoard.sol#L2)

	```solidity
	pragma solidity 0.8.20;
	```

- Found in src/ThePredicter.sol [Line: 2](src/ThePredicter.sol#L2)

	```solidity
	pragma solidity 0.8.20;
	```

</details>



