export function isRealLoginHost(hostHeader: string | undefined): boolean {
  return hostHeader !== undefined && /^localhost(?::\d+)?$/.test(hostHeader);
}
