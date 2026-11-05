/*
   REDTIGER KEY BOT
   =================
   Genere et gere les cles du panel RedTiger depuis Discord.
   Les cles sont enregistrees dans le fichier keys.json du depot
   GitHub chefnon29/REDTIGER-Lua (le meme que lit le script du panel).

   Commandes :
     /genkey    duree:<1h|1jour|1semaine|2semaines|1mois|3mois| lifetime>  quantite:1..10
     /listkeys
     /delkey    cle:<REDTIGER-....>
     /check     cle:<REDTIGER-....>
     /extend    cle:<REDTIGER-....>  duree:<...>

   Qui peut utiliser :
     - Dans un serveur : seulement les personnes avec la permission Integrer/Server-Admin (Admin).
     - En direct (DM) : seulement les ID lists dans config.json -> "admins".
*/

const {
    Client,
    GatewayIntentBits,
    PermissionsBitField,
    ApplicationCommandOptionType,
    REST,
    Routes,
    Events,
} = require("discord.js");
const fs = require("fs");
const path = require("path");
const RT = require("./crypto.js");

// =================== CONFIG ===================
const CONFIG = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json"), "utf8"));

const DISCORD_TOKEN = CONFIG.discordToken;
const GITHUB_TOKEN  = CONFIG.githubToken;
const REPO          = CONFIG.githubRepo;              // "chefnon29/REDTIGER-Lua"
const KEYS_FILE     = CONFIG.keysFile || "keys.json";
const KEY_SALT      = CONFIG.keySalt;                 // OBLIGATOIRE (hash des cles)
const PANEL_KEY     = CONFIG.panelKey;                // cle de dechiffrement du panel chiffre
const ADMINS        = CONFIG.admins || [];            // IDs Discord autorises en DM
const ALLOWED_GUILDS = CONFIG.allowedServers || [];   // serveurs autorisees (vide = tous)

const API_REPO  = `https://api.github.com/repos/${REPO}/contents/${KEYS_FILE}`;
const LOCAL_DB  = path.join(__dirname, "keys.json");

// =================== DUREES ===================
const DURATIONS = {
    "1h":        { label: "1 heure",    seconds: 3600 },
    "1jour":     { label: "1 jour",     seconds: 86400 },
    "1semaine":  { label: "1 semaine",  seconds: 604800 },
    "2semaines": { label: "2 semaines", seconds: 1209600 },
    "1mois":     { label: "1 mois",     seconds: 86400 * 30 },
    "3mois":     { label: "3 mois",     seconds: 86400 * 90 },
    "lifetime":  { label: "a vie",      seconds: 0 },
};

// =================== BASE DE CLES ===================
let keys = {};

// ---------- helpers cryptés ----------
function pkeyFor(userKey) {
    // la cle du panel (PANEL_KEY) chiffree AVEC la cle de l'utilisateur :
    // le loader peut la decouvrir, personne d'autre.
    return Buffer.from(RT.xorBytes(RT.strBytes(PANEL_KEY), RT.makeCipher(userKey))).toString("base64");
}

function maskOf(key) {
    const up = key.toUpperCase().trim();
    if (up.length < 14) return "REDTIGER-****";
    return up.slice(0, 9) + "****-****-" + up.slice(-4);
}

function normalizeKeyInput(raw) {
    return String(raw || "").toUpperCase().trim().replace(/\s/g, "");
}

// Migration : les vieilles entrees sont en clair ("REDTIGER-...").
// On les transforme en entrees hachées (irreversibles) une fois pour toutes.
function forceNormalizeKeys() {
    let changed = false;
    const pending = [];
    for (const [name, entry] of Object.entries(keys)) {
        if (/^REDTIGER-/i.test(name)) {
            const up = normalizeKeyInput(name);
            entry.mask = entry.mask || maskOf(up);
            if (!entry.pkey && PANEL_KEY) entry.pkey = pkeyFor(up);
            keys[RT.keyHash(up, KEY_SALT)] = entry;
            delete keys[name];
            changed = true;
        } else if (typeof entry === "object" && entry !== null && !entry.mask && !name.startsWith("_")) {
            pending.push(name);
        }
    }
    for (const h of pending) {
        // entree hachée sans masque : on garde le hash comme masque tronque
        keys[h].mask = "REDTIGER-****-" + h.slice(-4);
    }
    if (!Array.isArray(keys["_retired"])) {
        keys["_retired"] = [];
        changed = true;
    }
    return changed;
}

