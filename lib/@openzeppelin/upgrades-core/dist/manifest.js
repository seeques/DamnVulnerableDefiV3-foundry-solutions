"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.normalizeManifestData = exports.DeploymentNotFound = exports.migrateManifest = exports.Manifest = void 0;
const path_1 = __importDefault(require("path"));
const fs_1 = require("fs");
const provider_1 = require("./provider");
const proper_lockfile_1 = __importDefault(require("proper-lockfile"));
const compare_versions_1 = require("compare-versions");
const pick_1 = require("./utils/pick");
const map_values_1 = require("./utils/map-values");
const error_1 = require("./error");
const currentManifestVersion = '3.2';
function defaultManifest() {
    return {
        manifestVersion: currentManifestVersion,
        impls: {},
        proxies: [],
    };
}
const manifestDir = '.openzeppelin';
class Manifest {
    constructor(chainId) {
        this.locked = false;
        this.chainId = chainId;
        const fallbackName = `unknown-${this.chainId}`;
        this.fallbackFile = path_1.default.join(manifestDir, `${fallbackName}.json`);
        const name = provider_1.networkNames[this.chainId] ?? fallbackName;
        this.file = path_1.default.join(manifestDir, `${name}.json`);
    }
    static async forNetwork(provider) {
        return new Manifest(await (0, provider_1.getChainId)(provider));
    }
    async getAdmin() {
        return (await this.read()).admin;
    }
    async getDeploymentFromAddress(address) {
        const data = await this.read();
        const deployment = Object.values(data.impls).find(d => d?.address === address || d?.allAddresses?.includes(address));
        if (deployment === undefined) {
            throw new DeploymentNotFound(`Deployment at address ${address} is not registered`);
        }
        return deployment;
    }
    async getProxyFromAddress(address) {
        const data = await this.read();
        const deployment = data.proxies.find(d => d?.address === address);
        if (deployment === undefined) {
            throw new DeploymentNotFound(`Proxy at address ${address} is not registered`);
        }
        return deployment;
    }
    async addProxy(proxy) {
        await this.lockedRun(async () => {
            const data = await this.read();
            const existing = data.proxies.findIndex(p => p.address === proxy.address);
            if (existing >= 0) {
                data.proxies.splice(existing, 1);
            }
            data.proxies.push(proxy);
            await this.write(data);
        });
    }
    async exists(file) {
        try {
            await fs_1.promises.access(file);
            return true;
        }
        catch (e) {
            return false;
        }
    }
    async readFile() {
        if (this.file === this.fallbackFile) {
            return await fs_1.promises.readFile(this.file, 'utf8');
        }
        else {
            const fallbackExists = await this.exists(this.fallbackFile);
            const fileExists = await this.exists(this.file);
            if (fileExists && fallbackExists) {
                throw new error_1.UpgradesError(`Network files with different names ${this.fallbackFile} and ${this.file} were found for the same network.`, () => `More than one network file was found for chain ID ${this.chainId}. Determine which file is the most up to date version, then take a backup of and delete the other file.`);
            }
            else if (fallbackExists) {
                return await fs_1.promises.readFile(this.fallbackFile, 'utf8');
            }
            else {
                return await fs_1.promises.readFile(this.file, 'utf8');
            }
        }
    }
    async writeFile(content) {
        await this.renameFileIfRequired();
        await fs_1.promises.writeFile(this.file, content);
    }
    async renameFileIfRequired() {
        if (this.file !== this.fallbackFile && (await this.exists(this.fallbackFile))) {
            try {
                await fs_1.promises.rename(this.fallbackFile, this.file);
            }
            catch (e) {
                throw new Error(`Failed to rename network file from ${this.fallbackFile} to ${this.file}: ${e.message}`);
            }
        }
    }
    async read() {
        const release = this.locked ? undefined : await this.lock();
        try {
            const data = JSON.parse(await this.readFile());
            return validateOrUpdateManifestVersion(data);
        }
        catch (e) {
            if (e.code === 'ENOENT') {
                return defaultManifest();
            }
            else {
                throw e;
            }
        }
        finally {
            await release?.();
        }
    }
    async write(data) {
        if (!this.locked) {
            throw new Error('Manifest must be locked');
        }
        const normalized = normalizeManifestData(data);
        await this.writeFile(JSON.stringify(normalized, null, 2) + '\n');
    }
    async lockedRun(cb) {
        if (this.locked) {
            throw new Error('Manifest is already locked');
        }
        const release = await this.lock();
        try {
            return await cb();
        }
        finally {
            await release();
        }
    }
    async lock() {
        const lockfileName = path_1.default.join(manifestDir, `chain-${this.chainId}`);
        await fs_1.promises.mkdir(path_1.default.dirname(lockfileName), { recursive: true });
        const release = await proper_lockfile_1.default.lock(lockfileName, { retries: 3, realpath: false });
        this.locked = true;
        return async () => {
            await release();
            this.locked = false;
        };
    }
}
exports.Manifest = Manifest;
function validateOrUpdateManifestVersion(data) {
    if (typeof data.manifestVersion !== 'string') {
        throw new Error('Manifest version is missing');
    }
    else if ((0, compare_versions_1.compare)(data.manifestVersion, '3.0', '<')) {
        throw new Error('Found a manifest file for OpenZeppelin CLI. An automated migration is not yet available.');
    }
    else if ((0, compare_versions_1.compare)(data.manifestVersion, currentManifestVersion, '<')) {
        return migrateManifest(data);
    }
    else if (data.manifestVersion === currentManifestVersion) {
        return data;
    }
    else {
        throw new Error(`Unknown value for manifest version (${data.manifestVersion})`);
    }
}
function migrateManifest(data) {
    switch (data.manifestVersion) {
        case '3.0':
        case '3.1':
            data.manifestVersion = currentManifestVersion;
            data.proxies = [];
            return data;
        default:
            throw new Error('Manifest migration not available');
    }
}
exports.migrateManifest = migrateManifest;
class DeploymentNotFound extends Error {
}
exports.DeploymentNotFound = DeploymentNotFound;
function normalizeManifestData(input) {
    return {
        manifestVersion: input.manifestVersion,
        admin: input.admin && normalizeDeployment(input.admin),
        proxies: input.proxies.map(p => normalizeDeployment(p, ['kind'])),
        impls: (0, map_values_1.mapValues)(input.impls, i => i && normalizeDeployment(i, ['layout', 'allAddresses'])),
    };
}
exports.normalizeManifestData = normalizeManifestData;
function normalizeDeployment(input, include = []) {
    return (0, pick_1.pick)(input, ['address', 'txHash', ...include]);
}
//# sourceMappingURL=manifest.js.map