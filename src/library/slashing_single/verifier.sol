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
            [843262189546824653856300664816494167685936438164657360181554542791283027183,
             8662114855262902568394696654862756750962785328860631588405547979783682375115],
            [18026836584059044840693569073931314721127863762360494263514523854220125972512,
             4001365035140166500305202334468566577889900753739696461571225708100737976068]
        );
        vk.IC = new Pairing.G1Point[](76);
        
        vk.IC[0] = Pairing.G1Point( 
            20246294195983751475361576830498236131901466726379382695087889514160143418702,
            18481533617612696196918282029864415958003211295728751037451035907112227216240
        );                                      
        
        vk.IC[1] = Pairing.G1Point( 
            19170285143851790772438269635711427721187511355028338687827861198655635315810,
            21253038974035885724373975969768790486611853344337120684080754149994156103209
        );                                      
        
        vk.IC[2] = Pairing.G1Point( 
            1035772824446649205601198865840171836983738196230977211777507920291272141896,
            14420831250548946824620469029748645280544802110056109415977276797601524730944
        );                                      
        
        vk.IC[3] = Pairing.G1Point( 
            10030080672780568376469069164576502061831049320915785697373251241200746858327,
            12553638966136988965543487097754443972280216504040691820894617440951243122274
        );                                      
        
        vk.IC[4] = Pairing.G1Point( 
            1446698215915681254446372629660553946198038246375438092954092902474850438325,
            8593300095083186171399060539075018254218472102421003707402510584530382342551
        );                                      
        
        vk.IC[5] = Pairing.G1Point( 
            3288844579375631319866542699975479028801454488292593587398553743219248426804,
            12317286491122716093692595199123253843181037104018747134078525523391964647682
        );                                      
        
        vk.IC[6] = Pairing.G1Point( 
            20968393124522100291537593436563222188559953703293617081572011158741751499333,
            6526136524826229328191818577037661673513245636156495278901381143394290124584
        );                                      
        
        vk.IC[7] = Pairing.G1Point( 
            7070054967665596073000930382393865141719407510848634374194923083631670197598,
            13848044366591585648709925540316767912470961758288270623297024266229487854723
        );                                      
        
        vk.IC[8] = Pairing.G1Point( 
            4423192739866753018156615961136065302014951706674134030515260577417531219392,
            15126707053498188678685281141025214013915372137502592143683197747953383828236
        );                                      
        
        vk.IC[9] = Pairing.G1Point( 
            19306309580977623433541535791642692568318439388860993925000074603015083673729,
            15172149550443405200918176322219315566402655994220382700022955561399537923630
        );                                      
        
        vk.IC[10] = Pairing.G1Point( 
            13695828855700013612490978400929539097984515663455457919814270184192821880860,
            6676559793250377084844016406466402712304753062923268217105946863088502078833
        );                                      
        
        vk.IC[11] = Pairing.G1Point( 
            9794279528881618601338439607392374202354423597510072321938784396244928037271,
            19693620473036444939142765318820631328467432388860179373877344570797546299731
        );                                      
        
        vk.IC[12] = Pairing.G1Point( 
            20804317937579199045962726946503821087996033206161684514269744740367658094323,
            12760762906634787793914720048086563339264878565630352410832467884665193071842
        );                                      
        
        vk.IC[13] = Pairing.G1Point( 
            17735174501408170635882717742326901263906129891265195917581732918615609399178,
            20921340036016640968105468708348228647617239364533747455979238782974153400908
        );                                      
        
        vk.IC[14] = Pairing.G1Point( 
            17562050291392012547220239289679723521402820122477561849956309378835784827802,
            8566129322216176297887911979644034283503328265082123808799483606971542045425
        );                                      
        
        vk.IC[15] = Pairing.G1Point( 
            2999805181267271291394209782335227257358218784228268130052456561188519473226,
            21053192271140319413100395521764333055038028241222788175141260208751250809962
        );                                      
        
        vk.IC[16] = Pairing.G1Point( 
            9898398853546093765991206133857677098480883186618500271151865651466206712168,
            2400082962386535514351446132342814528270194866884171915558375925958957678970
        );                                      
        
        vk.IC[17] = Pairing.G1Point( 
            4135630046966608416108092194723948937199716179323503774313562012497460421789,
            9679421144287303547007507864620827787990546532377254293146983484184530377598
        );                                      
        
        vk.IC[18] = Pairing.G1Point( 
            4684856693722202885672381714445648682060962171905025135572457412205931113905,
            15940475830100780833079612949174414298249376160531375366606966103645054870925
        );                                      
        
        vk.IC[19] = Pairing.G1Point( 
            17916668080369687505938008564777322065686107849818390782223644526182869631912,
            8218651343954871721603117898854772836953879476217000851981890722212060616270
        );                                      
        
        vk.IC[20] = Pairing.G1Point( 
            9473611963237335766159885920351758322024454825205175368195372761830923757679,
            21850101742684918086556417656182848688755265689647923646550474512463461875988
        );                                      
        
        vk.IC[21] = Pairing.G1Point( 
            19945938375972340277511454915679956600039223959751122578134642137710491853426,
            7057892580455301414603902500770052100941324242578161880524916507249154041908
        );                                      
        
        vk.IC[22] = Pairing.G1Point( 
            10698927209269898651784759753890387382469696882035739630331685380173320010902,
            840183469438274080351635846195164763701692794832956516609866043025193363144
        );                                      
        
        vk.IC[23] = Pairing.G1Point( 
            21091922067162082531883257935533266618515520765148665854374290740523566066413,
            19657566533186265429841712451362386370823903535567383799317389031608777725477
        );                                      
        
        vk.IC[24] = Pairing.G1Point( 
            6440569855351309889582313346826483042636205404320986894205765672878501610703,
            5871733358633497051958650300848057194071856777135043660081316100359659191061
        );                                      
        
        vk.IC[25] = Pairing.G1Point( 
            4038254979073447702658262174008568186008188898362228195465092129592397617404,
            6333124618163481262665492043788314762973931843476137247430693968081902778074
        );                                      
        
        vk.IC[26] = Pairing.G1Point( 
            16146547614690605297882082570917869019936539294233131269779862726699888974611,
            11356671404779026918045495957568603984129708872617988374813269335621468759862
        );                                      
        
        vk.IC[27] = Pairing.G1Point( 
            2337840848772875365522799867227758203059088229226151773324490540867428550323,
            7284390484251493182954192004874407168020506425662321005308399595027655041801
        );                                      
        
        vk.IC[28] = Pairing.G1Point( 
            8914651141006748804261554648645910441170583950876547323414735644444670777402,
            15389862442364338592950072718664012434613527398665484757487004285870206019328
        );                                      
        
        vk.IC[29] = Pairing.G1Point( 
            2770936230203248511598054661424228324346093247959287265045309180368104656966,
            12428953932464454537186370145062880001738497109635327440560351029403728775331
        );                                      
        
        vk.IC[30] = Pairing.G1Point( 
            795933299140187235134332721987169951333553517517254987858089295032055661456,
            13583727078861866595194152390830939598187561170058212267929206262727018411128
        );                                      
        
        vk.IC[31] = Pairing.G1Point( 
            5522971489649185674313403305729874032849638466650714733767534142050844297231,
            21593321864824596307437720447649374676046194644795996027359077997746668385232
        );                                      
        
        vk.IC[32] = Pairing.G1Point( 
            15763992166873155100056981899634000191789887969630636802946158811034089801288,
            9592410414247247102351284393399107403316510113282796253702480392794086439425
        );                                      
        
        vk.IC[33] = Pairing.G1Point( 
            10618862365170787305319760344150908968242098314453303382966456658358528586794,
            11404934600647219464872529207802335309289720757436980660569021304102228102913
        );                                      
        
        vk.IC[34] = Pairing.G1Point( 
            20650771167076397452802598717521158263376126957034331958396995029221543373639,
            6593358165031505492504586862632440552922534379879262453612103992565346984180
        );                                      
        
        vk.IC[35] = Pairing.G1Point( 
            559902246071382764895452674413064114670512659974772112383929203031451660741,
            17556717575314873857302225412228197964141797745261794230246296232058715845837
        );                                      
        
        vk.IC[36] = Pairing.G1Point( 
            19433629522717678160502534024310833963540629271806567911556698167483445050737,
            14309898637276831374144259375481520868513763023871099168951902216323778540968
        );                                      
        
        vk.IC[37] = Pairing.G1Point( 
            16806642826269440150016377276130573231987957648753997846170474718398323401750,
            1913581160991249460491234046715483833037699237710436712086601290003130337273
        );                                      
        
        vk.IC[38] = Pairing.G1Point( 
            21602182015106401839808790871480446257792164599367685465066742017001024788135,
            20190533412071602978926565485583870584935790492217658803069914495949601922629
        );                                      
        
        vk.IC[39] = Pairing.G1Point( 
            302947191009125338652617801570475874019284493835168270422928251642233179240,
            9720465543753508906072438625343547777805874360918370980195677750790166074129
        );                                      
        
        vk.IC[40] = Pairing.G1Point( 
            9062035059599780814268963095600718261555687879291685829201183936904348659275,
            19017488825228414493967931783834205713469545528319350639899133874695648343035
        );                                      
        
        vk.IC[41] = Pairing.G1Point( 
            683683943597927615065227905983784282108732095112096614878149341752341925264,
            18005524286717532975912217414227340414660176701096856828225150497675120834977
        );                                      
        
        vk.IC[42] = Pairing.G1Point( 
            18431322442452583816240606386422977575341062705086678641506983599942667280974,
            12133541435719180706783749561399493674761912820921888749237254327086127649630
        );                                      
        
        vk.IC[43] = Pairing.G1Point( 
            13462069156228187212519807682284692668135257696486157449767361660531665866519,
            5972629468044471647770718980441568481971950878940989317551787478583805078279
        );                                      
        
        vk.IC[44] = Pairing.G1Point( 
            10433242403124796403174414000268171682335735634305279279397106645621921221387,
            19559842992685009826207833328059310988757220515748873054821230842554822646872
        );                                      
        
        vk.IC[45] = Pairing.G1Point( 
            8375149376460960842858670747297008239967573690702897900373266425323945744398,
            1619115625364917022829680969378719685564337360122617112596365022248493342284
        );                                      
        
        vk.IC[46] = Pairing.G1Point( 
            8456897643130093772151400952225349098754737639427537512334677557561392529811,
            5898704804167202494228367279965095755013013275233375524192928873928930753027
        );                                      
        
        vk.IC[47] = Pairing.G1Point( 
            9705597209208269453306625843044404498247810074716053220959870987920278643686,
            18346451380635328112047006268882721475673963275897212548305174384753825549965
        );                                      
        
        vk.IC[48] = Pairing.G1Point( 
            5975029227177657690536199544140618687932514338228050104557725975901425243195,
            11034402547522823930434231001061642263855191515364759378048015564784526039662
        );                                      
        
        vk.IC[49] = Pairing.G1Point( 
            21387529184092408927068792523739013663654931201993010478904560197319693409994,
            13187805010900486562727644864846976189635683185154345166257680959036623477068
        );                                      
        
        vk.IC[50] = Pairing.G1Point( 
            7810028826701436292692857552393091784602673705478652041484532072433761277908,
            5838759047433105898235270315873617848210072978680975508012831482726889810304
        );                                      
        
        vk.IC[51] = Pairing.G1Point( 
            14004482919816777188611287975176578067707633833087704291372157890114985803654,
            16338178782771574542199804200876937359626845264267101898728622670430203190704
        );                                      
        
        vk.IC[52] = Pairing.G1Point( 
            12609616031272511356419606888452928525860564322230119782966652758191687121479,
            1082274473616692880096975249052076439313570351636707777249313466408252476543
        );                                      
        
        vk.IC[53] = Pairing.G1Point( 
            14512973166663232995750051114946262205902511869899197829325300944555697551235,
            3031126229270836761869525968065736164565517304105146826909862735484636308458
        );                                      
        
        vk.IC[54] = Pairing.G1Point( 
            6881363254339402548563955497182398898414487038233869425342093408079498443748,
            19069500197581051289153604168880055150140572805303594303349646922270500692053
        );                                      
        
        vk.IC[55] = Pairing.G1Point( 
            13213721223554482356208953292705032506468993910749817470720063523469337255972,
            19982284045958931707422763459370156191979827938887302176917108578343033881082
        );                                      
        
        vk.IC[56] = Pairing.G1Point( 
            21820375467793162961622543635900540944184158177295100329919277048951235729263,
            17095297203656926583622815533944453736640712530771984401295958820487044444187
        );                                      
        
        vk.IC[57] = Pairing.G1Point( 
            336081879369234628756353866000683070454577168029856421117326477451941671514,
            18728537472390399033323772922526816729160826344626693769553952018379515539603
        );                                      
        
        vk.IC[58] = Pairing.G1Point( 
            15594236637749355087133505337768406585972159406184990758524239124270388913929,
            14600465075089520969499440644787485495065133540721486228500318580137398910431
        );                                      
        
        vk.IC[59] = Pairing.G1Point( 
            794189624129169876172760369824551417114810481393022030227137376305104523173,
            20140398231922846674428237880932156303539305993232903721030999611355167808200
        );                                      
        
        vk.IC[60] = Pairing.G1Point( 
            20420626293999140315185680140056096651377964719188939193290626416449832583499,
            11555199994475770494381621734898378327111305314173577505685580184001860297399
        );                                      
        
        vk.IC[61] = Pairing.G1Point( 
            12768514335420402359711150159141809926761367831620825083292603905550012248370,
            11944967999678005006281453087127597323844474804943233203350366816773074279367
        );                                      
        
        vk.IC[62] = Pairing.G1Point( 
            12784641902621250103474657666241973285352543149981051096867855941623381088500,
            2646198534453454461496133896191979880591079912715320079892514766994243610073
        );                                      
        
        vk.IC[63] = Pairing.G1Point( 
            21570787730947430103385051800328520252400014960395225058882719995829892443571,
            11702020505290558469344103250941834272729972029694544893527345857595521817539
        );                                      
        
        vk.IC[64] = Pairing.G1Point( 
            16638562952220289723996898102099045797012179849515736558885753897903746033648,
            11411472192104411207708825188223113295304137520578065968029752014884995925659
        );                                      
        
        vk.IC[65] = Pairing.G1Point( 
            9993079129492959762188921288705380339063231622316343666742782991831899182148,
            12550259365486515657842398096765072753079117601210133229540738186220566321010
        );                                      
        
        vk.IC[66] = Pairing.G1Point( 
            5440970560517327107816388594035709421947662139427343057790005268247990015793,
            11114530604372736413583936669865724514378263137214700821982255590274789809299
        );                                      
        
        vk.IC[67] = Pairing.G1Point( 
            20458381072946528612010296777173262078719459449383234523282739195508752968362,
            7222913969414107442755330913786801795274939780576030272389922078893208865672
        );                                      
        
        vk.IC[68] = Pairing.G1Point( 
            5852835117436497832319977464209145534734542906502972135682181736325188151102,
            2544257950734872962167936924215544909570906985408158144740571486294355824992
        );                                      
        
        vk.IC[69] = Pairing.G1Point( 
            15216965132515655755181930660578775706636919991987964746761817177650721410119,
            16759505928582059245323928308403074850991696446638103291246538818888147541701
        );                                      
        
        vk.IC[70] = Pairing.G1Point( 
            15867294051735302690910856998762413996478300917709552210548140398187226317656,
            12866819351702043031550840287728159756213205344463563605777565484035899783176
        );                                      
        
        vk.IC[71] = Pairing.G1Point( 
            9210431480278132435110546150069690308261529876692511914081763645199353633918,
            6737247507715381531477180268407533014148461891164775767956732166456829639474
        );                                      
        
        vk.IC[72] = Pairing.G1Point( 
            15551642338408622699226861290104014694556344403187643712810140800032231435204,
            3786206892243600431064482788780264743385082509594846770649846824622581949658
        );                                      
        
        vk.IC[73] = Pairing.G1Point( 
            20988265929034839491537584942032491836845809833394186259251739304121773625641,
            7560443211667275255701969806821116223905228039031137273959160053062656448385
        );                                      
        
        vk.IC[74] = Pairing.G1Point( 
            18881556972468553620588267199542759124486106308608195238617730415473409396772,
            16567772823972918375083874115125751054889605322251802559818600173091433738003
        );                                      
        
        vk.IC[75] = Pairing.G1Point( 
            5090364695099189931274018512648103330068138477756163464245235521681595849827,
            16935868377901266871347196764394587551972999948462901133258619020933088867582
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
            uint[75] memory input
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
