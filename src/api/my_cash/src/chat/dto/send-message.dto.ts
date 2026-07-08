export type ChatRole = 'user' | 'assistant';

export interface ChatMessageDto {
  role: ChatRole;
  content: string;
}

export interface SendMessageDto {
  /** Full conversation so far, oldest first, ending with the new user message. */
  messages: ChatMessageDto[];
}
