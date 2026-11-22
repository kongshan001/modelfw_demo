import { ScoutApp } from "@/components/ScoutApp";
import { getAppStatus } from "@/lib/vision";

export const dynamic = "force-dynamic";

export default function HomePage() {
  const initialStatus = getAppStatus();

  return <ScoutApp initialStatus={initialStatus} />;
}
