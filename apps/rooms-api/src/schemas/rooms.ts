import { z } from "zod";

const experimentalSchema = z
  .object({
    board_size: z.number().int().positive().optional(),
    turn_duration_seconds: z.number().int().positive().optional(),
  })
  .strict();

export const createRoomRequestSchema = z
  .object({
    player_count: z.union([z.literal(2), z.literal(3), z.literal(4)]),
    experimental: experimentalSchema.optional(),
  })
  .strict();

export const roomRecordSchema = z
  .object({
    game_id: z.string().uuid(),
    created_by: z.string().min(1),
    player_count: z.union([z.literal(2), z.literal(3), z.literal(4)]),
    experimental: experimentalSchema.optional(),
    created_at: z.string().datetime(),
  })
  .strict();

export type CreateRoomRequest = z.infer<typeof createRoomRequestSchema>;
export type RoomRecord = z.infer<typeof roomRecordSchema>;
