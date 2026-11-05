/*
   build-encrypted-panel.js
   ========================
   Chiffre Panel.lua -> Panel.enc.lua avec PANEL_KEY (config.json).
   Le code source du panel n'apparait donc plus jamais en clair sur GitHub :
   impossible de le dechiffrer sans une cle valide (la cle du panel est
   elle-meme chiffree avec la cle de chaque utilisateur dans keys.json).

   A relancer a chaque mise a jour de Panel.lua :
     node build-encrypted-panel.js
*/

const fs = require("fs");
const path = require("path");
const RT = require("./crypto.js");

const CONFIG = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json"), "utf8"));
const PANEL_KEY = CONFIG.panelKey;
if (!PANEL_KEY) {
    console.error("ERREUR : panelKey manquant dans config.json");
    process.exit(1);
}

const SRC  = path.join(__dirname, "..", "REDTIGER-Lua", "Panel.lua");
const OUT  = path.join(__dirname, "..", "REDTIGER-Lua", "Panel.enc.lua");

const src = fs.readFileSync(SRC);
if (src.length === 0) {
    console.error("ERREUR : Panel.lua vide ou introuvable");
    process.exit(1);
}

// Chiffrement : XOR avec le flux derive de PANEL_KEY, puis base64
const encBytes = RT.xorBytes(Array.from(src), RT.makeCipher(PANEL_KEY));
const b64 = Buffer.from(encBytes).toString("base64");
fs.writeFileSync(OUT, b64);

console.log(`Panel chiffre : ${src.length} octets -> ${b64.length} octets base64 (${path.basename(OUT)})`);

// Smoke test : le dechiffrement redonne bien le fichier source
const storedB64 = fs.readFileSync(OUT, "utf8");
const encBack = Array.from(Buffer.from(storedB64, "base64"));
const roundtripSrc = Buffer.from(RT.xorBytes(encBack, RT.makeCipher(PANEL_KEY))).toString("utf8");
const ok = roundtripSrc === fs.readFileSync(SRC, "utf8");
console.log(ok ? "Smoke test : dechiffrement reel OK" : "ERREUR : le dechiffrement ne redonne pas le meme code !");
process.exit(ok ? 0 : 2);
