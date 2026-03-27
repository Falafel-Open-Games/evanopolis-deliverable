import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname } from "node:path";

import { roomRecordSchema, type RoomRecord } from "./schemas/rooms.js";

export class RoomsStore {
  #rooms = new Map<string, RoomRecord>();
  #roomsDataFile: string;

  constructor(roomsDataFile = "") {
    this.#roomsDataFile = roomsDataFile;
  }

  async initialize(): Promise<void> {
    if (!this.#roomsDataFile) {
      return;
    }

    try {
      const raw = await readFile(this.#roomsDataFile, "utf8");
      const parsed = JSON.parse(raw);
      if (!Array.isArray(parsed)) {
        throw new Error("rooms_data_file_must_contain_an_array");
      }

      for (const [index, roomValue] of parsed.entries()) {
        const roomResult = roomRecordSchema.safeParse(roomValue);
        if (!roomResult.success) {
          console.warn(
            `Skipping incompatible room record at index ${index} in ${this.#roomsDataFile}: ${roomResult.error.message}`,
          );
          continue;
        }

        const room = roomResult.data;
        this.#rooms.set(room.game_id, room);
      }
    } catch (error) {
      if (
        error &&
        typeof error === "object" &&
        "code" in error &&
        error.code === "ENOENT"
      ) {
        return;
      }
      throw error;
    }
  }

  async createRoom(room: RoomRecord): Promise<RoomRecord> {
    this.#rooms.set(room.game_id, room);
    await this.#persist();
    return room;
  }

  getRoom(gameId: string): RoomRecord | null {
    return this.#rooms.get(gameId) ?? null;
  }

  async #persist(): Promise<void> {
    if (!this.#roomsDataFile) {
      return;
    }

    const directory = dirname(this.#roomsDataFile);
    const tempPath = `${this.#roomsDataFile}.tmp`;
    const payload = JSON.stringify(Array.from(this.#rooms.values()), null, 2);

    await mkdir(directory, { recursive: true });
    await writeFile(tempPath, payload);
    await rename(tempPath, this.#roomsDataFile);
  }
}
