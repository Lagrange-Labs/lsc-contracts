'use strict';
/*! noble-bls12-381 - MIT License (c) 2019 Paul Miller (paulmillr.com) */
// bls12-381 is a construction of two curves:
// 1. Fp: (x, y)
// 2. Fp₂: ((x₁, x₂+i), (y₁, y₂+i)) - (complex numbers)
//
// Bilinear Pairing (ate pairing) is used to combine both elements into a paired one:
//   Fp₁₂ = e(Fp, Fp2)
//   where Fp₁₂ = 12-degree polynomial
// Pairing is used to verify signatures.
//
// We are using Fp for private keys (shorter) and Fp2 for signatures (longer).
// Some projects may prefer to swap this relation, it is not supported for now.
var __importDefault =
  (this && this.__importDefault) ||
  function (mod) {
    return mod && mod.__esModule ? mod : { default: mod };
  };
Object.defineProperty(exports, '__esModule', { value: true });
exports.verifyBatch =
  exports.aggregateSignatures =
  exports.aggregatePublicKeys =
  exports.verify =
  exports.sign =
  exports.getPublicKey =
  exports.pairing =
  exports.PointG2 =
  exports.PointG1 =
  exports.utils =
  exports.CURVE =
  exports.Fp12 =
  exports.Fp2 =
  exports.Fr =
  exports.Fp =
    void 0;
