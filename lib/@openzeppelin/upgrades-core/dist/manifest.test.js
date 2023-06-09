"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const ava_1 = __importDefault(require("ava"));
const manifest_1 = require("./manifest");
const fs_1 = require("fs");
const path_1 = __importDefault(require("path"));
async function writeTestManifest(file) {
    const testManifest = {
        manifestVersion: '3.2',
        impls: {},
        proxies: [
            {
                address: '0x123',
                txHash: '0x0',
                kind: 'uups',
            },
        ],
    };
    await fs_1.promises.mkdir(path_1.default.dirname(file), { recursive: true });
    await fs_1.promises.writeFile(file, JSON.stringify(testManifest, null, 2) + '\n');
}
async function deleteFile(t, file) {
    try {
        await fs_1.promises.unlink(file);
    }
    catch (e) {
        if (!e.message.includes('ENOENT')) {
            t.fail(e);
        }
    }
}
async function assertOldName(t, id) {
    await fs_1.promises.access(`.openzeppelin/unknown-${id}.json`);
    t.throwsAsync(fs_1.promises.access(`.openzeppelin/polygon-mumbai.json`));
}
async function assertNewName(t, id) {
    t.throwsAsync(fs_1.promises.access(`.openzeppelin/unknown-${id}.json`));
    await fs_1.promises.access(`.openzeppelin/polygon-mumbai.json`);
}
async function deleteManifests(t, id) {
    await deleteFile(t, `.openzeppelin/unknown-${id}.json`);
    await deleteFile(t, '.openzeppelin/polygon-mumbai.json');
}
ava_1.default.serial('multiple manifests', async (t) => {
    const id = 80001;
    await deleteManifests(t, id);
    await writeTestManifest(`.openzeppelin/unknown-${id}.json`);
    await writeTestManifest(`.openzeppelin/polygon-mumbai.json`);
    const manifest = new manifest_1.Manifest(id);
    await manifest.lockedRun(async () => {
        await t.throwsAsync(() => manifest.read(), {
            message: new RegExp(`Network files with different names .openzeppelin/unknown-${id}.json and .openzeppelin/polygon-mumbai.json were found for the same network.`),
        });
    });
    await deleteManifests(t, id);
});
ava_1.default.serial('rename manifest', async (t) => {
    const id = 80001;
    await deleteManifests(t, id);
    await writeTestManifest(`.openzeppelin/unknown-${id}.json`);
    const manifest = new manifest_1.Manifest(id);
    t.is(manifest.file, `.openzeppelin/polygon-mumbai.json`);
    t.throwsAsync(fs_1.promises.access(`.openzeppelin/chain-${id}.lock`));
    await assertOldName(t, id);
    await manifest.lockedRun(async () => {
        await fs_1.promises.access(`.openzeppelin/chain-${id}.lock`);
        const data = await manifest.read();
        data.proxies.push({
            address: '0x456',
            txHash: '0x0',
            kind: 'uups',
        });
        await assertOldName(t, id);
        await manifest.write(data);
        await assertNewName(t, id);
    });
    await assertNewName(t, id);
    t.throwsAsync(fs_1.promises.access(`.openzeppelin/chain-${id}.lock`));
    // check that the contents were persisted
    const data = await new manifest_1.Manifest(id).read();
    t.true(data.proxies[0].address === '0x123');
    t.true(data.proxies[1].address === '0x456');
    await assertNewName(t, id);
    t.throwsAsync(fs_1.promises.access(`.openzeppelin/chain-${id}.lock`));
    await deleteManifests(t, id);
});
(0, ava_1.default)('manifest name for a known network', t => {
    const manifest = new manifest_1.Manifest(1);
    t.is(manifest.file, '.openzeppelin/mainnet.json');
});
(0, ava_1.default)('manifest name for an unknown network', t => {
    const id = 55555;
    const manifest = new manifest_1.Manifest(id);
    t.is(manifest.file, `.openzeppelin/unknown-${id}.json`);
});
(0, ava_1.default)('normalize manifest', t => {
    const deployment = {
        address: '0x1234',
        txHash: '0x1234',
        kind: 'uups',
        layout: { types: {}, storage: [] },
        deployTransaction: {},
    };
    const input = {
        manifestVersion: '3.0',
        admin: deployment,
        impls: { a: deployment },
        proxies: [deployment],
    };
    const norm = (0, manifest_1.normalizeManifestData)(input);
    t.like(norm.admin, {
        ...deployment,
        kind: undefined,
        layout: undefined,
        deployTransaction: undefined,
    });
    t.like(norm.impls.a, {
        ...deployment,
        kind: undefined,
        deployTransaction: undefined,
    });
    t.like(norm.proxies[0], {
        ...deployment,
        layout: undefined,
        deployTransaction: undefined,
    });
});
//# sourceMappingURL=manifest.test.js.map