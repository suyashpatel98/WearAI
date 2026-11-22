/// <reference types="node" />
import { execSync } from "node:child_process";
import type { ConfigContext, ExpoConfig } from "expo/config";

// Two Android apps that install side by side (docs/spec/dev-ex.md#two-app-variants-side-by-side).
// APP_VARIANT picks the package; APP_ENV (via the env files) picks the Supabase project.
const variant =
  process.env.APP_VARIANT === "release" ? "release" : "development";

const VARIANTS = {
  development: { name: "WearAI Dev", package: "app.wearai.dev" },
  release: { name: "WearAI", package: "app.wearai" },
} as const;

function git(command: string, fallback: string): string {
  try {
    return execSync(`git ${command}`, { stdio: ["ignore", "pipe", "ignore"] })
      .toString()
      .trim();
  } catch {
    return fallback;
  }
}

// versionCode always goes up: it's the commit count on the built commit.
const commitCount = Number(git("rev-list --count HEAD", "1"));
const commitSha = git("rev-parse --short HEAD", "unknown");

export default ({ config }: ConfigContext): ExpoConfig => ({
  ...config,
  name: VARIANTS[variant].name,
  slug: "wearai",
  version: `0.1.${commitCount}`,
  orientation: "portrait",
  icon: "./assets/images/icon.png",
  scheme: variant === "release" ? "wearai" : "wearai-dev",
  userInterfaceStyle: "automatic",
  platforms: ["android"],
  android: {
    package: VARIANTS[variant].package,
    versionCode: commitCount,
    adaptiveIcon: {
      backgroundColor: "#E6F4FE",
      foregroundImage: "./assets/images/android-icon-foreground.png",
      backgroundImage: "./assets/images/android-icon-background.png",
      monochromeImage: "./assets/images/android-icon-monochrome.png",
    },
    predictiveBackGestureEnabled: false,
  },
  plugins: [
    "expo-router",
    "expo-sqlite",
    [
      "expo-splash-screen",
      {
        backgroundColor: "#208AEF",
        image: "./assets/images/splash-icon.png",
        imageWidth: 76,
      },
    ],
  ],
  experiments: {
    typedRoutes: true,
    reactCompiler: true,
  },
  extra: {
    variant,
    commitSha,
  },
});
