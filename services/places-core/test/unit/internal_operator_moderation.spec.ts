import { assertInternalOperatorModeration } from "../../src/modules/venues/application/internal-operator-moderation";

describe("internal operator media moderation", () => {
  const previous = process.env.NODE_ENV;

  afterEach(() => {
    process.env.NODE_ENV = previous;
  });

  it("allows the bound internal operator in production", () => {
    process.env.NODE_ENV = "production";
    expect(() =>
      assertInternalOperatorModeration({
        uid: "op:prod",
        claims: { placesInternalOperator: true },
        onBehalfOfProviderId: "11111111-1111-4111-8111-111111111111",
      }),
    ).not.toThrow();
  });

  it("still refuses a provider user without the operator claim", () => {
    process.env.NODE_ENV = "production";
    expect(() =>
      assertInternalOperatorModeration({
        uid: "provider-1",
        claims: { placesProvider: true },
      }),
    ).toThrow(/placesInternalOperator required/);
  });
});
