//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// 2019 OKIMS
//      ported to solidity 0.6
//      fixed linter warnings
//      added requiere error messages
//
//
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;
library Pairing {
    struct G1Point {
        uint X;
        uint Y;
    }
    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint[2] X;
        uint[2] Y;
    }
    /// @return the generator of G1
    function P1() internal pure returns (G1Point memory) {
        return G1Point(1, 2);
    }
    /// @return the generator of G2
    function P2() internal pure returns (G2Point memory) {
        // Original code point
        return G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
             10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
             8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );

/*
        // Changed by Jordi point
        return G2Point(
            [10857046999023057135944570762232829481370756359578518086990519993285655852781,
             11559732032986387107991004021392285783925812861821192530917403151452391805634],
            [8495653923123431417604973247489272438418190587263600148770280649306958101930,
             4082367875863433681332203403145435568316851327593401208105741076214120093531]
        );
*/
    }
    /// @return r the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1Point memory p) internal pure returns (G1Point memory r) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0)
            return G1Point(0, 0);
        return G1Point(p.X, q - (p.Y % q));
    }
    /// @return r the sum of two points of G1
    function addition(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success,"pairing-add-failed");
    }
    /// @return r the product of a point on G1 and a scalar, i.e.
    /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
    function scalar_mul(G1Point memory p, uint s) internal view returns (G1Point memory r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require (success,"pairing-mul-failed");
    }
    /// @return the result of computing the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
    /// return true.
    function pairing(G1Point[] memory p1, G2Point[] memory p2) internal view returns (bool) {
        require(p1.length == p2.length,"pairing-lengths-failed");
        uint elements = p1.length;
        uint inputSize = elements * 6;
        uint[] memory input = new uint[](inputSize);
        for (uint i = 0; i < elements; i++)
        {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[0];
            input[i * 6 + 3] = p2[i].X[1];
            input[i * 6 + 4] = p2[i].Y[0];
            input[i * 6 + 5] = p2[i].Y[1];
        }
        uint[1] memory out;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success,"pairing-opcode-failed");
        return out[0] != 0;
    }
    /// Convenience method for a pairing check for two pairs.
    function pairingProd2(G1Point memory a1, G2Point memory a2, G1Point memory b1, G2Point memory b2) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for three pairs.
    function pairingProd3(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](3);
        G2Point[] memory p2 = new G2Point[](3);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for four pairs.
    function pairingProd4(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2,
            G1Point memory d1, G2Point memory d2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](4);
        G2Point[] memory p2 = new G2Point[](4);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p1[3] = d1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        p2[3] = d2;
        return pairing(p1, p2);
    }
}
contract Verifier {
    using Pairing for *;
    struct VerifyingKey {
        Pairing.G1Point alfa1;
        Pairing.G2Point beta2;
        Pairing.G2Point gamma2;
        Pairing.G2Point delta2;
        Pairing.G1Point[] IC;
    }
    struct Proof {
        Pairing.G1Point A;
        Pairing.G2Point B;
        Pairing.G1Point C;
    }
    function verifyingKey() internal pure returns (VerifyingKey memory vk) {
        vk.alfa1 = Pairing.G1Point(
            20491192805390485299153009773594534940189261866228447918068658471970481763042,
            9383485363053290200918347156157836566562967994039712273449902621266178545958
        );

        vk.beta2 = Pairing.G2Point(
            [4252822878758300859123897981450591353533073413197771768651442665752259397132,
             6375614351688725206403948262868962793625744043794305715222011528459656738731],
            [21847035105528745403288232691147584728191162732299865338377159692350059136679,
             10505242626370262277552901082094356697409835680220590971873171140371331206856]
        );
        vk.gamma2 = Pairing.G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
             10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
             8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );
        vk.delta2 = Pairing.G2Point(
            [2889436353216888123260590465365711633958414928498814691404894348676306618884,
             16021724262003648545254508382087078144346723407507805847045574507912293237836],
            [7197563489107184808542474185107486533545120492010555336551659927713674770130,
             21710947552645752582396720139834260688740906408328830966623089512126069028997]
        );
        vk.IC = new Pairing.G1Point[](48);
        
        vk.IC[0] = Pairing.G1Point( 
            9144871144958728385491285712823593615878450654668473187455458536507794629715,
            20524338721123237865304187165396518615022896606616781624436745897087556279571
        );                                      
        
        vk.IC[1] = Pairing.G1Point( 
            15743309112207442667401151440569546366272899222632532897431519743488727136218,
            9374392287643445070043294986287091288752145613903723725797562745337195631849
        );                                      
        
        vk.IC[2] = Pairing.G1Point( 
            11555010483891580319033578836056923396292039753129378563557635379110433522716,
            13921071897197366608513357072116796782306223908911227702086257584466401501766
        );                                      
        
        vk.IC[3] = Pairing.G1Point( 
            17813596289059688497168180386036661706096452578308550021460242378504692218845,
            17117582881965236931335392445528956470861886407363211534920218192341684046903
        );                                      
        
        vk.IC[4] = Pairing.G1Point( 
            323835850129231414069530995553180148805338130480531906831404781545008757937,
            9098791137588818253538878879934485409165412575442928540137990302756769387752
        );                                      
        
        vk.IC[5] = Pairing.G1Point( 
            4907298921928491278803803112039465456022976619339442541063928185262376241761,
            16479493783519085395665462528670439210073615073317244669165178233464858853721
        );                                      
        
        vk.IC[6] = Pairing.G1Point( 
            3231954307764704732125795798544653422466854148432832515351061196526058599593,
            20991516698822140581309529400399953999934669875571068349584599650358967523369
        );                                      
        
        vk.IC[7] = Pairing.G1Point( 
            8613817270316520333725218457967295412363958021114941108840282091173824197372,
            14464633686633793164234087781977149954939219158382433251568919763810808799657
        );                                      
        
        vk.IC[8] = Pairing.G1Point( 
            5585052919121019269758499472152493900840853558192366810315162616960275830891,
            15699627196222330129620784812553830059506586475198663740597485213475448324636
        );                                      
        
        vk.IC[9] = Pairing.G1Point( 
            13674703483465903975725778504386222399552121059179117276781740183088579912503,
            6822944410156961576290253478980263292759818963180950624506726900013566779807
        );                                      
        
        vk.IC[10] = Pairing.G1Point( 
            2782825498073565060816731126614462865674522815794688682651564725634892033384,
            21071996830424309085482078925289475480700895477169976426998510786452162569149
        );                                      
        
        vk.IC[11] = Pairing.G1Point( 
            16852749124513792582204291310952979046643917945608127311762478580674276465706,
            19943018258148010526884519521052501448408352596034754930859841315219975819559
        );                                      
        
        vk.IC[12] = Pairing.G1Point( 
            4710734340013024851401084849064562821137888386003826118450361450790125461614,
            1124738016863137145664090401015084410828121598567026458420288595260627575546
        );                                      
        
        vk.IC[13] = Pairing.G1Point( 
            7689822931231889336320845937373233608536590337857988409110994821729637026056,
            14876200841061341038476463878650830085755170595582235111071621273419911137242
        );                                      
        
        vk.IC[14] = Pairing.G1Point( 
            13243192068165859260607635747241086439804983445988760634666111135037476640110,
            2144797926635560749742617260929460014395915134650516322656584461342337057580
        );                                      
        
        vk.IC[15] = Pairing.G1Point( 
            14517579852693369659974219456040683154415947052564063901191802314531811801739,
            1007809080468709069521567729178414210116194287082961000401188052417480394549
        );                                      
        
        vk.IC[16] = Pairing.G1Point( 
            18935262681399674094958466325724686171029708976833559776854675174344349480040,
            8615849799387668455771422128505446650022739119997441127124453087081347042900
        );                                      
        
        vk.IC[17] = Pairing.G1Point( 
            8433264637547720351219131293895621161565058650141660169590148967172164706067,
            7311963769349127885844550823402446299639435091258813767492390450036019599704
        );                                      
        
        vk.IC[18] = Pairing.G1Point( 
            9850103691290474973631190495590220717859185729869594313806652883168084837407,
            19526686737173847476733693877070131645479513985500881422225750515304912163652
        );                                      
        
        vk.IC[19] = Pairing.G1Point( 
            5397818598359879748926436816348657973349283086334818238640867025476949878811,
            13480007138544796859099477730837902302077874808510117241989423705685933317438
        );                                      
        
        vk.IC[20] = Pairing.G1Point( 
            4495352481836331437630872683717026190255794745523493992872141605935112375035,
            2721433364911924119290254835942841668928292732710780284289006738930239379246
        );                                      
        
        vk.IC[21] = Pairing.G1Point( 
            20417179022311249238085434277264416439745725787643719519800389577399570937958,
            1452159102700083952539664494414017600928938448256891423351679400346631905807
        );                                      
        
        vk.IC[22] = Pairing.G1Point( 
            12460609752130295915442750632458592175216736457015621048714099321922887819904,
            4330811198824904659124025072071262385402843695597228863442762144855083152014
        );                                      
        
        vk.IC[23] = Pairing.G1Point( 
            18985939358063971934383960071025076293914257092141601527527862260910912514509,
            12655775750534059326135622629598592981308333538197800151025196857160802017160
        );                                      
        
        vk.IC[24] = Pairing.G1Point( 
            8722667480582954938416079503465710279099395144583403120567758172049965127076,
            1373305147934950803815642431700515968547355099690451311494714525679606370576
        );                                      
        
        vk.IC[25] = Pairing.G1Point( 
            6689603304826874562530928475616641053782307564632070704701851138929096036608,
            8268184901562279595604576525546812325981473851823065069308811288220854428300
        );                                      
        
        vk.IC[26] = Pairing.G1Point( 
            3303987123560647268843801590215241479563249718559608786477606934252801888063,
            20402214145856325753241841750231916192680931428301651189949225654289647796012
        );                                      
        
        vk.IC[27] = Pairing.G1Point( 
            2832292886389617208747121980639169813641695913550320526226431847727965454444,
            11692235981973694937593261296464581240681331287669390184490090497632095278511
        );                                      
        
        vk.IC[28] = Pairing.G1Point( 
            18730501886138274488488366192800872667234461449914337369433908978632894815040,
            2883885637986730815112349809052400880477328758074579071072058389023724177569
        );                                      
        
        vk.IC[29] = Pairing.G1Point( 
            5157365518368873217503252815416456016638643801581700906845993545641670474808,
            4281092005178620670308009441367178258234910911814533690056308700497970433251
        );                                      
        
        vk.IC[30] = Pairing.G1Point( 
            11534770867584939231198772507574821221536129160337176588367299638025794047390,
            12765268042510896536590475845799212987969960790474783896571182489381495321469
        );                                      
        
        vk.IC[31] = Pairing.G1Point( 
            19832821400784972647113434922532999543102172803292903534200119802135085529515,
            7346653527912653544031620603609643888777154641595038215583548597955444875409
        );                                      
        
        vk.IC[32] = Pairing.G1Point( 
            10703879933221687278402618060264414015222590303003014668543791625232100443274,
            10354562208099101722814994589269916477782939815485547761289546828450019070458
        );                                      
        
        vk.IC[33] = Pairing.G1Point( 
            6476939878058138462998070957521269939607731338710045503884351166662137923347,
            10148465750766003002213400329082677107648028044168980772008272221223813566103
        );                                      
        
        vk.IC[34] = Pairing.G1Point( 
            20322484012984272431352227909865686967809537364713238859002666194914249757886,
            9395900987119028289473080790689926100812766415589900235416776886763853227174
        );                                      
        
        vk.IC[35] = Pairing.G1Point( 
            13677882703565565577260635513614033176820157890806091630684783196387657055085,
            5943202215037056745039050761583077745346319541681261664346549345952590303267
        );                                      
        
        vk.IC[36] = Pairing.G1Point( 
            18906913357093157705286113244654355585907850017033230750672244122479826168490,
            21871657149801315208301557494965919170474497554410176369345866944968474209665
        );                                      
        
        vk.IC[37] = Pairing.G1Point( 
            12899706136154221576316150638820288267062901622563123942562796254230747648414,
            12189151408657817573424383682886250814283952132537115910078199455734858325447
        );                                      
        
        vk.IC[38] = Pairing.G1Point( 
            12567339920213488846570095186735259881477126102076727102105267841972287767605,
            15463105278687147842043673711327915032328918905306075266608933714795591615815
        );                                      
        
        vk.IC[39] = Pairing.G1Point( 
            512348036537597553137726040340658989979609294985940582815993435153439278442,
            9801331188197894703838525810809106723474771345236836281267652768911671816179
        );                                      
        
        vk.IC[40] = Pairing.G1Point( 
            19303493880734826119540437595440947009962142743439835210171388208214477952246,
            9103511328073872036460594907754296915031461208522953288219298621481821188184
        );                                      
        
        vk.IC[41] = Pairing.G1Point( 
            14464284083815320127672744011259949488259054746475562618990217355862858021636,
            6958432293541937644217865997176947579250255893067058570549118635774284778185
        );                                      
        
        vk.IC[42] = Pairing.G1Point( 
            19174157650017495174750747630896004459287467153099375816935866865503829146722,
            21490315772166088209835417157634429512630775904272663617119758408345749662612
        );                                      
        
        vk.IC[43] = Pairing.G1Point( 
            15528483668391684574944219849248113995926360194995705834145890039746881101333,
            7084906090778248314811547047868102662375028780574758524945673172347663027427
        );                                      
        
        vk.IC[44] = Pairing.G1Point( 
            11685526852818098250248680938540098817221890360747707913769494175027333315357,
            10192424691811900987059041059217801497227856207726324091109684251391915868356
        );                                      
        
        vk.IC[45] = Pairing.G1Point( 
            8712420236526483301431051994539353021502859605592045825470778777915205320205,
            15712257466136699166543472986442113949631938809162352402625982094061929278404
        );                                      
        
        vk.IC[46] = Pairing.G1Point( 
            7209250062027158983111977262618009781879484179841433456949692142174958315173,
            159360079748682505715108186410383198292879101817387013137650894338477449845
        );                                      
        
        vk.IC[47] = Pairing.G1Point( 
            2403282290140333554914566495776495609821489514730808623889305264001699358773,
            10829336224093446875805240994852870229911309915331105496020186766539967173340
        );                                      
        
    }
    function verify(uint[] memory input, Proof memory proof) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        VerifyingKey memory vk = verifyingKey();
        require(input.length + 1 == vk.IC.length,"verifier-bad-input");
        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(input[i] < snark_scalar_field,"verifier-gte-snark-scalar-field");
            vk_x = Pairing.addition(vk_x, Pairing.scalar_mul(vk.IC[i + 1], input[i]));
        }
        vk_x = Pairing.addition(vk_x, vk.IC[0]);
        if (!Pairing.pairingProd4(
            Pairing.negate(proof.A), proof.B,
            vk.alfa1, vk.beta2,
            vk_x, vk.gamma2,
            proof.C, vk.delta2
        )) return 1;
        return 0;
    }
    /// @return r  bool true if proof is valid
    function verifyProof(
            uint[2] memory a,
            uint[2][2] memory b,
            uint[2] memory c,
            uint[47] memory input
        ) public view returns (bool r) {
        Proof memory proof;
        proof.A = Pairing.G1Point(a[0], a[1]);
        proof.B = Pairing.G2Point([b[0][0], b[0][1]], [b[1][0], b[1][1]]);
        proof.C = Pairing.G1Point(c[0], c[1]);
        uint[] memory inputValues = new uint[](input.length);
        for(uint i = 0; i < input.length; i++){
            inputValues[i] = input[i];
        }
        if (verify(inputValues, proof) == 0) {
            return true;
        } else {
            return false;
        }
    }
}
