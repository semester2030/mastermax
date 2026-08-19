/**
 * Gate 7B.4 — Diversity policy + applied profile (pure, no SQL).
 */
import {
  diversityAppliedMeta,
  resolveAppliedProfile,
  resolveDiversityPolicy,
} from '../../src/modules/filters/application/discovery-diversity-policy';
import {
  DIVERSITY_K_DEFAULT,
  DIVERSITY_VERSION_CURRENT,
} from '../../src/modules/filters/application/discovery-cursor-v2';
import { applyDiscoveryDefaults } from '../../src/modules/filters/application/discovery-query';

describe('Gate 7B.4 — G7B4-DIV-01 activation matrix', () => {
  const cases: Array<{
    name: string;
    input: { surface?: string; category?: string; sort?: string; q?: string };
    applied: boolean;
  }> = [
    { name: 'feed+best', input: { surface: 'feed', sort: 'best' }, applied: true },
    { name: 'feed+newest', input: { surface: 'feed', sort: 'newest' }, applied: true },
    { name: 'feed+default sort', input: { surface: 'feed' }, applied: true },
    {
      name: 'feed+category',
      input: { surface: 'feed', category: 'hotel', sort: 'newest' },
      applied: false,
    },
    { name: 'map+best', input: { surface: 'map', sort: 'best' }, applied: false },
    { name: 'circle+best', input: { surface: 'circle', sort: 'best' }, applied: false },
    { name: 'search+best', input: { surface: 'search', sort: 'best' }, applied: false },
    { name: 'feed+rating', input: { surface: 'feed', sort: 'rating' }, applied: false },
    { name: 'feed+cheapest', input: { surface: 'feed', sort: 'cheapest' }, applied: false },
    {
      name: 'feed+most_expensive',
      input: { surface: 'feed', sort: 'most_expensive' },
      applied: false,
    },
    {
      name: 'feed+near_me',
      input: { surface: 'feed', sort: 'near_me' },
      applied: false,
    },
    {
      name: 'feed+near_place',
      input: { surface: 'feed', sort: 'near_place' },
      applied: false,
    },
    {
      name: 'feed+q→search_rank',
      input: { surface: 'feed', q: 'فندق' },
      applied: false,
    },
  ];

  for (const c of cases) {
    it(`G7B4-DIV-01 ${c.name} → applied=${c.applied}`, () => {
      const d = applyDiscoveryDefaults(c.input as never);
      const p = resolveDiversityPolicy(d);
      expect(p.applied).toBe(c.applied);
      expect(p.mode).toBe(c.applied ? 'required' : 'forbidden');
      expect(p.version).toBe(c.applied ? DIVERSITY_VERSION_CURRENT : 0);
      expect(p.k).toBe(c.applied ? DIVERSITY_K_DEFAULT : 0);
      expect(diversityAppliedMeta(p).applied).toBe(c.applied);
    });
  }

  it('G7B4-SAME profile same_type_near_place only for circle+near_place+sameTypeOnly', () => {
    expect(
      resolveAppliedProfile({
        surface: 'circle',
        sort: 'near_place',
        sameTypeOnly: true,
      }),
    ).toBe('same_type_near_place');
    expect(
      resolveAppliedProfile({
        surface: 'circle',
        sort: 'near_place',
        sameTypeOnly: false,
      }),
    ).toBeNull();
    expect(
      resolveAppliedProfile({ surface: 'search', sort: 'near_place', sameTypeOnly: true }),
    ).toBeNull();
  });
});
