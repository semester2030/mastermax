import { ProviderShell } from "@/components/provider-shell";
import { getSessionProviderId } from "@/lib/auth/session";

/** Auth session + client forms — never statically prerender. */
export const dynamic = "force-dynamic";

export default async function AppLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const providerId = await getSessionProviderId();
  return <ProviderShell providerId={providerId}>{children}</ProviderShell>;
}
