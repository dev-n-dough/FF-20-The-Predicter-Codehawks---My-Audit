// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract ScoreBoard 
{
    // q is this correct? ->YES (use https://www.epochconverter.com/)
    uint256 private constant START_TIME = 1723752000; // Thu Aug 15 2024 20:00:00 GMT+0000
    uint256 private constant NUM_MATCHES = 9;

    enum Result {
        Pending,
        First,
        Draw,
        Second
    }

    struct PlayerPredictions {
        Result[NUM_MATCHES] predictions; // e array of enums of fixed size
        bool[NUM_MATCHES] isPaid; // e by default , all values are init to false
        // q wdym by predictionsCount ?
        uint8 predictionsCount; // q overflow/unsafe casting? look out! -> doesnt look like it
    }

    // q something seems wrong idk why // @followup -> its probly nothing

    // written make it immutable
    address owner; // e internal state variable 

    // false-alarm instead of this , make a mapping from address to bool , where each player is marked true and just check this in `onlyThePredicter` modifier . ==> or better , do this in ThePredictor.sol
    address thePredicter; // q wtf is this? shouldnt it be array of predicters? -> ITS THE PREDICTER CONTRACT

    Result[NUM_MATCHES] private results; // q hopefully updated by owner only ? -> YES
    mapping(address players => PlayerPredictions) playersPredictions;

    error ScoreBoard__UnauthorizedAccess();

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert ScoreBoard__UnauthorizedAccess();
        }
        _;
    }

    modifier onlyThePredicter() {
        if (msg.sender != thePredicter) {
            revert ScoreBoard__UnauthorizedAccess();
            // written maybe have diff event names for different access controls
        }
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setThePredicter(address _thePredicter) public onlyOwner {
        thePredicter = _thePredicter;
    }
    
    function setResult(uint256 matchNumber, Result result) public onlyOwner {
    // q is matchNumber 0-indexed? mp yes as owner isnt malicious(but still may do mistake tho)
    // @written add a require statement

    // written add events
        results[matchNumber] = result;
    }

    function confirmPredictionPayment(
        address player,
        uint256 matchNumber
    ) public onlyThePredicter {
        // q so a predictor can come and mark any match number as paid? -> No as we will set access controls in Predicter contract
        playersPredictions[player].isPaid[matchNumber] = true;
    }

    // q onlyThePredictor should be there(see README) -> No as we will set access controls in Predicter contract
    // e a player setting their pred for a given match
    function setPrediction(
        address player,
        uint256 matchNumber,
        Result result
    ) public {
        // e betting allowed only before 7 PM
        if (block.timestamp <= START_TIME + matchNumber * 68400 - 68400)
        // written redundant statement as makePrediction already makes the same check


        // e START_TIME -> 8 PM
        // matchNumber * 68400 -> takes 19 hrs forward on 0th day , 1st day , ...
        // -68400 -> takes 19 hrs back
        // q where are the curly braces of the if statement?? -> No need , it is correct syntax
        // written (upper line) correct -> (<= START_TIME + matchNumber*86400 - 3600)
        // q check calcu and arithmetic errors/bracket positioning -> will follow BODMAS so is correct
            playersPredictions[player].predictions[matchNumber] = result;

        // q so even if above if statement fails , following logic still happens? // @followup
        // q in else block , should we revert or throw error or leave blank?

        playersPredictions[player].predictionsCount = 0; // q wtf?
        // e whenev you place a new pred , this function will re-evaluate all your predictions whose results havent been declared yet
        // q shouldnt this be done when result of a particular match is announced? its also increasing gas costs for the user
        for (uint256 i = 0; i < NUM_MATCHES; ++i) {
            if (
                playersPredictions[player].predictions[i] != Result.Pending &&
                playersPredictions[player].isPaid[i]
            ) ++playersPredictions[player].predictionsCount; // q again , where are the curly braces -> No need , it is correct syntax
        }
    }

    function clearPredictionsCount(address player) public onlyThePredicter {
        playersPredictions[player].predictionsCount = 0;
    }

    // e according to readme , the score accross 9 matches combined will lie between [-9,9] hence int8 is enough 
    // q after result declaration , should we set isPaid of that match to false?
    function getPlayerScore(address player) public view returns (int8 score) {
        for (uint256 i = 0; i < NUM_MATCHES; ++i) {
            if (
                playersPredictions[player].isPaid[i] &&
                playersPredictions[player].predictions[i] != Result.Pending // e only the owner can change the state of Result of a match so this line is safe
            ) {
                score += playersPredictions[player].predictions[i] == results[i]
                    ? int8(2) 
                    : -1; // e integer literals are by default treated as uint256 or int256 hence explicit conversion is necessary
                    // @e no need to explicity convert -1 to int8 as even though -1 is a int256 , it still lies in the range of int8 so solidity will automatically implicitly convert it to int8 when adding it to `score`.
            }
        }
    }

    function isEligibleForReward(address player) public view returns (bool) {
        return
            results[NUM_MATCHES - 1] != Result.Pending && // e results of all matches have been declared
            playersPredictions[player].predictionsCount > 1; // e atleast 1 pred was made
            // written - should be >= 1
            // q can I mess with the pred count maliciously ? -> Well , not in a good way I think , `clearPredictionsCount` can be called by the predictor
            }

}