function loadLocal() {
    try {
        keys = JSON.parse(fs.readFileSync(LOCAL_DB, "utf8"));
    } catch {
        keys = {};
    }
}

// la base officielle = GitHub ; on la lit au demarrage pour jamais ecraser l'etat distant
async function fetchRemote() {
    try {
        const res = await fetch(API_REPO, {
            headers: { Authorization: `Bearer ${GITHUB_TOKEN}`, Accept: "application/vnd.github+json", "User-Agent": "RedTiger-KeyBot" },
        });
        if (res.status === 404) return {};                      // keys.json existe pas encore
        if (!res.ok) { console.error("GitHub GET:", res.status); return null; }
        const json = await res.json();
        const buff = Buffer.from(json.content, "base64");
        return JSON.parse(buff.toString("utf8"));
    } catch (e) {
        console.error("GitHub GET erreur:", e.message);
        return null;
    }
}

let remoteSha = null;

async function saveKeys() {
    try {
        // sha courant (obligatoire pour modifier un fichier existant)
        const headRes = await fetch(API_REPO, {
            headers: { Authorization: `Bearer ${GITHUB_TOKEN}`, Accept: "application/vnd.github+json", "User-Agent": "RedTiger-KeyBot" },
        });
        if (headRes.ok) {
            const head = await headRes.json();
            remoteSha = head.sha;
        }
        const body = {
            message: "RedTiger KeyBot: mise a jour des cles",
            content: Buffer.from(JSON.stringify(keys, null, 2), "utf8").toString("base64"),
        };
        if (remoteSha) body.sha = remoteSha;
        const res = await fetch(API_REPO, {
            method: "PUT",
            headers: { Authorization: `Bearer ${GITHUB_TOKEN}`, Accept: "application/vnd.github+json", "User-Agent": "RedTiger-KeyBot" },
            body: JSON.stringify(body),
        });
        if (!res.ok) {
            const text = await res.text();
            throw new Error(`${res.status} ${text.slice(0, 200)}`);
        }
        fs.writeFileSync(LOCAL_DB, JSON.stringify(keys, null, 2));
        remoteSha = (await res.json()).content.sha;
        return true;
    } catch (e) {
        console.error("GitHub PUT erreur:", e.message);
        return false;
    }
}

// =================== GENERATION ===================
function randomChunk(n) {
    const charset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    let out = "";
    for (let i = 0; i < n; i++) out += charset[Math.floor(Math.random() * charset.length)];
    return out;
}

function generateKey() {
    // Jamais deux fois la même clé : vérifie la base courante
    // ET l'historique _retired (une clé supprimée ne revient jamais).
    let key, h;
    do {
        key = `REDTIGER-${randomChunk(4)}-${randomChunk(4)}-${randomChunk(4)}`;
        h = RT.keyHash(key, KEY_SALT);
    } while (keys[h] || (keys["_retired"] && keys["_retired"].includes(h)));
    return key;
}

function frDate(timestamp) {
    if (timestamp <= 0) return "jamais (a vie)";
    return new Date(timestamp * 1000).toLocaleString("fr-FR", { dateStyle: "full", timeStyle: "short" });
}

// =================== SECU ===================
function isAuthorized(interaction) {
    if (interaction.inGuild()) {
        if (ALLOWED_GUILDS.length > 0 && !ALLOWED_GUILDS.includes(interaction.guildId)) return false;
        return interaction.memberPermissions.has(PermissionsBitField.Flags.Administrator);
    }
    // en DM : seulement les admins listes
    return ADMINS.includes(interaction.user.id);
}

