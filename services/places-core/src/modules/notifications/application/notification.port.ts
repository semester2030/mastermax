export interface NotificationPort {
  handle(eventName: string, payload: Record<string, unknown>): Promise<void>;
}

export const NOTIFICATION_PORT = Symbol('NOTIFICATION_PORT');
