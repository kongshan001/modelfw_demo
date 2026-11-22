import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        paper: "#F3EEE3",
        cream: "#FBF8F0",
        ink: "#1C1914",
        muted: "#6C6558",
        line: "#DCD3C2",
        vermilion: "#C5482B",
        "vermilion-dark": "#A9371E",
        teal: "#0D6A5A",
        "teal-soft": "#DDEBE5",
        gold: "#A8792C",
        "gold-soft": "#F2E7CE",
        blush: "#F4DED4"
      },
      fontFamily: {
        display: ["Songti SC", "STSong", "Noto Serif SC", "Georgia", "serif"],
        sans: [
          "-apple-system",
          "BlinkMacSystemFont",
          "PingFang SC",
          "Hiragino Sans GB",
          "Microsoft YaHei",
          "sans-serif"
        ],
        mono: ["SFMono-Regular", "Menlo", "Consolas", "monospace"]
      },
      boxShadow: {
        card: "0 1px 0 rgba(28,25,20,0.04), 0 18px 45px -30px rgba(28,25,20,0.35)",
        lift: "0 20px 55px -28px rgba(28,25,20,0.45)"
      },
      keyframes: {
        rise: {
          "0%": { opacity: "0", transform: "translateY(10px)" },
          "100%": { opacity: "1", transform: "translateY(0)" }
        },
        sweep: {
          "0%": { transform: "translateX(-100%)" },
          "100%": { transform: "translateX(350%)" }
        },
        pulseSoft: {
          "0%, 100%": { opacity: "0.55" },
          "50%": { opacity: "1" }
        }
      },
      animation: {
        rise: "rise 420ms cubic-bezier(0.22,1,0.36,1) both",
        sweep: "sweep 1.6s ease-in-out infinite",
        pulseSoft: "pulseSoft 1.8s ease-in-out infinite"
      }
    }
  },
  plugins: []
};

export default config;
