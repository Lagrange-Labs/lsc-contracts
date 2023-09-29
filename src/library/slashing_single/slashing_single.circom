pragma circom 2.0.0;

include "../../circuits/slashing_single.circom";

component main { public [pubkey ,signature, signingRoot ] } = SingleBLSProofOfSlashing(55, 7);