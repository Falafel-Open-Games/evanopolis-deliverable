import { z } from "zod";

const envSchema = z.object({
  PORT: z.coerce.number().int().positive().default(3001),
  AUTH_BASE_URL: z.string().url(),
  AUTH_VERIFY_PATH: z.string().default("/whoami"),
  ALLOWED_ORIGINS: z.string().default(""),
  ROOMS_DATA_FILE: z.string().default(""),
});

export type AppConfig = z.infer<typeof envSchema>;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const parsed = envSchema.safeParse(env);
  if (!parsed.success) {
    const issues = parsed.error.issues.map(
      (issue) => `${issue.path.join(".")}: ${issue.message}`,
    );
    throw new Error(`Invalid configuration:\n${issues.join("\n")}`);
  }
  return parsed.data;
}

export function parseAllowedOrigins(config: AppConfig): string[] {
  return config.ALLOWED_ORIGINS.split(",")
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);
}
