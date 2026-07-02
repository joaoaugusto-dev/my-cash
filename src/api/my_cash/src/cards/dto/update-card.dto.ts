import { CreateCardDto } from './create-card.dto';

export interface UpdateCardDto extends Partial<CreateCardDto> {}
