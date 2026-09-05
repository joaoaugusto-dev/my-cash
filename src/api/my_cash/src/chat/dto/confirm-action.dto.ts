export interface ConfirmActionDto {
  /** One of chat.tools.ts's WRITE_TOOLS — anything else is rejected. */
  tool: string;
  args: Record<string, unknown>;
}