// =================== COMMANDES ===================
const LOG_WEBHOOK = () => keys["_config"]?.logsWebhook || null;

// Edit protege de l'interaction : jamais de crash "Unknown Message".
// Si le message d'origine est mort/perdu, on renvoie un nouveau message.
async function safeEdit(interaction, content) {
    try {
        return await interaction.editReply(content);
    } catch (e) {
        console.error("editReply:", e.message);
        try {
            return await interaction.followUp({ content: "(message perdu, relance la commande)\nErreur : " + e.message, ephemeral: true });
        } catch {
            return null;
        }
    }
}


async function postLog(title, description, color) {
    const url = LOG_WEBHOOK();
    if (!url) { return; }
    try {
        await fetch(url, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ username: "RedTiger Logs", embeds: [{ title, description, color }] }),
        });
    } catch { /* non bloquant */ }
}

const COMMANDS = [
    {
        name: "genkey",
        description: "Genere des cles pour le panel RedTiger (les cles apparaissent dans le panel)",
        options: [
            {
                name: "duree",
                description: "Combien de temps la cle est valable",
                type: ApplicationCommandOptionType.String,
                required: true,
                choices: Object.entries(DURATIONS).map(([value, d]) => ({ name: d.label, value })),
            },
            {
                name: "quantite",
                description: "Nombre de cles a generer (par defaut 1, max 10)",
                type: ApplicationCommandOptionType.Integer,
                required: false,
            },
        ],
    },
    { name: "listkeys", description: "Voir toutes les cles enregistrees", options: [] },
    {
        name: "delkey",
        description: "Supprimer une cle",
        options: [{ name: "cle", description: "La cle a supprimer", type: ApplicationCommandOptionType.String, required: true }],
    },
    {
        name: "check",
        description: "Etat d'une cle (expire quand ?)",
        options: [{ name: "cle", description: "La cle a verifier", type: ApplicationCommandOptionType.String, required: true }],
    },
    {
        name: "extend",
        description: "Rallonger la duree d'une cle",
        options: [
            { name: "cle", description: "La cle", type: ApplicationCommandOptionType.String, required: true },
            {
                name: "duree",
                description: "Temps a rajouter par rapport a maintenant",
                type: ApplicationCommandOptionType.String,
                required: true,
                choices: Object.entries(DURATIONS).filter(([k]) => k !== "lifetime").map(([value, d]) => ({ name: "+" + d.label, value })),
            },
        ],
    },
    {
        name: "reset-hwid",
        description: "Delier une cle de son PC (remet la cle a 0 machine)",
        options: [{ name: "cle", description: "La cle", type: ApplicationCommandOptionType.String, required: true }],
    },
    {
        name: "logs",
        description: "Activer le canal de logs (usage des cles posté ici : qui, quelle clé, quel jeu)",
        options: [{ name: "canal", description: "Le canal de logs", type: ApplicationCommandOptionType.Channel, required: true }],
    },
];

// =================== CLIENT ===================
const client = new Client({ intents: [GatewayIntentBits.Guilds] });

async function registerGuildCommands(guildId) {
    const rest = new REST({ version: "10" }).setToken(DISCORD_TOKEN);
    await rest.put(Routes.applicationGuildCommands(client.user.id, guildId), { body: COMMANDS });
    console.log(`Commandes enregistrees pour le serveur ${guildId}`);
}

