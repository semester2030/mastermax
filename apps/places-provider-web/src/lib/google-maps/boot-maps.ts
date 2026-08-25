export async function bootLocationMaps(input: {
  loadScript: () => Promise<void>;
  createSession: () => Promise<unknown>;
  attachPin: () => Promise<void>;
  attachPinFallback?: () => Promise<void>;
}): Promise<{ ready: boolean; session: unknown }> {
  await input.loadScript();
  let session: unknown = null;
  try {
    session = await input.createSession();
  } catch {
    session = null;
  }
  try {
    await input.attachPin();
    return { ready: true, session };
  } catch {
    if (input.attachPinFallback) {
      await input.attachPinFallback();
      return { ready: true, session };
    }
    throw new Error("maps_attach_failed");
  }
}
