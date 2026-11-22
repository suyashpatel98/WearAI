import Constants from "expo-constants";
import { StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { appEnv } from "@/lib/env";

// Placeholder until the first product slice. Shows which environment and commit this build is.
export default function HomeScreen() {
  const commitSha =
    (Constants.expoConfig?.extra?.commitSha as string | undefined) ?? "unknown";

  return (
    <SafeAreaView style={styles.screen}>
      {appEnv === "local" && (
        <View
          style={styles.badge}
          accessibilityLabel="Pointing at the local Supabase stack"
        >
          <Text style={styles.badgeText}>LOCAL</Text>
        </View>
      )}
      <View style={styles.center}>
        <Text style={styles.title}>WearAI</Text>
        <Text style={styles.meta}>
          {Constants.expoConfig?.version} · {commitSha}
        </Text>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: "#fff" },
  badge: {
    position: "absolute",
    top: 48,
    right: 16,
    zIndex: 1,
    backgroundColor: "#E5484D",
    borderRadius: 6,
    paddingHorizontal: 8,
    paddingVertical: 3,
  },
  badgeText: {
    color: "#fff",
    fontWeight: "700",
    fontSize: 12,
    letterSpacing: 1,
  },
  center: { flex: 1, alignItems: "center", justifyContent: "center", gap: 8 },
  title: { fontSize: 32, fontWeight: "700", color: "#111" },
  meta: { fontSize: 14, color: "#666", fontVariant: ["tabular-nums"] },
});