client.on(Events.ClientReady, async (c) => {
    console.log(`[RedTiger KeyBot] Connecte en tant que ${c.user.tag}`);

    // invite pour l'utilisateur
    const inviteUrl = `https://discord.com/oauth2/authorize?client_id=${c.user.id}&scope=bot%20applications.commands&permissions=0`;
    console.log("\n==========================================");
    console.log("INVITE LE BOT DANS TON SERVEUR VS ICI :");
    console.log(inviteUrl);
    console.log("==========================================\n");

    // base distante (jamais d'ecrasement involontaire)
    const remote = await fetchRemote();
    if (remote && typeof remote === "object") {
        keys = remote;
        console.log(`Base distante chargee : ${Object.keys(keys).filter((k) => !k.startsWith("_")).length} cle(s)`);
    } else if (remote === null) {
        console.error("Base distante illisible : le bot utilise sa sauvegarde locale jusqu'a reussite.");
    }

    // chiffre les vieilles cles en clair + prepare l'historique
    if (!KEY_SALT) {
        console.error("ERREUR : keySalt absent de config.json — impossible de continuer.");
        process.exit(1);
    }
    if (forceNormalizeKeys()) {
        console.log("Migration : cles chiffrees dans la base (plus rien en clair sur GitHub).");
        const okM = await saveKeys();
        console.log(okM ? "Migration synchronisee sur GitHub." : "ERREUR de synchro de la migration (les cles clair resteraient visibles !) — relance le bot.");
    } else {
        console.log("Base deja chiffree, rien a migrer.");
    }
    if (!PANEL_KEY) {
        console.error("ATTENTION : panelKey absent de config.json — les cles seroitas creees sans acces au panel !");
    }

    for (const g of c.guilds.cache.values()) {
        await registerGuildCommands(g.id).catch((e) => console.error("register", g.id, e.message));
    }
});

client.on(Events.GuildCreate, (guild) => {
    console.log(`Nouveau serveur : ${guild.name} (${guild.id})`);
    registerGuildCommands(guild.id).catch((e) => console.error("register", guild.id, e.message));
});

