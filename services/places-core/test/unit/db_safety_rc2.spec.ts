import { assertCiDatabaseUrl } from '../helpers/db-safety';

describe('db-safety Wave1 RC2', () => {
  it('refuses places_core_test staging', () => {
    expect(() =>
      assertCiDatabaseUrl('postgresql://127.0.0.1:5432/places_core_test'),
    ).toThrow(/places_core_test/);
  });

  it('refuses non-_ci names', () => {
    expect(() =>
      assertCiDatabaseUrl('postgresql://127.0.0.1:5432/places_core_dev'),
    ).toThrow(/_ci/);
  });

  it('allows places_core_ci', () => {
    expect(
      assertCiDatabaseUrl('postgresql://127.0.0.1:5432/places_core_ci'),
    ).toContain('places_core_ci');
  });
});
