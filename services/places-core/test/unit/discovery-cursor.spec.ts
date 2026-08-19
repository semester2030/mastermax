import { AppError } from '../../src/shared/errors/app-error';
import { ErrorCodes } from '../../src/shared/errors/error-codes';
import { newId } from '../../src/shared/ids/ids';
import {
  CURSOR_DISTANCE_METERS_MAX,
  CURSOR_PG_INT_MAX,
  CURSOR_PRICE_MAX,
  CURSOR_PRICE_MAX_TEXT,
  DISCOVERY_FILTER_PRICE_MAX,
  cursorFromRow,
  decodeCursor,
  encodeCursor,
  formatPriceCursorSv,
} from '../../src/modules/filters/application/discovery-cursor';

function expectValidation(fn: () => unknown): void {
  try {
    fn();
    throw new Error('expected VALIDATION_ERROR');
  } catch (e) {
    expect(e).toBeInstanceOf(AppError);
    expect((e as AppError).code).toBe(ErrorCodes.VALIDATION_ERROR);
  }
}

describe('discovery-cursor numeric range hardening (pre-SQL)', () => {
  const id = () => newId();

  it('accepts valid cursors for every sort including prices above filter max', () => {
    expect(
      decodeCursor(
        encodeCursor({ v: 1, sort: 'best', sv: '4.5', sv2: '12', id: id() }),
        'best',
      ).sv,
    ).toBe('4.5');
    expect(
      decodeCursor(
        encodeCursor({ v: 1, sort: 'cheapest', sv: '1000001', id: id() }),
        'cheapest',
      ).sv,
    ).toBe('1000001');
    expect(
      decodeCursor(
        encodeCursor({ v: 1, sort: 'most_expensive', sv: CURSOR_PRICE_MAX_TEXT, id: id() }),
        'most_expensive',
      ).sv,
    ).toBe(CURSOR_PRICE_MAX_TEXT);
    expect(
      decodeCursor(encodeCursor({ v: 1, sort: 'cheapest', sv: null, id: id() }), 'cheapest').sv,
    ).toBeNull();
    expect(
      decodeCursor(
        encodeCursor({
          v: 1,
          sort: 'near_me',
          sv: String(CURSOR_DISTANCE_METERS_MAX),
          id: id(),
        }),
        'near_me',
      ).sv,
    ).toBe(String(CURSOR_DISTANCE_METERS_MAX));
    expect(
      decodeCursor(
        encodeCursor({ v: 1, sort: 'newest', sv: '2031-06-15T12:30:00.000Z', id: id() }),
        'newest',
      ).sv,
    ).toBe('2031-06-15T12:30:00.000Z');
    expect(DISCOVERY_FILTER_PRICE_MAX).toBe(1_000_000);
    expect(CURSOR_PRICE_MAX).toBe(9_999_999_999.99);
  });

  it('price cursor round-trip cursorFromRow → encode → decode', () => {
    for (const price of ['1000001', '1000001.5', '9999999999.99', '0', '12.34']) {
      const encoded = cursorFromRow('cheapest', {
        id: id(),
        starting_price_hint: price,
      });
      const decoded = decodeCursor(encoded, 'cheapest');
      expect(decoded.sv).toBe(formatPriceCursorSv(price));
    }
  });

  it('rejects price above NUMERIC(12,2) and more than 2 decimals', () => {
    expectValidation(() =>
      decodeCursor(
        encodeCursor({ v: 1, sort: 'cheapest', sv: '10000000000', id: id() }),
        'cheapest',
      ),
    );
    expectValidation(() =>
      decodeCursor(
        encodeCursor({ v: 1, sort: 'cheapest', sv: '9999999999.999', id: id() }),
        'cheapest',
      ),
    );
    expectValidation(() =>
      decodeCursor(encodeCursor({ v: 1, sort: 'cheapest', sv: '-1', id: id() }), 'cheapest'),
    );
  });

  it('rejects rating sv outside NUMERIC(4,2) range and bad sv2 before SQL', () => {
    expect(() =>
      decodeCursor(encodeCursor({ v: 1, sort: 'rating', sv: '5.01', sv2: '1', id: id() }), 'rating'),
    ).not.toThrow();
    expectValidation(() =>
      decodeCursor(encodeCursor({ v: 1, sort: 'rating', sv: '100.00', sv2: '1', id: id() }), 'rating'),
    );
    expectValidation(() =>
      decodeCursor(encodeCursor({ v: 1, sort: 'rating', sv: '-0.1', sv2: '1', id: id() }), 'rating'),
    );
    expectValidation(() =>
      decodeCursor(encodeCursor({ v: 1, sort: 'rating', sv: '4', sv2: '-1', id: id() }), 'rating'),
    );
    expectValidation(() =>
      decodeCursor(encodeCursor({ v: 1, sort: 'rating', sv: '4', sv2: '1.5', id: id() }), 'rating'),
    );
    expectValidation(() =>
      decodeCursor(
        encodeCursor({
          v: 1,
          sort: 'rating',
          sv: '4',
          sv2: String(CURSOR_PG_INT_MAX + 1),
          id: id(),
        }),
        'rating',
      ),
    );
  });

  it('rejects distance OOB, NaN/Infinity, exponent, unexpected sv2', () => {
    expectValidation(() =>
      decodeCursor(encodeCursor({ v: 1, sort: 'near_me', sv: '-1', id: id() }), 'near_me'),
    );
    expectValidation(() =>
      decodeCursor(
        encodeCursor({
          v: 1,
          sort: 'near_me',
          sv: String(CURSOR_DISTANCE_METERS_MAX + 1),
          id: id(),
        }),
        'near_me',
      ),
    );
    for (const token of ['NaN', 'Infinity', '-Infinity', 'abc', '1e3']) {
      expectValidation(() =>
        decodeCursor(encodeCursor({ v: 1, sort: 'cheapest', sv: token, id: id() }), 'cheapest'),
      );
    }
    expectValidation(() =>
      decodeCursor(
        encodeCursor({ v: 1, sort: 'cheapest', sv: '10', sv2: '1', id: id() }),
        'cheapest',
      ),
    );
  });

  it('newest impossible date regression still VALIDATION_ERROR', () => {
    expectValidation(() =>
      decodeCursor(
        encodeCursor({ v: 1, sort: 'newest', sv: '2035-99-99T99:99:99Z', id: id() }),
        'newest',
      ),
    );
  });
});
