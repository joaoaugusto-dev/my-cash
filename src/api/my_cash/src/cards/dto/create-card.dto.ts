export interface CreateCardDto {
  name: string;
  brand: string;
  lastDigits: string;
  limitAmount: number;
  closingDay: number;
  /** Hex color chosen by the user for the card face, e.g. "#6D28D9". Optional — defaults server-side. */
  color?: string;
}
