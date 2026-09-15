export function nextClientDataRevision(
  existingRevision: number | null,
  expectedVersion: number | undefined,
) {
  if (existingRevision == null) {
    if (expectedVersion !== undefined) throw new Error('CLIENT_DATA_CONFLICT');
    return 1;
  }
  if (expectedVersion !== existingRevision) {
    throw new Error('CLIENT_DATA_CONFLICT');
  }
  return existingRevision + 1;
}