const crypto_1 = __importDefault(require('crypto'));
// prettier-ignore
const math_js_1 = require("./math.js");
Object.defineProperty(exports, 'Fp', {
  enumerable: true,
  get: function () {
    return math_js_1.Fp;
  },
});
Object.defineProperty(exports, 'Fr', {
  enumerable: true,
  get: function () {
    return math_js_1.Fr;
  },
});
Object.defineProperty(exports, 'Fp2', {
  enumerable: true,
  get: function () {
    return math_js_1.Fp2;
  },
});
Object.defineProperty(exports, 'Fp12', {
  enumerable: true,
  get: function () {
    return math_js_1.Fp12;
  },
});
Object.defineProperty(exports, 'CURVE', {
  enumerable: true,
  get: function () {
    return math_js_1.CURVE;
  },
});
const POW_2_381 = 2n ** 381n;
const POW_2_382 = POW_2_381 * 2n;
const POW_2_383 = POW_2_382 * 2n;
const PUBLIC_KEY_LENGTH = 48;
const SHA256_DIGEST_SIZE = 32;
// Default hash_to_field options are for hash to G2.
//
// Parameter definitions are in section 5.3 of the spec unless otherwise noted.
// Parameter values come from section 8.8.2 of the spec.
// https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-hash-to-curve-11#section-8.8.2
//
// Base field F is GF(p^m)
// p = 0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab
// m = 2 (or 1 for G1 see section 8.8.1)
// k = 128
const htfDefaults = {
  // DST: a domain separation tag
  // defined in section 2.2.5
  // Use utils.getDSTLabel(), utils.setDSTLabel(value)
  DST: 'BLS_SIG_BLS12381G2_XMD:SHA-256_SSWU_RO_POP_',
  // p: the characteristic of F
  //    where F is a finite field of characteristic p and order q = p^m
  p: math_js_1.CURVE.P,
  // m: the extension degree of F, m >= 1
  //     where F is a finite field of characteristic p and order q = p^m
  m: 2,
  // k: the target security level for the suite in bits
  // defined in section 5.1
  k: 128,
  // option to use a message that has already been processed by
  // expand_message_xmd
  expand: true,
};
function isWithinCurveOrder(num) {
  return 0 < num && num < math_js_1.CURVE.r;
}
const crypto = {
  node: crypto_1.default,
  web: typeof self === 'object' && 'crypto' in self ? self.crypto : undefined,
};
exports.utils = {
  hashToField: hash_to_field,
  /**
   * Can take 40 or more bytes of uniform input e.g. from CSPRNG or KDF
   * and convert them into private key, with the modulo bias being neglible.
   * As per FIPS 186 B.1.1.
   * https://research.kudelskisecurity.com/2020/07/28/the-definitive-guide-to-modulo-bias-and-how-to-avoid-it/
   * @param hash hash output from sha512, or a similar function
   * @returns valid private key
   */
  hashToPrivateKey: (hash) => {
    hash = ensureBytes(hash);
    if (hash.length < 40 || hash.length > 1024)
      throw new Error('Expected 40-1024 bytes of private key as per FIPS 186');
    const num = (0, math_js_1.mod)(bytesToNumberBE(hash), math_js_1.CURVE.r);
    // This should never happen
    if (num === 0n || num === 1n) throw new Error('Invalid private key');
    return numberTo32BytesBE(num);
  },
  bytesToHex,
  randomBytes: (bytesLength = 32) => {
    if (crypto.web) {
      return crypto.web.getRandomValues(new Uint8Array(bytesLength));
    } else if (crypto.node) {
      const { randomBytes } = crypto.node;
      return new Uint8Array(randomBytes(bytesLength).buffer);
    } else {
      throw new Error("The environment doesn't have randomBytes function");
    }
  },
  // NIST SP 800-56A rev 3, section 5.6.1.2.2
  // https://research.kudelskisecurity.com/2020/07/28/the-definitive-guide-to-modulo-bias-and-how-to-avoid-it/
  randomPrivateKey: () => {
    return exports.utils.hashToPrivateKey(exports.utils.randomBytes(40));
  },
  sha256: async (message) => {
    if (crypto.web) {
      const buffer = await crypto.web.subtle.digest('SHA-256', message.buffer);
      return new Uint8Array(buffer);
    } else if (crypto.node) {
      return Uint8Array.from(
        crypto.node.createHash('sha256').update(message).digest(),
      );
    } else {
      throw new Error("The environment doesn't have sha256 function");
    }
  },
  mod: math_js_1.mod,
  getDSTLabel() {
    return htfDefaults.DST;
  },
  setDSTLabel(newLabel) {
    // https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-hash-to-curve-11#section-3.1
    if (
      typeof newLabel !== 'string' ||
      newLabel.length > 2048 ||
      newLabel.length === 0
    ) {
      throw new TypeError('Invalid DST');
    }
    htfDefaults.DST = newLabel;
  },
};
function bytesToNumberBE(uint8a) {
  if (!(uint8a instanceof Uint8Array)) throw new Error('Expected Uint8Array');
  return BigInt('0x' + bytesToHex(Uint8Array.from(uint8a)));
}
const hexes = Array.from({ length: 256 }, (v, i) =>
  i.toString(16).padStart(2, '0'),
);
function bytesToHex(uint8a) {
  // pre-caching chars could speed this up 6x.
  let hex = '';
  for (let i = 0; i < uint8a.length; i++) {
    hex += hexes[uint8a[i]];
  }
  return hex;
}
function hexToBytes(hex) {
  if (typeof hex !== 'string') {
    throw new TypeError('hexToBytes: expected string, got ' + typeof hex);
  }
  if (hex.length % 2)
    throw new Error('hexToBytes: received invalid unpadded hex');
  const array = new Uint8Array(hex.length / 2);
  for (let i = 0; i < array.length; i++) {
    const j = i * 2;
    const hexByte = hex.slice(j, j + 2);
    if (hexByte.length !== 2) throw new Error('Invalid byte sequence');
    const byte = Number.parseInt(hexByte, 16);
    if (Number.isNaN(byte) || byte < 0)
      throw new Error('Invalid byte sequence');
    array[i] = byte;
  }
  return array;
}
function numberTo32BytesBE(num) {
  const length = 32;
  const hex = num.toString(16).padStart(length * 2, '0');
  return hexToBytes(hex);
}
function toPaddedHex(num, padding) {
  if (typeof num !== 'bigint' || num < 0n)
    throw new Error('Expected valid bigint');
  if (typeof padding !== 'number')
    throw new TypeError('Expected valid padding');
  return num.toString(16).padStart(padding * 2, '0');
}
function ensureBytes(hex) {
  // Uint8Array.from() instead of hash.slice() because node.js Buffer
  // is instance of Uint8Array, and its slice() creates **mutable** copy
  return hex instanceof Uint8Array ? Uint8Array.from(hex) : hexToBytes(hex);
}
function concatBytes(...arrays) {
  if (arrays.length === 1) return arrays[0];
  const length = arrays.reduce((a, arr) => a + arr.length, 0);
  const result = new Uint8Array(length);
  for (let i = 0, pad = 0; i < arrays.length; i++) {
    const arr = arrays[i];
    result.set(arr, pad);
    pad += arr.length;
  }
  return result;
}
// UTF8 to ui8a
function stringToBytes(str) {
  const bytes = new Uint8Array(str.length);
  for (let i = 0; i < str.length; i++) {
    bytes[i] = str.charCodeAt(i);
  }
  return bytes;
}
// Octet Stream to Integer
function os2ip(bytes) {
  let result = 0n;
  for (let i = 0; i < bytes.length; i++) {
    result <<= 8n;
    result += BigInt(bytes[i]);
  }
  return result;
}
// Integer to Octet Stream
function i2osp(value, length) {
  if (value < 0 || value >= 1 << (8 * length)) {
    throw new Error(`bad I2OSP call: value=${value} length=${length}`);
  }
  const res = Array.from({ length }).fill(0);
  for (let i = length - 1; i >= 0; i--) {
    res[i] = value & 0xff;
    value >>>= 8;
  }
  return new Uint8Array(res);
}
function strxor(a, b) {
  const arr = new Uint8Array(a.length);
  for (let i = 0; i < a.length; i++) {
    arr[i] = a[i] ^ b[i];
  }
  return arr;
}
// Produces a uniformly random byte string using a cryptographic hash function H that outputs b bits
// https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-hash-to-curve-11#section-5.4.1
async function expand_message_xmd(msg, DST, lenInBytes) {
  const H = exports.utils.sha256;
  const b_in_bytes = SHA256_DIGEST_SIZE;
  const r_in_bytes = b_in_bytes * 2;
  const ell = Math.ceil(lenInBytes / b_in_bytes);
  if (ell > 255) throw new Error('Invalid xmd length');
  const DST_prime = concatBytes(DST, i2osp(DST.length, 1));
  const Z_pad = i2osp(0, r_in_bytes);
  const l_i_b_str = i2osp(lenInBytes, 2);
  const b = new Array(ell);
  const b_0 = await H(
    concatBytes(Z_pad, msg, l_i_b_str, i2osp(0, 1), DST_prime),
  );
  b[0] = await H(concatBytes(b_0, i2osp(1, 1), DST_prime));
  for (let i = 1; i <= ell; i++) {
    const args = [strxor(b_0, b[i - 1]), i2osp(i + 1, 1), DST_prime];
    b[i] = await H(concatBytes(...args));
  }
  const pseudo_random_bytes = concatBytes(...b);
  return pseudo_random_bytes.slice(0, lenInBytes);
}
// hashes arbitrary-length byte strings to a list of one or more elements of a finite field F
// https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-hash-to-curve-11#section-5.3
// Inputs:
// msg - a byte string containing the message to hash.
// count - the number of elements of F to output.
// Outputs:
// [u_0, ..., u_(count - 1)], a list of field elements.
async function hash_to_field(msg, count, options = {}) {
  // if options is provided but incomplete, fill any missing fields with the
  // value in hftDefaults (ie hash to G2).
  const htfOptions = { ...htfDefaults, ...options };
  const log2p = htfOptions.p.toString(2).length;
  const L = Math.ceil((log2p + htfOptions.k) / 8); // section 5.1 of ietf draft link above
  const len_in_bytes = count * htfOptions.m * L;
  const DST = stringToBytes(htfOptions.DST);
  let pseudo_random_bytes = msg;
  if (htfOptions.expand) {
    pseudo_random_bytes = await expand_message_xmd(msg, DST, len_in_bytes);
  }
  const u = new Array(count);
  for (let i = 0; i < count; i++) {
    const e = new Array(htfOptions.m);
    for (let j = 0; j < htfOptions.m; j++) {
      const elm_offset = L * (j + i * htfOptions.m);
      const tv = pseudo_random_bytes.slice(elm_offset, elm_offset + L);
      e[j] = (0, math_js_1.mod)(os2ip(tv), htfOptions.p);
    }
    u[i] = e;
  }
  return u;
}
function normalizePrivKey(key) {
  let int;
  if (key instanceof Uint8Array && key.length === 32)
    int = bytesToNumberBE(key);
  else if (typeof key === 'string' && key.length === 64)
    int = BigInt(`0x${key}`);
  else if (typeof key === 'number' && key > 0 && Number.isSafeInteger(key))
    int = BigInt(key);
  else if (typeof key === 'bigint' && key > 0n) int = key;
  else throw new TypeError('Expected valid private key');
  int = (0, math_js_1.mod)(int, math_js_1.CURVE.r);
  if (!isWithinCurveOrder(int))
    throw new Error('Private key must be 0 < key < CURVE.r');
  return int;
}
function assertType(item, type) {
  if (!(item instanceof type))
    throw new Error('Expected Fp* argument, not number/bigint');
}
// Point on G1 curve: (x, y)
// We add z because we work with projective coordinates instead of affine x-y: that's much faster.
class PointG1 extends math_js_1.ProjectivePoint {
  constructor(x, y, z = math_js_1.Fp.ONE) {
    super(x, y, z, math_js_1.Fp);
    assertType(x, math_js_1.Fp);
    assertType(y, math_js_1.Fp);
    assertType(z, math_js_1.Fp);
  }
  static fromHex(bytes) {
    bytes = ensureBytes(bytes);
    const { P } = math_js_1.CURVE;
    let point;
    if (bytes.length === 48) {
      const compressedValue = bytesToNumberBE(bytes);
      const bflag = (0, math_js_1.mod)(compressedValue, POW_2_383) / POW_2_382;
      if (bflag === 1n) {
        return this.ZERO;
      }
      const x = new math_js_1.Fp(
        (0, math_js_1.mod)(compressedValue, POW_2_381),
      );
      const right = x.pow(3n).add(new math_js_1.Fp(math_js_1.CURVE.b)); // y² = x³ + b
      let y = right.sqrt();
      if (!y) throw new Error('Invalid compressed G1 point');
      const aflag = (0, math_js_1.mod)(compressedValue, POW_2_382) / POW_2_381;
      if ((y.value * 2n) / P !== aflag) y = y.negate();
      point = new PointG1(x, y);
    } else if (bytes.length === 96) {
      // Check if the infinity flag is set
      if ((bytes[0] & (1 << 6)) !== 0) return PointG1.ZERO;
      const x = bytesToNumberBE(bytes.slice(0, PUBLIC_KEY_LENGTH));
      const y = bytesToNumberBE(bytes.slice(PUBLIC_KEY_LENGTH));
      point = new PointG1(new math_js_1.Fp(x), new math_js_1.Fp(y));
    } else {
      throw new Error('Invalid point G1, expected 48/96 bytes');
    }
    point.assertValidity();
    return point;
  }
  static fromPrivateKey(privateKey) {
    return this.BASE.multiplyPrecomputed(normalizePrivKey(privateKey));
  }
  toRawBytes(isCompressed = false) {
    return hexToBytes(this.toHex(isCompressed));
  }
  toHex(isCompressed = false) {
    this.assertValidity();
    const { P } = math_js_1.CURVE;
    if (isCompressed) {
      let hex;
      if (this.isZero()) {
        hex = POW_2_383 + POW_2_382;
      } else {
        const [x, y] = this.toAffine();
        const flag = (y.value * 2n) / P;
        hex = x.value + flag * POW_2_381 + POW_2_383;
      }
      return toPaddedHex(hex, PUBLIC_KEY_LENGTH);
    } else {
      if (this.isZero()) {
        // 2x PUBLIC_KEY_LENGTH
        return '4'.padEnd(2 * 2 * PUBLIC_KEY_LENGTH, '0'); // bytes[0] |= 1 << 6;
      } else {
        const [x, y] = this.toAffine();
        return (
          toPaddedHex(x.value, PUBLIC_KEY_LENGTH) +
          toPaddedHex(y.value, PUBLIC_KEY_LENGTH)
        );
      }
    }
  }
  assertValidity() {
    if (this.isZero()) return this;
    if (!this.isOnCurve()) throw new Error('Invalid G1 point: not on curve Fp');
    if (!this.isTorsionFree())
      throw new Error('Invalid G1 point: must be of prime-order subgroup');
    return this;
  }
  [Symbol.for('nodejs.util.inspect.custom')]() {
    return this.toString();
  }
  // Sparse multiplication against precomputed coefficients
  millerLoop(P) {
    return (0, math_js_1.millerLoop)(P.pairingPrecomputes(), this.toAffine());
  }
  // Clear cofactor of G1
  // https://eprint.iacr.org/2019/403
  clearCofactor() {
    // return this.multiplyUnsafe(CURVE.h);
    const t = this.mulCurveMinusX();
    return t.add(this);
  }
  // Checks for equation y² = x³ + b
  isOnCurve() {
    const b = new math_js_1.Fp(math_js_1.CURVE.b);
    const { x, y, z } = this;
    const left = y.pow(2n).multiply(z).subtract(x.pow(3n));
    const right = b.multiply(z.pow(3n));
    return left.subtract(right).isZero();
  }
  // σ endomorphism
  sigma() {
    const BETA =
      0x1a0111ea397fe699ec02408663d4de85aa0d857d89759ad4897d29650fb85f9b409427eb4f49fffd8bfd00000000aaacn;
    const [x, y] = this.toAffine();
    return new PointG1(x.multiply(BETA), y);
  }
  // φ endomorphism
  phi() {
    const cubicRootOfUnityModP =
      0x5f19672fdf76ce51ba69c6076a0f77eaddb3a93be6f89688de17d813620a00022e01fffffffefffen;
    return new PointG1(this.x.multiply(cubicRootOfUnityModP), this.y, this.z);
  }
  // [-0xd201000000010000]P
  mulCurveX() {
    return this.multiplyUnsafe(math_js_1.CURVE.x).negate();
  }
  // [0xd201000000010000]P
  mulCurveMinusX() {
    return this.multiplyUnsafe(math_js_1.CURVE.x);
  }
  // Checks is the point resides in prime-order subgroup.
  // point.isTorsionFree() should return true for valid points
  // It returns false for shitty points.
  // https://eprint.iacr.org/2021/1130.pdf
  isTorsionFree() {
    // todo: unroll
    const xP = this.mulCurveX(); // [x]P
    const u2P = xP.mulCurveMinusX(); // [u2]P
    return u2P.equals(this.phi());
    // https://eprint.iacr.org/2019/814.pdf
    // (z² − 1)/3
    // const c1 = 0x396c8c005555e1560000000055555555n;
    // const P = this;
    // const S = P.sigma();
    // const Q = S.double();
    // const S2 = S.sigma();
    // // [(z² − 1)/3](2σ(P) − P − σ²(P)) − σ²(P) = O
    // const left = Q.subtract(P).subtract(S2).multiplyUnsafe(c1);
    // const C = left.subtract(S2);
    // return C.isZero();
  }
}
exports.PointG1 = PointG1;
PointG1.BASE = new PointG1(
  new math_js_1.Fp(math_js_1.CURVE.Gx),
  new math_js_1.Fp(math_js_1.CURVE.Gy),
  math_js_1.Fp.ONE,
);
PointG1.ZERO = new PointG1(
  math_js_1.Fp.ONE,
  math_js_1.Fp.ONE,
  math_js_1.Fp.ZERO,
);
// Point on G2 curve (complex numbers): (x₁, x₂+i), (y₁, y₂+i)
// We add z because we work with projective coordinates instead of affine x-y: that's much faster.
class PointG2 extends math_js_1.ProjectivePoint {
  constructor(x, y, z = math_js_1.Fp2.ONE) {
    super(x, y, z, math_js_1.Fp2);
    assertType(x, math_js_1.Fp2);
    assertType(y, math_js_1.Fp2);
    assertType(z, math_js_1.Fp2);
  }
  // Encodes byte string to elliptic curve
  // https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-hash-to-curve-11#section-3
  static async hashToCurve(msg) {
    msg = ensureBytes(msg);
    const u = await hash_to_field(msg, 2);
    //console.log(`hash_to_curve(msg}) u0=${new Fp2(u[0])} u1=${new Fp2(u[1])}`);
    const Q0 = new PointG2(
      ...(0, math_js_1.isogenyMapG2)(
        (0, math_js_1.map_to_curve_simple_swu_9mod16)(u[0]),
      ),
    );
    const Q1 = new PointG2(
      ...(0, math_js_1.isogenyMapG2)(
        (0, math_js_1.map_to_curve_simple_swu_9mod16)(u[1]),
      ),
    );
    const R = Q0.add(Q1);
    const P = R.clearCofactor();
    //console.log(`hash_to_curve(msg) Q0=${Q0}, Q1=${Q1}, R=${R} P=${P}`);
    return P;
  }
  // TODO: Optimize, it's very slow because of sqrt.
  static fromSignature(hex) {
    hex = ensureBytes(hex);
    const { P } = math_js_1.CURVE;
    const half = hex.length / 2;
    if (half !== 48 && half !== 96)
      throw new Error('Invalid compressed signature length, must be 96 or 192');
    const z1 = bytesToNumberBE(hex.slice(0, half));
    const z2 = bytesToNumberBE(hex.slice(half));
    // Indicates the infinity point
    const bflag1 = (0, math_js_1.mod)(z1, POW_2_383) / POW_2_382;
    if (bflag1 === 1n) return this.ZERO;
    const x1 = new math_js_1.Fp(z1 % POW_2_381);
    const x2 = new math_js_1.Fp(z2);
    const x = new math_js_1.Fp2(x2, x1);
    const y2 = x.pow(3n).add(math_js_1.Fp2.fromBigTuple(math_js_1.CURVE.b2)); // y² = x³ + 4
    // The slow part
    let y = y2.sqrt();
    if (!y) throw new Error('Failed to find a square root');
    // Choose the y whose leftmost bit of the imaginary part is equal to the a_flag1
    // If y1 happens to be zero, then use the bit of y0
    const { re: y0, im: y1 } = y.reim();
    const aflag1 = (z1 % POW_2_382) / POW_2_381;
    const isGreater = y1 > 0n && (y1 * 2n) / P !== aflag1;
    const isZero = y1 === 0n && (y0 * 2n) / P !== aflag1;
    if (isGreater || isZero) y = y.multiply(-1n);
    const point = new PointG2(x, y, math_js_1.Fp2.ONE);
    point.assertValidity();
    return point;
  }
  static fromHex(bytes) {
    bytes = ensureBytes(bytes);
    let point;
    if (bytes.length === 96) {
      throw new Error('Compressed format not supported yet.');
    } else if (bytes.length === 192) {
      // Check if the infinity flag is set
      if ((bytes[0] & (1 << 6)) !== 0) {
        return PointG2.ZERO;
      }
      const x1 = bytesToNumberBE(bytes.slice(0, PUBLIC_KEY_LENGTH));
      const x0 = bytesToNumberBE(
        bytes.slice(PUBLIC_KEY_LENGTH, 2 * PUBLIC_KEY_LENGTH),
      );
      const y1 = bytesToNumberBE(
        bytes.slice(2 * PUBLIC_KEY_LENGTH, 3 * PUBLIC_KEY_LENGTH),
      );
      const y0 = bytesToNumberBE(bytes.slice(3 * PUBLIC_KEY_LENGTH));
      point = new PointG2(
        math_js_1.Fp2.fromBigTuple([x0, x1]),
        math_js_1.Fp2.fromBigTuple([y0, y1]),
      );
    } else {
      throw new Error('Invalid uncompressed point G2, expected 192 bytes');
    }
    point.assertValidity();
    return point;
  }
  static fromPrivateKey(privateKey) {
    return this.BASE.multiplyPrecomputed(normalizePrivKey(privateKey));
  }
  toSignature() {
    if (this.equals(PointG2.ZERO)) {
      const sum = POW_2_383 + POW_2_382;
      const h =
        toPaddedHex(sum, PUBLIC_KEY_LENGTH) +
        toPaddedHex(0n, PUBLIC_KEY_LENGTH);
      return hexToBytes(h);
    }
    const [{ re: x0, im: x1 }, { re: y0, im: y1 }] = this.toAffine().map((a) =>
      a.reim(),
    );
    const tmp = y1 > 0n ? y1 * 2n : y0 * 2n;
    const aflag1 = tmp / math_js_1.CURVE.P;
    const z1 = x1 + aflag1 * POW_2_381 + POW_2_383;
    const z2 = x0;
    return hexToBytes(
      toPaddedHex(z1, PUBLIC_KEY_LENGTH) + toPaddedHex(z2, PUBLIC_KEY_LENGTH),
    );
  }
  toRawBytes(isCompressed = false) {
    return hexToBytes(this.toHex(isCompressed));
  }
  toHex(isCompressed = false) {
    this.assertValidity();
    if (isCompressed) {
      throw new Error('Point compression has not yet been implemented');
    } else {
      if (this.equals(PointG2.ZERO)) {
        return '4'.padEnd(2 * 4 * PUBLIC_KEY_LENGTH, '0'); // bytes[0] |= 1 << 6;
      }
      const [{ re: x0, im: x1 }, { re: y0, im: y1 }] = this.toAffine().map(
        (a) => a.reim(),
      );
      return (
        toPaddedHex(x1, PUBLIC_KEY_LENGTH) +
        toPaddedHex(x0, PUBLIC_KEY_LENGTH) +
        toPaddedHex(y1, PUBLIC_KEY_LENGTH) +
        toPaddedHex(y0, PUBLIC_KEY_LENGTH)
      );
    }
  }
  assertValidity() {
    if (this.isZero()) return this;
    if (!this.isOnCurve())
      throw new Error('Invalid G2 point: not on curve Fp2');
    if (!this.isTorsionFree())
      throw new Error('Invalid G2 point: must be of prime-order subgroup');
    return this;
  }
  // Ψ endomorphism
  psi() {
    return this.fromAffineTuple((0, math_js_1.psi)(...this.toAffine()));
  }
  // Ψ²
  psi2() {
    return this.fromAffineTuple((0, math_js_1.psi2)(...this.toAffine()));
  }
  // [-x]P aka [z]P
  mulCurveX() {
    return this.multiplyUnsafe(math_js_1.CURVE.x).negate();
  }
  // Maps the point into the prime-order subgroup G2.
  // clear_cofactor_bls12381_g2 from cfrg-hash-to-curve-11
  // https://eprint.iacr.org/2017/419.pdf
  // prettier-ignore
  clearCofactor() {
        const P = this;
        let t1 = P.mulCurveX(); // [-x]P
        let t2 = P.psi(); // Ψ(P)
        let t3 = P.double(); // 2P
        t3 = t3.psi2(); // Ψ²(2P)
        t3 = t3.subtract(t2); // Ψ²(2P) - Ψ(P)
        t2 = t1.add(t2); // [-x]P + Ψ(P)
        t2 = t2.mulCurveX(); // [x²]P - [x]Ψ(P)
        t3 = t3.add(t2); // Ψ²(2P) - Ψ(P) + [x²]P - [x]Ψ(P)
        t3 = t3.subtract(t1); // Ψ²(2P) - Ψ(P) + [x²]P - [x]Ψ(P) + [x]P
        const Q = t3.subtract(P); // Ψ²(2P) - Ψ(P) + [x²]P - [x]Ψ(P) + [x]P - 1P =>
        return Q; // [x²-x-1]P + [x-1]Ψ(P) + Ψ²(2P)
    }
  // Checks for equation y² = x³ + b
  isOnCurve() {
    const b = math_js_1.Fp2.fromBigTuple(math_js_1.CURVE.b2);
    const { x, y, z } = this;
    const left = y.pow(2n).multiply(z).subtract(x.pow(3n));
    const right = b.multiply(z.pow(3n));
    return left.subtract(right).isZero();
  }
  // Checks is the point resides in prime-order subgroup.
  // point.isTorsionFree() should return true for valid points
  // It returns false for shitty points.
  // https://eprint.iacr.org/2021/1130.pdf
  // prettier-ignore
  isTorsionFree() {
        const P = this;
        return P.mulCurveX().equals(P.psi()); // ψ(P) == [u](P)
        // https://eprint.iacr.org/2019/814.pdf
        // const psi2 = P.psi2();                        // Ψ²(P)
        // const psi3 = psi2.psi();                      // Ψ³(P)
        // const zPsi3 = psi3.mulNegX();                 // [z]Ψ³(P) where z = -x
        // return zPsi3.subtract(psi2).add(P).isZero();  // [z]Ψ³(P) - Ψ²(P) + P == O
    }
  // Improves introspection in node.js. Basically displays point's x, y.
  [Symbol.for('nodejs.util.inspect.custom')]() {
    return this.toString();
  }
  clearPairingPrecomputes() {
    this._PPRECOMPUTES = undefined;
  }
  pairingPrecomputes() {
    if (this._PPRECOMPUTES) return this._PPRECOMPUTES;
    this._PPRECOMPUTES = (0, math_js_1.calcPairingPrecomputes)(
      ...this.toAffine(),
    );
    return this._PPRECOMPUTES;
  }
}
exports.PointG2 = PointG2;
PointG2.BASE = new PointG2(
  math_js_1.Fp2.fromBigTuple(math_js_1.CURVE.G2x),
  math_js_1.Fp2.fromBigTuple(math_js_1.CURVE.G2y),
  math_js_1.Fp2.ONE,
);
PointG2.ZERO = new PointG2(
  math_js_1.Fp2.ONE,
  math_js_1.Fp2.ONE,
  math_js_1.Fp2.ZERO,
);
// Calculates bilinear pairing
function pairing(P, Q, withFinalExponent = true) {
  if (P.isZero() || Q.isZero())
    throw new Error('No pairings at point of Infinity');
  P.assertValidity();
  Q.assertValidity();
  // Performance: 9ms for millerLoop and ~14ms for exp.
  const looped = P.millerLoop(Q);
  return withFinalExponent ? looped.finalExponentiate() : looped;
}
exports.pairing = pairing;
function normP1(point) {
  return point instanceof PointG1 ? point : PointG1.fromHex(point);
}
function normP2(point) {
  return point instanceof PointG2 ? point : PointG2.fromSignature(point);
}
async function normP2Hash(point) {
  return point instanceof PointG2 ? point : PointG2.hashToCurve(point);
}
// Multiplies generator by private key.
// P = pk x G
function getPublicKey(privateKey) {
  return PointG1.fromPrivateKey(privateKey).toRawBytes(true);
}
exports.getPublicKey = getPublicKey;
async function sign(message, privateKey) {
  const msgPoint = await normP2Hash(message);
  msgPoint.assertValidity();
  const sigPoint = msgPoint.multiply(normalizePrivKey(privateKey));
  if (message instanceof PointG2) return sigPoint;
  return sigPoint.toSignature();
}
exports.sign = sign;
// Checks if pairing of public key & hash is equal to pairing of generator & signature.
// e(P, H(m)) == e(G, S)
async function verify(signature, message, publicKey) {
  const P = normP1(publicKey);
  const Hm = await normP2Hash(message);
  const G = PointG1.BASE;
  const S = normP2(signature);
  // Instead of doing 2 exponentiations, we use property of billinear maps
  // and do one exp after multiplying 2 points.
  const ePHm = pairing(P.negate(), Hm, false);
  const eGS = pairing(G, S, false);
  const exp = eGS.multiply(ePHm).finalExponentiate();
  return exp.equals(math_js_1.Fp12.ONE);
}
exports.verify = verify;
function aggregatePublicKeys(publicKeys) {
  if (!publicKeys.length) throw new Error('Expected non-empty array');
  const agg = publicKeys
    .map(normP1)
    .reduce((sum, p) => sum.add(p), PointG1.ZERO);
  if (publicKeys[0] instanceof PointG1) return agg.assertValidity();
  return agg.toRawBytes(true);
}
exports.aggregatePublicKeys = aggregatePublicKeys;
function aggregateSignatures(signatures) {
  if (!signatures.length) throw new Error('Expected non-empty array');
  const agg = signatures
    .map(normP2)
    .reduce((sum, s) => sum.add(s), PointG2.ZERO);
  if (signatures[0] instanceof PointG2) return agg.assertValidity();
  return agg.toSignature();
}
exports.aggregateSignatures = aggregateSignatures;
// https://ethresear.ch/t/fast-verification-of-multiple-bls-signatures/5407
// e(G, S) = e(G, SUM(n)(Si)) = MUL(n)(e(G, Si))
async function verifyBatch(signature, messages, publicKeys) {
  if (!messages.length) throw new Error('Expected non-empty messages array');
  if (publicKeys.length !== messages.length)
    throw new Error('Pubkey count should equal msg count');
  const sig = normP2(signature);
  const nMessages = await Promise.all(messages.map(normP2Hash));
  const nPublicKeys = publicKeys.map(normP1);
  try {
    const paired = [];
    for (const message of new Set(nMessages)) {
      const groupPublicKey = nMessages.reduce(
        (groupPublicKey, subMessage, i) =>
          subMessage === message
            ? groupPublicKey.add(nPublicKeys[i])
            : groupPublicKey,
        PointG1.ZERO,
      );
      // const msg = message instanceof PointG2 ? message : await PointG2.hashToCurve(message);
      // Possible to batch pairing for same msg with different groupPublicKey here
      paired.push(pairing(groupPublicKey, message, false));
    }
    paired.push(pairing(PointG1.BASE.negate(), sig, false));
    const product = paired.reduce((a, b) => a.multiply(b), math_js_1.Fp12.ONE);
    const exp = product.finalExponentiate();
    return exp.equals(math_js_1.Fp12.ONE);
  } catch {
    return false;
  }
}
exports.verifyBatch = verifyBatch;
// Pre-compute points. Refer to README.
PointG1.BASE.calcMultiplyPrecomputes(4);
console.log(hexToBytes('5b3f'));
