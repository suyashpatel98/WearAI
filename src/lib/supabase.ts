import "expo-sqlite/localStorage/install";

import { createClient } from "@supabase/supabase-js";
import { AppState, type AppStateStatus } from "react-native";

import type { Database } from "@/db";
import { supabasePublishableKey, supabaseUrl } from "@/lib/env";

// The session is kept on the phone (expo-sqlite's localStorage). There is no browser URL to read
// a session from, and tokens refresh only while the app is in the foreground.
export const supabase = createClient<Database>(
  supabaseUrl,
  supabasePublishableKey,
  {
    auth: {
      storage: localStorage,
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: false,
    },
  },
);

function onAppStateChange(state: AppStateStatus) {
  if (state === "active") {
    void supabase.auth.startAutoRefresh();
  } else {
    void supabase.auth.stopAutoRefresh();
  }
}

AppState.addEventListener("change", onAppStateChange);
