export type ChatRole = 'user' | 'assistant';

/** Audio formats Gemini accepts as inline input. */
export type ChatAudioFormat = 'wav' | 'mp3';

export type ChatContentPart =
  | { type: 'text'; text: string }
  /** `url` must be a `data:image/...;base64,` URI — remote URLs are rejected. */
  | { type: 'image_url'; image_url: { url: string } }
  | { type: 'input_audio'; input_audio: { data: string; format: ChatAudioFormat } };

export interface ChatMessageDto {
  role: ChatRole;
  /** Plain text, or multimodal parts when the user sent a photo/voice note. */
  content: string | ChatContentPart[];
}

export interface SendMessageDto {
  /** Full conversation so far, oldest first, ending with the new user message. */
  messages: ChatMessageDto[];
}
