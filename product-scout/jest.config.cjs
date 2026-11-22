/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: "node",
  roots: ["<rootDir>/src"],
  testMatch: ["**/__tests__/**/*.test.ts"],
  moduleNameMapper: {
    "^@/(.*)$": "<rootDir>/src/$1"
  },
  transform: {
    "^.+\\.ts$": [
      "ts-jest",
      {
        tsconfig: {
          target: "es2022",
          module: "commonjs",
          moduleResolution: "node",
          strict: true,
          esModuleInterop: true,
          skipLibCheck: true
        }
      }
    ]
  },
  clearMocks: true
};
