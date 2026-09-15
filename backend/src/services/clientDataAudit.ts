import type { PoolConnection } from 'mysql2/promise';

export async function recordClientDataChange(
  connection: PoolConnection,
  clientId: number,
  actorUserId: number,
  changeType: string,
  payload: unknown,
) {
  await connection.execute(
    `INSERT INTO client_data_change_log (
       client_id, actor_user_id, change_type, payload_json
     ) VALUES (?, ?, ?, ?)`,
    [clientId, actorUserId, changeType, JSON.stringify(payload)],
  );
}