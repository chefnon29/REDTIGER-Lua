/*
   RT-CRYPTO v1 — moteur partagé bot / loader Roblox.
   L'implémentation Lua identique (bit32) est dans REDTIGER.lua / Panel.lua.
   ATTENTION : toute modification ici DOIT être reflétée en Lua au caractère près.

   Principe :
   - Les clés ne sont JAMAIS stockées en clair sur GitHub :
     le nom de l'entrée = hash64(key, keySalt) — irréversible.
   - Le code du panel est stocké chiffré (Panel.enc.lua, XOR-flot xorshift128)
     avec une clé de panel K. K est lui-même chiffré par chaque clé utilisateur
     (entry.pkey) : impossible de déchiffrer le panel sans une clé valide.
*/

function bxor(a, b) { return (a ^ b) >>> 0; }
function lshift(x, n) { return (x << n) >>> 0; }
function rshift(x, n) { return (x >>> n) >>> 0; }
function rotl32(x, n) { n &= 31; return n === 0 ? x >>> 0 : ((x << n) | (x >>> (32 - n))) >>> 0; }
function imul32(a, b) { return Math.imul(a, b) >>> 0; }

function strBytes(s) {
    const out = [];
    for (let i = 0; i < s.length; i++) out.push(s.charCodeAt(i) & 0xff);
    return out;
}

// hash32 : FNV-1a "salé" + finalisation murmur3 fmix32
function hash32(msg, saltStr) {
    let h = 0x811c9dc5;
    const mix = (b) => {
        h = bxor(h, b);
        h = imul32(h, 0x01000193);
        h = bxor(h, rotl32(h, 7));
    };
    for (const b of strBytes(saltStr)) mix(b);
    for (const b of strBytes(msg)) mix(b);
    h = bxor(h, rshift(h, 16));
    h = imul32(h, 0x85ebca6b);
    h = bxor(h, rshift(h, 13));
    h = imul32(h, 0xc2b2ae35);
    h = bxor(h, rshift(h, 16));
    return h >>> 0;
}

function hex8(h) { return (h >>> 0).toString(16).padStart(8, "0").toUpperCase(); }

// 64 bits = concat de 2 hash32 — 16 caractères hex
function hash64(msg, salt) {
    return hex8(hash32(msg, salt)) + hex8(hash32(msg, salt + "#2"));
}

function keyHash(key, keySalt) {
    return hash64(key, keySalt + "/key/");
}

// Chiffrement de flot xorshift128, seeded par 4 hash du secret
function makeCipher(secret) {
    let x = hash32(secret, "rt/cipher/1");
    let y = hash32(secret, "rt/cipher/2");
    let z = hash32(secret, "rt/cipher/3");
    let d = hash32(secret, "rt/cipher/4");
    return function nextByte() {
        const t = bxor(x, lshift(x, 11));
        x = y; y = z; z = d;
        d = bxor(bxor(d, rshift(d, 19)), bxor(t, rshift(t, 8)));
        return d & 0xff;
    };
}

// dataBytes = array d'octets ; xor avec le flux
function xorBytes(dataBytes, next) {
    const out = new Array(dataBytes.length);
    for (let i = 0; i < dataBytes.length; i++) out[i] = dataBytes[i] ^ next();
    return out;
}

module.exports = { bxor, lshift, rshift, rotl32, imul32, strBytes, hash32, hex8, hash64, keyHash, makeCipher, xorBytes };
