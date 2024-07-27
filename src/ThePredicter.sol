// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// written Address lib isnt used anywhere . either remove it or use it to send money
import {Address} from "@openzeppelin/contracts/utils/Address.sol"; // q any bugs? -> NO
import {ScoreBoard} from "./ScoreBoard.sol";

contract ThePredicter {

    // q where is theResult of matches set?

    // q should the owner send entranceFee and enter the contract via the constructor itself? Currently he is entering the same way as others

    // q where does the Owner set the result? there exists a `ScoreBoard::setResult` fn but not used anywhere in this contract
    // q does Ivan(organiser) pay pred Fee? -> YES , he calls the `makePrediction` function like everyone else
    // q what if ivan deploys contract after 4 PM?
    // report-skipped centralisation risk (Ivan isnt malicious)

    // written remove it or use it
    using Address for address payable;

    uint256 private constant START_TIME = 1723752000; // Thu Aug 15 2024 20:00:00 GMT+0000

    // q Unknown is not used?
    // written remove unused enum states : `Unknown`
    enum Status {
        Unknown,
        Pending,
        Approved,
        Canceled 
    }

    // q everything public?

    // written make organizer,entranceFee,predictionFee immutable
    address public organizer;
    address[] public players;
    uint256 public entranceFee;
    uint256 public predictionFee;
    ScoreBoard public scoreBoard;
    mapping(address players => Status) public playersStatus;

    error ThePredicter__IncorrectEntranceFee();
    error ThePredicter__RegistrationIsOver();
    error ThePredicter__IncorrectPredictionFee();
    error ThePredicter__AllPlacesAreTaken();
    error ThePredicter__CannotParticipateTwice();
    error ThePredicter__NotEligibleForWithdraw();
    error ThePredicter__PredictionsAreClosed();
    error ThePredicter__UnauthorizedAccess();

    constructor(
        address _scoreBoard,
        uint256 _entranceFee,
        uint256 _predictionFee
    ) {
        // q should owner also needs to send `entranceFee` -> Make the constructor payable and check the amount sent, also  should do players[0] = msg.sender or players.push(msg.sender) -> not necessary
        organizer = msg.sender;

        // written deploy a new ScoreBoard contract to become the owner else you wont be able to call onlyOwner functions
        // else , change setting of owner to `tx.origin` . same in modifier 
        scoreBoard = ScoreBoard(_scoreBoard);
        entranceFee = _entranceFee;
        predictionFee = _predictionFee;

        // scoreBoard.setThePredicter(address(this));

    }

    // e the contract is holding the balance
    function register() public payable {
        if (msg.value != entranceFee) {
            revert ThePredicter__IncorrectEntranceFee();
        }

        // e 8 PM - 4 hrs = 4 PM @ 15 Aug
        if (block.timestamp > START_TIME - 14400) { // e deadline is 1723752000 - 14400 = 1723737600
            revert ThePredicter__RegistrationIsOver();
        }

        if (playersStatus[msg.sender] == Status.Pending) {
            revert ThePredicter__CannotParticipateTwice();
        }

        playersStatus[msg.sender] = Status.Pending;
    }

    function cancelRegistration() public {
        if (playersStatus[msg.sender] == Status.Pending) {
            // written re-entrancy
            (bool success, ) = msg.sender.call{value: entranceFee}("");
            require(success, "Failed to withdraw");
            playersStatus[msg.sender] = Status.Canceled;
            return;
        }
        revert ThePredicter__NotEligibleForWithdraw(); // e if you have been made a player , then you cant withdraw
    }

    function approvePlayer(address player) public {
        if (msg.sender != organizer) {
            revert ThePredicter__UnauthorizedAccess();
        }
        if (players.length >= 30) {
            revert ThePredicter__AllPlacesAreTaken();
        }
        if (playersStatus[player] == Status.Pending) {
            playersStatus[player] = Status.Approved;
            players.push(player);
        }
    }

    // e looks good mostly
    function makePrediction(
        uint256 matchNumber,
        ScoreBoard.Result prediction // e this is correct(accessing a data type , here enum , via contract name )
    ) public payable {
        if (msg.value != predictionFee) {
            revert ThePredicter__IncorrectPredictionFee();
        }

        // written correct -> ( > START_TIME + matchNumber*86400 - 3600)
        if (block.timestamp > START_TIME + matchNumber * 68400 - 68400) {
            revert ThePredicter__PredictionsAreClosed();
        }

        scoreBoard.confirmPredictionPayment(msg.sender, matchNumber); // q where is thePredicter set?
        scoreBoard.setPrediction(msg.sender, matchNumber, prediction);
    }

    //  e owner withdraws all the pred fees
    function withdrawPredictionFees() public {
        if (msg.sender != organizer) {
            revert ThePredicter__NotEligibleForWithdraw();
        }

        // written this way, fee of users who havent been approved to be players , will be withdrawn in form of pred fee. Or worse , if the user withdraws fee , all this calcu will fail
        // rather just keep track of all the pred fees in a variable and withdraw that amount
        uint256 fees = address(this).balance - players.length * entranceFee;

        // q do we have to worry about the following call failing? prob not as owner isnt malicious
        // still pull over push can be followed
        (bool success, ) = msg.sender.call{value: fees}("");
        require(success, "Failed to withdraw");
    }

    // e most imp function imo -> Spend time on it
    function withdraw() public {
        if (!scoreBoard.isEligibleForReward(msg.sender)) {
            revert ThePredicter__NotEligibleForWithdraw();
        }

        int8 score = scoreBoard.getPlayerScore(msg.sender);
        
        int8 maxScore = -1; // q should it be 0? -> NO
        int256 totalPositivePoints = 0; // q why is it 'int' when it can never be negative ? why not uint


        // written cache the length of players array
        for (uint256 i = 0; i < players.length; ++i) {
            int8 cScore = scoreBoard.getPlayerScore(players[i]);
            if (cScore > maxScore) maxScore = cScore;
            if (cScore > 0) totalPositivePoints += cScore;
        }

        // e README says only 'positive' point player will get reward

        if (maxScore > 0 && score <= 0) {
            revert ThePredicter__NotEligibleForWithdraw();
        }

        uint256 shares = uint8(score); // e score will be +ve if I have passed the above if check

        // written unnecessary initial declaration as int , couldve directly written uint and saved the following conversion gas costs
        uint256 totalShares = uint256(totalPositivePoints); // q watch out for totalPositivePoints = 0
        uint256 reward = 0;

        // written should be (maxScore <= 0) as maxScore == 0 is covered nowhere in this fn
        reward = maxScore < 0 // e means all scores are < 0
            ? entranceFee
            : (shares * players.length * entranceFee) / totalShares; // e note that fee of users who werent approved shouldnt be given to winners/players

        // q when would reward be <= 0 ?
        // can never be <0
        // can never be 0 (imp analysis)
        // written redundant `if` statement
        if (reward > 0) {
            scoreBoard.clearPredictionsCount(msg.sender);


            // q what if the following call fails?
            // well , user wont be able to withdraw his funds again because his pred count has been cleared
            // so , a non-mal user may accidently have a smart contract with improper receive/fallback and they will not get their reward
            // a mal user cant re-enter as this function is following CEI

            // written use pull over push method as ext call may fail for winners
            (bool success, ) = msg.sender.call{value: reward}("");
            require(success, "Failed to withdraw");
        }
    }
}
