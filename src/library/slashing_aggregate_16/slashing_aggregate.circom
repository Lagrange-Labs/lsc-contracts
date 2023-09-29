pragma circom 2.0.5;

include "../../circuits/slashing_aggregate.circom";

component main {public [currentCommittee, nextCommittee, chainHeader]} = SlashingAggregate(16, 4);