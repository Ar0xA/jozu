// Runs the board generator off the page's main thread, so the game keeps drawing while it thinks.
import { dotnet } from './_framework/dotnet.js';

let api = null;
const ready = (async () => {
	const { getAssemblyExports, getConfig } = await dotnet.create();
	const exports = await getAssemblyExports(getConfig().mainAssemblyName);
	api = exports.Web;
	postMessage({ ready: true });
})().catch((e) => postMessage({ error: String(e) }));

onmessage = async (ev) => {
	await ready;
	const a = ev.data;
	try {
		postMessage({ id: a.id, out: api ? api.Make(a.seed, a.lo, a.hi, a.budget, a.bracket, a.order || 0) : '' });
	} catch (e) {
		postMessage({ id: a.id, error: String(e) });
	}
};
