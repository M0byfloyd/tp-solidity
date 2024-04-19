// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable {
    constructor() Ownable(msg.sender) {
        currentWorkflowStatus = WorkflowStatus.RegisteringVoters;
    }

    // -- Structs -- //
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
    }

    // -- Workflow enum -- //
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        votingSessionStarted,
        votingSessionEnded,
        votesTallied
    }

    // -- Events -- //
    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    // -- Variables -- //
    // Proposals
    mapping(uint => Proposal) proposals;
    uint winningProposalId;
    uint proposalCounter = 0;
    uint winnerProposalCount = 0;

    // Voter
    mapping(address => Voter) voterList;

    // Workflow
    WorkflowStatus currentWorkflowStatus;


    // -- Modifiers -- //
    modifier onlyRegistered()  {
        if (!voterList[msg.sender].isRegistered)
            revert("You're not allowed to do this");
        _;
    }

    modifier onlyOnVotersRegistering() {
        if (currentWorkflowStatus != WorkflowStatus.RegisteringVoters)
            revert("It's too late to modify the list");
            _;
    }

    // -- Functions -- //

    // - Status functions - //
    function transition(WorkflowStatus newStatus) onlyOwner private {
        if (uint(newStatus) != uint(currentWorkflowStatus) + 1)
            revert("You can't do this in that way");

        currentWorkflowStatus = newStatus;
        emit WorkflowStatusChange(currentWorkflowStatus, newStatus);
    }

    function startProposals() public {
        transition(WorkflowStatus.ProposalsRegistrationStarted);
    }

    function startVote() public {
        transition(WorkflowStatus.votingSessionStarted);
    }

    function endProposals() public {
        if (proposalCounter == 0)
            revert("Nobody voted");

        transition(WorkflowStatus.ProposalsRegistrationEnded);
    }

    function endVote() onlyOwner public {
        transition(WorkflowStatus.votingSessionEnded);

        for (uint i = 1; i <= proposalCounter; i++) {
            if (proposals[i].voteCount > proposals[winningProposalId].voteCount)
                winningProposalId = i;
        }

        transition(WorkflowStatus.votesTallied);
    }

    // - Voterlist administration -//
    function addVoter(address voterAddress) onlyOwner onlyOnVotersRegistering public {
        if (voterList[voterAddress].isRegistered)
            revert("You can't register twice a voter");

        voterList[voterAddress] = Voter(true, false, 0);
        emit VoterRegistered(voterAddress);
    }

    function deleteVoter(address voterAddress) onlyOwner onlyOnVotersRegistering public {
        if (!voterList[voterAddress].isRegistered)
            revert("Voter is not in the list");
        delete voterList[voterAddress];
    }

    // - Misc. -//
    function submitProposals(string memory description) onlyRegistered public {
        if (currentWorkflowStatus != WorkflowStatus.ProposalsRegistrationStarted)
            revert("The admin did not start the proposal registration or it's too late");

        proposalCounter++;
        proposals[proposalCounter] = Proposal(description, 0);
        emit ProposalRegistered(proposalCounter);
    }

    function vote(uint proposalNumber) onlyRegistered public {
        if (currentWorkflowStatus != WorkflowStatus.votingSessionStarted)
            revert("The admin did not start the voting session or it's too late");
        if (voterList[msg.sender].hasVoted)
            revert("You have already voted");

        proposals[proposalNumber].voteCount++;
        voterList[msg.sender].hasVoted = true;
        voterList[msg.sender].votedProposalId = proposalNumber;

        emit Voted(msg.sender, proposalNumber);
    }

    function getWinner() public view returns (Proposal memory) {
        return proposals[winningProposalId];
    }
}