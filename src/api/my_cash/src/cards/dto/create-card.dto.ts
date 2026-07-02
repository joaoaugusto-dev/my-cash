export interface CreateCardDto {
  name: string;
  brand: string;
  lastDigits: string;
  limitAmount: number;
  closingDay: number;
  dueDay: number;
}