client.on(Events.InteractionCreate, async (interaction) => {
    if (!interaction.isChatInputCommand()) return;
    try {
        if (!isAuthorized(interaction)) {
            await interaction.reply({ content: "**Tu n'es pas authorize.** Cette commande est reservee aux Admin du serveur / d'un ID autorise.", ephemeral: true });
            return;
        }

        const cmd = interaction.commandName;

        if (cmd === "genkey") {
            const durationKey = interaction.options.getString("duree", true);
            const quantity    = Math.min(Math.max(interaction.options.getInteger("quantite") ?? 1, 1), 10);
            const dur         = DURATIONS[durationKey];
            const now         = Math.floor(Date.now() / 1000);
            const expires     = dur.seconds === 0 ? 0 : now + dur.seconds;

            await interaction.deferReply({ ephemeral: true });

            const created = [];
            for (let i = 0; i < quantity; i++) {
                const key = generateKey();
                const h = RT.keyHash(key, KEY_SALT);
                keys[h] = { mask: maskOf(key), duration: durationKey, created: now, expires, hwid: null };
                if (PANEL_KEY) keys[h].pkey = pkeyFor(key);
                created.push(key);
            }
            const okS = await saveKeys();

            const lines = created.map((k) => `> \`${k}\``).join("\n");
            await safeEdit(interaction,
                `**Cles generees !** (duree : **${dur.label}**) ${okS ? "Synchronise avec GitHub." : "Enregistrement local seul."}\n` +
                lines +
                (dur.seconds === 0 ? "\n*Cles a vie, jamais expireront*" : `\n*Expireront le : ${frDate(expires)}*`) +
                `\nBase : **${Object.keys(keys).filter((k) => !k.startsWith("_")).length}** cle(s) au total`
            );
            await postLog("🔑 Cles generees", `${created.length} cle(s) **${dur.label}**\n${created.map((k) => `\`${k}\``).join("\n")}${dur.seconds === 0 ? "\n*a vie*" : `\n*expire ${frDate(expires)}*`} par ${interaction.user}`, 3066993);
            return;
        }

        if (cmd === "listkeys") {
            await interaction.deferReply({ ephemeral: true });
            const entries = Object.entries(keys).filter(([k]) => !k.startsWith("_"));
            if (entries.length === 0) {
                await safeEdit(interaction, "Aucune cle dans la base. Utilise `/genkey`");
                return;
            }
            const now = Math.floor(Date.now() / 1000);
            const lines = entries.map(([h, e]) => {
                const expired = e.expires > 0 && now >= e.expires;
                const remaining = e.expires > 0 ? `${Math.max(0, e.expires - now)}s restantes` : "a vie";
                return `\`${e.mask || ("REDTIGER-****-" + h.slice(-4))}\` — ${DURATIONS[e.duration]?.label ?? e.duration}${expired ? " (expire)" : ` (${remaining})`}`;
            });
            for (let i = 0; i < lines.length; i += 25) {
                const chunk = lines.slice(i, i + 25).join("\n");
                if (i === 0) await safeEdit(interaction, `**${entries.length} cle(s) :**\n${chunk}`);
                else await interaction.followUp({ content: chunk, ephemeral: true }).catch(() => {});
            }
            return;
        }

        if (cmd === "delkey") {
            await interaction.deferReply({ ephemeral: true });
            const key = normalizeKeyInput(interaction.options.getString("cle", true));
            const h = RT.keyHash(key, KEY_SALT);
            if (!keys[h]) {
                await safeEdit(interaction, `Cle \`${maskOf(key)}\` introuvable.`);
                return;
            }
            delete keys[h];
            // historique : cette clé ne sera JAMAIS regeneree
            const retired = keys["_retired"];
            if (Array.isArray(retired) && !retired.includes(h)) retired.push(h);
            const okS = await saveKeys();
            await safeEdit(interaction, `Cle \`${maskOf(key)}\` supprimee. ${okS ? "Synchronise avec GitHub." : "Sauvegarde locale seulement."}\n(ajoutee a l'historique : jamais regeneree)\nBase : **${Object.keys(keys).filter((k) => !k.startsWith("_")).length}** cle(s)`);
            await postLog("🗑️ Cle supprimee", `\`${maskOf(key)}\` supprimee par ${interaction.user}\nSi quelqu'un l'a encore en session, il sera ejecte a la prochaine verification.`, 15158332);
            return;
        }

        if (cmd === "check") {
            await interaction.deferReply({ ephemeral: true });
            const key = normalizeKeyInput(interaction.options.getString("cle", true));
            const entry = keys[RT.keyHash(key, KEY_SALT)];
            if (!entry) {
                await safeEdit(interaction, `\`${maskOf(key)}\` : cle **invalide** (n'existe pas dans la base).`);
                return;
            }
            const now = Math.floor(Date.now() / 1000);
            const expired = entry.expires > 0 && now >= entry.expires;
            await safeEdit(interaction,
                `**${entry.mask || maskOf(key)}**\n` +
                `- Duree : **${DURATIONS[entry.duration]?.label ?? entry.duration}**\n` +
                `- Cree le : ${frDate(entry.created)}\n` +
                `- Expire le : ${frDate(entry.expires)}\n` +
                `- Statut : **${expired ? "expire" : "valide"}**\n` +
                `- HWID : ${entry.hwid ? "lie a un PC" : "delie (libre)"}`
            );
            return;
        }

        if (cmd === "extend") {
            await interaction.deferReply({ ephemeral: true });
            const key = normalizeKeyInput(interaction.options.getString("cle", true));
            const dur = DURATIONS[interaction.options.getString("duree", true)];
            const entry = keys[RT.keyHash(key, KEY_SALT)];
            if (!entry) {
                await safeEdit(interaction, `Cle \`${maskOf(key)}\` introuvable.`);
                return;
            }
            const durInfo = DURATIONS[entry.duration] ?? { seconds: 0, label: "?" };
            if (durInfo.seconds === 0) {
                await safeEdit(interaction, `Cle \`${entry.mask || maskOf(key)}\` est deja **a vie**, rien a rallonger !`);
                return;
            }
            entry.expires = Math.max(entry.expires ?? 0, Math.floor(Date.now() / 1000)) + dur.seconds;
            entry.duration = interaction.options.getString("duree", true);
            const okS = await saveKeys();
            await safeEdit(interaction, `Cle \`${entry.mask || maskOf(key)}\` : nouvelle duree **${dur.label}** (expire ${frDate(entry.expires)}) ${okS ? "Synchronise avec GitHub." : ""}`);
            return;
        }

        if (cmd === "reset-hwid") {
            await interaction.deferReply({ ephemeral: true });
            const key = normalizeKeyInput(interaction.options.getString("cle", true));
            const entry = keys[RT.keyHash(key, KEY_SALT)];
            if (!entry) {
                await safeEdit(interaction, `Cle \`${maskOf(key)}\` introuvable.`);
                return;
            }
            entry.hwid = null;
            const okS = await saveKeys();
            await safeEdit(interaction, `Cle \`${entry.mask || maskOf(key)}\` : HWID delie. Ok ${okS ? "synchronise" : "local seul"}.`);
            return;
        }

        if (cmd === "logs") {
            await interaction.deferReply({ ephemeral: true });
            const channel = interaction.options.getChannel("canal", true);

            // (re)creer le webhook du canal
            let webhook;
            try {
                webhook = await channel.createWebhook({ name: "RedTiger Logs" });
            } catch (e) {
                await safeEdit(interaction, `Impossible de creer le webhook dans <#${channel.id}> : ${e.message}`);
                return;
            }

            keys["_config"] = { logsWebhook: webhook.url };
            const okS = await saveKeys();
            await safeEdit(interaction,
                `Canal de logs configure : **<#${channel.id}>**\n` +
                `Chaque utilisation de cle (qui, quelle cle, quel jeu) sera postee ici par le panel.\n` +
                `${okS ? "Synchronise avec GitHub (les panels utilisent ca tout de suite)." : "Erreur de synchro GitHub, retente en relancant la commande."}`
            );
            try {
                await webhook.send({ embeds: [{ title: "Logs RedTiger initialisés", description: "Ce canal recevra toutes les utilisations de cles du panel", color: 3066993 }] });
            } catch { /* non bloquant */ }
            return;
        }
    } catch (e) {
        console.error("interaction err:", e);
        const msg = "Erreur : " + (e && e.message ? e.message : String(e));
        try {
            if (!interaction.deferred && !interaction.replied) {
                await interaction.reply({ content: msg, ephemeral: true }).catch(() => {});
            } else {
                await interaction.editReply(msg).catch(() => {});
            }
        } catch { /* le message est peut-etre mort : on ne peut que log la console */ }
    }
});

