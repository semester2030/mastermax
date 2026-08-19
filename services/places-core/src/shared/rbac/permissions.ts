export type ProviderRole = 'owner' | 'manager' | 'front_desk' | 'finance' | 'content' | 'pricing';

export type Permission =
  | 'venue.crud'
  | 'venue.publish'
  | 'media.upload'
  | 'inventory.block'
  | 'pricing.edit'
  | 'calendar.edit'
  | 'bookings.view'
  | 'bookings.checkin'
  | 'bookings.cancel'
  | 'finance.view'
  | 'team.manage';

const MATRIX: Record<ProviderRole, Permission[]> = {
  owner: [
    'venue.crud',
    'venue.publish',
    'media.upload',
    'inventory.block',
    'pricing.edit',
    'calendar.edit',
    'bookings.view',
    'bookings.checkin',
    'bookings.cancel',
    'finance.view',
    'team.manage',
  ],
  manager: [
    'venue.crud',
    'venue.publish',
    'media.upload',
    'inventory.block',
    'pricing.edit',
    'calendar.edit',
    'bookings.view',
    'bookings.checkin',
    'bookings.cancel',
  ],
  front_desk: ['inventory.block', 'calendar.edit', 'bookings.view', 'bookings.checkin'],
  finance: ['bookings.view', 'finance.view'],
  content: ['venue.publish', 'media.upload'],
  pricing: ['pricing.edit'],
};

export function can(role: ProviderRole, permission: Permission): boolean {
  return MATRIX[role].includes(permission);
}
