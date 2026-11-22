// Public values only, exported by the mise task from env/local.env or env/hosted.env (docs/spec/dev-ex.md#secrets).
// Expo inlines EXPO_PUBLIC_* only when read as process.env.NAME, so each one is spelled out.

export type AppEnv = "local" | "hosted";

function required(name: string, value: string | undefined): string {
  if (!value)
    throw new Error(
      `${name} is not set. Start Metro with mise run dev or mise run dev:hosted.`,
    );
  return value;
}

export const appEnv: AppEnv =
  process.env.EXPO_PUBLIC_APP_ENV === "hosted" ? "hosted" : "local";

export const supabaseUrl = required(
  "EXPO_PUBLIC_SUPABASE_URL",
  process.env.EXPO_PUBLIC_SUPABASE_URL,
);

export const supabasePublishableKey = required(
  "EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY",
  process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
);