// =================== START ===================
client.on("error", (e) => console.error("[Client erreur]", e.message));
process.on("unhandledRejection", (e) => console.error("[Rejection non géré]", e));

// ----- verrou anti-double-instance -----
// (deux bots qui tournent en meme temps = edits "Unknown Message" + gros bugs)
const LOCK_FILE = path.join(__dirname, "bot.lock");
try {
    let otherAlive = false;
    if (fs.existsSync(LOCK_FILE)) {
        const oldPid = parseInt(fs.readFileSync(LOCK_FILE, "utf8").trim(), 10);
        if (oldPid && oldPid !== process.pid) {
            try { process.kill(oldPid, 0); otherAlive = true; } catch { /* mort */ }
        }
    }
    if (otherAlive) {
        console.error("===============================================");
        console.error("UN AUTRE REDTIGER KEYBOT TOURNE DEJA (PID " + oldPid + ")");
        console.error("Ferme cette fenetre, et ferme l'autre aussi");
        console.error("(ferme toutes les fenetres du bot puis relance)");
        console.error("===============================================");
        process.exit(1);
    }
    fs.writeFileSync(LOCK_FILE, String(process.pid));
    process.on("exit", () => {
        try {
            if (fs.readFileSync(LOCK_FILE, "utf8").trim() === String(process.pid)) fs.unlinkSync(LOCK_FILE);
        } catch { /* rien */ }
    });
} catch { /* si le verrou ne peut pas etre ecrit, on continue quand meme */ }

loadLocal();
client.login(DISCORD_TOKEN);
