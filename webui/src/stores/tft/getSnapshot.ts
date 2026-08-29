export async function getSnapshot() {
  const resp = await fetch("/api/services/tft");

  if (!resp.ok) {
    throw new Error(`Failed to fetch - ${resp.status} ${resp.statusText}`);
  }

  return resp.json();
}
